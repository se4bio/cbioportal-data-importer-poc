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
    # store all header names (except the first: sample id)
    for (i = 2; i <= NF; i++) H[i] = $i
    print "sample_id", "profile_id", "panel_id", "stage_meta_id"
    next
}

# melt remaining data rows
{
    sample_id = $1
    for (i = 2; i <= NF; i++)
        print sample_id, H[i], $i, sid
}
' "$input"
