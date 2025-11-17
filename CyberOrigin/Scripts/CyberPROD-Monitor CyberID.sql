@set cyber = '23-0674'

--************************************ PSI ************************************
SELECT "timestamp", cyber_id, cyber_id_group, group_record_type, superseded, data_field_type , is_only_one_production  
  FROM product_search_index psi WHERE cyber_id ~ ${cyber} ORDER BY "timestamp" DESC;
 
-- ************************************ CyberID ************************************
SELECT id, deleted AS del, cancelled AS canc, cyber_id, cyber_id_group_id, "timestamp", api_name, api_version AS v, revision AS rev,cyber_id_type
  FROM cyber_id ci  
 WHERE cyber_id ~ ${cyber}
 ORDER BY "timestamp" DESC;

-- ************************************ CyberID (rank) ************************************
 WITH tots AS (
SELECT id, deleted AS del, cancelled AS canc, cyber_id, cyber_id_group_id, lot_id, "timestamp", api_name, api_version AS v, revision AS rev,cyber_id_type,
	   rank() OVER (PARTITION BY lot_id ORDER BY revision DESC) AS rrank
  FROM cyber_id ci  
 WHERE cyber_id ~ ${cyber})
SELECT * FROM tots 
 WHERE rrank=1 
 ORDER BY "timestamp" DESC;
 
-- ************************************ STEPS ************************************
	SELECT id, timestamp, activity_name, api || ' v' || api_version AS api, blockchain ,	 cyber_id , lot_id_out, step, success, 
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

SELECT coalesce(group_cyber_id, cyber_id), chain_member_company_name, KEY, value_convert_string AS value, api, api_version, "timestamp"
  FROM v_step_record_and_fields vsraf 
 WHERE chain_member_company_name <> 'MAA Diamonds'
   AND value_convert_string ~ 'Prime'
 ORDER BY timestamp DESC, key;

@set cyber = '23-0590-272763'

 
-- CYR01-21-0101-196329
-- CYR01-22-0532-201393 

SELECT cyber_id, lot_id, cyber_id_group FROM product_search_index psi WHERE cyber_id_group  IS NULL AND superseded =FALSE ;

SELECT cyber_id, lot_id, cyber_id_group FROM product_search_index psi WHERE cyber_id ='CYR01-23-0510-245730D258339';

WITH tots AS (
	SELECT vsraf.api ||' '||vsraf.api_version AS api, COALESCE(vsraf.group_cyber_id,vsraf.cyber_id_revision) AS cyber_id,
	       string_agg(DISTINCT CASE WHEN KEY = 'Rough_Buyer' THEN public_step||'-'||initcap(value_convert_string) ELSE '' END, ', ') AS rough_buyer,
	       string_agg(DISTINCT CASE WHEN KEY = 'Rough_Supplier' THEN public_step||'-'||initcap(value_convert_string) ELSE '' END, ', ') AS rough_supplier,
		   string_agg(DISTINCT to_char(vsraf.public_step,'FM00')||'-'||LEFT(COALESCE(vsraf.chain_member_company_name,''),5),', ' 
		   		      ORDER BY to_char(vsraf.public_step,'FM00')||'-'||LEFT(COALESCE(vsraf.chain_member_company_name,''),5)) AS stakeholders
	  FROM v_step_record_and_fields vsraf 
	       LEFT OUTER JOIN product_search_index psi ON psi.lot_id=COALESCE(vsraf.group_cyber_id,vsraf.cyber_id_revision)
	       LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
	 WHERE psi.superseded=FALSE
	   AND ci.deleted=FALSE
	   AND vsraf.public_step>0
	 GROUP BY api, vsraf.api_version, vsraf.group_cyber_id, cyber_id_revision
	 ORDER BY api, vsraf.api_version, vsraf.group_cyber_id
)
SELECT api, stakeholders, rough_buyer, rough_supplier, count(*), string_agg(cyber_id, ', ' ORDER BY cyber_id)
  FROM tots
 GROUP BY api, stakeholders, rough_buyer, rough_supplier



-- ************************************ FIELDS ***********************************
 SELECT  timestamp, public_step, role_name, KEY, LEFT(group_cyber_id,20), value_convert_string, cyber_id
   FROM 	v_step_record_and_fields vsraf  
  WHERE cyber_id ~ ${cyber} -- replace('22-0503',', ','|')      
--    AND KEY ~'Colour'
--    AND value_convert_string ~'202'
  ORDER BY timestamp desc, public_step, KEY;

-- ////////////
-- ////////////

SELECT cyber_id, superseded, TYPE, "timestamp", is_only_one_production, * FROM product_search_index psi WHERE cyber_id~${cyber} ORDER BY "timestamp" DESC; 
--UPDATE product_search_index SET superseded=TRUE WHERE cyber_id  ~${cyber} RETURNING cyber_id;

SELECT cyber_id, deleted, cancelled, * FROM cyber_id ci WHERE cyber_id  ~${cyber} ORDER BY "timestamp" DESC;
--UPDATE cyber_id SET deleted=TRUE, cancelled=TRUE, "exception"='New revision available', cancelled_timestamp=now() WHERE cyber_id  ~${cyber}  AND id IN (1479);

-- ************************************ tmp_rankstep (max step for each cyber_id.rank) ************************************
--@set cyber_02v2  = '23-0708-293561'
--@set cyber_01v5g = '23-0511'
--@set cyber_01v5s = '23-0637-283130'
--@set cyber_20v1s = '22-0542-202516'
--@set cyber_21v1s = '22-0556-204036'
--
--@set cyber = ${cyber_02v2}
--@set cyber = ${cyber_01v5g}
--@set cyber = ${cyber_01v5s}
--@set cyber = ${cyber_20v1s}
--@set cyber = ${cyber_21v1s}
--
--SELECT * FROM cyber_id ci WHERE cyber_id~${cyber} ORDER BY id DESC;
--SELECT * FROM v_step_record_cyber_id vsrci WHERE COALESCE(group_cyber_id,cyber_id) ~${cyber} ORDER BY "timestamp" desc;
--SELECT * FROM register_log WHERE lot_id_out  ~${cyber} AND success= TRUE ORDER BY id DESC;
--
--SELECT COALESCE(group_cyber_id,cyber_id_revision), count(*) 
--  FROM v_step_record_cyber_id vsrci 
-- WHERE COALESCE(group_cyber_id,cyber_id_revision) ~${cyber} 
-- GROUP BY COALESCE(group_cyber_id,cyber_id_revision) 
-- ORDER BY COALESCE(group_cyber_id,cyber_id_revision) DESC NULLS LAST;

DROP TABLE tmp_rankstep;

-- 1. Creació taula de, per cada Cyber_ID: ranking versió + suma passes registrades a v_step_record
SELECT ci.id, deleted AS del, cancelled AS canc, ci.cyber_id, cyber_id_group_id, ci."timestamp", api_name, ci.api_version AS v, revision AS rev, ci.cyber_id_type,
      rank() OVER (PARTITION BY ci.lot_id ORDER BY revision DESC) AS rrank,  count(vsrci.*) AS steps
 INTO tmp_rankstep
 FROM cyber_id ci   
      LEFT OUTER JOIN v_step_record_cyber_id vsrci ON COALESCE(group_cyber_id,cyber_id_revision)=ci.cyber_id 
GROUP BY ci.id, deleted, cancelled, ci.cyber_id, cyber_id_group_id, ci."timestamp", api_name, ci.api_version, revision, ci.cyber_id_type;

-- 2A. Llistat amb segon flux proper
SELECT SUBSTRING(tr1.cyber_id FROM 7 FOR 14) AS lot, tr1.cyber_id, tr2.cyber_id, tr1.del AS del1, tr2.del AS del2, 
		tr1.api_name || ' ' || tr1.v AS api1, tr2.api_name || ' ' || tr2.v AS api2,
		tr1.rrank AS rk1, tr2.rrank AS rk2, tr1.steps AS s1a, tr2.steps AS s2
  FROM tmp_rankstep tr1
       LEFT OUTER JOIN tmp_rankstep tr2 ON left(tr1.cyber_id,20)=left(tr2.cyber_id,20) AND tr1.rrank=1 AND tr2.rrank>1
 WHERE tr1.steps<3 -- tr2.steps>=tr1.steps
   AND tr1.rrank=1
   AND tr1.del = FALSE 
   AND SUBSTRING(tr1.cyber_id FROM 22 FOR 1)='R'
 ORDER BY tr1.cyber_id DESC 
 
-- 2B. Llistat simple (millor!)
SELECT SUBSTRING(tr1.cyber_id FROM 7 FOR 14) AS lot, tr1.cyber_id, tr1.del AS del1, 
		w.blockchain_name, tr1.api_name || ' ' || tr1.v AS api1, tr1.rrank AS rk1, tr1.steps AS s1a
  FROM tmp_rankstep tr1
       LEFT OUTER JOIN workflows w ON w.api=tr1.api_name
 WHERE tr1.steps<3 -- tr2.steps>=tr1.steps
   AND tr1.rrank=1
   AND tr1.del = FALSE 
   AND SUBSTRING(tr1.cyber_id FROM 22 FOR 1)='R'
 ORDER BY blockchain_name, tr1.cyber_id DESC 
