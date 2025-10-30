#!/usr/bin/env python3
"""
prep_stage_mapper.py

Reads a TSV from stdin with header:
id, cancer_study_identifier, genetic_alteration_type, datatype, stable_id, other, meta_filepath, data_filepath

Fetches the required preprocessing script and staging table for ELT.

Uses a hardcoded mapping from (genetic_alteration_type, datatype) -> list of
(preprocessing_script, db_table). If multiple mappings exist, replicates the row.

Exits with error if a combination is not supported.

Writes TSV to stdout with exactly 4 columns (no header):
id, preprocessing_script, data_filepath, db_table

Usage:
    cat meta.tsv | ./prep_stage_mapper.py > output.tsv
"""

import sys
import csv

csv.field_size_limit(sys.maxsize)

REQUIRED_COLUMNS = {
    "id", "genetic_alteration_type", "datatype", "data_filepath"
}

DEFAULT_PREPROCESSOR_SCRIPT="default.sh"
MAPPING = {
        ("CANCER_TYPE", "CANCER_TYPE"): [('add_data_cancer_type_header.sh', 'staging.stage_data_cancer_type')],
        # clinical and timeline
        ("CLINICAL", "PATIENT_ATTRIBUTES"): [('extract_clinical_attributes_definition.py', 'staging.stage_data_clinical_patient_attributes'), ('melt_clinical_attributes_table.sh', 'staging.stage_data_clinical_patient_attributes_values')],
        ("CLINICAL", "SAMPLE_ATTRIBUTES"): [('extract_clinical_attributes_definition.py', 'staging.stage_data_clinical_sample_attributes'), ('melt_clinical_attributes_table.sh', 'staging.stage_data_clinical_sample_attributes_values')],
        ("CLINICAL", "TIMELINE"): [(DEFAULT_PREPROCESSOR_SCRIPT, 'staging.stage_data_clinical_timeline')],
        # rppa and mass spectrometry
        ("PROTEIN_LEVEL", "LOG2-VALUE"): [('melt_protein_level_table.sh', 'staging.stage_data_protein_level')],
        ("PROTEIN_LEVEL", "Z-SCORE"): [('melt_protein_level_table.sh', 'staging.stage_data_protein_level')],
        ("PROTEIN_LEVEL", "CONTINUOUS"): [('melt_protein_level_table.sh', 'staging.stage_data_protein_level')],
        # cna
        ("COPY_NUMBER_ALTERATION", "DISCRETE"): [('melt_gene_sample_table.sh', 'staging.stage_data_copy_number_alteration_discrete')],
        ("COPY_NUMBER_ALTERATION", "DISCRETE_LONG"): [(DEFAULT_PREPROCESSOR_SCRIPT, 'staging.stage_data_copy_number_alteration_discrete')],
        ("COPY_NUMBER_ALTERATION", "CONTINUOUS"): [('melt_gene_sample_table.sh', 'staging.stage_data_copy_number_alteration_continuous')],
        ("COPY_NUMBER_ALTERATION", "LOG2-VALUE"): [('melt_gene_sample_table.sh', 'staging.stage_data_copy_number_alteration_continuous')],
        ("COPY_NUMBER_ALTERATION", "SEG"): [(DEFAULT_PREPROCESSOR_SCRIPT, 'staging.stage_data_copy_number_alteration_segmented')],
        # expression
        ("MRNA_EXPRESSION", "CONTINUOUS"): [('melt_gene_sample_table.sh', 'staging.stage_data_mrna_expression')],
        ("MRNA_EXPRESSION", "Z-SCORE"): [('melt_gene_sample_table.sh', 'staging.stage_data_mrna_expression')],
        # methylation
        ('METHYLATION', 'CONTINUOUS'): [('melt_gene_sample_table.sh', 'staging.stage_data_mrna_expression')],
        # mutations
        ("MUTATION_EXTENDED", "MAF"): [(DEFAULT_PREPROCESSOR_SCRIPT, 'staging.stage_data_maf')],
        ("MUTATION_UNCALLED", "MAF"): [(DEFAULT_PREPROCESSOR_SCRIPT, 'staging.stage_data_maf')],
        # others
        ("GENE_PANEL_MATRIX", "GENE_PANEL_MATRIX"): [('melt_gene_panel_matrix.sh', 'staging.stage_data_gene_panel')],
        ("STRUCTURAL_VARIANT", "SV"): [(DEFAULT_PREPROCESSOR_SCRIPT, 'staging.stage_data_structural_variant')],
        # cross-sample molecular statistics (for gene selection)
        ("GISTIC_GENES_AMP", "Q-VALUE"): [(DEFAULT_PREPROCESSOR_SCRIPT, 'staging.stage_data_gistic')],
        ("GISTIC_GENES_DEL", "Q-VALUE"): [(DEFAULT_PREPROCESSOR_SCRIPT, 'staging.stage_data_gistic')],
        ("MUTSIG", "Q-VALUE"): [(DEFAULT_PREPROCESSOR_SCRIPT, 'staging.stage_data_mutsig')],
        ("GENESET_SCORE", "GSVA-SCORE"): [('melt_geneset_table.sh', 'staging.stage_data_geneset')],
        ("GENESET_SCORE", "P-VALUE"): [('melt_geneset_table.sh', 'staging.stage_data_geneset')],
        ("GENERIC_ASSAY", "LIMIT-VALUE"): [('melt_generic_assay_table.sh', 'staging.stage_data_generic_assay')],
        ("GENERIC_ASSAY", "BINARY"): [('melt_generic_assay_table.sh', 'staging.stage_data_generic_assay')],
        ("GENERIC_ASSAY", "CATEGORICAL"): [('melt_generic_assay_table.sh', 'staging.stage_data_generic_assay')],
        # Add more combinations as needed
}

def main():
    reader = csv.reader(sys.stdin, delimiter="\t")
    try:
        header = next(reader)
    except StopIteration:
        print("ERROR: input is empty", file=sys.stderr)
        sys.exit(2)

    header = [h.strip() for h in header]
    missing = REQUIRED_COLUMNS - set(h.lower() for h in header)
    if missing:
        print(f"ERROR: input missing required columns: {sorted(missing)}", file=sys.stderr)
        sys.exit(2)

    # Get column indices
    idx_map = {name.lower(): i for i, name in enumerate(header)}
    idx_id = idx_map["id"]
    idx_genetic = idx_map["genetic_alteration_type"]
    idx_datatype = idx_map["datatype"]
    idx_datafile = idx_map["data_filepath"]

    writer = csv.writer(sys.stdout, delimiter="\t", lineterminator="\n")

    for row_num, row in enumerate(reader, start=2):
        if len(row) < len(header):
            row = row + [""] * (len(header) - len(row))

        id_val = row[idx_id].strip()
        datafile_val = row[idx_datafile].strip()
        genetic_val = row[idx_genetic].strip()
        datatype_val = row[idx_datatype].strip()
        if not datafile_val or not genetic_val or not datafile_val:
            continue
        key = (genetic_val, datatype_val)

        if key not in MAPPING:
            print(f"ERROR: unsupported combination at line {row_num}: {key}", file=sys.stderr)
            sys.exit(3)

        for script, table in MAPPING[key]:
            out_row = [id_val, script, datafile_val, table]
            writer.writerow(out_row)

    try:
        sys.stdout.flush()
    except Exception:
        pass

if __name__ == "__main__":
    main()

