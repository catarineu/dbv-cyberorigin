-- ==============================
--   GRAN RESUM DE STAKEHOLDERS
-- ==============================
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
SELECT psi.id, psi.cyber_id, psi.cyber_id_group, psi.lot_id, psi.ci_id, psi.ci_cyber_id, nsr.id AS sr_id
  FROM psi_sub psi
       LEFT OUTER JOIN nice_sr nsr ON nsr.nice_cyber_id=psi.ci_cyber_id
), psi_detail AS (
SELECT DISTINCT id, lot_id, pas.sr_id, vsraf.api || ' ' || vsraf.api_version AS api,
       CASE WHEN KEY = 'Rough_Buyer'    THEN COALESCE(to_char(public_step,'FM00'),'99')||'-'||LEFT(initcap(value_convert_string),8) ELSE '' END rough_buyer,
       CASE WHEN KEY = 'Rough_Supplier' THEN COALESCE(to_char(public_step,'FM00'),'99')||'-'||LEFT(initcap(value_convert_string),8) ELSE '' END rough_supplier,
	   to_char(public_step,'FM00')||'-'||COALESCE(LEFT(chain_member_company_name,6),'') AS stakeholders
  FROM psi_all_sr pas
   	   LEFT OUTER JOIN v_step_record_and_fields vsraf ON vsraf.step_record_id=pas.sr_id
 WHERE api IS NOT NULL 
), psi_stake AS (
SELECT api, id, LEFT(lot_id,20) AS lot_id,
--		string_agg(''||sr_id, ', ' ORDER BY sr_id) AS srecords, 
		string_agg(DISTINCT rough_buyer,    ', ' ORDER BY rough_buyer    NULLS LAST) AS rough_buyer,
		string_agg(DISTINCT rough_supplier, ', ' ORDER BY rough_supplier NULLS LAST) AS rough_supplier,
		string_agg(DISTINCT stakeholders,   ', ' ORDER BY stakeholders   NULLS LAST) AS stakeholders
  FROM psi_detail
 GROUP BY api, id, lot_id
 ORDER BY api, id, lot_id, stakeholders
)
--SELECT * FROM psi_stake WHERE lot_id='CYR01-23-0510-245730';
SELECT api, rough_buyer, rough_supplier,  stakeholders, count(DISTINCT lot_id), string_agg(DISTINCT lot_id, ', ' ORDER BY lot_id) AS cyber_ids
  FROM psi_stake
 GROUP BY api, stakeholders, rough_buyer, rough_supplier
 ORDER BY api, stakeholders, rough_buyer, rough_supplier

SELECT * FROM step ORDER BY api, api_version, public_step;
   	      
   	   

-- ********************************************************
-- DETECCIÓ DE SI ES GRUP (=no surt a monitoring encara)
 SELECT sr.cyber_id, srf.step_record_id, KEY, string_value
   FROM step_record sr
        LEFT OUTER JOIN step_record_fields srf ON srf.step_record_id=sr.id 
  WHERE cyber_id ~ '23-0674'
    AND srf.KEY ~ 'Only'
