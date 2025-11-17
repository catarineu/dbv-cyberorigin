DROP VIEW v_step_record_fields;

CREATE OR REPLACE VIEW public.v_step_record_fields
AS SELECT srf.step_record_id,
    srf.key,
    COALESCE(srf.string_value, COALESCE(srf.number_value::character varying, COALESCE(srf.url_value::character varying, COALESCE(srf.date_value::character varying, srf.json_value::character varying)))) AS value_convert_string,
    srf.type,
    srf.string_value,
    srf.number_value,
    srf.date_value,
    srf.url_value,
    srf.json_value
   FROM step_record_fields srf;
   

CREATE OR REPLACE VIEW public.v_step_record_and_fields
AS SELECT ac.api,
    ac.api_version,
    regexp_replace(sr.out_batch_id::text, '-R.*'::text, ''::text) AS cyber_id,
    sr.id AS step_record_id,
    sr.in_batch_id,
    sr.out_batch_id,
    sr.bc_id,
    sr.bc_creation_date,
    s.public_step,
    sr.role_name,
    sr."timestamp",
    sr.stakeholder AS chain_member_id,
    cm.company_name AS chain_member_company_name,
    ccc.id AS stakeholder_id,
    ccc.user_external_id AS stakeholder_user_external_id,
    ccc.name AS stakeholder_name,
    ccc.name_to_show AS stakeholder_name_to_show,
    srf.key,
    srf.bc_type,
    srf.type,
    COALESCE(srf.string_value, COALESCE(srf.number_value::character varying, COALESCE(srf.url_value::character varying, COALESCE(srf.date_value::character varying, srf.json_value::character varying)))) AS value_convert_string,
    srf.string_value,
    srf.number_value,
    srf.date_value,
    srf.url_value,
    srf.json_value
   FROM step_record sr
     LEFT JOIN app_config ac ON sr.workflow_id::text = ac.workflow_group::text OR sr.workflow_id::text = ac.workflow_id::text OR sr.workflow_id::text = ac.continuity_workflow_id::text OR sr.workflow_id::text = ac.continuity_workflow_id_2::text OR sr.workflow_id::text = ac.workflow_delivery::text OR sr.workflow_id::text = ac.workflow_validation_prod_id::text
     LEFT JOIN step s ON s.api::text = ac.api::text AND s.api_version::text = ac.api_version::text AND s.activity_name::text = sr.role_name::text
     LEFT JOIN chain_member cm ON cm.id = sr.stakeholder
     LEFT JOIN cob_chain_company ccc ON ccc.chain_member_id = cm.id AND ccc.type::text = 'STAKEHOLDER_COMPANY'::text
     LEFT JOIN step_record_fields srf ON srf.step_record_id = sr.id;
     