#!/bin/sh

set -e

echo "Contents of /backup:"
find /backup -type f 2>/dev/null | head -20 || true

file_count="$(find /backup -type f 2>/dev/null | wc -l | tr -d ' ')"

if [ "${file_count}" = "0" ]; then
  echo "No files in /backup; skipping S3 upload (export initContainer may have found nothing)"
  exit 0
fi

bucket="${WORKFLOWS_S3_BUCKET:?}"
prefix="${WORKFLOWS_S3_PREFIX:-n8n/workflows}"
dest="s3://${bucket}/${prefix}/"

echo "Uploading ${file_count} file(s) from /backup to ${dest}"
aws s3 sync /backup/ "${dest}" --delete

echo "S3 listing after sync:"
aws s3 ls "${dest}" | head -20
