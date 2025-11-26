SELECT year AS year, workflow_type AS blockChainType, workflow_id AS blockChainName, workflow_name AS blockChainWorkflowName, diamanter_extid AS
    diamanterExternalId, diamanter_namets AS diamanterNameToShow, customer_extid AS customerExternalId, customer_namets AS customerNameToShow,
    brand_extid AS brandExternalId, brand_namets AS brandNameToShow, origin_countries AS originCountries, origin_providers AS originProviders,
    lots_sum AS sumLots, nfts_sum AS sumNfts, pieces_sum AS sumPieces, carats_sum AS sumCarats, lots_pc AS pctLots, nfts_pc AS pctNfts, pieces_pc AS
    pctPieces, carats_pc AS pctCarats, cyber_ids AS cyberIds
FROM public.get_new_stats_detail ('01', '00009', NULL, NULL, '2025-01-01', '2025-06-30', FALSE, FALSE, TRUE, FALSE);

--p_diamanter text DEFAULT NULL::text, p_customer text DEFAULT NULL::text, p_brand text DEFAULT NULL::text, p_type text DEFAULT NULL::text, p_begin date DEFAULT NULL::date, p_end date DEFAULT NULL::date, p_only_nfts boolean DEFAULT false, p_by_year boolean DEFAULT false, p_by_origins boolean DEFAULT false, p_with_cyber_ids boolean DEFAULT false)


--                                  cust, brand,       type, begin?, end?,  cyber_ids? 
--                                        cust, brand, type, begin?, end?,  cyber_ids?
--WITH tmp AS (
SELECT
    YEAR,
    blockchain_id,
    cust , custname ,
    brand, brandname ,
    providers ,
    origens,
    lots ,  --lots_pc || ' %' AS lots_pc,
    carats, --carats_pc || ' %' AS carats_pc,
    pieces, --pieces_pc || ' %' AS pieces_pc,
    cyber_ids 
  FROM get_stats_origin(NULL, NULL,  NULL, '2025-01-01', '2025-07-01',   FALSE, FALSE)
 ORDER BY YEAR, custname, brandname, lots DESC
-- )  SELECT json_agg(t) FROM tmp t;
 
 ; -- NULL, NULL,  NULL, NULL,   NULL,  FALSE 
 
--                                  cust, brand, type, begin?, end?,  cyber_ids? by_year?
SELECT * FROM get_stats_origin('01115', NULL, NULL, NULL, NULL, TRUE, TRUE);

-- get_new_stats_detail(p_diamanter, p_customer, p_brand, p_type, p_begin, p_end, 
-- p_only_nfts, p_by_year, p_by_origins, p_with_cyber_ids)
SELECT YEAR, workflow_id, workflow_name, customer_extid, customer_namets, brand_extid, brand_namets, lots_sum, pieces_sum, carats_sum
FROM get_new_stats_detail(NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, FALSE, FALSE)
ORDER BY YEAR DESC, carats_sum DESC NULLS LAST; 

SELECT YEAR, customer_extid AS "Customer", customer_namets AS "Cust. Name", brand_extid AS brand, brand_namets AS "Brand Name",  substring(workflow_id,12) || ' - ' || workflow_name AS blockchain, 
		sum(carats_sum) AS Carats, sum(lots_sum) AS Lots, sum(pieces_sum) AS Pieces 
FROM get_new_stats_detail(NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, FALSE, FALSE)
GROUP BY YEAR, workflow_id, workflow_name, customer_extid, customer_namets, brand_extid, brand_namets
ORDER BY YEAR DESC, Carats DESC NULLS LAST; 


SELECT YEAR, customer_extid AS "Customer", customer_namets AS "Cust. Name", brand_extid AS brand, brand_namets AS "Brand Name", sum(carats_sum) AS Carats, sum(lots_sum) AS Lots, sum(pieces_sum) AS Pieces 
FROM get_new_stats_detail(NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, FALSE, FALSE)
GROUP BY YEAR, customer_extid, customer_namets, brand_extid, brand_namets
ORDER BY YEAR DESC, Carats DESC NULLS LAST; 


WHERE YEAR='2025'; 

SELECT * FROM get_stats_origin(NULL, NULL, NULL, NULL, NULL, FALSE, TRUE)
  WHERE (cust='01092' OR brand='01092')
    AND YEAR='2022'; 


SELECT * FROM cob_chain_company ccc ;


SELECT * FROM erp_date_rfb edr WHERE cyber_id~'22-0556-204036'

SELECT sum(lots) FROM get_stats_origin(NULL, NULL, NULL, NULL, NULL, TRUE, TRUE); 

SELECT * FROM ocr_report or2 WHERE cyber_id ~'CYR01-23-0666-291430' 





SELECT user_external_id, name, name_to_show, * 
  FROM cob_chain_company 
-- WHERE level1client_company_id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'
--   AND type = 'LEVEL_2_CLIENT_COMPANY'
 ORDER BY user_external_id ;

-- CYR01-22-0641-218982, CYR01-22-0641-218983, CYR01-22-0641-218984, CYR01-22-0641-218985, CYR01-22-0641-218986, CYR01-22-0641-218987, CYR01-22-0641-218988
-- CYR01-23-0550-259474, CYR01-23-0550-259475, CYR01-23-0550-259476, CYR01-23-0550-259477, CYR01-23-0550-259478, CYR01-23-0550-259479, CYR01-23-0550-259480

SELECT DISTINCT "timestamp", cyber_id, KEY, value_convert_string,
		RANK() OVER (PARTITION BY cyber_id ORDER BY "timestamp" DESC) AS RANK
  FROM v_step_record_and_fields vsraf		
 WHERE cyber_id = ANY(string_to_array('CYR01-22-0642-219025, CYR01-22-0642-219026, CYR01-22-0642-219027, CYR01-22-0642-219028, CYR01-22-0642-219029, CYR01-22-0642-219030, CYR01-22-0642-219031',','))
--AND KEY='Final_certificate'
AND vsraf.cyber_id_deleted =FALSE AND vsraf.group_cyber_id_deleted =FALSE
ORDER BY cyber_id, "timestamp" desc


