#!/bin/bash

awk -v sid="$2" '
BEGIN {
    OFS = "\t"
    print "type_of_cancer", "name", "dedicated_color", "parent_type_of_cancer", "stage_meta_id"
}

/^#/ { next }                       # skip commented lines
{ 
    print $0, sid		  # add stage_meta_id
} 
' FS='\t' OFS='\t' "$1"
