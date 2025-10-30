#!/bin/bash

input="$1"
stage_meta_id="$2"

awk -v sid="$stage_meta_id" -F '\t' '
BEGIN { 
	OFS = FS
	header_read = 0;
}

/^#/ { next }                       # skip commented lines

# first non-comment line → header
header_read == 0 {
    header_read=1
    # store all header names (except the first: ENTITY_STABLE_ID)
    for (i = 2; i <= NF; i++) H[i] = $i
    print "entity_stable_id", "attribute", "value", "stage_meta_id"
    next
}

# melt remaining data rows
{
    entity_stable_id = $1
    for (i = 2; i <= NF; i++) {
	if ($i == "NA") continue;
        print entity_stable_id, H[i], $i, sid
    }
}
' "$input"
