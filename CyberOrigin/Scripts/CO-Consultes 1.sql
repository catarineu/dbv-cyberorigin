SELECT CASE WHEN substring(cyber_id,1,1)='C' THEN cyber_id ELSE  'CYR01-' || cyber_id END AS c2, *
  FROM v_register_log vrl
 WHERE success IS FALSE 
UNION
SELECT CASE WHEN substring(cyber_id,1,1)='C' THEN cyber_id ELSE  'CYR01-' || cyber_id END AS c2, *
  FROM v_register_log vrl
 WHERE substring(cyber_id,7) IN (SELECT cyber_id  FROM v_register_log vrl WHERE success IS FALSE AND substring(cyber_id,1,1)<>'C')  
 ORDER BY c2, "timestamp" DESC 

 
 
 SELECT cyber_id, wtype, wname, maxstep, step, activity_name, "timestamp", success, errorcode, message, status
  FROM v_register_log vrl
 WHERE success IS TRUE
   AND step < maxstep;


SELECT in_batch_id, substring(in_batch_id,1,24) FROM step_record sr WHERE in_batch_id ~ '0104-197421' 
SELECT DISTINCT type FROM product_search_index psi 
SELECT * FROM workflows w ORDER BY id

SELECT ac.api, sr.role_name, sr.cyber_id, srf.*
  FROM step_record sr 
       LEFT OUTER JOIN step_record_fields srf ON (srf.step_record_id=sr.id)
       LEFT OUTER JOIN app_config ac ON (ac.workflow_id=sr.workflow_id)
  WHERE cyber_id  ~ '0114-198125'
  ORDER BY sr.role_name, srf."key"  

 SELECT * FROM app_config ac
  
