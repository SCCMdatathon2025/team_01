
-- Identify midodrine administrations
CREATE TEMP TABLE midodrine_meds AS
WITH midodrine_meds AS (
  SELECT DISTINCT
    m.patientunitstayid,
    m.drugname,
    m.drugstartoffset,
    m.drugstopoffset,
    m.dosage,
    m.routeadmin
  FROM `sccm-discovery.eicu_crd_ii_v0_2_0.medication` m
  WHERE (LOWER(m.drugname) LIKE '%midodrine%' 
         OR LOWER(m.drugname) LIKE '%proamatine%'
         OR LOWER(m.drugname) LIKE '%orvaten%')
      AND m.drugstartoffset IS NOT NULL
      AND LOWER(COALESCE(m.routeadmin, '')) IN ('po', 'oral', 'enteral', 'gt', 'ng', 'peg', '')
)
SELECT * FROM midodrine_meds;






-- Identify all vasopressor administrations
CREATE TEMP TABLE vasopressor_meds AS
WITH medication_vaso AS (
    SELECT DISTINCT 
        m.patientunitstayid,
        m.drugname,
        m.drugstartoffset,
        m.drugstopoffset,
        CASE 
            WHEN LOWER(m.drugname) LIKE '%norepinephrine%' OR LOWER(m.drugname) LIKE '%noradrenaline%' OR LOWER(m.drugname) LIKE '%levophed%' THEN 'norepinephrine'
            WHEN LOWER(m.drugname) LIKE '%epinephrine%' OR LOWER(m.drugname) LIKE '%adrenaline%' THEN 'epinephrine'
            WHEN LOWER(m.drugname) LIKE '%dopamine%' THEN 'dopamine'
            WHEN LOWER(m.drugname) LIKE '%vasopressin%' OR LOWER(m.drugname) LIKE '%pitressin%' THEN 'vasopressin'
            WHEN LOWER(m.drugname) LIKE '%phenylephrine%' OR LOWER(m.drugname) LIKE '%neosynephrine%' THEN 'phenylephrine'
            WHEN LOWER(m.drugname) LIKE '%dobutamine%' THEN 'dobutamine'
        END as vasopressor_type
    FROM `sccm-discovery.eicu_crd_ii_v0_2_0.medication` m
    WHERE (LOWER(m.drugname) LIKE '%norepinephrine%' OR LOWER(m.drugname) LIKE '%noradrenaline%' OR LOWER(m.drugname) LIKE '%levophed%'
           OR LOWER(m.drugname) LIKE '%epinephrine%' OR LOWER(m.drugname) LIKE '%adrenaline%'
           OR LOWER(m.drugname) LIKE '%dopamine%' OR LOWER(m.drugname) LIKE '%intropin%'
           OR LOWER(m.drugname) LIKE '%vasopressin%' OR LOWER(m.drugname) LIKE '%pitressin%'
           OR LOWER(m.drugname) LIKE '%phenylephrine%' OR LOWER(m.drugname) LIKE '%neosynephrine%'
           OR LOWER(m.drugname) LIKE '%dobutamine%' OR LOWER(m.drugname) LIKE '%dobutrex%')
        AND m.drugstartoffset IS NOT NULL
),
infusion_vaso AS (
    SELECT DISTINCT
        i.patientunitstayid,
        i.drugname,
        i.infusionoffset as drugstartoffset,
        LEAD(i.infusionoffset) OVER (PARTITION BY i.patientunitstayid, i.drugname ORDER BY i.infusionoffset) as drugstopoffset,
        CASE 
            WHEN LOWER(i.drugname) LIKE '%norepinephrine%' OR LOWER(i.drugname) LIKE '%noradrenaline%' THEN 'norepinephrine'
            WHEN LOWER(i.drugname) LIKE '%epinephrine%' OR LOWER(i.drugname) LIKE '%adrenaline%' THEN 'epinephrine'
            WHEN LOWER(i.drugname) LIKE '%dopamine%' THEN 'dopamine'
            WHEN LOWER(i.drugname) LIKE '%vasopressin%' THEN 'vasopressin'
            WHEN LOWER(i.drugname) LIKE '%phenylephrine%' THEN 'phenylephrine'
            WHEN LOWER(i.drugname) LIKE '%dobutamine%' THEN 'dobutamine'
        END as vasopressor_type
    FROM `sccm-discovery.eicu_crd_ii_v0_2_0.infusiondrug` i
    WHERE (LOWER(i.drugname) LIKE '%norepinephrine%' OR LOWER(i.drugname) LIKE '%noradrenaline%'
           OR LOWER(i.drugname) LIKE '%epinephrine%' OR LOWER(i.drugname) LIKE '%adrenaline%'
           OR LOWER(i.drugname) LIKE '%dopamine%' OR LOWER(i.drugname) LIKE '%vasopressin%'
           OR LOWER(i.drugname) LIKE '%phenylephrine%' OR LOWER(i.drugname) LIKE '%dobutamine%')
        AND SAFE_CAST(i.drugrate AS FLOAT64) > 0
        AND i.infusionoffset IS NOT NULL
)
SELECT * FROM medication_vaso
UNION ALL
SELECT * FROM infusion_vaso;







-- Create patient-level vasopressor summary
WITH patient_vasopressor_summary AS (
  SELECT 
      patientunitstayid,
      MIN(drugstartoffset) as first_vasopressor_offset,
      MAX(COALESCE(drugstopoffset, drugstartoffset + 1440)) as last_vasopressor_offset,
      COUNT(DISTINCT vasopressor_type) as num_vasopressor_types,
      STRING_AGG(DISTINCT vasopressor_type ORDER BY vasopressor_type) as vasopressor_types,
      MAX(CASE WHEN vasopressor_type = 'norepinephrine' THEN 1 ELSE 0 END) as received_norepinephrine,
      MAX(CASE WHEN vasopressor_type = 'epinephrine' THEN 1 ELSE 0 END) as received_epinephrine,
      MAX(CASE WHEN vasopressor_type = 'dopamine' THEN 1 ELSE 0 END) as received_dopamine,
      MAX(CASE WHEN vasopressor_type = 'vasopressin' THEN 1 ELSE 0 END) as received_vasopressin,
      MAX(CASE WHEN vasopressor_type = 'phenylephrine' THEN 1 ELSE 0 END) as received_phenylephrine
  FROM vasopressor_meds
  GROUP BY patientunitstayid
)
SELECT *
FROM patient_vasopressor_summary;



-- Step 4: Create patient-level midodrine summary
CREATE TEMP TABLE patient_midodrine_summary AS
SELECT 
    patientunitstayid,
    1 as received_midodrine,
    MIN(drugstartoffset) as first_midodrine_offset,
    MAX(COALESCE(drugstopoffset, drugstartoffset + 480)) as last_midodrine_offset,
    COUNT(*) as midodrine_administrations,
    STRING_AGG(DISTINCT dosage) as dosage_range
FROM midodrine_meds
GROUP BY patientunitstayid;

