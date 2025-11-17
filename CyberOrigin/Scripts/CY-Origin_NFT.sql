--
-- Per veure, STEP by STEP quins camps tenen el nft_origin=True
--
select
	ac.api, ac.api_version AS api_v, s.public_step AS ps,
	sr.cyber_id, 
	sr.role_name,
	srf."key" , wf.fkey, 
	coalesce ( srf.string_value, 
		coalesce ( cast ( srf.number_value as varchar),  
			coalesce (cast ( srf.date_value as varchar) ,
				coalesce (srf.url_value ,					cast (srf.json_value as varchar) ) 
			)
		)
	) as value,
	srf.bc_type,
	wf.nft_origin, wf.fname, wf.VERSION, wf.wf, wf.step
from
	step_record sr
	INNER JOIN step_record_fields srf on sr.id = srf.step_record_id	
	LEFT OUTER JOIN app_config ac ON sr.workflow_id = ac.workflow_id    OR sr.workflow_id = ac.continuity_workflow_id OR sr.workflow_id = ac.continuity_workflow_id_2 
							   	  OR sr.workflow_id = ac.workflow_group OR sr.workflow_id = ac.workflow_delivery
    LEFT OUTER JOIN step s ON ac.api=s.api AND ac.api_version=s.api_version AND sr.role_name=s.activity_name 
    LEFT OUTER JOIN wf_fields wf ON wf.wf='01' AND wf.step=s.public_step AND wf.fkey=srf.KEY AND wf.version=4
WHERE  substring(sr.cyber_id,1,20) IN (
'CYR01-23-0500-243412'--,'CYR01-23-0587-272734','CYR01-23-0588-272748','CYR01-23-0581-271981','CYR01-23-0591-272808','CYR01-23-0573-267144','CYR01-23-0582-271985','CYR01-23-0547-258362','CYR01-23-0523-247312','CYR01-22-0720-236834','CYR01-22-0720-236828'
)
-- AND sr.role_name ='Naturalness Control (M-Screen)'
--AND KEY~'RJC'
/*AND coalesce ( srf.string_value, 
		coalesce ( cast ( srf.number_value as varchar),  
			coalesce (cast ( srf.date_value as varchar) ,
				coalesce (srf.url_value ,					cast (srf.json_value as varchar) ) 
			)
		)
	) ~'s3.'*/
AND public_step=10
order by substring(cyber_id,1,20), public_step, nft_origin, cyber_id, key; 


--
-- Per veure si fkey està ben definida per encaixat amb srf.key
--
SELECT * 
  FROM wf_fields wf 
 WHERE wf='01' AND step=10
 ORDER BY step, pos;

INSERT INTO wf_fields (wf, step, pos, fname, ftype, format, controls, VERSION, s_actor, nft_origin, fkey) VALUES ('01', 9, 15, 'NC_Certificate',    'Text', '', '', 4, 'Universal', TRUE, 'NC_Certificate');

--
-- Per extreure, STEP by STEP els camps em JSON
--
select
	ac.api, substring(sr.cyber_id,1,20) AS cyber_id,
	public_step,
	sr.role_name AS step_name,
	wf.fkey, 
	coalesce ( srf.string_value, 
		coalesce ( cast ( srf.number_value as varchar),  
			coalesce (cast ( srf.date_value::date as varchar) ,
				coalesce (srf.url_value ,					cast (srf.json_value as varchar) ) 
			)
		)
	) as value,
	substring(sr.cyber_id,22) AS cyber_id_sufix
from
	step_record sr
	INNER JOIN step_record_fields srf on sr.id = srf.step_record_id	
	LEFT OUTER JOIN app_config ac ON sr.workflow_id = ac.workflow_id    OR sr.workflow_id = ac.continuity_workflow_id OR sr.workflow_id = ac.continuity_workflow_id_2 
							   	  OR sr.workflow_id = ac.workflow_group OR sr.workflow_id = ac.workflow_delivery
    LEFT OUTER JOIN step s ON ac.api=s.api AND ac.api_version=s.api_version AND sr.role_name=s.activity_name 
    LEFT OUTER JOIN wf_fields wf ON wf.wf='01' AND wf.step=s.public_step AND wf.fkey=srf.KEY AND wf.version=4
WHERE  substring(sr.cyber_id,1,20) IN (
'CYR01-23-0500-243412','CYR01-23-0587-272734','CYR01-23-0588-272748','CYR01-23-0581-271981','CYR01-23-0591-272808','CYR01-23-0573-267144','CYR01-23-0582-271985','CYR01-23-0547-258362','CYR01-23-0523-247312','CYR01-22-0720-236834','CYR01-22-0720-236828')
AND nft_origin =TRUE 
order by substring(cyber_id,1,20), public_step, nft_origin, sr.cyber_id, key; 


--- ================================================================
--- ================================================================
SELECT id, cyber_id, lot_id, has_nft, nft_url, superseded, is_only_one_production 
  FROM product_search_index psi 
 WHERE cyber_id ~'CYR01-23-0582-271985'
 ORDER BY cyber_id ;

SELECT id, cyber_id, lot_id, has_nft, nft_url, superseded, is_only_one_production 
  FROM product_search_index psi 
 WHERE has_nft IS TRUE 
 ORDER BY cyber_id ;

SELECT * 
  FROM cyber_id ci WHERE  cyber_id ~'CYR01-23-0582-271985'

SELECT id, cyber_id, has_nft, nft_url, *  FROM product_search_index psi WHERE cyber_id ~ '23-0582-271985';

-- https://minting.origyn.ch/user-view.html#/64b5304176bd639aa64845bd?preview=true&tokenId=64b5304176bd639aa64845bd&canisterId=l2ho7-5aaaa-aaaap-abftq-cai

