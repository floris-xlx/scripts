#!/usr/bin/env python3
"""Resize every image in a folder to the same target dimensions."""

from __future__ import annotations

import argparse
import logging
from pathlib import Path
from typing import Sequence, Tuple

from PIL import Image, UnidentifiedImageError

SUPPORTED_SUFFIXES = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}


def collect_images(directory: Path) -> Sequence[Path]:
    """List all supported image files in `directory`, sorted alphabetically."""
    if not directory.exists():
        raise FileNotFoundError(f"{directory} does not exist")
    if not directory.is_dir():
        raise NotADirectoryError(f"{directory} is not a directory")

    return sorted(
        child
        for child in directory.iterdir()
        if child.is_file() and child.suffix.lower() in SUPPORTED_SUFFIXES
    )


def resize_image(
    source: Path,
    dest: Path,
    size: Tuple[int, int],
    keep_aspect_ratio: bool,
) -> None:
    """Resize `source` and write the result to `dest`. Respects the aspect ratio flag."""

    try:
        with Image.open(source) as img:
            img_format = img.format or dest.suffix.lstrip(".").upper() or "JPEG"

            if keep_aspect_ratio:
                resized = img.copy()
                resized.thumbnail(size, Image.LANCZOS)
            else:
                resized = img.resize(size, Image.LANCZOS)

            resized.save(dest, format=img_format)
    except UnidentifiedImageError as exc:
        raise ValueError(f"{source} is not a recognized image") from exc


def ensure_output_dir(path: Path, overwrite: bool) -> None:
    """Create the output directory, optionally clearing it first if overwrite is requested."""
    if path.exists():
        if overwrite:
            for child in path.iterdir():
                if child.is_file():
                    child.unlink()
        elif any(path.iterdir()):
            raise FileExistsError(f"{path} exists and is not empty; use --overwrite to clear it")
    else:
        path.mkdir(parents=True, exist_ok=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input_dir",
        type=Path,
        help="Directory that contains the images to resize.",
    )
    parser.add_argument(
        "width", type=int, help="Target width, in pixels, for every image."
    )
    parser.add_argument(
        "height", type=int, help="Target height, in pixels, for every image."
    )
    parser.add_argument(
        "--output-dir",
        "-o",
        type=Path,
        help="Where to write resized images (defaults to <input_dir>/resized).",
    )
    parser.add_argument(
        "--keep-aspect-ratio",
        "-k",
        action="store_true",
        help="Preserve the original aspect ratio and fit each image inside the requested dimensions.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Clear the output directory before writing new files.",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Log each processed file to stdout.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    size = (args.width, args.height)
    output_dir = args.output_dir or args.input_dir / "resized"

    logging.basicConfig(
        format="%(levelname)s: %(message)s",
        level=logging.INFO if args.verbose else logging.WARNING,
    )

    ensure_output_dir(output_dir, args.overwrite)
    images = collect_images(args.input_dir)

    if not images:
        logging.warning("No supported images found in %s", args.input_dir)
        return

    for image in images:
        destination = output_dir / image.name
        logging.info("Resizing %s → %s", image, destination)
        resize_image(image, destination, size, args.keep_aspect_ratio)

    logging.info("Resized %d image(s) into %s", len(images), output_dir)


if __name__ == "__main__":
    main()
