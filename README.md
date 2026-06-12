# scripts
A collection of bash, ps, py scripts i've used

`download_s3_bucket.py`
- Downloads an S3 bucket or prefix into a local folder while preserving the bucket's folder structure.
- Uses ANSI-colored output, a `tqdm` byte progress bar, manifest-based resume/skip logic, and local dedupe via hardlinks when possible.
- Install deps with `python -m pip install boto3 tqdm`
- Example: `python download_s3_bucket.py my-bucket ./bucket-backup --prefix uploads/ --profile default`
