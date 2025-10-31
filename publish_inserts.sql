-- 1) Cancer types
INSERT INTO type_of_cancer(type_of_cancer_id, name, dedicated_color, short_name, parent)
SELECT
    ct.type_of_cancer,
    ct.name,
    ct.dedicated_color,
    ct.short_name,
    ct.parent_type_of_cancer
FROM staging.stage_data_cancer_type ct
INNER JOIN staging.stage_meta m ON m.id = ct.stage_meta_id
WHERE m.stage_change_set_id = '<stage_change_set_id>';

INSERT INTO cancer_study(cancer_study_id, cancer_study_identifier, type_of_cancer_id, name, description, public, pmid, groups, citation, status, import_date, reference_genome_id)
SELECT 
    row_number() OVER () + ifNull((SELECT max(cancer_study_id) FROM cancer_study), 0) AS cancer_study_id,
    cancer_study_identifier,
    other['type_of_cancer'] as type_of_cancer_id,
    other['name'] as name, 
    other['description'] as description, 
    0 as public,
    other['pmid'] as pmid, 
    other['groups'] as groups, 
    other['citation'] as citation, 
    1 as status,
    now64(3) as import_date,
    rg.reference_genome_id as reference_genome_id
FROM staging.stage_meta
LEFT JOIN reference_genome rg ON mapContains(other, 'reference_genome') AND rg.name = other['reference_genome']
WHERE stage_change_set_id = '<stage_change_set_id>' 
AND mapContains(other, 'type_of_cancer');

WITH 
patients AS (
    SELECT DISTINCT
        cs.cancer_study_id,
        pav.patient_id
    FROM staging.stage_data_clinical_patient_attributes_values AS pav
    INNER JOIN staging.stage_meta AS m 
        ON m.id = pav.stage_meta_id
    INNER JOIN cancer_study AS cs 
        ON cs.cancer_study_identifier = m.cancer_study_identifier
    WHERE m.stage_change_set_id = '<stage_change_set_id>'
)
INSERT INTO patient(internal_id, stable_id, cancer_study_id)
SELECT
    row_number() OVER () + ifNull((SELECT max(internal_id) FROM patient), 0) AS internal_id,
    patient_id,
    cancer_study_id
FROM patients;

-- 2) Clinical patient attributes
INSERT INTO clinical_attribute_meta(attr_id, display_name, description, datatype, patient_attribute, priority, cancer_study_id)
SELECT
    a.attribute,
    a.name,
    a.description,
    a.type,
    1, -- patient_attribute = 1 for patient-level
    a.priority,
    cs.cancer_study_id
FROM staging.stage_data_clinical_patient_attributes a
INNER JOIN staging.stage_meta m ON m.id = a.stage_meta_id
INNER JOIN cancer_study cs ON cs.cancer_study_identifier = m.cancer_study_identifier
WHERE m.stage_change_set_id = '<stage_change_set_id>';

-- 3) Clinical patient attribute values
INSERT INTO clinical_patient(internal_id, attr_id, attr_value)
SELECT
    p.internal_id,
    v.attribute,
    v.value
FROM staging.stage_data_clinical_patient_attributes_values v
INNER JOIN staging.stage_meta m ON m.id = v.stage_meta_id
INNER JOIN cancer_study cs ON cs.cancer_study_identifier = m.cancer_study_identifier
INNER JOIN patient p ON p.stable_id = v.patient_id AND p.cancer_study_id = cs.cancer_study_id
WHERE m.stage_change_set_id = '<stage_change_set_id>';

-- 4) Clinical sample attributes
INSERT INTO clinical_attribute_meta(attr_id, display_name, description, datatype, patient_attribute, priority, cancer_study_id)
SELECT
    a.attribute,
    a.name,
    a.description,
    a.type,
    0, -- sample-level
    a.priority,
    cs.cancer_study_id
FROM staging.stage_data_clinical_sample_attributes a
INNER JOIN staging.stage_meta m ON m.id = a.stage_meta_id
INNER JOIN cancer_study cs ON cs.cancer_study_identifier = m.cancer_study_identifier
WHERE m.stage_change_set_id = '<stage_change_set_id>';

WITH 
samples AS (
    SELECT DISTINCT
        p.internal_id AS patient_id,
        sav.sample_id AS stable_id,
        sav_type.value AS sample_type
    FROM staging.stage_data_clinical_sample_attributes_values AS sav
    INNER JOIN staging.stage_meta AS m 
        ON m.id = sav.stage_meta_id
    INNER JOIN patient p 
        ON p.stable_id = sav.patient_id
    -- join once more to get SAMPLE_TYPE for the same sample_id and patient_id
    LEFT JOIN staging.stage_data_clinical_sample_attributes_values AS sav_type
        ON sav_type.patient_id = sav.patient_id
       AND sav_type.sample_id = sav.sample_id
       AND sav_type.attribute = 'SAMPLE_TYPE'
    WHERE m.stage_change_set_id = '<stage_change_set_id>'
)
INSERT INTO sample(internal_id, stable_id, sample_type, patient_id)
SELECT
    row_number() OVER () + ifNull((SELECT max(internal_id) FROM sample), 0) AS internal_id,
    stable_id,
    sample_type,
    patient_id
FROM samples;

-- 5) Clinical sample attribute values
INSERT INTO clinical_sample(internal_id, attr_id, attr_value)
SELECT
    s.internal_id,
    v.attribute,
    v.value
FROM staging.stage_data_clinical_sample_attributes_values v
INNER JOIN staging.stage_meta m ON m.id = v.stage_meta_id
INNER JOIN cancer_study cs ON cs.cancer_study_identifier = m.cancer_study_identifier
INNER JOIN patient p ON p.stable_id = v.patient_id AND p.cancer_study_id = cs.cancer_study_id
INNER JOIN sample s ON s.stable_id = v.sample_id
                  AND s.patient_id = p.internal_id
WHERE m.stage_change_set_id = '<stage_change_set_id>';


INSERT INTO genetic_profile(genetic_profile_id, stable_id, cancer_study_id, genetic_alteration_type, generic_assay_type, datatype, name, description, show_profile_in_analysis_tab, pivot_threshold, sort_order, patient_level)
SELECT 
    row_number() OVER () + ifNull((SELECT max(genetic_profile_id) FROM genetic_profile), 0) AS genetic_profile_id,
    m.stable_id,
    cs.cancer_study_id,
    m.genetic_alteration_type,
    m.other['generic_assay_type'] as generic_assay_type,
    m.datatype,
    m.other['profile_name'] as name,
    m.other['description'] as description,
    (m.other['show_profile_in_analysis_tab'] = 'true') as show_profile_in_analysis_tab,
    m.other['pivot_threshold'] as pivot_threshold,
    m.other['sort_order'] as sort_order,
    m.other['patient_level'] as patient_level
FROM staging.stage_meta m
INNER JOIN cancer_study cs ON cs.cancer_study_identifier = m.cancer_study_identifier
WHERE (empty(m.genetic_alteration_type) = 0)
AND (empty(m.datatype) = 0)
AND (empty(m.stable_id) = 0)
AND (m.genetic_alteration_type NOT IN ('CLINICAL', 'CANCER_TYPE'))
AND m.stage_change_set_id = '<stage_change_set_id>' 
AND mapContains(m.other, 'profile_name');

-- Mutation events
-- TODO should be made distinct by gene id, chr, start pos, end pos, protein change, tumor seq. allele, mutation type
INSERT INTO mutation_event(mutation_event_id, entrez_gene_id, chr, start_position, end_position, reference_allele, tumor_seq_allele, protein_change, mutation_type, ncbi_build, strand, variant_type, db_snp_rs, db_snp_val_status, refseq_mrna_id, codon_change, uniprot_accession, protein_pos_start, protein_pos_end, canonical_transcript, keyword)
SELECT
    row_number() OVER () + ifNull((SELECT max(mutation_event_id) FROM mutation_event), 0) AS mutation_event_id,
    g.entrez_gene_id,
    m.chromosome,
    m.start_position,
    m.end_position,
    m.reference_allele,
    any(m.tumor_seq_allele1), -- TODO calculation has to be more sofisticated then this
    'MUTATED', -- TODO calculation has to be more sofisticated then this
    m.variant_classification, -- TODO calculation has to be more sofisticated then this
    any(m.ncbi_build),
    any(m.strand),
    any(m.variant_type),
    any(m.dbsnp_rs),
    any(m.dbsnp_val_status),
    any(m.other['ONCOTATOR_REFSEQ_MRNA_ID']) as refseq_mrna_id,
    any(m.other['ONCOTATOR_CODON_CHANGE']) as codon_change,
    any(m.other['ONCOTATOR_UNIPROT_ACCESSION']) as uniprot_accession,
    any(m.other['ONCOTATOR_PROTEIN_POS_START']) as protein_pos_start,
    any(m.other['ONCOTATOR_PROTEIN_POS_END']) as protein_pos_end,
    1 as canonical_transcript, -- not really used
    '' as keywords -- TODO
FROM staging.stage_data_maf m
INNER JOIN staging.stage_meta sm ON sm.id = m.stage_meta_id
INNER JOIN cancer_study cs ON cs.cancer_study_identifier = sm.cancer_study_identifier
INNER JOIN patient p ON p.cancer_study_id = cs.cancer_study_id
INNER JOIN sample s ON s.stable_id = m.tumor_sample_barcode
                  AND s.patient_id = p.internal_id
LEFT JOIN gene g ON g.entrez_gene_id = m.entrez_gene_id OR g.hugo_gene_symbol = m.hugo_symbol
WHERE sm.stage_change_set_id = '<stage_change_set_id>'
GROUP BY g.entrez_gene_id, m.chromosome, m.start_position, m.end_position, m.reference_allele, m.variant_classification;

-- Mutations
INSERT INTO mutation(mutation_event_id, genetic_profile_id, sample_id, entrez_gene_id, center, sequencer, mutation_status, validation_status, tumor_seq_allele1, tumor_seq_allele2,
matched_norm_sample_barcode, match_norm_seq_allele1, match_norm_seq_allele2, tumor_validation_allele1, tumor_validation_allele2, match_norm_validation_allele1, match_norm_validation_allele2, verification_status, sequencing_phase, sequence_source, validation_method, score, bam_file, tumor_alt_count, tumor_ref_count, normal_alt_count, normal_ref_count, amino_acid_change)
SELECT
    me.mutation_event_id,
    gp.genetic_profile_id,
    s.internal_id,
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
    m.hgvsp_short
FROM staging.stage_data_maf m
-- TODO this join is fragile. Has to be improved
INNER JOIN mutation_event me ON me.chr = m.chromosome AND me.start_position = m.start_position AND me.end_position = m.end_position AND me.reference_allele = m.reference_allele AND me.mutation_type = m.variant_classification 
INNER JOIN staging.stage_meta sm ON sm.id = m.stage_meta_id
INNER JOIN cancer_study cs ON cs.cancer_study_identifier = sm.cancer_study_identifier
INNER JOIN genetic_profile gp ON cs.cancer_study_id = gp.cancer_study_id AND gp.genetic_alteration_type = sm.genetic_alteration_type AND gp.datatype = sm.datatype
INNER JOIN patient p ON p.cancer_study_id = cs.cancer_study_id
INNER JOIN sample s ON s.stable_id = m.tumor_sample_barcode
                  AND s.patient_id = p.internal_id
WHERE sm.stage_change_set_id = '<stage_change_set_id>';

-- TODO calculate allele_specific_copy_number

-- TODO Proceed here !!!!

-- 12) Structural variants
-- INSERT INTO structural_variant(
--     sample_id,
--     sv_status,
--     site1_entrez_gene_id,
--     site1_chromosome,
--     site1_position,
--     site2_entrez_gene_id,
--     site2_chromosome,
--     site2_position,
--     ncbi_build,
--     event_info,
--     dna_support,
--     rna_support,
--     annotation
-- )
-- SELECT
--     s.internal_id,
--     sv.sv_status,
--     sv.site1_entrez_gene_id,
--     sv.site1_chromosome,
--     sv.site1_position,
--     sv.site2_entrez_gene_id,
--     sv.site2_chromosome,
--     sv.site2_position,
--     sv.ncbi_build,
--     sv.event_info,
--     sv.dna_support,
--     sv.rna_support,
--     sv.annotation
-- FROM staging.stage_data_structural_variant sv
-- INNER JOIN staging.stage_meta m ON m.id = sv.stage_meta_id
-- INNER JOIN cancer_study cs ON cs.cancer_study_identifier = m.cancer_study_identifier
-- INNER JOIN patient p ON p.stable_id = sv.patient_id AND p.cancer_study_id = cs.cancer_study_id
-- INNER JOIN sample s ON s.stable_id = sv.sample_id
--                   AND s.patient_id = p.internal_id
-- WHERE m.stage_change_set_id = '<stage_change_set_id>';
