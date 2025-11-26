-- ****** WHITELIST ******
--INSERT INTO cyber_id_white_list (cyber_id) VALUES ('CYR01-24-0072-316375');

SELECT * FROM product_search_index psi WHERE cyber_id ~ 'CYR01-22-0556-204036';


-- *******************************************************************************
-- ************************************ STEPS ************************************
-- *******************************************************************************
SELECT api_name, deleted, cancelled, cyber_id, cyber_id_group_id FROM cyber_id     WHERE cyber_id ~${cyber} ORDER BY id desc;
SELECT superseded, cyber_id, cyber_id_group  FROM product_search_index psi WHERE cyber_id ~${cyber} ORDER BY id desc;

-- CYR01-23-0661-289946
@set cyber = '25-0122-366280'

-- register_log: Últims STEPS. Principalment per veure darrers ERRORS de pas.
	SELECT rl.id, blockchain, rl.timestamp, rl.step, rl.activity_name, -- api || ' v' || api_version AS api, blockchain,
		rl.cyber_id , /*lot_id_out,*/ rl.success AS "ok?", 
--	    NOT((xpath('//amendment/text()'::text, xml_request::xml))[1]::TEXT='false') AS amendment,
--	 	timestamp_request, timestamp_response, 
		CASE WHEN ci.cancelled THEN '*** CANCELLED ***   ' ELSE '' END ||
	    COALESCE(LEFT((xpath('//faultstring/text()'::text, rl.xml_response::xml))[1]::TEXT,200),'') AS message,
	    LEFT((xpath('//errorCode/text()'::text, rl.xml_response::xml))[1]::TEXT,40) AS errorcode,
	 	rl.timestamp_response - rl.timestamp_request AS wait_time
	    ,xml_response, xml_request
	 FROM register_log rl
	     LEFT OUTER JOIN cyber_id ci ON (rl.lot_id_out=ci.cyber_id)
--	WHERE blockchain IN ('Blockchain-10','Blockchain-20')
	WHERE rl.cyber_id~${cyber}
--	WHERE rl.cyber_id ~ ('CYR01-22-0535-201476|CYR01-22-0535-201477|CYR01-23-0580-271976|CYR01-24-0020-297015|CYR01-24-0020-297016|CYR01-24-0041-305131|CYR01-24-0041-305132|CYR01-24-0061-310574|CYR01-24-0061-310580|CYR01-24-0061-310581|CYR01-24-0061-310582')
--	 AND step=1
--	 AND timestamp_response >= '2023-10-01'
--	 AND success = true
	ORDER BY rl.id DESC NULLS LAST, LEFT(rl.cyber_id,20);

SELECT cyber_id, * FROM product_search_index WHERE TYPE='ROUND_COLOURED_STONES';
SELECT * FROM workflows w ;

-- *******************************************************************************
-- ************************************ FIELDS ***********************************
-- *******************************************************************************
@set cyber = '24-0104'

-- DETALL de dades enviades en passos
 SELECT  timestamp, cyber_id, public_step, REPLACE(role_name,'Group','Start') AS role, KEY, value_convert_string AS value, LEFT(group_cyber_id,20) AS cyber_id, stakeholder_name_to_show,
         step_record_id,  cyber_id
   FROM 	v_step_record_and_fields vsraf  
  WHERE 1=1
    AND cyber_id ~ ${cyber}      
--    AND key ~*'NC_ID'
--    AND public_step IS NOT NULL 
--      AND role_name IN ('Naturalness Control (M-Screen)')
--    AND cyber_id IN (SELECT DISTINCT LEFT(cyber_id,20) FROM v_step_record_and_fields WHERE stakeholder_name_to_show='Maa Diamonds')      
--    AND value_convert_string ~'http'
--    AND value_convert_string ~'8A'
--    AND timestamp >'2023-12-15' 
  ORDER BY timestamp desc, public_step, KEY;



 SELECT  public_step, REPLACE(role_name,'Group','Start') AS role, KEY, value_convert_string AS value
   FROM 	v_step_record_and_fields vsraf  
  WHERE 1=1
    AND cyber_id ~ ${cyber}      
--    AND key ~*'NC_ID'
--    AND public_step IS NOT NULL 
--      AND role_name IN ('Naturalness Control (M-Screen)')
--    AND cyber_id IN (SELECT DISTINCT LEFT(cyber_id,20) FROM v_step_record_and_fields WHERE stakeholder_name_to_show='Maa Diamonds')      
--    AND value_convert_string ~'http'
--    AND value_convert_string ~'8A'
--    AND timestamp >'2023-12-15' 
  ORDER BY timestamp desc, public_step, KEY;



SELECT * FROM register_log rl WHERE timestamp BETWEEN '2025-10-21 10:17:50' AND '2025-10-21 10:18:00';

SELECT step_record_id, KEY, url_value FROM step_record_fields srf WHERE step_record_id =66039;
SELECT id, cyber_id, final_certificate_url FROM product_search_index psi WHERE cyber_id ~ ${cyber} AND superseded = FALSE; 


SELECT blocktype, TYPE, customerid, brandid, psi.cyber_id, psi."date"::date, edr.date_rfb, 
	   CASE WHEN edr.date_rfb IS NULL THEN 0 WHEN psi."date"::date <> edr.date_rfb THEN 1 ELSE 2 END AS comp
  FROM product_search_index psi 
       LEFT OUTER JOIN erp_rfb edr ON LEFT(psi.cyber_id,20)=edr.cyber_id
 WHERE superseded=FALSE
ORDER BY CASE WHEN edr.date_rfb IS NULL THEN 0 WHEN psi."date"::date = edr.date_rfb THEN 1 ELSE 2 END, psi.date DESC, psi.cyber_id ;


SELECT * FROM chain_member_vottun_id cmvi 

SELECT * FROM product_search_index psi WHERE cyber_id ~'24-0132'

SELECT * FROM dynamic_enum_value dev ;

SELECT * FROM workflow_name ORDER BY code;
SELECT id, api, api_version, is_group, steps, workflow_name_id FROM workflow_version wv ;
SELECT * FROM workflows w ORDER BY id;


SELECT * FROM wf_steps ws;


INSERT INTO public.workflows (id,"name",steps,api,blockchain_name,name_fr,psi_type)
	VALUES ('03','Lab Grown Diamonds Semi-full',5,'lab-grown-diamonds-semi-full','Blockchain-03','Lab Grown Semi-full','LABG_DIAMONDS_SEMI_FULL');
UPDATE public.workflows
	SET id='99'
	WHERE id='03';


SELECT * FROM field_mapping_value fmv WHERE api='diamonds-full' AND api_version ='5' ORDER BY step_name, field;



SELECT * FROM v_register_log_with_actions vrlwa WHERE cyber_id ~'24-0160';

WITH tot AS (
     SELECT v_register_log.wtype,
        v_register_log.wname,
        "left"(v_register_log.cyber_id::text, 20)::character varying(255) AS cyber_id,
        v_register_log.cyber_id_revision AS cyber_id_v,
        v_register_log.maxstep,
        v_register_log.step,
        rank() OVER (PARTITION BY ("left"(v_register_log.cyber_id::text, 20)) ORDER BY v_register_log.rev DESC NULLS LAST, v_register_log.step DESC NULLS LAST, v_register_log.success DESC NULLS LAST) AS rrank,
        v_register_log.activity_name,
        v_register_log."timestamp",
        v_register_log.api,
        v_register_log.api_version,
        v_register_log.success,
        v_register_log.errorcode,
        v_register_log.message,
        v_register_log.status,
        v_register_log.idstepregister,
            CASE
                WHEN v_register_log.status = 'FIRST_STEP_DONE'::text THEN 'Continue with step 2'::text
                WHEN v_register_log.status = 'FIRST_STEP_ERROR'::text THEN 'Correct the error and retry'::text
                WHEN v_register_log.status = 'MID_STEP_DONE'::text THEN 'Continue with step '::text || (v_register_log.step + 1)
                WHEN v_register_log.status = 'MID_STEP_ERROR'::text THEN 'Correct the error and retry'::text
                WHEN v_register_log.status = 'LAST_STEP_DONE'::text THEN 'Job done!'::text
                WHEN v_register_log.status = 'LAST_STEP_PENDING'::text THEN ('Continue with step '::text || v_register_log.maxstep) || ' (last one)'::text
                WHEN v_register_log.status = 'LAST_STEP_ERROR'::text THEN 'Talk with stakeholders'::text
                ELSE '(n.a.)'::text
            END AS what_to_do,
            CASE
                WHEN v_register_log.status = 'FIRST_STEP_DONE'::text THEN 'Stakeholder #2'::text
                WHEN v_register_log.status = 'FIRST_STEP_ERROR'::text THEN 'Gil Sertissage'::text
                WHEN v_register_log.status = 'MID_STEP_DONE'::text THEN ('Stakeholder #'::text || (v_register_log.step + 1)) || ' '::text
                WHEN v_register_log.status = 'MID_STEP_ERROR'::text THEN ('Stakeholder #'::text || v_register_log.step) || ' '::text
                WHEN v_register_log.status = 'LAST_STEP_DONE'::text THEN '-'::text
                WHEN v_register_log.status = 'LAST_STEP_ERROR'::text THEN 'Gil Sertissage'::text
                WHEN v_register_log.status = 'LAST_STEP_PENDING'::text THEN 'Gil Sertissage'::text
                ELSE '(n.a.)'::text
            END AS who,
        v_register_log.rev,
        v_register_log.id
       FROM v_register_log)
 SELECT ci.deleted, tot.wtype,    tot.wname,    tot.cyber_id,    tot.maxstep,    tot.step,    tot.rrank,    tot.activity_name,    tot."timestamp",
    tot.api,    tot.api_version,    tot.success,    tot.errorcode,    tot.message,    tot.status,    tot.idstepregister,    tot.what_to_do,
    tot.who,    tot.rev,    tot.id
    FROM tot     LEFT JOIN cyber_id ci ON ci.cyber_id::text = tot.cyber_id_v
  WHERE -- ci.deleted <> true AND 
        -- tot.rrank = 1 AND
        tot.cyber_id ~'CYR01-24-0160-341941';


SELECT blockchain_name, name_fr FROM workflow_name wn ORDER BY code;
