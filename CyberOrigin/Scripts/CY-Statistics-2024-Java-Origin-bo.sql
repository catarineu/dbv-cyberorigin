--                                  cust, brand,       type, begin?, end?,  cyber_ids? 
--                                        cust, brand, type, begin?, end?,  cyber_ids?
SELECT
    blockchain_id,
    cust  || ' - ' || custname AS cust,
    brand || ' - ' || brandname AS brand,
    providers ,
    origens,
    lots ,  lots_pc || ' %' AS lots_pc,
    carats, carats_pc || ' %' AS carats_pc,
    pieces, pieces_pc || ' %' AS pieces_pc,
    cyber_ids
  FROM get_stats_origin(NULL, NULL,  NULL, NULL,   NULL,  TRUE); -- NULL, NULL,  NULL, NULL,   NULL,  FALSE 
 
--                                  cust, brand, type, begin?, end?,  cyber_ids? by_year?
SELECT * FROM get_stats_origin(NULL, NULL, NULL, NULL, NULL, TRUE, TRUE);




WITH tmp AS (
SELECT YEAR, name_fr || ' (' || blockchain_id || ')' AS block,
		cust, custname, brand, brandname,  
--		REPLACE(REPLACE(initcap(providers),',',';'),'Diamond Company', '') AS providers, 
		REPLACE(REPLACE(initcap(origens),',',';'),'Diamond Company', '') AS origens,
		lots, round(carats::numeric,2) AS carats, pieces, cyber_ids
  FROM get_stats_origin(NULL, NULL, NULL, NULL, NULL, TRUE, TRUE)
 WHERE 
       (cust='00112' OR brand='00112') AND 
   YEAR IN ('2023', '2024')
--   AND blockchain_id='Blockchain-01'
) 
SELECT YEAR, block, cust, ccc1."name", brand, ccc2."name", '-' AS origens, /*providers,*/ origens,
		sum(lots) AS s_lots, sum(carats) AS s_carats, sum(pieces) AS s_pieces, string_agg(cyber_ids,'') AS cybers
	FROM tmp
	     LEFT OUTER JOIN cob_chain_company ccc1 ON  ccc1.user_external_id=cust
	     LEFT OUTER JOIN cob_chain_company ccc2 ON  ccc2.user_external_id=brand
GROUP BY GROUPING SETS ((YEAR, block, cust, ccc1.name, brand, ccc2.name, /*providers,*/ origens),
						(YEAR, block, cust, ccc1.name, brand, ccc2.name),())
ORDER BY YEAR, block, cust, brand, GROUPING(/*providers,*/ origens), sum(pieces) DESC, sum(carats) DESC, sum(lots) DESC;



SELECT user_external_id, name, name_to_show
  FROM cob_chain_company 
-- WHERE level1client_company_id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'
   WHERE type = 'LEVEL_2_CLIENT_COMPANY'
 ORDER BY user_external_id ;




SELECT * FROM product_search_index psi WHERE lot_id='CYR01-24-0035-302424-R03';

SELECT * FROM step_record_fields WHERE step_record_id=47250;
SELECT * FROM step_record_fields WHERE step_record_id=38891;

SELECT LEFT(cyber_id,27) FROM step_record WHERE id=47250;
SELECT cyber_id FROM step_record WHERE id=38891;

SELECT user_external_id, name FROM cob_chain_company ccc WHERE user_external_id IN ('01099', '00132', '01092', '00314');
SELECT * FROM cob_chain_company ccc WHERE user_external_id ='01092';

	SELECT DISTINCT substring(sr.cyber_id FROM '^(.*?-R[0-9]+[0-9])') AS cyber_id, cyber_id_group_id, ci.deleted
	  FROM step_record sr
	       LEFT OUTER JOIN cyber_id ci ON (ci.cyber_id=substring(sr.cyber_id FROM '^(.*?-R[0-9]+[0-9])'))
	 WHERE  ci.deleted = FALSE
		AND substring(sr.cyber_id FROM '^(.*?-R[0-9]+[0-9])')~'24-0035';


-- CYR01-22-0641-218982, CYR01-22-0641-218983, CYR01-22-0641-218984, CYR01-22-0641-218985, CYR01-22-0641-218986, CYR01-22-0641-218987, CYR01-22-0641-218988
-- CYR01-23-0550-259474, CYR01-23-0550-259475, CYR01-23-0550-259476, CYR01-23-0550-259477, CYR01-23-0550-259478, CYR01-23-0550-259479, CYR01-23-0550-259480

SELECT DISTINCT "timestamp", cyber_id, KEY, value_convert_string,
		RANK() OVER (PARTITION BY cyber_id ORDER BY "timestamp" DESC) AS RANK
  FROM v_step_record_and_fields vsraf		
 WHERE cyber_id = ANY(string_to_array('CYR01-22-0642-219025, CYR01-22-0642-219026, CYR01-22-0642-219027, CYR01-22-0642-219028, CYR01-22-0642-219029, CYR01-22-0642-219030, CYR01-22-0642-219031',','))
--AND KEY='Final_certificate'
AND vsraf.cyber_id_deleted =FALSE AND vsraf.group_cyber_id_deleted =FALSE
ORDER BY cyber_id, "timestamp" desc


