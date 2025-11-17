-- Valors possibles ------------------------------------------------------------
SELECT wn.blockchain_name, dev.api, api_version AS v, enum_type, cob_value, name, name_fr, dev.*
FROM dynamic_enum_value dev
LEFT OUTER JOIN workflow_name wn ON wn.api = dev.api
WHERE enum_type IN ('Material','StoneType', 'Type', 'Cut')
AND obsolete = FALSE
AND api_version = (
    SELECT MAX(api_version) 
    FROM dynamic_enum_value dev2 
    WHERE dev2.api = dev.api
)
ORDER BY blockchain_name, api_version, enum_type, cob_value;

-- Valors usats en els lots actuals --------------------------------------------
SELECT wn.blockchain_name, dev.api, api_version AS v, enum_type, cob_value
  FROM dynamic_enum_value dev 
  	   LEFT OUTER JOIN workflow_name wn ON wn.api=dev.api
 WHERE enum_type IN ('Material','StoneType', 'Type', 'Cut') 
   AND obsolete = FALSE 
ORDER BY blockchain_name, api_version, enum_type, cob_value ;

-- Valors usats en els lots actuals --------------------------------------------
SELECT DISTINCT api, vsraf.api_version AS v, public_step || ' ' || role_name AS step,  KEY, lower(value_convert_string) AS value
  FROM v_step_record_and_fields vsraf 
       LEFT OUTER JOIN cyber_id ci ON ci.cyber_id = vsraf.cyber_id_revision 
 WHERE KEY IN ('Material','StoneType', 'Type', 'Cut')
   AND ci.cancelled = FALSE
   AND vsraf.api_version =  (
	    SELECT MAX(api_version) 
	    FROM dynamic_enum_value dev2 
	    WHERE dev2.api = vsraf.api)
ORDER BY api,vsraf.api_version, KEY, public_step || ' ' || role_name;


SELECT * FROM v_step_record_and_fields WHERE lower(value_convert_string) ='saphirs roses'

SET plan_cache_mode = force_custom_plan;
SELECT * FROM get_new_stats_detail('01', '00009', NULL, NULL, NULL, NULL, FALSE, FALSE, FALSE, FALSE);
--p_diamanter, p_customer, p_brand, p_type, p_begin, p_end, p_only_nfts, p_by_year, p_by_origins, p_with_cyber_ids


 

SELECT  *
FROM public.get_new_stats_detail (CAST('01' AS text), CAST('00009' AS text), CAST(NULL AS text), CAST(NULL AS text), CAST(CAST(NULL AS varchar(255)) AS date),
    CAST(CAST(NULL AS varchar(255)) AS date), FALSE, FALSE, FALSE, FALSE);


UPDATE dynamic_enum_value SET obsolete =TRUE WHERE api='diamonds';