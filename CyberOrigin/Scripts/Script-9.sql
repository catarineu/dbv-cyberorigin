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
SELECT pas.sr_id, pas.psi_id, LEFT(pas.lot_id,20), 
		vsraf.role_name, vsraf.key, vsraf.value_convert_string
-- INTO tmp_ocr
  FROM psi_all_sr pas
   	   LEFT OUTER JOIN v_step_record_and_fields vsraf ON vsraf.step_record_id=pas.sr_id
 WHERE api IS NOT NULL 
  AND lot_id ~'CYR01-23-0560-265556'
   AND value_convert_string~'^http'
   AND KEY NOT IN ('Final_certificate','RJC_Member_Certificate');
  
SELECT * FROM tmp_ocr  WHERE lot_id ~'CYR01-23-0560-265556';
  