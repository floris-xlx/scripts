import argparse
import asyncio
import json
import logging
import os
import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional
from datetime import date, datetime
from uuid import UUID

import asyncpg
import httpx
from supabase import create_client
from tqdm import tqdm

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("pg-typesense-sync")

DEFAULT_TYPESENSE_API_KEY = os.environ.get(
    "TYPESENSE_API_KEY", "xxxxxxxx"
)
DEFAULT_TYPESENSE_HOST = os.environ.get(
    "TYPESENSE_HOST", "https://example.com"
)


@dataclass
class SyncConfig:
    table_name: str
    collection_name: str
    chunk_size: int
    batch_size: int
    global_limit: Optional[int]
    id_column: Optional[str]
    drop_collection: bool
    pg_uri: Optional[str]
    supabase_project_ref: Optional[str]
    supabase_anon_key: Optional[str]
    typesense_host: str = DEFAULT_TYPESENSE_HOST
    typesense_api_key: str = DEFAULT_TYPESENSE_API_KEY
    callback_url: Optional[str] = None
    callback_headers: Dict[str, str] = None
    failed_batch_log: str = "failed_typesense_batches.log"
    metrics: Dict[str, int] = field(
        default_factory=lambda: {
            "total_batches": 0,
            "failed_batches": 0,
            "successful_docs": 0,
        }
    )
    metrics_lock: Optional[asyncio.Lock] = None

    @property
    def supabase_url(self) -> Optional[str]:
        if self.supabase_project_ref:
            return f"https://{self.supabase_project_ref}.supabase.co"
        return None


def parse_args() -> SyncConfig:
    parser = argparse.ArgumentParser(
        description="Sync data from Supabase or PostgreSQL into Typesense"
    )
    parser.add_argument("table_name", help="Table to fetch from Supabase/Postgres")
    parser.add_argument("collection_name", help="Typesense collection to create/index")
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=2500,
        help="Batch size to fetch rows (default: 2500)",
    )
    parser.add_argument(
        "--id-column",
        help="Column name to use as default sorting field (e.g., story_id)",
    )
    parser.add_argument(
        "--global-limit", type=int, help="Global limit on the number of rows to fetch"
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=50,
        help="Batch size for indexing to Typesense (default: 50)",
    )
    parser.add_argument(
        "--drop-collection",
        action="store_true",
        help="Drop the Typesense collection before syncing",
    )
    parser.add_argument(
        "--pg-uri",
        "--postgresql-url",
        dest="pg_uri",
        help="PostgreSQL connection URI (takes precedence over Supabase credentials)",
    )
    parser.add_argument(
        "--supabase-anon-key",
        help="Supabase anon key (fall back to SUPABASE_ANON_KEY env var)",
    )
    parser.add_argument(
        "--supabase-project-ref",
        help="Supabase project ref (e.g., abcd1234, falls back to SUPABASE_PROJECT_REF env var)",
    )
    parser.add_argument(
        "--typesense-host",
        default=DEFAULT_TYPESENSE_HOST,
        help="Typesense host URL (defaults to production URI)",
    )
    parser.add_argument(
        "--typesense-api-key",
        default=DEFAULT_TYPESENSE_API_KEY,
        help="Typesense API key (can also be set via TYPESENSE_API_KEY env var)",
    )
    parser.add_argument(
        "--failed-batch-log",
        default="failed_typesense_batches.log",
        help="File path to append failed Typesense batch metadata",
    )
    parser.add_argument(
        "--callback-url",
        help="URL to POST to after each successful Typesense batch import",
    )
    parser.add_argument(
        "--callback-header",
        action="append",
        default=[],
        help="Additional header for callback as 'Key:Value'; can repeat",
    )

    args = parser.parse_args()
    supabase_ref = args.supabase_project_ref or os.environ.get("SUPABASE_PROJECT_REF")
    supabase_key = args.supabase_anon_key or os.environ.get("SUPABASE_ANON_KEY")

    if not args.pg_uri and not (supabase_ref and supabase_key):
        parser.error(
            "Provide either --pg-uri/--postgresql-url or both supabase project ref and anon key."
        )

    if args.pg_uri:
        supabase_ref = None
        supabase_key = None

    headers = {}
    for header in args.callback_header:
        if ":" not in header:
            parser.error("callback headers must be in 'Key:Value' format")
        key, value = header.split(":", 1)
        headers[key.strip()] = value.strip()

    return SyncConfig(
        table_name=args.table_name,
        collection_name=args.collection_name,
        chunk_size=args.chunk_size,
        batch_size=args.batch_size,
        global_limit=args.global_limit,
        id_column=args.id_column,
        drop_collection=args.drop_collection,
        pg_uri=args.pg_uri,
        supabase_project_ref=supabase_ref,
        supabase_anon_key=supabase_key,
        typesense_host=args.typesense_host,
        typesense_api_key=args.typesense_api_key,
        failed_batch_log=args.failed_batch_log,
        callback_url=args.callback_url,
        callback_headers=headers if headers else None,
    )


def infer_typesense_type(value: Any) -> Optional[str]:
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int64"
    if isinstance(value, float):
        return "float"
    if isinstance(value, str):
        return "string"
    return None


COMMON_COLUMN_TYPES = {
    "link": "string",
    "full_name": "string",
    "location": "string",
    "avatar_url": "string",
    "zip": "string",
    "address_street": "string",
    "city_name": "string",
    "follower_count": "int64",
    "following_count": "int64",
    "is_business": "bool",
    "status": "string",
    "media_count": "int64",
    "dexter_id": "int64",
    "ondernemings_nr": "string",
    "adress": "string",
    "date": "string",
    "ent": "string",
    "company_name": "string",
    "company_status": "string",
    "incorporation_date": "string",
    "company_number": "string",
    "registered_office_address": "string",
    "vinted_id": "int64",
    "age": "int64",
    "instagram_private": "bool",
    "media_count": "int64",
    "rights_form": "string",
    "last_update": "string",
    "description": "string",
    "region": "string",
    "rights_form_code": "string",
    "name_english": "string",
    "legal_persons": "string",
    "contact_data": "string",
    "activities": "string",
    "activity_code_table": "string",
    "establishment_type": "string",
}

BANNED_FIELDS = {
    "occupations",
    "cup_sizes",
    "clothing_sizes",
    "age",
    "instagram_private",
    "account_type",
    "date",
    "first_seen",
    "is_business",
    "last_updated",
    "media_count",
    "index",
    "follower_count",
    "following_count",
    "establishment",
    "house_number",
    "main_sbi_code",
    "active",
    "vinted_id",
    "price_unit",
    "last_updated_at",
    "last_aggregated_at",
    "post_count",
}


def validate_table_name(table_name: str) -> str:
    if not re.match(r"^[\w\.]+$", table_name):
        raise ValueError(f"Invalid table name '{table_name}'.")
    return table_name


def clean_record(record: Dict[str, Any]) -> Dict[str, Any]:
    return {k: v for k, v in record.items() if k not in BANNED_FIELDS}


def coerce_value(value: Any) -> Any:
    if value is None:
        return ""
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, UUID):
        return str(value)
    return value


def build_typesense_schema_from_sample(
    collection_name: str, sample_row: Dict[str, Any]
) -> Dict[str, Any]:
    fields: List[Dict[str, Any]] = []
    for key, value in sample_row.items():
        if key in BANNED_FIELDS:
            logger.info(f"Skipping banned field '{key}'")
            continue
        ts_type = COMMON_COLUMN_TYPES.get(key)
        if ts_type:
            try:
                if ts_type == "int64":
                    value = int(value)
                elif ts_type == "float":
                    value = float(value)
                elif ts_type == "bool":
                    value = bool(value)
                elif ts_type == "string":
                    value = "" if value is None else str(value)
            except (ValueError, TypeError) as e:
                logger.warning(f"Skipping field '{key}' due to casting error: {e}")
                continue
        else:
            ts_type = infer_typesense_type(value)
            if ts_type == "string":
                value = "" if value is None else str(value)
        if not ts_type:
            logger.warning(
                f"Skipping field '{key}' (unsupported or null type: {type(value).__name__})"
            )
            continue
        fields.append({"name": key, "type": ts_type, "optional": True})

    if not fields:
        raise ValueError("Could not infer any valid fields from sample row.")

    default_sort = next(
        (f["name"] for f in fields if f["type"] in ["int64", "float", "string"]),
        fields[0]["name"],
    )

    try:
        with open(f"{collection_name}_fields.txt", "w", encoding="utf-8") as f:
            for field in fields:
                f.write(f"{field['name']}: {field['type']}\n")
    except Exception as e:
        logger.warning(f"Could not write fields to txt: {e}")

    return {
        "name": collection_name,
        "fields": fields,
        "default_sorting_field": default_sort,
    }


async def fetch_sample_row_from_supabase(supabase, table_name: str) -> Dict[str, Any]:
    logger.info(f"Fetching sample row from Supabase table '{table_name}'")
    try:
        response = supabase.table(table_name).select("*").limit(1).execute()
        sample = response.data[0] if response.data else {}
        if not sample:
            raise ValueError("No data found to infer schema.")
        return sample
    except Exception as e:
        logger.exception(f"Failed to fetch sample row: {e}")
        raise


async def fetch_all_rows_from_supabase(
    supabase, table: str, chunk_size: int, global_limit: Optional[int] = None
) -> List[Dict[str, Any]]:
    all_data = []
    offset = 0
    logger.info("Starting to fetch data from Supabase...")
    pbar = tqdm(total=global_limit, desc="Fetching data")
    current_chunk_size = chunk_size
    consecutive_successes = 0
    prev_chunk_before_growth = current_chunk_size
    while True:
        try:
            if global_limit and offset >= global_limit:
                break
            resp = (
                supabase.table(table)
                .select("*")
                .range(offset, offset + current_chunk_size - 1)
                .execute()
            )
            data = resp.data
            if not data:
                break
            cleaned_data = [clean_record(row) for row in data]
            all_data.extend(cleaned_data)
            pbar.update(len(data))
            offset += len(data)
            if global_limit and len(all_data) >= global_limit:
                all_data = all_data[:global_limit]
                break
            consecutive_successes += 1
            if consecutive_successes >= 10:
                prev_chunk_before_growth = current_chunk_size
                new_size = max(10, int(current_chunk_size * 1.5))
                logger.info(f"Increasing chunk size to {new_size}")
                current_chunk_size = new_size
                consecutive_successes = 0
        except Exception as e:
            if (
                "statement timeout" in str(e) or "read operation timed out" in str(e)
            ) and current_chunk_size > 10:
                reduced = max(10, (prev_chunk_before_growth or current_chunk_size // 2))
                current_chunk_size = reduced
                logger.warning(
                    f"Query timed out. Reducing chunk size to {current_chunk_size} and retrying. after 4 seconds"
                )
                await asyncio.sleep(12)
                consecutive_successes = 0
            else:
                logger.error(f"Failed to fetch data: {e}")
                raise
    pbar.close()
    return all_data


async def fetch_sample_row_from_postgres(
    pool: asyncpg.Pool, table_name: str
) -> Dict[str, Any]:
    sanitized = validate_table_name(table_name)
    logger.info(f"Fetching sample row from Postgres table '{sanitized}'")
    try:
        async with pool.acquire() as conn:
            row = await conn.fetchrow(f"SELECT * FROM {sanitized} LIMIT 1")
            if not row:
                raise ValueError("No data found to infer schema.")
            return dict(row)
    except Exception as e:
        logger.exception(f"Failed to fetch sample row from Postgres: {e}")
        raise


async def fetch_all_rows_from_postgres(
    pool: asyncpg.Pool, table_name: str, chunk_size: int, global_limit: Optional[int] = None
) -> List[Dict[str, Any]]:
    sanitized = validate_table_name(table_name)
    all_data: List[Dict[str, Any]] = []
    offset = 0
    logger.info(f"Starting to fetch data from Postgres table '{sanitized}'...")
    pbar = tqdm(total=global_limit, desc="Fetching data")
    current_chunk_size = chunk_size
    consecutive_successes = 0
    prev_chunk_before_growth = current_chunk_size
    async with pool.acquire() as conn:
        while True:
            if global_limit and offset >= global_limit:
                break
            limit = current_chunk_size
            if global_limit:
                remaining = global_limit - offset
                if remaining <= 0:
                    break
                limit = min(limit, remaining)
            query = f"SELECT * FROM {sanitized} OFFSET {offset} LIMIT {limit}"
            try:
                rows = await conn.fetch(query)
                if not rows:
                    break
                cleaned_data = [clean_record(dict(row)) for row in rows]
                all_data.extend(cleaned_data)
                pbar.update(len(rows))
                offset += len(rows)
                if global_limit and len(all_data) >= global_limit:
                    all_data = all_data[:global_limit]
                    break
                consecutive_successes += 1
                if consecutive_successes >= 10:
                    prev_chunk_before_growth = current_chunk_size
                    new_size = max(10, int(current_chunk_size * 1.5))
                    logger.info(f"Increasing chunk size to {new_size}")
                    current_chunk_size = new_size
                    consecutive_successes = 0
            except Exception as e:
                if (
                    "statement timeout" in str(e)
                    or "read operation timed out" in str(e)
                ) and current_chunk_size > 10:
                    reduced = max(10, (prev_chunk_before_growth or current_chunk_size // 2))
                    current_chunk_size = reduced
                    logger.warning(
                        f"Query timed out. Reducing chunk size to {current_chunk_size} and retrying. after 4 seconds"
                    )
                    await asyncio.sleep(12)
                    consecutive_successes = 0
                    continue
                logger.error(f"Postgres fetch failed: {e}")
                raise
    pbar.close()
    return all_data


def finalize_schema(
    schema: Dict[str, Any], data: List[Dict[str, Any]], id_column: Optional[str]
) -> Dict[str, Any]:
    fields = [field for field in schema["fields"] if field["name"] != "id"]
    if not fields:
        raise ValueError("Schema had no valid fields after removing 'id'.")

    formatted_fields: List[Dict[str, Any]] = []
    for field in fields:
        field_name = field["name"]
        field_type = field["type"]
        formatted_field = {
            "name": field_name,
            "type": field_type,
            "optional": field.get("optional", True),
        }
        if "id" in field_name.lower() and field_type in ["int64", "string"]:
            formatted_field["facet"] = True
        formatted_fields.append(formatted_field)

    schema["fields"] = formatted_fields

    default_sort = id_column or schema.get("default_sorting_field")
    field_names = [field["name"] for field in formatted_fields]
    if not default_sort or default_sort not in field_names:
        default_sort = next(
            (name for name in field_names if "id" in name.lower() and len(name) > 3),
            field_names[0],
        )
    schema["default_sorting_field"] = default_sort

    field_types = {field["name"]: field["type"] for field in formatted_fields}
    default_type = field_types.get(default_sort)
    if default_type not in ["int64", "float"]:
        logger.info(
            f"Default sorting field '{default_sort}' is not numeric. Adding row_id field."
        )
        schema["fields"].append({"name": "row_id", "type": "int64", "optional": False})
        schema["default_sorting_field"] = "row_id"
        for idx, record in enumerate(data, start=1):
            record["row_id"] = idx
    else:
        for field in schema["fields"]:
            if field["name"] == schema["default_sorting_field"]:
                field["optional"] = False
                break

    for field in schema["fields"]:
        if isinstance(field["name"], str):
            field["name"] = field["name"].replace("'", '"')
        if isinstance(field["type"], str):
            field["type"] = field["type"].replace("'", '"')

    required_keys = ["name", "fields", "default_sorting_field"]
    for key in required_keys:
        if key not in schema:
            raise ValueError(f"Missing required key in schema: {key}")

    return schema


async def maybe_drop_typesense_collection(config: SyncConfig):
    if not config.drop_collection:
        return
    url = f"{config.typesense_host.rstrip('/')}/collections/{config.collection_name}"
    logger.info(
        f"Attempting to drop Typesense collection '{config.collection_name}'..."
    )
    async with httpx.AsyncClient() as client:
        try:
            response = await client.delete(
                url,
                headers={"X-TYPESENSE-API-KEY": config.typesense_api_key},
            )
            if response.status_code in [200, 204]:
                logger.info(
                    f"Collection '{config.collection_name}' dropped successfully."
                )
            elif response.status_code == 404:
                logger.info(
                    f"Collection '{config.collection_name}' does not exist (404)."
                )
            else:
                logger.error(
                    f"Failed to drop collection: {response.status_code} - {response.text}"
                )
        except Exception as e:
            logger.error(f"Error while dropping collection: {e}")


async def create_typesense_collection(schema: Dict[str, Any], config: SyncConfig):
    host = config.typesense_host.rstrip("/")
    async with httpx.AsyncClient(timeout=10.0) as client:
        delete_url = f"{host}/collections/{schema['name']}"
        try:
            del_resp = await client.delete(
                delete_url,
                headers={"X-TYPESENSE-API-KEY": config.typesense_api_key},
            )
            if del_resp.status_code in [200, 204]:
                logger.info(f"Deleted existing collection '{schema['name']}'")
            else:
                logger.debug(
                    f"No existing collection to delete or delete failed: {del_resp.status_code} - {del_resp.text}"
                )
        except Exception as e:
            logger.warning(f"Exception during collection delete: {e}")

        try:
            logger.info(f"Creating collection with {len(schema['fields'])} fields")
            if not schema.get("name") or not schema.get("fields"):
                raise ValueError("Invalid schema: 'name' and 'fields' are required.")
            schema_json = json.dumps(schema)
            response = await client.post(
                f"{host}/collections",
                headers={
                    "X-TYPESENSE-API-KEY": config.typesense_api_key,
                    "Content-Type": "application/json",
                },
                data=schema_json,
            )
            if response.status_code in [200, 201]:
                logger.info("Collection created successfully.")
            elif response.status_code == 409:
                logger.info(f"Collection already exists (409): {response.text}")
            else:
                logger.error(
                    f"Failed to create collection: {response.status_code} - {response.text}"
                )
                raise Exception("Collection creation failed")
        except httpx.HTTPStatusError as he:
            logger.error(
                f"HTTP error while creating collection: {he.response.status_code} - {he.response.text}"
            )
            raise
        except httpx.RequestError as re:
            logger.error(f"Connection error while creating collection: {re}")
            raise


async def maybe_notify_callback(
    config: SyncConfig,
    collection_name: str,
    batch_start: int,
    batch_size: int,
    added: int,
):
    if (
        not config.callback_url
        or not added
        or not config.callback_url.strip()
    ):
        return
    payload = {
        "collection": collection_name,
        "batch_start": batch_start,
        "batch_size": batch_size,
        "added": added,
    }
    headers = {"Content-Type": "application/json"}
    if config.callback_headers:
        headers.update(config.callback_headers)
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                config.callback_url, json=payload, headers=headers, timeout=30
            )
            if response.status_code not in (200, 201, 202, 204):
                logger.warning(
                    f"Callback to {config.callback_url} returned {response.status_code}"
                )
    except Exception as exc:
        logger.warning(f"Callback POST failed: {exc}")


def record_failed_batch(
    config: SyncConfig,
    collection_name: str,
    batch_start: int,
    batch_size: int,
    reason: str,
):
    if not config.failed_batch_log:
        return
    entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "collection": collection_name,
        "batch_start": batch_start,
        "batch_size": batch_size,
        "reason": reason,
    }
    try:
        with open(config.failed_batch_log, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception as exc:
        logger.warning(f"Could not write failed batch log: {exc}")


async def push_to_typesense(
    data: List[Dict[str, Any]],
    collection_name: str,
    config: SyncConfig,
    batch_size: int = 50,
    global_limit: Optional[int] = None,
    start_index: int = 0,
):
    banned_fields = set(BANNED_FIELDS)
    if global_limit is not None:
        data = data[:global_limit]
    logger.info(
        f"Indexing {len(data)} records into Typesense collection '{collection_name}'"
    )
    host = config.typesense_host.rstrip("/")
    async with httpx.AsyncClient(timeout=60.0) as client:
        pbar = tqdm(total=len(data), desc="Indexing to Typesense")
        i = 0
        while i < len(data):
            if global_limit is not None and i >= global_limit:
                break
            end_index = i + batch_size
            if global_limit is not None:
                end_index = min(end_index, global_limit)
            batch = data[i:end_index]
            jsonl_data = ""
            for record in batch:
                for banned in banned_fields:
                    record.pop(banned, None)
                record.pop("id", None)
                if "dexter_id" in record:
                    try:
                        record["dexter_id"] = int(record["dexter_id"])
                    except (ValueError, TypeError):
                        record["dexter_id"] = 0
                if "kvk_number" in record:
                    try:
                        kvk_val = record["kvk_number"]
                        if isinstance(kvk_val, str):
                            kvk_val = kvk_val.strip().replace("-", "").replace(" ", "")
                        record["kvk_number"] = int(kvk_val)
                    except (ValueError, TypeError, AttributeError):
                        record["kvk_number"] = 0
                for k, v in list(record.items()):
                    record[k] = coerce_value(v)
                jsonl_data += json.dumps(record) + "\n"
            if jsonl_data.endswith("\n"):
                jsonl_data = jsonl_data[:-1]
            max_retries = 3
            attempt = 0
            if config.metrics_lock:
                async with config.metrics_lock:
                    config.metrics["total_batches"] += 1
            batch_success_count = 0
            reason = ""
            batch_failed = True
            while attempt < max_retries:
                try:
                    url = f"{host}/collections/{collection_name}/documents/import?action=upsert"
                    logger.debug(f"Posting batch {i}-{end_index} to {url}, size={len(jsonl_data)} bytes")
                    response = await client.post(
                        url,
                        headers={
                            "X-TYPESENSE-API-KEY": config.typesense_api_key,
                            "Content-Type": "application/json",
                        },
                        content=jsonl_data,
                    )
                    logger.debug(f"Response status: {response.status_code}")
                    if response.status_code == 413:
                        batch_size = max(10, batch_size // 2)
                        reason = "request too large"
                        logger.warning(
                            f"Request too large. Reducing batch size to {batch_size} and retrying."
                        )
                        break
                    if response.status_code != 200:
                        reason = response.text
                        attempt += 1
                        logger.warning(f"Failed to index batch: {reason}")
                        if attempt < max_retries:
                            await asyncio.sleep(2 * attempt)
                            continue
                        break
                    response_lines = response.text.strip().split("\n")
                    success_in_batch = 0
                    for j, line in enumerate(response_lines):
                        try:
                            result = json.loads(line)
                            if not result.get("success", False):
                                logger.warning(
                                    f"Failed to index document {i+j}: {line}"
                                )
                            else:
                                success_in_batch += 1
                        except json.JSONDecodeError:
                            logger.warning(f"Could not parse response line: {line}")
                    batch_success_count = success_in_batch
                    reason = "success"
                    batch_failed = False
                    await maybe_notify_callback(
                        config,
                        collection_name,
                        start_index,
                        len(batch),
                        batch_success_count,
                    )
                    async with config.metrics_lock:
                        config.metrics["successful_documents"] += batch_success_count
                    break
                except (
                    httpx.RequestError,
                    httpx.TimeoutException,
                    httpx.ConnectError,
                ) as e:
                    attempt += 1
                    reason = str(e)
                    logger.error(
                        f"Network error indexing batch (attempt {attempt}/{max_retries}): {e}"
                    )
                    if attempt < max_retries:
                        await asyncio.sleep(2 * attempt)
                        continue
                    logger.error(
                        f"Giving up on this batch after {max_retries} attempts."
                    )
                    break
                except Exception as e:
                    reason = str(e)
                    logger.error(f"Error indexing batch: {e}")
                    raise
            if batch_failed:
                async with config.metrics_lock:
                    config.metrics["failed_batches"] += 1
                record_failed_batch(
                    config,
                    collection_name,
                    start_index,
                    len(batch),
                    reason or "unknown failure",
                )
            pbar.update(len(batch))
            i += len(batch)
        pbar.close()


async def push_to_typesense_with_workers(
    data: List[Dict[str, Any]],
    collection_name: str,
    config: SyncConfig,
    batch_size: int,
    num_workers: int = 5,
):
    """Push data to Typesense using concurrent workers, each handling one batch at a time."""
    semaphore = asyncio.Semaphore(num_workers)
    total = len(data)
    pbar = tqdm(total=total, desc="Indexing to Typesense")
    banned_fields = set(BANNED_FIELDS)
    host = config.typesense_host.rstrip("/")

    async def worker(batch: List[Dict[str, Any]], batch_index: int):
        async with semaphore:
            logger.info(f"Worker starting batch {batch_index}, size {len(batch)}")
            
            # Prepare JSONL payload
            jsonl_data = ""
            for record in batch:
                for banned in banned_fields:
                    record.pop(banned, None)
                record.pop("id", None)
                if "dexter_id" in record:
                    try:
                        record["dexter_id"] = int(record["dexter_id"])
                    except (ValueError, TypeError):
                        record["dexter_id"] = 0
                if "kvk_number" in record:
                    try:
                        kvk_val = record["kvk_number"]
                        if isinstance(kvk_val, str):
                            kvk_val = kvk_val.strip().replace("-", "").replace(" ", "")
                        record["kvk_number"] = int(kvk_val)
                    except (ValueError, TypeError, AttributeError):
                        record["kvk_number"] = 0
                for k, v in list(record.items()):
                    record[k] = coerce_value(v)
                jsonl_data += json.dumps(record) + "\n"
            
            if jsonl_data.endswith("\n"):
                jsonl_data = jsonl_data[:-1]
            
            if config.metrics_lock:
                async with config.metrics_lock:
                    config.metrics["total_batches"] += 1
            
            # Post to Typesense
            max_retries = 3
            attempt = 0
            batch_success_count = 0
            reason = ""
            
            async with httpx.AsyncClient(timeout=60.0) as client:
                while attempt < max_retries:
                    try:
                        url = f"{host}/collections/{collection_name}/documents/import?action=upsert"
                        logger.debug(f"POST {url}, batch {batch_index}, {len(jsonl_data)} bytes")
                        
                        response = await client.post(
                            url,
                            headers={
                                "X-TYPESENSE-API-KEY": config.typesense_api_key,
                                "Content-Type": "application/json",
                            },
                            content=jsonl_data,
                        )
                        logger.debug(f"Batch {batch_index} response: {response.status_code}")
                        
                        if response.status_code == 413:
                            reason = "request too large"
                            logger.warning(f"Batch {batch_index} too large")
                            break
                        
                        if response.status_code != 200:
                            reason = response.text
                            attempt += 1
                            logger.warning(f"Batch {batch_index} failed: {reason}")
                            if attempt < max_retries:
                                await asyncio.sleep(2 * attempt)
                                continue
                            break
                        
                        # Parse success count
                        response_lines = response.text.strip().split("\n")
                        for j, line in enumerate(response_lines):
                            try:
                                result = json.loads(line)
                                if result.get("success", False):
                                    batch_success_count += 1
                                else:
                                    logger.warning(f"Doc {batch_index+j} failed: {line}")
                            except json.JSONDecodeError:
                                logger.warning(f"Could not parse: {line}")
                        
                        if config.metrics_lock:
                            async with config.metrics_lock:
                                config.metrics["successful_docs"] += batch_success_count
                        
                        logger.info(f"Batch {batch_index} indexed {batch_success_count}/{len(batch)} docs")
                        
                        await maybe_notify_callback(
                            config, collection_name, batch_index, len(batch), batch_success_count
                        )
                        break
                        
                    except (httpx.RequestError, httpx.TimeoutException, httpx.ConnectError) as e:
                        attempt += 1
                        reason = str(e)
                        logger.error(f"Batch {batch_index} network error (attempt {attempt}/{max_retries}): {e}")
                        if attempt < max_retries:
                            await asyncio.sleep(2 * attempt)
                            continue
                        logger.error(f"Batch {batch_index} failed after {max_retries} attempts")
                        if config.metrics_lock:
                            async with config.metrics_lock:
                                config.metrics["failed_batches"] += 1
                        record_failed_batch(config, collection_name, batch_index, len(batch), reason)
                        break
                    except Exception as e:
                        reason = str(e)
                        logger.error(f"Batch {batch_index} error: {e}")
                        if config.metrics_lock:
                            async with config.metrics_lock:
                                config.metrics["failed_batches"] += 1
                        record_failed_batch(config, collection_name, batch_index, len(batch), reason)
                        break
            
            pbar.update(len(batch))

    tasks = []
    for i in range(0, total, batch_size):
        batch = data[i : i + batch_size]
        tasks.append(asyncio.create_task(worker(batch, i)))

    await asyncio.gather(*tasks)
    pbar.close()


async def main():
    config = parse_args()
    config.metrics_lock = asyncio.Lock()
    await maybe_drop_typesense_collection(config)

    supabase_client = None
    if not config.pg_uri:
        supabase_client = create_client(config.supabase_url, config.supabase_anon_key)

    sample_row: Dict[str, Any]
    if config.pg_uri:
        async with asyncpg.create_pool(
            config.pg_uri, min_size=1, max_size=4
        ) as pool:
            data = await fetch_all_rows_from_postgres(
                pool, config.table_name, config.chunk_size, config.global_limit
            )
            if not data:
                logger.warning("No data found in the source table.")
                return
            sample_row = await fetch_sample_row_from_postgres(pool, config.table_name)
    else:
        assert supabase_client is not None
        data = await fetch_all_rows_from_supabase(
            supabase_client, config.table_name, config.chunk_size, config.global_limit
        )
        if not data:
            logger.warning("No data found in the Supabase table.")
            return
        sample_row = await fetch_sample_row_from_supabase(
            supabase_client, config.table_name
        )

    if not data:
        logger.warning("No data found in the source table.")
        return

    schema = build_typesense_schema_from_sample(config.collection_name, sample_row)
    schema = finalize_schema(schema, data, config.id_column)

    await create_typesense_collection(schema, config)
    await push_to_typesense_with_workers(
        data, config.collection_name, config, config.batch_size, num_workers=20
    )
    async with config.metrics_lock:
        logger.info(f"Sync metrics: {config.metrics}")


if __name__ == "__main__":
    asyncio.run(main())
