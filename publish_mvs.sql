CREATE MATERIALIZED VIEW staging.type_of_cancer_mv TO type_of_cancer AS
SELECT
    ct.type_of_cancer,
    ct.name,
    ct.dedicated_color,
    ct.short_name,
    ct.parent_type_of_cancer
FROM staging.stage_change_set c
INNER JOIN staging.stage_meta m ON m.stage_change_set_id = c.id
INNER JOIN staging.stage_data_cancer_type ct ON ct.stage_meta_id = m.id
WHERE c.status = 'FINISHED_STAGING';

CREATE MATERIALIZED VIEW staging.cancer_study_mv TO cancer_study AS
SELECT 
    row_number() OVER () + ifNull((SELECT max(cancer_study_id) FROM cancer_study), 0) AS cancer_study_id,
    m.other['cancer_study_identifier'] AS cancer_study_identifier,
    m.other['type_of_cancer'] AS type_of_cancer_id,
    m.other['name'] AS name, 
    m.other['description'] AS description, 
    0 AS public,
    m.other['pmid'] AS pmid, 
    m.other['groups'] AS groups, 
    m.other['citetion'] AS citetion, 
    1 AS status,
    now64(3) AS import_date,
    rg.reference_genome_id AS reference_genome_id
FROM staging.stage_change_set c
INNER JOIN staging.stage_meta m ON m.stage_change_set_id = c.id
LEFT JOIN reference_genome rg 
       ON mapContains(m.other, 'reference_genome') AND rg.name = m.other['reference_genome']
WHERE c.status = 'FINISHED_STAGING'
  AND mapContains(m.other, 'type_of_cancer');

CREATE MATERIALIZED VIEW staging.patient_mv TO patient AS
WITH patients AS (
 SELECT
    cs.cancer_study_id,
    pav.patient_id
FROM cancer_study cs
INNER JOIN staging.stage_meta m
    ON m.other['cancer_study_identifier'] = cs.cancer_study_identifier
INNER JOIN (
    -- Select only the latest stage_change_set per cancer_study_id
    SELECT
        cancer_study_id,
        argMax(id, timestamp) AS latest_change_set_id
    FROM staging.stage_change_set
    WHERE status = 'FINISHED_STAGING'
    GROUP BY cancer_study_id
) AS latest_cs
    ON latest_cs.cancer_study_id = cs.cancer_study_id
INNER JOIN staging.stage_change_set c
    ON c.id = latest_cs.latest_change_set_id
INNER JOIN staging.stage_data_clinical_patient_attributes_values pav
    ON pav.stage_meta_id = m.id
)
SELECT
    row_number() OVER () + ifNull((SELECT max(internal_id) FROM patient), 0) AS internal_id,
    patient_id AS stable_id,
    cancer_study_id
FROM patients;

CREATE MATERIALIZED VIEW staging.clinical_attribute_meta_sample_mv TO clinical_attribute_meta AS
SELECT
    a.attribute AS attr_id,
    a.name AS display_name,
    a.description,
    a.type AS datatype,
    0 AS patient_attribute,
    a.priority,
    cs.cancer_study_id
FROM cancer_study cs
INNER JOIN staging.stage_meta m ON m.other['cancer_study_identifier'] = cs.cancer_study_identifier
INNER JOIN staging.stage_data_clinical_sample_attributes a ON a.stage_meta_id = m.id;

CREATE MATERIALIZED VIEW staging.sample_mv TO sample AS
WITH samples AS (
    SELECT DISTINCT
        p.internal_id AS patient_id,
        sav.sample_id AS stable_id,
        sav_type.value AS sample_type
    FROM patient p
    INNER JOIN staging.stage_meta m ON m.other['cancer_study_identifier'] = p.cancer_study_id
    INNER JOIN staging.stage_data_clinical_sample_attributes_values sav ON sav.stage_meta_id = m.id AND sav.patient_id = p.stable_id
    LEFT JOIN staging.stage_data_clinical_sample_attributes_values sav_type
        ON sav_type.patient_id = sav.patient_id
       AND sav_type.sample_id = sav.sample_id
       AND sav_type.attribute = 'SAMPLE_TYPE'
)
SELECT
    row_number() OVER () + ifNull((SELECT max(internal_id) FROM sample), 0) AS internal_id,
    stable_id,
    sample_type,
    patient_id
FROM samples;

CREATE MATERIALIZED VIEW staging.clinical_sample_mv TO clinical_sample AS
SELECT
    s.internal_id,
    v.attribute AS attr_id,
    v.value AS attr_value
FROM sample s
INNER JOIN staging.stage_meta m ON m.other['cancer_study_identifier'] = s.cancer_study_id
INNER JOIN staging.stage_data_clinical_sample_attributes_values v ON v.stage_meta_id = m.id AND v.sample_id = s.stable_id;

CREATE MATERIALIZED VIEW staging.genetic_profile_mv TO genetic_profile AS
SELECT 
    row_number() OVER () + ifNull((SELECT max(genetic_profile_id) FROM genetic_profile), 0) AS genetic_profile_id,
    m.stable_id,
    cs.cancer_study_id,
    m.genetic_alteration_type,
    m.other['generic_assay_type'] AS generic_assay_type,
    m.datatype,
    m.other['profile_name'] AS name,
    m.other['description'] AS description,
    (m.other['show_profile_in_analysis_tab'] = 'true') AS show_profile_in_analysis_tab,
    m.other['pivot_threshold'] AS pivot_threshold,
    m.other['sort_order'] AS sort_order,
    m.other['patient_level'] AS patient_level
FROM cancer_study cs
INNER JOIN staging.stage_meta m ON m.other['cancer_study_identifier'] = cs.cancer_study_identifier
WHERE NOT empty(m.genetic_alteration_type)
  AND NOT empty(m.datatype)
  AND NOT empty(m.stable_id)
  AND m.genetic_alteration_type NOT IN ('CLINICAL', 'CANCER_TYPE')
  AND mapContains(m.other, 'profile_name');

CREATE MATERIALIZED VIEW staging.mutation_event_mv TO mutation_event AS
SELECT
    row_number() OVER () + ifNull((SELECT max(mutation_event_id) FROM mutation_event), 0) AS mutation_event_id,
    g.entrez_gene_id,
    m.chromosome AS chr,
    m.start_position,
    m.end_position,
    m.reference_allele,
    any(m.tumor_seq_allele1) AS tumor_seq_allele,
    'MUTATED' AS protein_change,
    m.variant_classification AS mutation_type,
    any(m.ncbi_build) AS ncbi_build,
    any(m.strand) AS strand,
    any(m.variant_type) AS variant_type,
    any(m.dbsnp_rs) AS db_snp_rs,
    any(m.dbsnp_val_status) AS db_snp_val_status,
    any(m.other['ONCOTATOR_REFSEQ_MRNA_ID']) AS refseq_mrna_id,
    any(m.other['ONCOTATOR_CODON_CHANGE']) AS codon_change,
    any(m.other['ONCOTATOR_UNIPROT_ACCESSION']) AS uniprot_accession,
    any(m.other['ONCOTATOR_PROTEIN_POS_START']) AS protein_pos_start,
    any(m.other['ONCOTATOR_PROTEIN_POS_END']) AS protein_pos_end,
    1 AS canonical_transcript,
    '' AS keyword
FROM sample s
INNER JOIN staging.stage_meta sm ON sm.other['cancer_study_identifier'] = s.cancer_study_id
INNER JOIN staging.stage_data_maf m ON m.stage_meta_id = sm.id
LEFT JOIN gene g ON g.entrez_gene_id = m.entrez_gene_id OR g.hugo_gene_symbol = m.hugo_symbol
GROUP BY g.entrez_gene_id, m.chromosome, m.start_position, m.end_position, m.reference_allele, m.variant_classification;

CREATE MATERIALIZED VIEW staging.mutation_mv TO mutation AS
SELECT
    me.mutation_event_id,
    gp.genetic_profile_id,
    s.internal_id AS sample_id,
    me.entrez_gene_id,
    m.center,
    m.sequencer,
    m.mutation_status,
    m.validation_status,
    m.tumor_seq_allele1,
    m.tumor_seq_allele2,
    m.matched_norm_sample_barcode,
    m.match_norm_seq_allele1,
    m.match_norm_seq_allele2,
    m.tumor_validation_allele1,
    m.tumor_validation_allele2,
    m.match_norm_validation_allele1,
    m.match_norm_validation_allele2,
    m.verification_status,
    m.sequencing_phase,
    m.sequence_source,
    m.validation_method,
    m.score,
    m.bam_file,
    m.t_alt_count,
    m.t_ref_count,
    m.n_alt_count,
    m.n_ref_count,
    m.hgvsp_short AS amino_acid_change
FROM mutation_event me
INNER JOIN staging.stage_meta sm ON sm.other['cancer_study_identifier'] = me.cancer_study_id
INNER JOIN staging.stage_data_maf m ON m.stage_meta_id = sm.id
INNER JOIN genetic_profile gp ON gp.datatype = m.datatype AND gp.genetic_alteration_type = m.genetic_alteration_type
INNER JOIN patient p ON p.cancer_study_id = m.cancer_study_id
INNER JOIN sample s ON s.stable_id = m.tumor_sample_barcode AND s.patient_id = p.internal_id;
