-- public.v_register_log_with_actions source

SELECT status, step, * FROM v_register_log
WHERE cyber_id~'25-0065-351872'
ORDER BY "timestamp" DESC;

SELECT cyber_id, wtype, wname, maxstep AS mstep, step, success, activity_name, api, api_version AS apiv, rev, status, errorcode 
  FROM v_register_log2 
 WHERE cyber_id~'25-0065-351872'
 ORDER BY "timestamp" DESC;

DROP VIEW public.v_register_log2;
CREATE VIEW public.v_register_log2
AS SELECT rl.blockchain_id AS wtype,
    w.name::character varying AS wname,
    rl.cyber_id,
    regexp_replace(rl.lot_id_out::text, '(-R[0-9]{2}).*$'::text, '\1'::text) AS cyber_id_revision,
    ci.cyber_id_type,
        CASE
            WHEN ci.cancelled OR ci.deleted THEN true
            ELSE false
        END AS cyber_id_deleted,
    cig.cyber_id AS group_cyber_id,
        CASE
            WHEN cig.cancelled OR cig.deleted THEN true
            ELSE false
        END AS group_cyber_id_deleted,
    cig.cyber_id_type AS group_cyber_id_type,
        CASE
            WHEN wv.step_group_begin IS NOT NULL AND rl.step >= wv.step_group_begin AND rl.step <= wv.step_group_end THEN wv.step_group_end
            WHEN wv.step_group_production_end IS NOT NULL AND rl.step >= wv.step_group_production_begin AND rl.step <= wv.step_group_production_end THEN wv.step_group_production_end
            WHEN wv.step_group_verification_begin IS NOT NULL AND rl.step >= wv.step_group_verification_begin AND rl.step <= wv.step_group_verification_end THEN wv.step_group_verification_end
            WHEN wv.step_group_delivery_begin IS NOT NULL AND rl.step >= wv.step_group_delivery_begin AND rl.step <= wv.step_group_delivery_end THEN wv.step_group_delivery_end
            ELSE wv.steps
        END AS maxstepg,
    wv.steps AS maxstep,
    rl.step,
    rl.activity_name,
    rl."timestamp",
    rl.api,
    rl.api_version,
    rl.success,
    (xpath('//errorCode/text()'::text, rl.xml_response::xml))[1]::text AS errorcode,
    (xpath('//faultstring/text()'::text, rl.xml_response::xml))[1]::text AS message,
        CASE
            WHEN wv.steps <= rl.step AND rl.success = true THEN 'LAST_STEP_DONE'::text
            WHEN wv.steps <= rl.step AND rl.success = false THEN 'LAST_STEP_ERROR'::text
            WHEN (wv.steps - 1) = rl.step AND rl.success = true THEN 'LAST_STEP_PENDING'::text
            WHEN wv.steps > rl.step AND rl.step > 1 AND rl.success = false THEN 'MID_STEP_ERROR'::text
            WHEN (wv.steps - 1) > rl.step AND rl.step > 1 AND rl.success = true THEN 'MID_STEP_DONE'::text
            WHEN 1 = rl.step AND rl.success = true THEN 'FIRST_STEP_DONE'::text
            WHEN 1 = rl.step AND rl.success = false THEN 'FIRST_STEP_ERROR'::text
            ELSE 'UNKNOW_STATUS'::text
        END AS status,
    rl.lot_id_out AS idstepregister,
    COALESCE(cig.revision, ci.revision) AS rev,
    rl.id
   FROM register_log rl
     LEFT JOIN cyber_id ci ON ci.cyber_id::text = regexp_replace(rl.lot_id_out::text, '(-R[0-9]{2}).*$'::text, '\1'::text)
     LEFT JOIN cyber_id cig ON cig.id = ci.cyber_id_group_id
     LEFT JOIN workflow_name w ON rl.blockchain_id::bpchar = w.code
     LEFT JOIN workflow_version wv ON wv.workflow_name_id = w.id AND wv.api::text = rl.api::text AND wv.api_version::text = rl.api_version::text;


SELECT * FROM v_register_log
WHERE cyber_id~'25-0084-353187'
ORDER BY "timestamp" DESC;


SELECT * FROM v_register_log_with_actions
WHERE idstepregister~'24-0059-308646'
ORDER BY "timestamp" desc;

SELECT rev, step, success, * FROM v_register_log_with_actions
WHERE cyber_id~'25-0084-353187'
ORDER BY "timestamp" desc;

DROP VIEW public.v_register_log_with_actions2;
CREATE VIEW public.v_register_log_with_actions2
AS WITH cyb_groups AS (
         SELECT "left"(sr.cyber_id::text, 20) AS cyber_id
           FROM step_record sr
             LEFT JOIN cyber_id ci_1 ON ci_1.cyber_id::text = "left"(sr.cyber_id::text, length(ci_1.cyber_id::text))
          WHERE ci_1.deleted = false AND (sr.id IN ( SELECT srf.step_record_id
                   FROM step_record_fields srf
                  WHERE srf.string_value = 'false'::text AND srf.key::text = 'Only_One_Producction'::text))
        ), tot AS (
         SELECT vrl.wtype,
            vrl.wname,
            "left"(vrl.cyber_id_revision::text, 20)::character varying(255) AS cyber_id,
            vrl.cyber_id_revision AS cyber_id_v,
            vrl.maxstep,
            vrl.step,
            row_number() OVER (PARTITION BY ("left"(vrl.cyber_id_revision::text, 20)) ORDER BY vrl.rev DESC NULLS LAST, vrl.step DESC NULLS LAST, vrl.success DESC NULLS LAST) AS rrank,
            vrl.activity_name,
            vrl."timestamp",
            vrl.api,
            vrl.api_version,
            vrl.success,
            vrl.errorcode,
            vrl.message,
            vrl.status,
            vrl.idstepregister,
                CASE
                    WHEN vrl.status = 'FIRST_STEP_DONE'::text THEN 'Continue with step 2'::text
                    WHEN vrl.status = 'FIRST_STEP_ERROR'::text THEN 'Correct the error and retry'::text
                    WHEN vrl.status = 'MID_STEP_DONE'::text THEN 'Continue with step '::text || (vrl.step + 1)
                    WHEN vrl.status = 'MID_STEP_ERROR'::text THEN 'Correct the error and retry'::text
                    WHEN vrl.status = 'LAST_STEP_DONE'::text THEN 'Job done!'::text
                    WHEN vrl.status = 'LAST_STEP_PENDING'::text THEN ('Continue with step '::text || vrl.maxstep) || ' (last one)'::text
                    WHEN vrl.status = 'LAST_STEP_ERROR'::text THEN 'Talk with stakeholders'::text
                    ELSE '(n.a.)'::text
                END AS what_to_do,
                CASE
                    WHEN vrl.status = 'FIRST_STEP_DONE'::text THEN 'Stakeholder #2'::text
                    WHEN vrl.status = 'FIRST_STEP_ERROR'::text THEN 'Gil Sertissage'::text
                    WHEN vrl.status = 'MID_STEP_DONE'::text THEN ('Stakeholder #'::text || (vrl.step + 1)) || ' '::text
                    WHEN vrl.status = 'MID_STEP_ERROR'::text THEN ('Stakeholder #'::text || vrl.step) || ' '::text
                    WHEN vrl.status = 'LAST_STEP_DONE'::text THEN '-'::text
                    WHEN vrl.status = 'LAST_STEP_ERROR'::text THEN 'Gil Sertissage'::text
                    WHEN vrl.status = 'LAST_STEP_PENDING'::text THEN 'Gil Sertissage'::text
                    ELSE '(n.a.)'::text
                END AS who,
            vrl.rev,
            vrl.id
           FROM v_register_log2 vrl WHERE cyber_id~'25-0084-353187'
        )
 SELECT tot.wtype,
    tot.wname,
    tot.cyber_id,
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
     LEFT JOIN cyber_id ci ON ci.cyber_id::text = tot.cyber_id_v
  WHERE ci.deleted <> true 
    AND tot.rrank = 1 
    AND NOT ("left"(tot.cyber_id::text, 20) IN ( SELECT cyb_groups.cyber_id FROM cyb_groups)) AND "left"(tot.cyber_id::text, 3) = 'CYR'::text;



