#!/bin/bash

awk -v sid="$2" '
BEGIN {
    OFS = "\t"
    print "type_of_cancer", "name", "dedicated_color", "short_name", "parent_type_of_cancer", "stage_meta_id"
}

/^#/ { next }                       # skip commented lines
{
    for (i = NF + 1; i <= 5; i++) $i = ""
    $6 = sid # add stage_meta_id
    print $0
}
' FS='\t' OFS='\t' "$1"
