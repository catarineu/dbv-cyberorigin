SELECT * FROM cyber_id_white_list ciwl ;

SELECT * FROM cyber_id ci 
WHERE cyber_id  ~ 'CYR';

DELETE FROM public.register_log;
	
-- Funció de consulta 
DROP FUNCTION public.cy_workflows(wf TEXT, cyid text, finish boolean, inici date);

SELECT * FROM v_register_log 
 WHERE cyber_id ~ '23-0584'  ;

-- Creació VISTA CONTROL DE WORKFLOWS
DROP VIEW v_register_log;
CREATE VIEW v_register_log AS
 WITH max1 AS 
 (-- Dona'm l'últim registre per cada CyberID...
  SELECT cyber_id, max(id) AS id
    FROM register_log rl 
   WHERE (NOT (xpath_exists('//errorCode/text()'::text, xml_response::xml))  OR                     -- Ha anat bé
		 (xpath('//errorCode/text()'::text, xml_response::xml))[1]::text <> 'RECORD_NOT_FOUND')     -- Error diferent a NO_TROBAT
  GROUP BY blockchain, cyber_id)
 SELECT blockchain_id AS wtype, w."name" AS wname, cyber_id, 
		w.steps AS maxstep, step, activity_name, 
        timestamp, api, api_version, success, 
	 	(xpath('//errorCode/text()'::text, xml_response::xml))[1]::TEXT   AS errorcode,
	 	(xpath('//faultstring/text()'::text, xml_response::xml))[1]::text AS message
   FROM register_log rl
		LEFT OUTER JOIN workflows w ON (blockchain_id=w.id)
  WHERE rl.id in (SELECT id FROM max1); 
 
/*                               ultim
 *   5 ok  -- 6 ok   → 6 ok        6+
 *   5 ok  -- 6 err  → 6 err       6+
 *   5 ok' -- 6 err  → 5 ok'       5+
 *   5 ok' -- 6 ok'  → 6 ok'       5+
 *   3 ok  -- 6 err  → 3 ok        6*
 *         -- 6 err  → 6 err       6+
 */
 
-- Per la generació de l'Excel de "que fer ara?"
SELECT wtype, wname, cyber_id, maxstep, step, activity_name, success,  
       message, status, what_to_do, who
 FROM v_register_log_with_actions
WHERE cyber_id  ~ '^CYR\d{2}-\d{2}'
  AND NOT (status='LAST_STEP_DONE' AND success=True)
ORDER BY wtype, cyber_id, status, success, api; 


-- Per la generació de l'Excel de "TOT EL QUE ESTÀ INSERIT"
SELECT wtype, wname, cyber_id, maxstep, step, activity_name, success,  
       message, status, what_to_do, who
 FROM v_register_log_with_actions
WHERE cyber_id  ~ '^CYR\d{2}-\d{2}'
ORDER BY wtype, cyber_id, status, success, api; 

SELECT TYPE, cyber_id, final_certificate_id, data_field_carats, data_field_colour
  FROM product_search_index psi ;


-- What
CASE WHEN status='FIRST_STEP_DONE'   THEN 'Continue with step 2' 
	 WHEN status='FIRST_STEP_ERROR'  THEN 'Correct the error and retry'  
	 WHEN status='MID_STEP_DONE'     THEN 'Continue with step '||(step+1)  
	 WHEN status='MID_STEP_ERROR'    THEN 'Correct the error and retry'  
	 WHEN status='LAST_STEP_DONE'    THEN 'Job done!'  
	 WHEN status='LAST_STEP_PENDING' THEN 'Continue with step '||maxstep 
END 

-- Who
CASE WHEN status='FIRST_STEP_DONE'   THEN 'Stakeholder #2 (Marc)'  
	 WHEN status='FIRST_STEP_ERROR'  THEN 'Gil (Yoan)' 
	 WHEN status='MID_STEP_DONE'     THEN 'Stakeholder #'||(step+1)||' (Marc)'  
	 WHEN status='MID_STEP_ERROR'    THEN 'Stakeholder #'|| step   ||' (Marc)'  
	 WHEN status='LAST_STEP_DONE'    THEN '-' 
	 WHEN status='LAST_STEP_ERROR'   THEN 'QualityControlAndOrderControl and OrderApproval'  
	 WHEN status='LAST_STEP_PENDING' THEN 'Gil (Yoan)' 
END 

SELECT * FROM v_register_log_with_actions vrlwa 
WHERE status='LAST_STEP_ERROR'
;


SELECT * FROM product_search_index psi 
 WHERE cyber_id ='CYR01-22-0543-202502'
;


SELECT * FROM step_record;
SELECT * FROM product_search_index psi ;
 
SELECT psi.cyber_id, role_name, count(*), psi.type
  FROM step_record sr
       INNER JOIN product_search_index psi ON (psi.id=sr.product_search_index_id)
 GROUP BY psi.cyber_id, role_name, psi.type
HAVING count(*)>1
 ORDER BY TYPE, role_name, count(*) DESC, psi.cyber_id;


select timestamp, cyber_id , customer_id , brand_id , customer_id2, brand_id2
from product_search_index psi order by "timestamp" desc;



