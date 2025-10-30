#!/bin/bash

# Skip lines starting with # using grep and lowercase + sanitize the header
awk -v sid="$2" '
BEGIN {
    header_read = 0;
}

/^#/ { next }                       # skip commented lines

header_read==0 {
    header_read=1
    for (i=1; i<=NF; i++) {
        $i = tolower($i)          # lowercase
        gsub(/\./, "_", $i)       # replace dots with underscores
    }
    $NF = $NF"\tstage_meta_id"    # append new column
    print
    next
}
{ 
    for (i=1; i<=NF; i++) if ($i=="NA") $i=""; # replace "NA"s with empty string
    print $0, sid		  # add stage_meta_id
} 
' FS='\t' OFS='\t' "$1"
