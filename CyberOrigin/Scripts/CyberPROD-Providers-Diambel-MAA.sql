DROP TABLE tmp_rankstep;

WITH tots AS (
	SELECT ci.id, deleted AS del, cancelled AS canc, ci.cyber_id, cyber_id_group_id, ci."timestamp", api_name || ' ' || ci.api_version AS api, revision AS rev, ci.cyber_id_type,
	      rank() OVER (PARTITION BY ci.lot_id ORDER BY revision DESC) AS rrank,
	      vsraf.stakeholder_name, string_agg(DISTINCT public_step||'-'||KEY||'('||value_convert_string||')',', ' ORDER BY public_step||'-'||KEY||'('||value_convert_string||')') AS steps_data
	 FROM cyber_id ci   
	      LEFT OUTER JOIN v_step_record_and_fields vsraf ON COALESCE(vsraf.group_cyber_id,vsraf.cyber_id_revision)=ci.cyber_id 
	WHERE (value_convert_string ~* 'diambel' AND KEY <> 'out_batch_0')
	GROUP BY ci.id, deleted, cancelled, ci.cyber_id, cyber_id_group_id, ci."timestamp", api_name, ci.api_version, revision, ci.cyber_id_type, stakeholder_name
)
SELECT id, del, canc, cyber_id, cyber_id_group_id, timestamp, api, rev, stakeholder_name, steps_data
  FROM tots
 WHERE rrank=1
 ORDER BY cyber_id_group_id;


WITH tots AS (
	SELECT ci.id, deleted AS del, cancelled AS canc, ci.cyber_id, psi.date::date AS psi_date, cyber_id_group_id,  api_name || ' ' || ci.api_version AS api, revision AS rev, ci.cyber_id_type,
	      rank() OVER (PARTITION BY ci.lot_id ORDER BY revision DESC NULLS LAST) AS rrank,
	      vsraf.timestamp::date AS step_ts, vsraf.role_name, public_step AS step, vsraf.stakeholder_name,
	      string_agg(DISTINCT public_step||'-'||KEY||'('||value_convert_string||')',', ' ORDER BY public_step||'-'||KEY||'('||value_convert_string||')') AS steps_data
	 FROM cyber_id ci   
	      LEFT OUTER JOIN v_step_record_and_fields vsraf ON COALESCE(vsraf.group_cyber_id,vsraf.cyber_id_revision)=ci.cyber_id 
	      LEFT OUTER JOIN product_search_index psi ON psi.lot_id=ci.cyber_id
	WHERE ((public_step =8 AND stakeholder_name~*'maa') OR (role_name='RoughPurchasePost' AND value_convert_string~'0cbbac72-64d5-4112-bb62-87b17a0aef9e'))
	  AND deleted=false
	GROUP BY ci.id, deleted, cancelled, ci.cyber_id, psi.date, cyber_id_group_id, api_name, ci.api_version, revision, ci.cyber_id_type, 
	         role_name, stakeholder_name, public_step, vsraf.timestamp::date
)
SELECT id, del, canc, cyber_id, psi_date AS delivery_date, api, rev, step, role_name, stakeholder_name, step_ts--, steps_data
  FROM tots
 WHERE rrank=1
 ORDER BY psi_date DESC, cyber_id DESC NULLS LAST, step;


-- 7-Cyber_Id_Group(CYR01-21-0099-196271-R02), 7-Kimberley_id(SG006907), 7-LOT_ID(CYR01-21-0099-196271P00-R01), 7-next_step_users(0cbbac72-64d5-4112-bb62-87b17a0aef9e), 7-order(00), 7-out_batch_0(CYR01-21-0099-196271P00-R01-KPID.SG006907-POST), 7-roughCertificationActivityId(ea3745dc-2f9d-4525-a806-6531ef5a70df)
-- 7-Cyber_Id_Group(CYR01-24-0025-297405-R01), 7-Kimberley_id(AE156558), 7-LOT_ID(CYR01-24-0025-297405P1-R01), 7-next_step_users(96f43122-e889-46e9-9aea-2a1750144dff), 7-order(1), 7-out_batch_0(CYR01-24-0025-297405P1-R01-KPID.AE156558-POST), 7-roughCertificationActivityId(12afabe2-8dae-4a30-93b4-5de9e05aeacc)

SELECT date, lot_id, * FROM product_search_index psi WHERE cyber_id ~'23-0542-258243';
SELECT date, lot_id, * FROM product_search_index psi WHERE lot_id='CYR01-23-0542-258243-R02';



