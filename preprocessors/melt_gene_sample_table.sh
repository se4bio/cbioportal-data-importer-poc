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
        if ($i == "Hugo_Symbol") hugo_col = i;
        else if ($i == "Entrez_Gene_Id") entrez_col = i;
    }
    if (!hugo_col) {
        print "ERROR: Hugo_Symbol column not found in header" > "/dev/stderr";
        exit 1;
    }
    has_entrez = (entrez_col > 0);

    # print new header
    if (has_entrez)
        print "hugo_symbol", "entrez_gene_id", "sample_id", "value", "stage_meta_id";
    else
        print "hugo_symbol", "sample_id", "value", "stage_meta_id";
    next;
}

# Melt the rest of the rows
{
    hugo_symbol = $hugo_col;
    if (has_entrez) entrez_id = $entrez_col;

    for (i = 1; i <= num_cols; i++) {
        # skip ID columns
        if (i == hugo_col || (has_entrez && i == entrez_col)) continue;

	if ($i == "NA") continue;
        if (has_entrez)
            print hugo_symbol, entrez_id, H[i], $i, sid;
        else
            print hugo_symbol, H[i], $i, sid;
    }
}
' "$input"
