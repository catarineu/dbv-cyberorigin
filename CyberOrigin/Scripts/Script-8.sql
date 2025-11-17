 @set cyber = 'CYR01-23-0706-293515'
--CYR01-22-0642-219025, CYR01-22-0642-219026, CYR01-22-0642-219027, CYR01-22-0642-219028, CYR01-22-0642-219029, CYR01-22-0642-219030, CYR01-22-0642-219031
-- register_log: Últims STEPS. Principalment per veure darrers ERRORS de pas.
	SELECT *,id, timestamp, activity_name, api || ' v' || api_version AS api, blockchain ,	 cyber_id , lot_id_out, step, success, 
	 	timestamp_request, timestamp_response, timestamp_response - timestamp_request AS diff,
	    LEFT((xpath('//errorCode/text()'::text, xml_response::xml))[1]::TEXT,40) AS errorcode,
	    LEFT((xpath('//faultstring/text()'::text, xml_response::xml))[1]::TEXT,200) AS message
	    --xml_response, xml_request
	 FROM register_log
	WHERE cyber_id~${cyber}
--	 AND timestamp_response >= '2023-10-01'
--	 AND success = false
--   AND (xpath('//errorCode/text()'::text, xml_response::xml))[1]::text IS NOT NULL
	ORDER BY id DESC NULLS LAST ;


-- DETALL de dades enviades en passos
 SELECT  timestamp, public_step, role_name, KEY, LEFT(group_cyber_id,20), value_convert_string, cyber_id
   FROM 	v_step_record_and_fields vsraf  
  WHERE cyber_id ~ ${cyber} -- replace('22-0503',', ','|')      
--    AND KEY ~'Colour'
--    AND value_convert_string ~'202'
  ORDER BY timestamp desc, public_step, KEY;
  

 WITH hermes AS (
 SELECT id, lot_id, cyber_id FROM product_search_index psi 
  WHERE superseded= FALSE
--    AND date >= '2024-01-01'
    AND (brand_id2 IN ('00009','00314') OR customer_id2 IN ('00009','00314')))
, cybs AS (
    SELECT id FROM cyber_id ci WHERE cyber_id IN (SELECT lot_id FROM hermes))
, fullcybs AS (
SELECT cyber_id FROM cyber_id ci 
 WHERE id IN (SELECT id FROM cybs) OR cyber_id_group_id IN (SELECT id FROM cybs))
SELECT * FROM step_record sr JOIN fullcybs ON LEFT(fullcybs.cyber_id, 20)=sr.cyber_id
 WHERE stakeholder=6;

SELECT DISTINCT customer_id2, brand_id2, count(*), string_agg(lot_id,',')
  FROM product_search_index psi
 WHERE cyber_id IN (SELECT DISTINCT LEFT(cyber_id,20) FROM step_record WHERE stakeholder =6)
   AND superseded=FALSE 
   AND date>='2024-01-01'
 GROUP BY customer_id2, brand_id2 ;
 
-- CYR01-23-0512-245734-R03,CYR01-23-0637-283131-R03,CYR01-23-0637-283130-R03,CYR01-23-0511-245732-R04,CYR01-23-0514-245738-R05,CYR01-23-0513-245736-R05,CYR01-23-0510-245730-R06

WITH ids AS (
SELECT DISTINCT id, cyber_id  FROM step_record sr WHERE cyber_id ~'23-0512-245734'
and stakeholder =6)
SELECT * FROM step_record_fields srf WHERE step_record_id IN (SELECT id FROM ids)

select user_external_id, name FROM cob_chain_company ccc  WHERE user_external_id IN ('00009','01092','01105')

SELECT * FROM step

SELECT * FROM cob_chain_company ccc WHERE name ~* 'maa'
-- Sheetal
-- Jayamni

SELECT * FROM step_record_fields srf WHERE string_value ~*'shee';
