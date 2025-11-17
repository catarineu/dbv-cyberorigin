SELECT user_external_id, lower(name), name_to_show 
  FROM cob_chain_company ccc WHERE TYPE='LEVEL_2_CLIENT_COMPANY' 
 ORDER BY name, user_external_id ;



SELECT api || ' v' || api_version AS api, enum_type, string_agg(cob_value,', ' ORDER BY cob_value) AS values
FROM dynamic_enum_value dev
WHERE 
--api = 'lab-grown-diamonds-semi-full'
--  AND 
  	obsolete=FALSE 
--  AND api_version='1'
GROUP BY api, enum_type, api_version
ORDER BY api_version DESC, enum_type;

SELECT api || ' v' || api_version AS api, enum_type, cob_value
FROM dynamic_enum_value dev
WHERE api = 'lab-grown-diamonds-semi-full'
  AND obsolete=FALSE 
  AND api_version='1'
ORDER BY api_version DESC, enum_type;

UPDATE  dynamic_enum_value
   SET obsolete=TRUE 
 WHERE api='diamonds-semi-full' 
   AND enum_type='RJCStandardID'; 

SELECT *
  FROM dynamic_enum_value dev 
 WHERE api='lab-grown-diamonds-semi-full';

d

CREATE TABLE erp_rfb_backub AS (SELECT * FROM erp_rfb); 

SELECT user_external_id AS erp_code , name_to_show, "name" FROM cob_chain_company ccc 
 WHERE TYPE='LEVEL_2_CLIENT_COMPANY'
 ORDER BY user_external_id ;
 
 
 SELECT * FROM cust