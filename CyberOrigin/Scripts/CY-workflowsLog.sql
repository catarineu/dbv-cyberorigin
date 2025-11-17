SELECT
	blockchain, cyber_id, step, activity_name , "timestamp", success , api, api_version , timestamp_response - timestamp_request 
FROM
	register_log rl 
WHERE cyber_id ~ '';

test_gilchain


DROP FUNCTION public.cy_workflows(cyid text, inici date);

SELECT * FROM cy_workflows('23'::Text,'2021-01-01'::date);
CREATE OR REPLACE FUNCTION public.cy_workflows(cyid text, inici date)
 RETURNS TABLE(block_id varchar, cybid varchar, stepid text, moment timestamp, RESULT boolean,  
 			   apiname varchar, ipvers varchar, delay INTERVAL)
 LANGUAGE plpgsql
AS $function$
BEGIN
	RETURN QUERY
		SELECT
			blockchain, cyber_id, max(step || ' - ' || activity_name)::text, max(timestamp), success , api, api_version, NULL::interval --, timestamp_response - timestamp_request 
		FROM
			register_log rl 
		WHERE 
		 	 cyber_id ~ cyid
		 AND success = TRUE 
		GROUP BY blockchain, cyber_id, success, api, api_version
		HAVING max("timestamp") >= inici
		ORDER BY cyber_id, max("timestamp") DESC
		LIMIT 50;
END;
$function$
;

