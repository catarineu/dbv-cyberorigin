WITH steps AS (
	SELECT DISTINCT api, api_version, step_name, hidden 
	  FROM field_mapping_value fmv
	 WHERE lower(field)='stakeholder'
	 ORDER BY api, api_version, step_name
)  
SELECT DISTINCT api, api_version, step_name, hidden 
  FROM field_mapping_value fmv
 WHERE api||api_version||step_name NOT IN (SELECT api||api_version||step_name FROM steps)
 ORDER BY api, api_version, step_name 
 
 
 SELECT * 
	  FROM field_mapping_value fmv
	 WHERE lower(field)='stakeholder' AND api='*'
	 ORDER BY api, api_version, step_name