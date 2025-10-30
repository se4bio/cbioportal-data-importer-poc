#!/usr/bin/env bash
set -euo pipefail

# Directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Searching for the meta files."
meta_table=$("$SCRIPT_DIR/scan_meta.py" "$@" 2>/dev/tty)

echo "Found the following meta information."
echo "$meta_table"

if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    echo "Found .env in the current directory. Sourcing it."
    source .env
fi

echo "Ensuring the staging database exists."

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
   	"$@"
   #clickhouse-local --path /tmp/ "$@"
}

ch_client --multiquery < "$SCRIPT_DIR/stage_data_clickhouse_schema.sql"

stage_change_set_id=$(uuidgen)


echo "Started staging under id $stage_change_set_id."

ch_client \
    --query="INSERT INTO staging.stage_change_set(id, status)
    VALUES ('$stage_change_set_id', 'STARTED_STAGING')"

echo "Importing meta data."

echo "$meta_table" | ch_client \
    --query="INSERT INTO staging.stage_meta(id, cancer_study_identifier, genetic_alteration_type, datatype, stable_id, other, stage_change_set_id)
    SELECT id, cancer_study_identifier, genetic_alteration_type, datatype, stable_id, other, '$stage_change_set_id'
    FROM input('id String, cancer_study_identifier Nullable(String), genetic_alteration_type Nullable(String), datatype Nullable(String), stable_id Nullable(String), other Map(String, String)') FORMAT TSVWithNames"

echo "Staging data files."

prep_stage_mapper_table=$(echo "$meta_table" | "$SCRIPT_DIR/prep_stage_mapper.py" "$@" 2>/dev/tty)

echo "Recognised the following data types:"
echo "$prep_stage_mapper_table"

echo "$prep_stage_mapper_table" | while IFS=$'\t' read -r ID SCRIPT FILE TABLE; do
    echo "Processing $FILE"
    SCRIPT_PATH="$SCRIPT_DIR/preprocessors/$SCRIPT"
    "$SCRIPT_PATH" "$FILE" "$ID" | \
	    ch_client --query="INSERT INTO $TABLE FORMAT TSVWithNames"
done

echo "Finished staging $stage_change_set_id."

ch_client \
    --query="INSERT INTO staging.stage_change_set(id, status)
    VALUES ('$stage_change_set_id', 'FINISHED_STAGING')"
