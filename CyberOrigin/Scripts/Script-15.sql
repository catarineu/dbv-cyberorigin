-- DROP FUNCTION public.get_group_orders();


SELECT * FROM get_standard_open_orders();

CREATE OR REPLACE FUNCTION public.get_standard_open_orders()
 RETURNS TABLE(blockchain_name character varying, api character varying, apiv character varying, brand character varying, brandname character varying, cust character varying, custname character varying, cyber_id text, "timestamp" timestamp without time zone, last_step_done text, group_or_std text, pieces numeric, carats numeric, d_min_max text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        wn.blockchain_name AS blockchain,
        te.api,
        te.apiv,
        te.brand,
        ccc1.name_to_show AS brandname,
        te.cust,
        ccc2.name_to_show AS custname,
        te.cyber_id,
        te."timestamp",
        te.last_step_done,
        te.group_or_std,
        te.pieces,
        te.carats,
        te.d_min_max
    FROM vw_tmp_excel te
    LEFT OUTER JOIN cyber_id ci ON ci.cyber_id = te.cyber_id
    LEFT OUTER JOIN workflow_name wn ON wn.api = te.api
    LEFT OUTER JOIN cob_chain_company ccc1 ON ccc1.user_external_id = te.brand
    LEFT OUTER JOIN cob_chain_company ccc2 ON ccc2.user_external_id = te.cust
    WHERE ci.cancelled IS NOT TRUE
      AND te.rns = 1
      AND te.public_step < wn.steps
      AND te.group_or_std = 'Standard'
      AND wn.blockchain_name NOT IN ('Blockchain-10', 'Blockchain-20', 'Blockchain-30')
    ORDER BY wn.code, te.public_step DESC, te.group_cyber_id;
END;
$function$
;
