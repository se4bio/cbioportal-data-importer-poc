CREATE DATABASE IF NOT EXISTS staging;

-- 1) change set metadata
CREATE TABLE IF NOT EXISTS staging.stage_change_set
(
    id String DEFAULT toString(generateUUIDv4()),
    status String, -- STARTED_STAGING, FINISHED_STAGING, STARTED_VALIDATION, FINISHED_VALIDATION, STARTED_PUBLISHING, FINISHED_PUBLISHING
    `timestamp` DateTime64(3) DEFAULT now64(3),
    other Map(String, String) DEFAULT map()
)
ENGINE = MergeTree()
ORDER BY (id);

-- 2) stage metadata (contains stage_change_set_id)
CREATE TABLE IF NOT EXISTS staging.stage_meta
(
    id String DEFAULT toString(generateUUIDv4()),
    cancer_study_identifier Nullable(String),
    genetic_alteration_type Nullable(String),
    datatype Nullable(String),
    stable_id Nullable(String),
    other Map(String, String) DEFAULT map(),
    stage_change_set_id String
)
ENGINE = MergeTree()
ORDER BY (id);

-- 3) cancer type data
CREATE TABLE IF NOT EXISTS staging.stage_data_cancer_type
(
    type_of_cancer String,
    name Nullable(String),
    dedicated_color Nullable(String),
    parent_type_of_cancer Nullable(String),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, type_of_cancer);

-- 4) clinical patient attributes meta
CREATE TABLE IF NOT EXISTS staging.stage_data_clinical_patient_attributes
(
    attribute String,
    name Nullable(String),
    description Nullable(String),
    type Nullable(String),
    priority Nullable(UInt32),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, attribute);

-- 5) clinical patient attribute values
CREATE TABLE IF NOT EXISTS staging.stage_data_clinical_patient_attributes_values
(
    patient_id String,
    attribute String,
    value Nullable(String),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, patient_id, attribute);

-- 6) clinical sample attributes
CREATE TABLE IF NOT EXISTS staging.stage_data_clinical_sample_attributes
(
    attribute String,
    name Nullable(String),
    description Nullable(String),
    type Nullable(String),
    priority Nullable(UInt32),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, attribute);

-- 7) clinical sample attribute values
CREATE TABLE IF NOT EXISTS staging.stage_data_clinical_sample_attributes_values
(
    patient_id String,
    sample_id String,
    attribute String,
    value Nullable(String),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, sample_id, attribute);

-- 8) discrete copy number (long form)
CREATE TABLE IF NOT EXISTS staging.stage_data_copy_number_alteration_discrete
(
    hugo_symbol Nullable(String),
    entrez_gene_id Nullable(Int32),
    sample_id String,
    value Int8,              -- range -2 .. 2
    other Map(String,String) DEFAULT map(),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, sample_id, coalesce(hugo_symbol, toString(entrez_gene_id), ''));

-- 9) continuous copy number
CREATE TABLE IF NOT EXISTS staging.stage_data_copy_number_alteration_continuous
(
    hugo_symbol Nullable(String),
    entrez_gene_id Nullable(Int32),
    sample_id String,
    value Nullable(Float32),
    other Map(String,String) DEFAULT map(),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, sample_id, coalesce(hugo_symbol, toString(entrez_gene_id), ''));

-- 10) segmented copy number (CN segments)
CREATE TABLE IF NOT EXISTS staging.stage_data_copy_number_alteration_segmented
(
    id String,
    chrom Nullable(String),
    loc_start Nullable(UInt32),
    loc_end Nullable(UInt32),
    num_mark Nullable(Int32),
    seg_mean Nullable(Float32),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, id, coalesce(chrom, ''), coalesce(toString(loc_start), ''));

-- 11) driver annotations
CREATE TABLE IF NOT EXISTS staging.stage_data_driver_annotations
(
    hugo_symbol Nullable(String),
    entrez_gene_id Nullable(Int32),
    sample_id String,
    cbp_driver Nullable(String),
    cbp_driver_annotation Nullable(String),
    cbp_driver_tiers Nullable(String),
    cbp_driver_tiers_annotation Nullable(String),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, coalesce(hugo_symbol, toString(entrez_gene_id), ''), sample_id);

-- 12) mRNA expression
CREATE TABLE IF NOT EXISTS staging.stage_data_mrna_expression
(
    hugo_symbol Nullable(String),
    entrez_gene_id Nullable(Int32),
    sample_id String,
    value Nullable(Float32),
    other Map(String,String) DEFAULT map(),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, sample_id, coalesce(hugo_symbol, toString(entrez_gene_id), ''));

-- 13) mutations (MAF-like; normalized to lower_case)
CREATE TABLE IF NOT EXISTS staging.stage_data_maf
(
    hugo_symbol String,
    entrez_gene_id Nullable(Int32),
    center Nullable(String),
    ncbi_build String,             -- e.g. GRCh37 / GRCh38
    chromosome String,
    start_position Nullable(UInt32),
    end_position Nullable(UInt32),
    strand Nullable(String),
    variant_classification String,
    variant_type Nullable(String),
    reference_allele String,
    tumor_seq_allele1 Nullable(String),
    tumor_seq_allele2 String,
    dbsnp_rs Nullable(String),
    dbsnp_val_status Nullable(String),
    tumor_sample_barcode String,    -- sample_id
    matched_norm_sample_barcode Nullable(String),
    match_norm_seq_allele1 Nullable(String),
    match_norm_seq_allele2 Nullable(String),
    tumor_validation_allele1 Nullable(String),
    tumor_validation_allele2 Nullable(String),
    match_norm_validation_allele1 Nullable(String),
    match_norm_validation_allele2 Nullable(String),
    verification_status Nullable(String),
    validation_status Nullable(String),
    mutation_status Nullable(String),
    sequencing_phase Nullable(String),
    sequence_source Nullable(String),
    validation_method Nullable(String),
    score Nullable(String),
    bam_file Nullable(String),
    sequencer Nullable(String),
    hgvsp_short String,
    t_alt_count Nullable(Int32),
    t_ref_count Nullable(Int32),
    n_alt_count Nullable(Int32),
    n_ref_count Nullable(Int32),
    other Map(String,String) DEFAULT map(),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, tumor_sample_barcode, coalesce(hugo_symbol, toString(entrez_gene_id), ''), coalesce(start_position, 0));

-- 14) protein level
CREATE TABLE IF NOT EXISTS staging.stage_data_protein_level
(
    composite_element_ref String,
    sample_id String,
    value Nullable(Float32),
    other Map(String,String) DEFAULT map(),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, sample_id, composite_element_ref);

-- 15) structural variants
CREATE TABLE IF NOT EXISTS staging.stage_data_structural_variant
(
    sample_id String,
    sv_status String,
    site1_hugo_symbol Nullable(String),
    site1_ensembl_transcript_id Nullable(String),
    site1_entrez_gene_id Nullable(Int32),
    site1_region_number Nullable(UInt32),
    site1_region Nullable(String),
    site1_chromosome Nullable(String),
    site1_contig Nullable(String),
    site1_position Nullable(UInt32),
    site1_description Nullable(String),
    site2_hugo_symbol Nullable(String),
    site2_ensembl_transcript_id Nullable(String),
    site2_entrez_gene_id Nullable(Int32),
    site2_region_number Nullable(UInt32),
    site2_region Nullable(String),
    site2_chromosome Nullable(String),
    site2_contig Nullable(String),
    site2_position Nullable(UInt32),
    site2_description Nullable(String),
    site2_effect_on_frame Nullable(String),
    ncbi_build String,
    class Nullable(String),
    tumor_split_read_count Nullable(UInt32),
    tumor_paired_end_read_count Nullable(UInt32),
    event_info Nullable(String),
    connection_type Nullable(String),
    breakpoint_type Nullable(String),
    annotation Nullable(String),
    dna_support Nullable(String),
    rna_support Nullable(String),
    sv_length Nullable(UInt32),
    normal_read_count Nullable(UInt32),
    tumor_read_count Nullable(UInt32),
    normal_variant_count Nullable(UInt32),
    tumor_variant_count Nullable(UInt32),
    normal_paired_end_read_count Nullable(UInt32),
    normal_split_read_count Nullable(UInt32),
    comments Nullable(String),
    other Map(String,String) DEFAULT map(),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, sample_id, coalesce(site1_hugo_symbol, toString(site1_entrez_gene_id), ''), coalesce(site2_hugo_symbol, toString(site2_entrez_gene_id), ''));

-- 16) clinical timeline events
CREATE TABLE IF NOT EXISTS staging.stage_data_clinical_timeline
(
    patient_id String,
    start_date Nullable(UInt64),
    stop_date Nullable(UInt64),
    event_type Nullable(String),
    sample_id Nullable(String),
    style_shape Nullable(String),
    style_color Nullable(String),
    other Map(String,String) DEFAULT map(),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, patient_id);

-- 17) gistic peaks
CREATE TABLE IF NOT EXISTS staging.stage_data_gistic
(
    chromosome String,
    peak_start Nullable(UInt32),
    peak_end Nullable(UInt32),
    genes_in_region Nullable(String),
    amp Nullable(Float32),
    q_value Nullable(Float32),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, chromosome);

-- 18) mutsig (significantly mutated genes)
CREATE TABLE IF NOT EXISTS staging.stage_data_mutsig
(
    `rank` UInt32,
    gene String,
    n Nullable(UInt32),
    n_total Nullable(UInt32),
    p Nullable(Float32),
    q Nullable(Float32),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, `rank`, gene);

-- 19) gene panel
CREATE TABLE IF NOT EXISTS staging.stage_data_gene_panel
(
    sample_id String,
    profile_id String,
    panel_id String,
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, sample_id);

-- 20) geneset values
CREATE TABLE IF NOT EXISTS staging.stage_data_geneset
(
    geneset_id String,
    sample_id String,
    value Nullable(Float32),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, geneset_id, sample_id);

-- 21) generic assay
CREATE TABLE IF NOT EXISTS staging.stage_data_generic_assay
(
    entity_stable_id String,
    other Map(String,String) DEFAULT map(),
    attribute Nullable(String),
    value Nullable(String),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, entity_stable_id);

-- 22) resource definition
CREATE TABLE IF NOT EXISTS staging.stage_data_resource_definition
(
    resource_id String,
    display_name String,
    resource_type String,
    description Nullable(String),
    open_by_default Nullable(UInt8),
    priority Nullable(Int32),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, resource_id);

-- 23) resource study
CREATE TABLE IF NOT EXISTS staging.stage_data_resource_study
(
    resource_id String,
    url Nullable(String),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, resource_id);

-- 24) resource patient
CREATE TABLE IF NOT EXISTS staging.stage_data_resource_patient
(
    patient_id String,
    resource_id String,
    url Nullable(String),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, patient_id, resource_id);

-- 25) resource sample
CREATE TABLE IF NOT EXISTS staging.stage_data_resource_sample
(
    patient_id String,
    sample_id String,
    resource_id String,
    url Nullable(String),
    stage_meta_id String
)
ENGINE = MergeTree()
ORDER BY (stage_meta_id, sample_id, resource_id);

