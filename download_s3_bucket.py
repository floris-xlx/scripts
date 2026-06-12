#!/usr/bin/env python3
"""Download an S3 bucket into a local folder while preserving key paths."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any

MANIFEST_NAME = ".s3-bucket-download-manifest.json"
SIMPLE_ETAG_PATTERN = re.compile(r"^[0-9a-fA-F]{32}$")


class Ansi:
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    RESET = "\033[0m"


@dataclass(frozen=True)
class ObjectInfo:
    key: str
    size: int
    etag: str | None
    last_modified: str


@dataclass
class DownloadResult:
    key: str
    relative_path: str
    size: int
    etag: str | None
    last_modified: str
    sha256: str
    status: str


class Console:
    def __init__(self, force_color: bool) -> None:
        self.force_color = force_color

    def _colorize(self, message: str, color: str) -> str:
        if self.force_color or sys.stdout.isatty():
            return f"{color}{message}{Ansi.RESET}"
        return message

    def info(self, message: str) -> None:
        print(self._colorize(message, Ansi.CYAN))

    def success(self, message: str) -> None:
        print(self._colorize(message, Ansi.GREEN))

    def warn(self, message: str) -> None:
        print(self._colorize(message, Ansi.YELLOW))

    def error(self, message: str) -> None:
        print(self._colorize(message, Ansi.RED), file=sys.stderr)


class ProgressTracker:
    def __init__(self, total_bytes: int, total_files: int, tqdm_cls: Any) -> None:
        self.total_files = total_files
        self.processed_files = 0
        self.skipped_files = 0
        self.reused_files = 0
        self.failed_files = 0
        self._lock = threading.Lock()
        self._bar = tqdm_cls(
            total=total_bytes,
            desc="Downloading",
            unit="B",
            unit_scale=True,
            unit_divisor=1024,
            dynamic_ncols=True,
            colour="green",
        )
        self._refresh_postfix()

    def callback(self, amount: int) -> None:
        with self._lock:
            self._bar.update(amount)

    def mark_completed(self) -> None:
        with self._lock:
            self.processed_files += 1
            self._refresh_postfix()

    def mark_skipped(self, size: int) -> None:
        with self._lock:
            self.processed_files += 1
            self.skipped_files += 1
            self._bar.update(size)
            self._refresh_postfix()

    def mark_reused(self, size: int) -> None:
        with self._lock:
            self.processed_files += 1
            self.reused_files += 1
            self._bar.update(size)
            self._refresh_postfix()

    def mark_failed(self) -> None:
        with self._lock:
            self.processed_files += 1
            self.failed_files += 1
            self._refresh_postfix()

    def close(self) -> None:
        with self._lock:
            self._bar.close()

    def _refresh_postfix(self) -> None:
        self._bar.set_postfix(
            files=f"{self.processed_files}/{self.total_files}",
            skipped=self.skipped_files,
            reused=self.reused_files,
            failed=self.failed_files,
            refresh=False,
        )


class SharedState:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.sha_index: dict[str, Path] = {}
        self.etag_index: dict[tuple[str, int], Path] = {}

    def register(self, sha256: str, etag: str | None, size: int, path: Path) -> None:
        with self.lock:
            self.sha_index.setdefault(sha256, path)
            if etag and is_simple_etag(etag):
                self.etag_index.setdefault((etag, size), path)

    def get_by_sha(self, sha256: str) -> Path | None:
        with self.lock:
            path = self.sha_index.get(sha256)
            return path if path and path.exists() else None

    def get_by_etag(self, etag: str | None, size: int) -> Path | None:
        if not etag or not is_simple_etag(etag):
            return None
        with self.lock:
            path = self.etag_index.get((etag, size))
            return path if path and path.exists() else None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bucket", help="S3 bucket name.")
    parser.add_argument(
        "destination",
        type=Path,
        help="Local folder that will receive the bucket contents.",
    )
    parser.add_argument(
        "--prefix",
        default="",
        help="Only download keys under this S3 prefix.",
    )
    parser.add_argument(
        "--profile",
        help="AWS profile to use for credentials.",
    )
    parser.add_argument(
        "--region",
        help="AWS region for the S3 client.",
    )
    parser.add_argument(
        "--endpoint-url",
        help="Optional custom endpoint for S3-compatible storage.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=min(16, max(4, (os.cpu_count() or 4) * 2)),
        help="Concurrent download worker count.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ignore the manifest and redownload every object.",
    )
    parser.add_argument(
        "--no-dedupe",
        action="store_true",
        help="Disable reuse of identical objects and local hardlink deduplication.",
    )
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable ANSI colored output.",
    )
    return parser.parse_args()


def require_module(module_name: str, pip_name: str) -> Any:
    try:
        return __import__(module_name)
    except ModuleNotFoundError as exc:
        raise SystemExit(
            f"Missing dependency '{module_name}'. Install it with: python -m pip install {pip_name}"
        ) from exc


def load_runtime_dependencies() -> tuple[Any, Any, Any]:
    boto3 = require_module("boto3", "boto3 tqdm")
    tqdm_module = require_module("tqdm", "boto3 tqdm")
    transfer_module = __import__("boto3.s3.transfer", fromlist=["TransferConfig"])
    return boto3, tqdm_module.tqdm, transfer_module.TransferConfig


def get_s3_client(args: argparse.Namespace, boto3: Any) -> Any:
    session_kwargs: dict[str, Any] = {}
    if args.profile:
        session_kwargs["profile_name"] = args.profile
    if args.region:
        session_kwargs["region_name"] = args.region

    session = boto3.session.Session(**session_kwargs)

    client_kwargs: dict[str, Any] = {}
    if args.endpoint_url:
        client_kwargs["endpoint_url"] = args.endpoint_url

    return session.client("s3", **client_kwargs)


def manifest_path_for(destination: Path) -> Path:
    return destination / MANIFEST_NAME


def source_signature(args: argparse.Namespace) -> dict[str, str]:
    return {
        "bucket": args.bucket,
        "endpoint_url": args.endpoint_url or "",
    }


def load_manifest(path: Path, expected_source: dict[str, str], console: Console) -> dict[str, Any]:
    if not path.exists():
        return {"source": expected_source, "objects": {}}

    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        console.warn(f"Manifest could not be read cleanly, starting fresh: {exc}")
        return {"source": expected_source, "objects": {}}

    if payload.get("source") != expected_source:
        console.warn("Existing manifest source does not match this bucket; ignoring old manifest entries.")
        return {"source": expected_source, "objects": {}}

    objects = payload.get("objects")
    if not isinstance(objects, dict):
        console.warn("Manifest format was invalid; ignoring old manifest entries.")
        return {"source": expected_source, "objects": {}}

    return {"source": expected_source, "objects": objects}


def save_manifest(path: Path, manifest: dict[str, Any]) -> None:
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")


def build_target_path(destination: Path, key: str) -> Path:
    key_path = PurePosixPath(key.lstrip("/"))
    parts = [part for part in key_path.parts if part not in ("", ".")]
    if not parts:
        raise ValueError(f"Object key '{key}' does not map to a local file path")
    if any(part == ".." for part in parts):
        raise ValueError(f"Refusing to write unsafe object key '{key}'")
    return destination.joinpath(*parts)


def relative_posix_path(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def is_simple_etag(etag: str | None) -> bool:
    return bool(etag and SIMPLE_ETAG_PATTERN.fullmatch(etag))


def isoformat_utc(value: datetime) -> str:
    return value.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def list_bucket_objects(client: Any, bucket: str, prefix: str) -> list[ObjectInfo]:
    paginator = client.get_paginator("list_objects_v2")
    objects: list[ObjectInfo] = []

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for raw in page.get("Contents", []):
            key = raw["Key"]
            if key.endswith("/") and raw["Size"] == 0:
                continue

            objects.append(
                ObjectInfo(
                    key=key,
                    size=raw["Size"],
                    etag=(raw.get("ETag") or "").strip('"') or None,
                    last_modified=isoformat_utc(raw["LastModified"]),
                )
            )

    return objects


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def should_skip_download_for_path(
    obj: ObjectInfo,
    target: Path,
    manifest_entry: dict[str, Any] | None,
    destination: Path,
    force: bool,
) -> bool:
    if force or not target.exists() or not target.is_file() or manifest_entry is None:
        return False

    return (
        manifest_entry.get("relative_path") == relative_posix_path(target, destination)
        and manifest_entry.get("size") == obj.size
        and manifest_entry.get("etag") == obj.etag
        and manifest_entry.get("last_modified") == obj.last_modified
    )


def ensure_hardlinked_copy(source: Path, target: Path) -> str:
    if target.exists():
        target.unlink()

    try:
        os.link(source, target)
        return "hardlinked"
    except OSError:
        shutil.copy2(source, target)
        return "copied"


def reuse_known_duplicate(
    obj: ObjectInfo,
    target: Path,
    destination: Path,
    state: SharedState,
    dedupe_enabled: bool,
) -> DownloadResult | None:
    if not dedupe_enabled:
        return None

    canonical = state.get_by_etag(obj.etag, obj.size)
    if canonical is None or canonical == target:
        return None

    target.parent.mkdir(parents=True, exist_ok=True)
    reuse_mode = ensure_hardlinked_copy(canonical, target)
    sha256 = hash_file(canonical)
    state.register(sha256, obj.etag, obj.size, canonical)
    return DownloadResult(
        key=obj.key,
        relative_path=relative_posix_path(target, destination),
        size=obj.size,
        etag=obj.etag,
        last_modified=obj.last_modified,
        sha256=sha256,
        status=f"reused:{reuse_mode}",
    )


def finalize_download(
    temp_path: Path,
    target: Path,
    destination: Path,
    obj: ObjectInfo,
    state: SharedState,
    dedupe_enabled: bool,
) -> DownloadResult:
    sha256 = hash_file(temp_path)
    target.parent.mkdir(parents=True, exist_ok=True)

    if target.exists():
        target.unlink()

    canonical = state.get_by_sha(sha256) if dedupe_enabled else None
    if canonical is not None and canonical != target:
        dedupe_mode = ensure_hardlinked_copy(canonical, target)
        temp_path.unlink(missing_ok=True)
        state.register(sha256, obj.etag, obj.size, canonical)
        return DownloadResult(
            key=obj.key,
            relative_path=relative_posix_path(target, destination),
            size=obj.size,
            etag=obj.etag,
            last_modified=obj.last_modified,
            sha256=sha256,
            status=f"deduped:{dedupe_mode}",
        )

    shutil.move(str(temp_path), str(target))
    state.register(sha256, obj.etag, obj.size, target)
    return DownloadResult(
        key=obj.key,
        relative_path=relative_posix_path(target, destination),
        size=obj.size,
        etag=obj.etag,
        last_modified=obj.last_modified,
        sha256=sha256,
        status="downloaded",
    )


def seed_state_from_manifest(
    manifest_objects: dict[str, Any],
    destination: Path,
    state: SharedState,
) -> None:
    for entry in manifest_objects.values():
        relative_path = entry.get("relative_path")
        sha256 = entry.get("sha256")
        size = entry.get("size")
        etag = entry.get("etag")
        if not isinstance(relative_path, str) or not isinstance(sha256, str):
            continue
        if not isinstance(size, int):
            continue

        path = destination / Path(relative_path)
        if path.exists():
            state.register(sha256, etag if isinstance(etag, str) else None, size, path)


def download_object(
    client: Any,
    transfer_config: Any,
    bucket: str,
    destination: Path,
    manifest_objects: dict[str, Any],
    state: SharedState,
    progress: ProgressTracker,
    obj: ObjectInfo,
    force: bool,
    dedupe_enabled: bool,
) -> DownloadResult:
    target = build_target_path(destination, obj.key)
    manifest_entry = manifest_objects.get(obj.key)

    if should_skip_download_for_path(obj, target, manifest_entry, destination, force):
        sha256 = manifest_entry.get("sha256")
        if isinstance(sha256, str):
            state.register(sha256, obj.etag, obj.size, target)
        progress.mark_skipped(obj.size)
        return DownloadResult(
            key=obj.key,
            relative_path=relative_posix_path(target, destination),
            size=obj.size,
            etag=obj.etag,
            last_modified=obj.last_modified,
            sha256=sha256 if isinstance(sha256, str) else "",
            status="skipped",
        )

    reused = reuse_known_duplicate(obj, target, destination, state, dedupe_enabled)
    if reused is not None:
        progress.mark_reused(obj.size)
        return reused

    target.parent.mkdir(parents=True, exist_ok=True)
    temp_path = target.parent / f"{target.name}.part-{threading.get_ident()}"
    if temp_path.exists():
        temp_path.unlink()

    try:
        client.download_file(
            bucket,
            obj.key,
            str(temp_path),
            Callback=progress.callback,
            Config=transfer_config,
        )
        result = finalize_download(temp_path, target, destination, obj, state, dedupe_enabled)
        progress.mark_completed()
        return result
    finally:
        if temp_path.exists():
            temp_path.unlink(missing_ok=True)


def main() -> None:
    args = parse_args()
    console = Console(force_color=not args.no_color)
    boto3, tqdm_cls, transfer_config_cls = load_runtime_dependencies()

    if args.workers < 1:
        raise SystemExit("--workers must be at least 1")

    destination = args.destination.expanduser().resolve()
    destination.mkdir(parents=True, exist_ok=True)

    manifest_path = manifest_path_for(destination)
    manifest = load_manifest(manifest_path, source_signature(args), console)
    manifest_objects: dict[str, Any] = manifest["objects"]

    client = get_s3_client(args, boto3)
    transfer_config = transfer_config_cls(use_threads=False)

    console.info(
        f"Listing s3://{args.bucket}/{args.prefix} into {destination}"
    )
    objects = list_bucket_objects(client, args.bucket, args.prefix)
    total_bytes = sum(obj.size for obj in objects)

    if not objects:
        console.warn("No objects matched the requested bucket/prefix.")
        return

    console.info(
        f"Found {len(objects)} object(s), total size {total_bytes:,} bytes."
    )

    state = SharedState()
    seed_state_from_manifest(manifest_objects, destination, state)
    progress = ProgressTracker(total_bytes=total_bytes, total_files=len(objects), tqdm_cls=tqdm_cls)
    failures: list[tuple[str, str]] = []
    results: dict[str, DownloadResult] = {}

    try:
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            future_map = {
                executor.submit(
                    download_object,
                    client,
                    transfer_config,
                    args.bucket,
                    destination,
                    manifest_objects,
                    state,
                    progress,
                    obj,
                    args.force,
                    not args.no_dedupe,
                ): obj
                for obj in objects
            }

            for future in as_completed(future_map):
                obj = future_map[future]
                try:
                    result = future.result()
                    results[obj.key] = result
                except Exception as exc:
                    progress.mark_failed()
                    failures.append((obj.key, str(exc)))
    finally:
        progress.close()

    for key, result in results.items():
        manifest_objects[key] = {
            "relative_path": result.relative_path,
            "sha256": result.sha256,
            "size": result.size,
            "etag": result.etag,
            "last_modified": result.last_modified,
            "status": result.status,
        }

    save_manifest(manifest_path, manifest)

    downloaded_count = sum(1 for result in results.values() if result.status == "downloaded")
    deduped_count = sum(1 for result in results.values() if result.status.startswith("deduped:"))
    reused_count = sum(1 for result in results.values() if result.status.startswith("reused:"))
    skipped_count = sum(1 for result in results.values() if result.status == "skipped")

    console.success(
        f"Finished: downloaded={downloaded_count}, deduped={deduped_count}, reused={reused_count}, skipped={skipped_count}, failed={len(failures)}"
    )
    console.info(f"Manifest written to {manifest_path}")

    if failures:
        for key, message in failures[:10]:
            console.error(f"{key}: {message}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
