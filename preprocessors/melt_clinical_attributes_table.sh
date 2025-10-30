#!/bin/bash

input="$1"
stage_meta_id="$2"

awk -v sid="$stage_meta_id" -F '\t' '
BEGIN {
    OFS = FS;
    header_read = 0;
}

# Skip commented lines until header found
/^#/ { next }

# Capture the header (first non-comment line)
header_read == 0 {
    header_read = 1;
    num_cols = NF;
    for (i = 1; i <= NF; i++) {
        H[i] = $i;
        if ($i == "PATIENT_ID") patient_col = i;
        else if ($i == "SAMPLE_ID") sample_col = i;
    }
    if (!patient_col) {
        print "ERROR: PATIENT_ID column not found in header" > "/dev/stderr";
        exit 1;
    }
    has_sample = (sample_col > 0);

    # print new header
    if (has_sample)
        print "patient_id", "sample_id", "attribute", "value", "stage_meta_id";
    else
        print "patient_id", "attribute", "value", "stage_meta_id";
    next;
}

# Melt the rest of the rows
{
    patient = $patient_col;
    if (has_sample) sample = $sample_col;

    for (i = 1; i <= num_cols; i++) {
        # skip ID columns
        if (i == patient_col || (has_sample && i == sample_col)) continue;

        if (has_sample)
            print patient, sample, H[i], $i, sid;
        else
            print patient, H[i], $i, sid;
    }
}
' "$input"
