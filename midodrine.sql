
-- Step 2: Identify midodrine administrations
CREATE TEMP VIEW midodrine_meds AS
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



