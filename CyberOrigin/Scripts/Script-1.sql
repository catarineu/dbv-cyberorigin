CREATE OR REPLACE FUNCTION get_monitoring_data() -- Choose a descriptive name
  RETURNS TABLE ( -- Specify the columns the function will return
    api text,
    api_version text,
    cyber_id text,
    group_cyber_id text,
    ts timestamp,
    last_step_done text,
    max_st int,
    actor text,
    action text,
    key text,
    pieces int
--    key2 text,
--    carats int 
  )
AS $$ -- Start of the function body
BEGIN
	WITH lastreset AS (
	    SELECT vsrci.cyber_id, max(timestamp) AS maxtime
	    FROM v_step_record_cyber_id vsrci
	    WHERE LEFT(vsrci.cyber_id,7) = 'CYR01-2'
	      AND public_step = 1
	    GROUP BY vsrci.cyber_id
	), registers AS (
	    SELECT 
		    vsrci.api, 
		    vsrci.api_version,
	        LEFT(vsrci.cyber_id, 23) AS cyber_id, 
	        coalesce (LEFT(vsrci.group_cyber_id, 20), LEFT(vsrci.cyber_id, 20)) AS group_cyber_id,
	        vsrci.timestamp,
	        vsrci.public_step ,
	        vsrci.public_step || ' ' ||vsrci.role_name as public_step_and_name, 
	        CASE WHEN vsrci.cyber_id ~ 'P[1-9][0-9]?$' THEN max(vsrci.public_step) OVER (PARTITION BY LEFT(vsrci.cyber_id, 23)) -- Si es P de grup, mirem els seus passos
	        ELSE max(vsrci.public_step) OVER (PARTITION BY LEFT(vsrci.cyber_id, 20)) END as max_st,                             -- Si NO          , mirem els passos totals
	        ROW_NUMBER() OVER (PARTITION BY LEFT(vsrci.cyber_id, 23) ORDER BY vsrci.public_step DESC, vsrci.timestamp DESC) as rn,
	        srf.KEY, srf.number_value AS pieces
	--        srf2.KEY AS key2, srf2.number_value AS carats
	    FROM v_step_record_cyber_id vsrci
	    	 LEFT OUTER JOIN lastreset ON LEFT(lastreset.cyber_id,20) = LEFT(vsrci.cyber_id,20) 
	    	 LEFT OUTER JOIN step_record_fields srf ON (srf.step_record_id=vsrci.step_record_id AND srf.KEY IN ('Pieces_final', 'Max_Pieces'))
	--    	 LEFT OUTER JOIN step_record_fields srf2 ON (srf2.step_record_id=vsrci.step_record_id AND srf2.KEY ~* 'carat')
	    	 -- REPETIR AIXO AMB CARATS
	    WHERE LEFT(vsrci.cyber_id,3) = 'CYR'
	      AND vsrci.timestamp >= lastreset.maxtime
	      AND vsrci.public_step >= 1
	)
	SELECT 
		r.api, 
		r.api_version,
	    r.cyber_id,  
	    r.group_cyber_id, 
	    r.timestamp,
	    r.public_step_and_name AS Last_step_done, r.max_st,
	    case when r.public_step < 11 AND r.public_step = r.max_st then 'Marcs' 
	         when r.public_step = 11 AND r.public_step = r.max_st then 'Yoan'
	         when r.public_step = 12 AND r.public_step = r.max_st then 'Yoan'
	         else '--'
	    end as "actor",
	    case when r.public_step < 11 AND r.public_step = r.max_st then 'Register steps up to 11-"Order approval"' 
	         when r.public_step = 11 AND r.public_step = r.max_st then 'Register step 12-"Validation of production"'
	         when r.public_step = 12 AND r.public_step = r.max_st then 'Register step 13-"Delivery"'
	         else '--'
	    end as "action",
	    r.KEY, r.pieces
	--    ,key2, carats
	FROM registers r
	WHERE 
	     r.rn = 1
	AND r.api ='diamonds-full'
	AND r.api_version ='5'
	--AND left(cyber_id,20)~'CYR01-21-0102-197213'
	--ORDER BY left(cyber_id,20) DESC, timestamp DESC  
	ORDER BY left(cyber_id,21) DESC, LPAD(substring(cyber_id from '[PV]([0-9]+)'), 3, '0') DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql; -- Specify the language
