-- ========================================================================================================================
-- Creació de llistat inicial per OCR (adaptar-lo perquè serveixi per inserir només les novetats)
-- ========================================================================================================================
DROP TABLE tmp_ocr_files_in_steps;
WITH psi_ok AS (
	SELECT psi.id, psi.cyber_id, psi.cyber_id_group, psi.lot_id,
		   ci.cyber_id_group_id, ci.id AS  ci_id, ci.cyber_id AS ci_cyber_id
	  FROM product_search_index psi
		   LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
	 WHERE psi.superseded=FALSE AND ci.deleted <> TRUE
	   AND substring(psi.cyber_id FROM 21 FOR 1) <> 'D'
--	   AND ci.cyber_id ~'21-0099-196270'
), psi_sub AS (
  SELECT psi.id, psi.cyber_id, psi.cyber_id_group, psi.lot_id, ci_id, ci_cyber_id FROM psi_ok psi
UNION 
  SELECT psi.id, psi.cyber_id, psi.cyber_id_group, psi.lot_id, ci2.id AS ci_id, ci2.cyber_id AS ci_cyber_id -- CyberID pare
    FROM psi_ok psi
         LEFT OUTER JOIN cyber_id ci2 ON ci2.cyber_id_group_id=psi.ci_id         -- CyberID fills
), nice_sr AS (
SELECT sr.id, product_search_index_id, out_batch_id,
       CASE WHEN out_batch_id ~ '-R[0-9]{2}' THEN COALESCE(substring(out_batch_id from '^(.*-R\d{2})'),out_batch_id) ELSE LEFT(out_batch_id,20) END AS nice_cyber_id
  FROM step_record sr 
), psi_all_sr AS (
SELECT psi.id AS psi_id, psi.cyber_id, psi.cyber_id_group, psi.lot_id, psi.ci_id, psi.ci_cyber_id, nsr.id AS sr_id
  FROM psi_sub psi
       LEFT OUTER JOIN nice_sr nsr ON nsr.nice_cyber_id=psi.ci_cyber_id
)
SELECT pas.sr_id, pas.psi_id, LEFT(pas.lot_id,20) AS cyber_id,
		vsraf1.role_name, vsraf1.KEY AS field_key, vsraf1.value_convert_string AS s3_vottun, vsraf1.api || ' ' || vsraf1.api_version AS api,
		vsraf1.public_step, vsraf1.stakeholder_name, string_agg(DISTINCT vsraf2.value_convert_string, ', ' ORDER BY vsraf2.value_convert_string) AS provider_name
  INTO tmp_ocr_files_in_steps
  FROM psi_all_sr pas
   	   LEFT OUTER JOIN v_step_record_and_fields vsraf1 ON vsraf1.step_record_id=pas.sr_id
   	   LEFT OUTER JOIN v_step_record_and_fields vsraf2 ON vsraf2.step_record_id=pas.sr_id AND  vsraf2.key IN ('Rough_Supplier', 'Rough_Buyer', 'Institution')
 WHERE vsraf1.api IS NOT NULL 
   AND vsraf1.value_convert_string~'^http'
   AND vsraf1.key NOT IN ('Final_certificate','RJC_Member_Certificate')
 GROUP BY pas.sr_id, pas.psi_id, LEFT(pas.lot_id,20), vsraf1.role_name, vsraf1.KEY, vsraf1.value_convert_string, vsraf1.api || ' ' || vsraf1.api_version,
		vsraf1.public_step, vsraf1.stakeholder_name
 ORDER BY cyber_id DESC, sr_id DESC;


/*

ARA: A partir dels PSI ben tancats --> step_records
FUTUR: A partir de qualsevol CyberID --> 
		pases no cancel·lades des de l'últim pas 1 (=última revisió a taula CyberID) === f(CyberID)

FASE 1 - Professionalització procés (per CyberID)
	1. Automatitzar SQL previ (noves files ocr_results amb md5_sum NULL)
	2. Execució programa Python (down s3, control md5, ocr, upload s3.eu) --> OCR=string
	   * Upload de fitxers amb md5sum com a nom (i subcarpeta per primera lletra)
	3. Automatització controls/reports (regexp) 
	   * MILLORA: Configuració dels controls a fer per cada camp de tipus document (KP?)
	4. Resultats:
	   * Registre warnings OCR per cada lot (=cyberID)
	   -------
	   * Warnings >> Enviament Excel resum d'incidències
	   * Warning  >> Generació PDF warnings per lot (--> Pas 11)

FASE 2 - Millora OCR+
	1. Entrenament AWS especialitzat per tipus document
    
**/

SELECT * FROM tmp_ocr_files_in_steps;

SELECT ofi.cyber_id, role_name, field_key, api, public_step, s3_vottun
  FROM tmp_ocr_files_in_steps ofi
  	   LEFT OUTER JOIN product_search_index psi ON ofi.cyber_id=psi.cyber_id 
 WHERE psi.brand_id ;

SELECT *, "name" FROM cob_chain_company ccc; -- WHERE name ~*'peter';


--SELECT ocr_prepare_files_to_scan();

DROP FUNCTION ocr_prepare_files_to_scan;
CREATE OR REPLACE FUNCTION ocr_prepare_files_to_scan()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Drop the table if it exists
    DROP TABLE IF EXISTS tmp_ocr_files_in_steps;

    -- Create the permanent table
    CREATE TABLE tmp_ocr_files_in_steps (
        sr_id bigint,
        psi_id bigint,
        cyber_id varchar(20),
        role_name varchar(255),
        field_key varchar(255),
        s3_vottun text,
        api varchar(255),
        public_step boolean,
        stakeholder_name varchar(255),
        provider_name text
    );

    -- Insert data into the table
    INSERT INTO tmp_ocr_files_in_steps
    WITH psi_ok AS (
        SELECT 
            psi.id,
            psi.cyber_id,
            psi.cyber_id_group,
            psi.lot_id,
            ci.cyber_id_group_id,
            ci.id AS ci_id,
            ci.cyber_id AS ci_cyber_id
        FROM product_search_index psi
        LEFT OUTER JOIN cyber_id ci ON ci.cyber_id = psi.lot_id
        WHERE psi.superseded = FALSE 
        AND ci.deleted <> TRUE
        AND substring(psi.cyber_id FROM 21 FOR 1) <> 'D'
    ),
    psi_sub AS (
        SELECT 
            psi.id,
            psi.cyber_id,
            psi.cyber_id_group,
            psi.lot_id,
            ci_id,
            ci_cyber_id
        FROM psi_ok psi
        UNION
        SELECT 
            psi.id,
            psi.cyber_id,
            psi.cyber_id_group,
            psi.lot_id,
            ci2.id AS ci_id,
            ci2.cyber_id AS ci_cyber_id
        FROM psi_ok psi
        LEFT OUTER JOIN cyber_id ci2 ON ci2.cyber_id_group_id = psi.ci_id
    ),
    nice_sr AS (
        SELECT 
            sr.id,
            product_search_index_id,
            out_batch_id,
            CASE 
                WHEN out_batch_id ~ '-R[0-9]{2}' THEN 
                    COALESCE(substring(out_batch_id from '^(.*-R\d{2})'), out_batch_id)
                ELSE 
                    LEFT(out_batch_id, 20)
            END AS nice_cyber_id
        FROM step_record sr
    ),
    psi_all_sr AS (
        SELECT 
            psi.id AS psi_id,
            psi.cyber_id,
            psi.cyber_id_group,
            psi.lot_id,
            psi.ci_id,
            psi.ci_cyber_id,
            nsr.id AS sr_id
        FROM psi_sub psi
        LEFT OUTER JOIN nice_sr nsr ON nsr.nice_cyber_id = psi.ci_cyber_id
    )
    SELECT 
        pas.sr_id,
        pas.psi_id,
        LEFT(pas.lot_id, 20) AS cyber_id,
        vsraf1.role_name,
        vsraf1.key AS field_key,
        vsraf1.value_convert_string AS s3_vottun,
        vsraf1.api || ' ' || vsraf1.api_version AS api,
        CAST(vsraf1.public_step AS boolean),  -- Added CAST to boolean
        vsraf1.stakeholder_name,
        string_agg(DISTINCT vsraf2.value_convert_string, ', ' ORDER BY vsraf2.value_convert_string) AS provider_name
    FROM psi_all_sr pas
    LEFT OUTER JOIN v_step_record_and_fields vsraf1 ON vsraf1.step_record_id = pas.sr_id
    LEFT OUTER JOIN v_step_record_and_fields vsraf2 ON vsraf2.step_record_id = pas.sr_id
        AND vsraf2.key IN ('Rough_Supplier', 'Rough_Buyer', 'Institution')
    WHERE vsraf1.api IS NOT NULL
        AND vsraf1.value_convert_string ~ '^http'
        AND vsraf1.key NOT IN ('Final_certificate', 'RJC_Member_Certificate')
    GROUP BY 
        pas.sr_id,
        pas.psi_id,
        LEFT(pas.lot_id, 20),
        vsraf1.role_name,
        vsraf1.key,
        vsraf1.value_convert_string,
        vsraf1.api || ' ' || vsraf1.api_version,
        vsraf1.public_step,
        vsraf1.stakeholder_name
    ORDER BY cyber_id DESC, sr_id DESC;

    -- Raise notice when the function completes successfully
    RAISE NOTICE 'Successfully created and populated tmp_ocr_files_in_steps table';

EXCEPTION
    WHEN OTHERS THEN
        -- Log any errors that occur during execution
        RAISE EXCEPTION 'Error in ocr_prepare_files_to_scan(): %', SQLERRM;
END;
$$;




-- *** CAMPS INTERESSANTS ***
-- **************************
--SELECT step_record_id, public_step, role_name, KEY, value_convert_string 
--  FROM v_step_record_and_fields vsraf 
-- WHERE cyber_id ~'CYR01-21-0100-196301'
----   AND KEY IN ('Rough_Supplier', 'Rough_Buyer', 'Institution')
--ORDER BY step_record_id DESC, key;

-- Control, només una línea per sr_id
SELECT sr_id, count(*) FROM tmp_ocr_files_in_steps GROUP BY sr_id HAVING count(*)>1;

-- ========================================================================================================================
-- Traspàs incremental a OCR_Results dels nous fitxers
-- ========================================================================================================================
INSERT INTO public.ocr_results
	( step_record_id,     psi_id,     cyber_id,     step_role,     field_key,     s3_vottun,     api,     public_step,     stakedholder_name, provider_name, moment)
SELECT
    sr_id AS step_record_id,    psi_id,    cyber_id,    role_name AS step_role,    field_key,     s3_vottun,    api,     public_step,     stakeholder_name, provider_name, now()
FROM
    public.tmp_ocr_files_in_steps
ON CONFLICT (step_record_id) DO UPDATE
SET
    psi_id = EXCLUDED.psi_id,
    cyber_id = EXCLUDED.cyber_id,
    step_role = EXCLUDED.step_role,
    field_key = EXCLUDED.field_key,
    s3_vottun = EXCLUDED.s3_vottun,
    api = EXCLUDED.api,
    public_step = EXCLUDED.public_step,
    md5sum = NULL,
    moment_md5 = NULL,
    stakeholder_name = EXCLUDED.stakeholder_name,
    provider_name = EXCLUDED.provider_name,
    moment = EXCLUDED.moment
WHERE
    ocr_results.s3_vottun IS DISTINCT FROM EXCLUDED.s3_vottun
RETURNING step_record_id,     psi_id,     cyber_id,     step_role,     field_key,     api,     public_step, s3_vottun, stakeholder_name, provider_name;



SELECT api, public_step, field_key, stakeholder_name 
  FROM ocr_results 
 LIMIT 3;




-- =======================================================================================
SELECT psi.id, psi.cyber_id, psi.cyber_id_group, psi.lot_id,
	   ci.cyber_id_group_id, ci.id AS  ci_id, ci.cyber_id AS ci_cyber_id
  FROM product_search_index psi
	   LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
 WHERE psi.superseded=FALSE AND ci.deleted <> TRUE

SELECT md5sum FROM ocr_

DELETE FROM ocr_files where

SELECT * FROM ocr_files WHERE md5sum IN (
SELECT md5sum FROM ocr_results WHERE cyber_id='CYR01-23-0621-279568');



-- =======================================================================================
-- Execució PYTHON de OCR pels fitxers nous
-- =======================================================================================
-- Consulta dels nous fitxers que encara NO tenen el OCR fet
SELECT * FROM ocr_results or3 WHERE md5sum IS NULL LIMIT 50;

-- Execució PYTHON

-- =======================================================================================
-- Control que NO queden OCRs per fer (= zero)
-- =======================================================================================
SELECT count(*) FROM ocr_results WHERE md5sum IS NULL;
SELECT * FROM  ocr_results WHERE md5sum IS NULL;

-- =======================================================================================
-- Report creation
-- =======================================================================================

SELECT * FROM ocr_files of2 ORDER BY moment DESC LIMIT 5;
SELECT * FROM ocr_results or2 WHERE md5sum ='31e6a2249419e2efc4073f43f53cafa6';

SELECT * FROM ocr_report or2 WHERE ocr_text ~* 'peter';

DROP TABLE ocr_report2;

--========================= SISTEMA ANTIC ========================= 
--SELECT DISTINCT  
--		initcap(replace((regexp_matches(of2.ocr_text, 
--		'^gil[ \t]+\S+|okavango diamond|de beers|rio tinto|beauty[ -]gems|maa[ \t]+\S+|prime[ -]+gems|\yigi\y|yashi gems|'||
--		'HRD ANTWERP|peter (&|and) brooks|diambel|jayamini gems|ggtl|C4CUT|ano gems|arctic canadian|universal[ ]+traders|centur[- \t]+\S+', 'gi'))[1],'-',' ')) AS ocr_stake,
--		REPLACE((regexp_match(of2.ocr_text, '((BW|SG|EU|AE)\s*\d{6,8})'))[1],' ','') AS ocr_kp,
--		( SELECT string_agg(match[1], ',') FROM regexp_matches(of2.ocr_text, '((BW|SG|EU|AE)\s*\d{6,8})', 'g') AS match) AS ocr_kp,
--		replace((regexp_match(of2.ocr_text, '(\d+,\d+\s*-\s*\d+,\d+\s*MM)', 'i'))[1], E'\n', '') AS ocr_diam,
--		(regexp_matches(of2.ocr_text, '(?:CYR\d{2}-)?(?:\d{2}-\d{4}-\d{6})', 'g'))[1] AS ocr_cyber_id,
--		of2.s3_cyber, of2.ocr_text, moment
  FROM ocr_files of2
  WHERE s3_cyber ~'22-0601-210290' -- https://cyberorigin.ch/cyberid/CYR01-22-0601-210290
  ORDER BY moment DESC LIMIT 100;

--========================= SISTEMA MODERN ========================= 
DROP TABLE ocr_report;
WITH ocrs AS (
	SELECT DISTINCT 
	 	or2.step_record_id, or2.psi_id, or2.cyber_id, or2.step_role, or2.field_key, 
			--
			(
			  SELECT string_agg(DISTINCT initcap(replace(match[1], '-', ' ')), ',')
			  FROM regexp_matches(of2.ocr_text,
			    '^gil[ \t]+\S+|okavango diamond|de beers|rio tinto|beauty[ -]gems|maa[ \t]+\S+|prime[ -]+gems|\yigi\y|yashi gems|'||
			    'HRD ANTWERP|peter (?:&|and) brooks|diambel|jayamini gems|ggtl|C4CUT|ano gems|arctic canadian|universal[ ]+traders|centur[- \t]+\S+', 'gi'
			  ) AS match
			) AS ocr_stake,
			--
			(
			  SELECT string_agg(DISTINCT match[1], ',')
			  FROM regexp_matches(of2.ocr_text, '((BW|SG|EU|AE)\s*\d{6,8})', 'g') AS match
			) AS ocr_kp,
			--
			COALESCE(
			    (regexp_match(of2.ocr_text, 
			        '(\d{2}-G-\d{5}|\d{2}-\d{4}/\d{1,2})'
			    ))[1],
			    (regexp_match(of2.ocr_text, 
			        'reference:\s*(\.+)\n'
			    ))[1]) AS ocr_doc_id,
			--
			replace((regexp_match(of2.ocr_text, '(\d{1,2}\.\d{2}\.\d{4})','i'))[1], E'\n', '') AS ocr_date,
			--
			(
			  SELECT replace(replace(string_agg(DISTINCT match[1], ','),E'\n', ''), E' to ', '-')
			  FROM regexp_matches(of2.ocr_text, '(\d+[.,]\d+\s*(?:to|-)\s*\d+[.,]\d+\s*(?:MM)?)', 'g') AS match
			) AS ocr_diam,
			--
			(
			  SELECT string_agg(DISTINCT match[1], ',')
			  FROM regexp_matches(of2.ocr_text, '(?:C[RYV][RY][0OD]\d{1}-)??(?:\d{2}-\d{4}-\d{6})', 'g') AS match
			) AS ocr_cyber_id,
			--
			of2.s3_cyber, of2.ocr_text, of2.md5sum, of2.moment,
			or2.stakeholder_name, 
			initcap(regexp_replace(or2.provider_name, '\s*M/S\s*|\s*company|\s*singapore', '', 'gi')) AS provider_name, 
			public_step, api
	  FROM ocr_results or2 
	       LEFT OUTER JOIN ocr_files of2 ON or2.md5sum=of2.md5sum
	)
	SELECT step_record_id, psi_id, cyber_id, public_step, step_role, field_key,
			string_agg(ocr_stake, ', ' ORDER BY ocr_stake) AS ocr_stake, ocr_kp, ocr_doc_id, ocr_date, ocr_diam, ocr_cyber_id, 
			REPLACE(stakeholder_name, ' BV', '') AS stakeholder_name, provider_name, api, ocr_text, s3_cyber
	 INTO ocr_report
	 FROM ocrs
--	WHERE s3_cyber ~'22-0601-210289'
	GROUP BY  step_record_id, psi_id, cyber_id, step_role, field_key, ocr_text, ocr_kp, ocr_doc_id, ocr_date, ocr_diam, ocr_cyber_id, 
			ocr_kp,ocr_diam,ocr_cyber_id, s3_cyber, public_step, stakeholder_name, provider_name, api
	ORDER BY cyber_id, step_record_id;

SELECT * FROM ocr_report;

 
--FROM ocr_files of2 
--WHERE  s3_cyber ~'22-0601-210289'
--ORDER BY moment DESC ;
 
--SELECT replace((regexp_match('Our reference: 4165
--/1
--', '.*?(\d+\s*/\s*\d+)', 'i'))[1], E'\n', '');

--DROP TABLE ocr_report;
--WITH ocrs AS (
--SELECT DISTINCT or2.step_record_id, or2.psi_id, or2.cyber_id, or2.step_role, or2.field_key, of2.ocr_text, 
--		initcap(replace((regexp_matches(of2.ocr_text, 
--		'^gil[ \t]+\S+|okavango diamond|de beers|rio tinto|beauty[ -]gems|maa[ \t]+\S+|prime[ -]+gems|\yigi\y|yashi gems|'||
--		'HRD ANTWERP|peter & brooks|diambel|jayamini gems|ggtl|C4CUT|ano gems|arctic canadian|universal[ ]+traders|centur[- \t]+\S+', 'gi'))[1],'-',' ')) AS ocr_stake,
----		REPLACE((regexp_match(of2.ocr_text, '((BW|SG|EU|AE)\s*\d{6,8})'))[1],' ','') AS ocr_kp,
--		( SELECT string_agg(match[1], ',') FROM regexp_matches(of2.ocr_text, '((BW|SG|EU|AE)\s*\d{6,8})', 'g') AS match) AS ocr_kp,
--		replace((regexp_match(of2.ocr_text, '(\d+,\d+\s*-\s*\d+,\d+\s*MM)', 'i'))[1], E'\n', '') AS ocr_diam,
--		(regexp_match(of2.ocr_text, 'CYR\d{2}-\d{2}-\d{4}-\d{6}'))[1] AS ocr_cyber_id,
--		of2.s3_cyber, stakeholder_name, initcap(regexp_replace(provider_name, '\s*M/S\s*|\s*company|\s*singapore', '', 'gi')) AS provider_name, public_step, api
--  FROM ocr_results or2 
--       LEFT OUTER JOIN ocr_files of2 ON or2.md5sum=of2.md5sum
--)
--SELECT step_record_id, psi_id, cyber_id, public_step, step_role, field_key,
--		string_agg(ocr_stake, ', ' ORDER BY ocr_stake) AS ocr_stake, ocr_kp, ocr_diam, ocr_cyber_id,
--		REPLACE(stakeholder_name, ' BV', '') AS stakeholder_name, provider_name, api,
--		ocr_text, 
--		s3_cyber
-- INTO ocr_report
-- FROM ocrs
--WHERE s3_cyber ~'22-0601-210289'
--GROUP BY  step_record_id, psi_id, cyber_id, step_role, field_key, ocr_text, ocr_kp, ocr_diam, ocr_cyber_id, 
--		ocr_kp,ocr_diam,ocr_cyber_id, s3_cyber, public_step, stakeholder_name, provider_name, api
--ORDER BY cyber_id, step_record_id;
--
--SELECT * FROM ocr_report or2;
--
--WITH pre1 AS (
--SELECT cyber_id, public_step AS s, step_role, field_key,
--	   lower(regexp_replace(ocr_stake,       '\s*(Gems|diamond| |gil|bv|co.,ltd.)\s*','','gi')) AS doc_ocr, 
--	   lower(regexp_replace(stakeholder_name,'\s*(Gems|diamond| |gil|bv|\.|,|ltd)\s*','','gi')) AS stk_api, 
--	   lower(regexp_replace(provider_name,   '\s*(Gems|diamond| |gil|bv|co.,ltd.)\s*','','gi')) AS prov_data 
--  FROM ocr_report or2),
--pre2 AS (
-- SELECT *,
--        EXISTS (
--           SELECT 1
--           FROM unnest(string_to_array(doc_ocr, ',')) AS doc1
--           WHERE doc1 = ANY(string_to_array(stk_api, ','))
--       ) AS doc_stk,
--        EXISTS (
--           SELECT 1
--           FROM unnest(string_to_array(doc_ocr, ',')) AS doc2
--           WHERE doc2 = ANY(string_to_array(prov_data, ','))
--       ) AS doc_prov,
--        EXISTS (
--           SELECT 1
--           FROM unnest(string_to_array(stk_api, ',')) AS doc3
--           WHERE doc3 = ANY(string_to_array(prov_data, ','))
--       ) AS stk_prov
--FROM pre1
----WHERE cyber_id ~'23-0630'
--)
--SELECT DISTINCT cyber_id,* 
--  FROM pre2
-- WHERE s IN (5,6)-- AND  doc_stk=FALSE
--   AND prov_data~'prime'
-- ORDER BY cyber_id;
----SELECT * 
----  FROM pre2
---- WHERE cyber_id~'CYR01-22-0696-232936'
------ WHERE s IN (5,6) AND doc_stk=FALSE
-- ORDER BY cyber_id, s;
--
--SELECT * FROM ocr_report or2 WHERE cyber_id~'23-0583';
--
--SELECT * FROM cyber_id ci  WHERE cyber_id ~'CYR01-22-0696-232936' ORDER BY id DESC;
-- 
--SELECT * FROM workflows w 





-- =======================================================
-- REPORT #1: Wrong CyberID
-- =======================================================
SELECT wn.blockchain_name, ocr.api, cyber_id AS block_cyberid, ocr_cyber_id, public_step||' '||step_role AS step,
		'https://cyberorigin.ch/cyberid/'|| cyber_id AS web, s3_cyber AS PDF 
		-- , ocr.ocr_text 
  FROM ocr_report ocr
       LEFT OUTER JOIN workflow_name wn ON wn.api=SPLIT_PART(ocr.api, ' ', 1)
 WHERE ocr_cyber_id<>cyber_id
 ORDER BY wn.blockchain_name, cyber_id;

-- =======================================================
-- REPORT #2: Wrong stakeholder
-- =======================================================
WITH ocr_found AS (
SELECT (POSITION(lower(stakeholder_name) IN lower(ocr_stake))>0) AS word_found, *
FROM ocr_report)
SELECT wn.blockchain_name, ocr.api, ocr.cyber_id, public_step, step_role, field_key,word_found, stakeholder_name AS stake_blockchain,   ocr_stake AS stake_ocr, 
		'https://cyberorigin.ch/cyberid/'|| cyber_id AS web, s3_cyber AS PDF
  FROM ocr_found ocr
       LEFT OUTER JOIN workflow_name wn ON wn.api=SPLIT_PART(ocr.api, ' ', 1)
 WHERE ocr.api ~'diamonds-full' AND public_step<>10 AND word_found<>TRUE
 ORDER BY word_found, api, public_step, cyber_id;

-- =======================================================
-- REPORT #3: Wrong KP
-- =======================================================
--SELECT wn.blockchain_name, or2.api, or2.cyber_id,(REPLACE(ocr_kp,' ','')=REPLACE(vsraf.value_convert_string,' ','')) AS are_equals, 
--REPLACE(vsraf.value_convert_string,' ','') AS block_kp,  REPLACE(ocr_kp,' ','') AS ocr_kp, 
--		'https://cyberorigin.ch/cyberid/'|| or2.cyber_id AS web, or2.s3_cyber AS PDF
--  FROM ocr_report or2 
--       LEFT OUTER JOIN v_step_record_and_fields vsraf  ON or2.step_record_id=vsraf.step_record_id AND KEY='Kimberley_id'
--       LEFT OUTER JOIN workflow_name wn ON wn.api=SPLIT_PART(or2.api, ' ', 1)
-- WHERE (REPLACE(ocr_kp,' ','')=REPLACE(vsraf.value_convert_string,' ',''))=FALSE


 SELECT wn.blockchain_name, or2.api, or2.cyber_id, or2.public_step AS step, step_role, field_key,
(
        array(
            SELECT DISTINCT trim(unnest(string_to_array(REPLACE(ocr_kp, ' ', ''), ',')))
            ORDER BY 1
        ) = 
        array(
            SELECT DISTINCT trim(unnest(string_to_array(REPLACE(vsraf.value_convert_string, ' ', ''), ',')))
            ORDER BY 1
        )
    ) AS are_equals,
    REPLACE(vsraf.value_convert_string, ' ', '') AS block_kp,
    REPLACE(ocr_kp, ' ', '') AS ocr_kp,
    'https://cyberorigin.ch/cyberid/'|| or2.cyber_id AS web,
    or2.s3_cyber AS PDF
FROM ocr_report or2
LEFT OUTER JOIN v_step_record_and_fields vsraf 
    ON or2.step_record_id = vsraf.step_record_id AND KEY = 'Kimberley_id'
LEFT OUTER JOIN workflow_name wn 
    ON wn.api = SPLIT_PART(or2.api, ' ', 1)
WHERE (
        array(
            SELECT DISTINCT trim(unnest(string_to_array(REPLACE(ocr_kp, ' ', ''), ',')))
            ORDER BY 1
        ) = 
        array(
            SELECT DISTINCT trim(unnest(string_to_array(REPLACE(vsraf.value_convert_string, ' ', ''), ',')))
            ORDER BY 1
        )
    ) = FALSE
  AND vsraf.value_convert_string IS NOT NULL  AND ocr_kp IS NOT NULL 
ORDER BY cyber_id;
 
--SELECT * FROM ocr_report WHERE cyber_id='CYR01-21-0098-196263'; 

SELECT de FROM product_search_index psi 

-- =======================================================
-- REPORT #4: Missing KP
-- =======================================================
 SELECT wn.blockch2ain_name, or2.api , or2.cyber_id, stakeholder_name, public_step AS step, step_role, field_key, s3_cyber AS PDF
  FROM ocr_report or2 
       LEFT OUTER JOIN workflow_name wn ON wn.api=SPLIT_PART(or2.api, ' ', 1)
 WHERE step_role IN ('Naturalness Control (M-Screen)', 'RoughPurchase', 'Cut', '4C Quality Control', 'RoughCertification', 'Order approval') 
   AND ocr_kp IS NULL
 ORDER BY blockchain_name, step, cyber_id;


 SELECT wn.blockchain_name, or2.cyber_id, stakeholder_name, public_step AS step, step_role, field_key, s3_cyber AS PDF
  FROM ocr_report or2 
       LEFT OUTER JOIN workflow_name wn ON wn.api=SPLIT_PART(or2.api, ' ', 1)
 WHERE ocr_kp IS NOT NULL
--   AND public_step=11
 ORDER BY blockchain_name, step, cyber_id;




 SELECT *
  FROM ocr_report or2 
WHERE cyber_id='CYR01-21-0098-196263'

 SELECT *
  FROM ocr_results or2 
  WHERE cyber_id='CYR01-21-0098-196263'

SELECT ocr_text, 
       REPLACE((regexp_match(of2.ocr_text, '((BW|SG|EU|AE)\s*\d{6,8})'))[1],' ','') AS ocr_kp
  FROM ocr_files of2 WHERE of2.md5sum ='1e6541d26ab7ca44dddb4d23cb52541c';
  
 
SELECT 
    ocr_text,
    string_agg(
        REPLACE(match[1], ' ', ''),
        ','
    ) AS ocr_kp
FROM 
    ocr_files of2,
    regexp_matches(of2.ocr_text, '((BW|SG|EU|AE)\s*\d{6,8})', 'g') AS match
WHERE 
    of2.md5sum = '1e6541d26ab7ca44dddb4d23cb52541c'
GROUP BY 
    ocr_text;
 
 
 
 
 
 
 
  
-- =======================================================
-- CONTROL 1: Hi ha algun proveïdor nou?
-- =======================================================
WITH tots AS (
SELECT DISTINCT or2.step_record_id, 
		initcap((regexp_matches(of2.ocr_text, 
		'^gil[ \t]+\S+|okavango diamond|de beers|rio tinto|^beauty[^\n]*|maa[ \t]+\S+|prime[ ]+gems|\yigi\y|yashi gems|'||
		'HRD ANTWERP|peter (?:&|and) brooks|diambel|jayamini gems|ggtl|C4CUT|ano gems|arctic canadian|universal[ ]+traders|centur[ \t]+\S+|[ ]', 'gi'))[1]) AS ocr_stake
  FROM ocr_results or2
       LEFT OUTER JOIN ocr_files of2 ON or2.md5sum=of2.md5sum
 WHERE of2.ocr_text !~ '((BW|SG|EU|AE)\s*\d{6,8})' -- NO té KP
)
SELECT step_record_id, count(*)
  FROM tots
 GROUP BY step_record_id
HAVING count(*)=1;

-- =======================================================
-- CONTROL 2: Hi ha algun step_record_id amb > 1 fila?
-- =======================================================
WITH tots AS (
SELECT DISTINCT or2.step_record_id, or2.psi_id, or2.cyber_id, or2.step_role, or2.field_key, of2.ocr_text, 
		initcap((regexp_matches(of2.ocr_text, 
		'^gil[ \t]+\S+|okavango diamond|de beers|rio tinto|^beauty[^\n]*|maa[ \t]+\S+|prime[ ]+gems|\yigi\y|yashi gems|'||
		'HRD ANTWERP|peter & brooks|diambel|jayamini gems|ggtl|C4CUT|ano gems|arctic canadian|universal[ ]+traders|centur[ \t]+\S+', 'gi'))[1]) AS ocr_stake,
		(regexp_match(of2.ocr_text, '((BW|SG|EU|AE)\s*\d{6,8})'))[1] AS ocr_kp,
		replace((regexp_match(of2.ocr_text, '(\d+,\d+\s*-\s*\d+,\d+\s*MM)', 'i'))[1], E'\n', '') AS ocr_diam,
		(regexp_match(of2.ocr_text, 'CYR\d{2}-\d{2}-\d{4}-\d{6}'))[1] AS ocr_cyber_id,
		of2.s3_cyber
  FROM ocr_results or2
       LEFT OUTER JOIN ocr_files of2 ON or2.md5sum=of2.md5sum
), tots2 AS (
SELECT step_record_id, psi_id, cyber_id, step_role, field_key,
		string_agg(ocr_stake, ', ' ORDER BY ocr_stake) AS ocr_stake,
		ocr_kp,ocr_diam,ocr_cyber_id,  ocr_text, s3_cyber
 FROM tots
GROUP BY  step_record_id, psi_id, cyber_id, step_role, field_key, ocr_text, 
		ocr_kp,ocr_diam,ocr_cyber_id, s3_cyber
) SELECT step_record_id, count(1)
   FROM tots2
   GROUP BY step_record_id
  HAVING count(1)>1;
