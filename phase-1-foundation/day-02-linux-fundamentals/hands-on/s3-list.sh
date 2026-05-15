#!/bin/bash
# Day 2 hands-on: List S3 buckets + sizes with error handling
set -euo pipefail

OUTPUT_FILE="/tmp/s3-report-$(date +%Y%m%d).json"

echo "Fetching S3 buckets..."

buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null) || {
  echo "ERROR: Failed to list buckets. Check AWS credentials." >&2
  exit 1
}

result="["
first=true
for bucket in $buckets; do
  size=$(aws s3 ls "s3://$bucket" --recursive --human-readable --summarize 2>/dev/null \
    | grep "Total Size" | awk '{print $3, $4}' || echo "N/A")

  [[ "$first" == "true" ]] && first=false || result+=","
  result+="{\"bucket\":\"$bucket\",\"size\":\"$size\"}"
done
result+="]"

echo "$result" | python3 -m json.tool > "$OUTPUT_FILE"
echo "Report saved: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
