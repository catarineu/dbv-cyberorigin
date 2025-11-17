UPDATE public.dashboard_indicators
	SET nft_hcc_date='2024-09-30'
	WHERE nft_dia_quantity=496 AND nft_dia_date='2024-11-07' ;


SELECT * FROM dashboard_indicators di ;

-- public.v_register_log_with_actions source
         SELECT "left"(sr.cyber_id::text, 20) AS cyber_id
           FROM step_record sr
             LEFT JOIN cyber_id ci ON ci.cyber_id::text = "left"(sr.cyber_id::text, length(ci.cyber_id::text))
          WHERE ci.deleted = false AND (sr.id IN ( SELECT srf.step_record_id
                   FROM step_record_fields srf
                  WHERE srf.string_value = 'false'::text AND srf.key::text = 'Only_One_Producction'::text))

                  
                  
SELECT * FROM v_register_log_with_actions WHERE status='LAST_STEP_PENDING';                  

SELECT * FROM v_register_log;

DROP VIEW public.v_register_log_with_actions2;


CREATE OR REPLACE VIEW public.v_register_log_with_actions2
AS WITH cyb_groups AS (
         SELECT "left"(sr.cyber_id::text, 20) AS cyber_id
           FROM step_record sr
             LEFT JOIN cyber_id ci ON ci.cyber_id::text = "left"(sr.cyber_id::text, length(ci.cyber_id::text))
          WHERE ci.deleted = false AND (sr.id IN ( SELECT srf.step_record_id
                   FROM step_record_fields srf
                  WHERE srf.string_value = 'false'::text AND srf.key::text = 'Only_One_Producction'::text))
        ), tot AS (
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
           FROM v_register_log
        )
 SELECT tot.wtype,
    tot.wname,
    tot.cyber_id, cyber_id_v,
    tot.maxstep,
    tot.step,
    tot.rrank,
    tot.activity_name,
    tot."timestamp",
    tot.api,
    tot.api_version,
    tot.success,
    tot.errorcode,
    tot.message,
    tot.status,
    tot.idstepregister,
    tot.what_to_do,
    tot.who,
    tot.rev,
    tot.id
   FROM tot
        LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=cyber_id_v)
  WHERE ci.deleted <> TRUE
    AND tot.rrank = 1 AND NOT ("left"(tot.cyber_id::text, 20) IN ( SELECT cyb_groups.cyber_id
           FROM cyb_groups)) AND "left"(tot.cyber_id::text, 3) = 'CYR'::text;
           