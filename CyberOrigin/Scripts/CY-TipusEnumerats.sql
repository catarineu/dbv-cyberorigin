SELECT * FROM step_record WHERE cyber_id~'CYR01-22-0569-207015';


SELECT * FROM mlr_doc LIMIT 1;

SELECT api, blockchain_name, code FROM WORKFLOW_NAME WN WHERE code IN ('01', '02', '10','20') ORDER BY code

SELECT api, api_version, enum_type, cob_value, vottun_value 
  FROM dynamic_enum_value dev 
-- WHERE api='diamonds-full' AND api_version ='5'
 WHERE api = (SELECT api FROM WORKFLOW_NAME WN WHERE code = '02')
   AND obsolete IS FALSE 
   AND enum_type <> 'RsRegCountry'
 ORDER BY api_version DESC, enum_type, cob_value  
