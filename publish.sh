#!/usr/bin/env bash
set -euo pipefail

# Directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if there are no arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <stage_change_set_id>"
    echo "Example: $0 0cccb582-31f6-4cac-8d6a-9c916b89ab5c"
    exit 1
fi
stage_change_set_id=$1

if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    echo "Found .env in the current directory. Sourcing it."
    source .env
fi

# Required environment variables for ClickHouse
: "${CLICKHOUSE_HOST:?Need to set CLICKHOUSE_HOST}"
: "${CLICKHOUSE_PORT:?Need to set CLICKHOUSE_PORT}"
: "${CLICKHOUSE_USER:?Need to set CLICKHOUSE_USER}"
: "${CLICKHOUSE_PASSWORD:?Need to set CLICKHOUSE_PASSWORD}"
: "${CLICKHOUSE_DATABASE:?Need to set CLICKHOUSE_DATABASE}"

ch_client() {
   clickhouse-client \
       --host="$CLICKHOUSE_HOST" \
       --port="$CLICKHOUSE_PORT" \
       --user="$CLICKHOUSE_USER" \
       --password="$CLICKHOUSE_PASSWORD" \
       --database="$CLICKHOUSE_DATABASE" \
   	"$@"
}

echo "Started publishing change set with id=$stage_change_set_id."

ch_client \
    --query="INSERT INTO staging.stage_change_set(id, status)
    VALUES ('$stage_change_set_id', 'STARTED_PUBLISHING')"

echo "Running publishing sql statements."

sed "s/<stage_change_set_id>/$stage_change_set_id/g" "$SCRIPT_DIR/publish_inserts.sql" |  ch_client --multiquery

echo "Finished publishing change set with id=$stage_change_set_id."

ch_client \
    --query="INSERT INTO staging.stage_change_set(id, status)
    VALUES ('$stage_change_set_id', 'FINISHED_PUBLISHING')"
