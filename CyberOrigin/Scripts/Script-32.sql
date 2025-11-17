-- register_log: Últims STEPS. Principalment per veure darrers ERRORS de pas.
	SELECT rl.id, blockchain, rl.timestamp, rl.step, rl.activity_name, -- api || ' v' || api_version AS api, blockchain,
		rl.cyber_id , /*lot_id_out,*/ rl.success AS "ok?", 
--	    NOT((xpath('//amendment/text()'::text, xml_request::xml))[1]::TEXT='false') AS amendment,
--	 	timestamp_request, timestamp_response, 
		CASE WHEN ci.cancelled THEN '*** CANCELLED ***   ' ELSE '' END ||
	    COALESCE(LEFT((xpath('//faultstring/text()'::text, rl.xml_response::xml))[1]::TEXT,200),'') AS message,
	    LEFT((xpath('//errorCode/text()'::text, rl.xml_response::xml))[1]::TEXT,40) AS errorcode,
	 	rl.timestamp_response - rl.timestamp_request AS wait_time
--	    ,xml_response, xml_requests
	 FROM register_log rl
	     LEFT OUTER JOIN cyber_id ci ON (rl.lot_id_out=ci.cyber_id)
--	WHERE blockchain IN ('Blockchain-10','Blockchain-20')
--	WHERE rl.cyber_id~${cyber}
--	WHERE rl.cyber_id ~ ('CYR01-22-0535-201476|CYR01-22-0535-201477|CYR01-23-0580-271976|CYR01-24-0020-297015|CYR01-24-0020-297016|CYR01-24-0041-305131|CYR01-24-0041-305132|CYR01-24-0061-310574|CYR01-24-0061-310580|CYR01-24-0061-310581|CYR01-24-0061-310582')
--	 AND step=1
--	 AND timestamp_response >= '2023-10-01'
--	 AND success = true
	ORDER BY rl.id DESC NULLS LAST, LEFT(rl.cyber_id,20);