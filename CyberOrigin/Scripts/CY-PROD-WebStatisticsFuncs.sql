SELECT * FROM get_diamanter_customer_statistics(
    '2022-01-01', -- Begin
    '2024-08-05', -- End
    NULL, -- '00132' -- CUST: Raoul Guyot
    NULL, -- '00009' -- BRAND: La Montre Hermès
    NULL, -- '01'    -- DIAMANTAIRE
    'DIAMONDS_FULL', -- 'DIAMONDS_SEMI_FULL' -- TYPE
    FALSE,  -- by year ?
    FALSE   -- w/ cyber_ids ?
) ;

SELECT * FROM get_stats_totals (NULL::text, NULL::text, NULL::text,
						 '2024-01-01'::date, '2024-04-02'::date, FALSE, FALSE);

--DROP FUNCTION get_diamanter_customer_statistics;

CREATE OR REPLACE FUNCTION get_diamanter_customer_statistics(
    p_after_timestamp TIMESTAMP DEFAULT NULL,
    p_before_timestamp TIMESTAMP DEFAULT NULL,
    p_customer_id VARCHAR(255) DEFAULT NULL,
    p_brand_id VARCHAR(255) DEFAULT NULL,
    p_diamanter_user_external_id VARCHAR(255) DEFAULT '01',
    p_type_flux VARCHAR(255) DEFAULT NULL,
    p_by_year boolean DEFAULT FALSE,
    p_with_cyberids boolean DEFAULT FALSE
)
RETURNS TABLE (
    diamanterId VARCHAR(255),
    diamanterUserExternalId VARCHAR(255),
    diamanterNameToShow VARCHAR(255),
    diamanterName VARCHAR(255),
    YEAR TEXT,
    customerId VARCHAR(255),
    customerUserExternalId TEXT,
    customerNameToShow TEXT,
    customerName VARCHAR(255),
    brandUserExternalId TEXT,
    brandNameToShow TEXT,
    type VARCHAR(255),
    sumCarats NUMERIC,
    pctCarats NUMERIC,
    sumPieces INTEGER,
    pctPieces NUMERIC,
    sumLots INTEGER,
    pctLots NUMERIC,
    cyber_ids TEXT
)
AS $$
BEGIN
    RETURN QUERY
	SELECT 
        cast(diamanter.id AS VARCHAR(255)) AS diamanterId,
        diamanter.user_external_id AS diamanterUserExternalId,
        diamanter.name_to_show AS diamanterNameToShow,
        diamanter.name AS diamanterName, 
		gt.year,
		'-'::varchar AS customerid,
        gt.cust      AS customerUserExternalId,
        gt.custname  AS customerNameToShow,
        coalesce(customer.name,'(unknown)') AS customerName, 
        gt.brand      AS brandUserExternalId,
        gt.brandname  AS brandNameToShow,
        w.psi_type,
        gt.carats::numeric AS sumcarats, carats_pc::numeric AS pctcarats,
        gt.pieces::integer AS sumpieces, pieces_pc::numeric AS pctpieces,
        gt.lots::integer   AS sumlots,   lots_pc::numeric   AS pctlots,
		gt.cyber_ids
  	FROM get_stats_totals (p_customer_id::text, p_brand_id::text, p_type_flux::text,
						 p_after_timestamp::date, p_before_timestamp::date, 
					     p_with_cyberids, p_by_year) gt
		LEFT JOIN cob_chain_company diamanter
		    ON diamanter.user_external_id = coalesce(p_diamanter_user_external_id,'01')
		    and diamanter.type = 'LEVEL_1_CLIENT_COMPANY'
	    LEFT JOIN cob_chain_company customer
		    ON customer.level_1_client_company = diamanter.id
		    and customer.type = 'LEVEL_2_CLIENT_COMPANY'
		    and customer.user_external_id = gt.cust
		LEFT OUTER JOIN workflows w ON w.blockchain_name=gt.blockchain_id;
END;
$$ LANGUAGE plpgsql;


-- ================================================================================
-- ================================================================================
SELECT * FROM get_diamanter_summary_statistics(
    '2022-01-01', -- Begin
    '2024-08-03', -- End
    NULL, -- '00132' -- Raoul Guyot
    NULL, -- '00009' -- La Montre Hermès
    NULL, -- '01'
    NULL, -- 'DIAMONDS_SEMI_FULL'
    TRUE  -- by year ?
);

--DROP FUNCTION get_diamanter_summary_statistics;

CREATE OR REPLACE FUNCTION get_diamanter_summary_statistics(
    p_after TIMESTAMP DEFAULT NULL,
    p_before TIMESTAMP DEFAULT NULL,
    p_customer_id VARCHAR(255) DEFAULT NULL,
    p_brand_id VARCHAR(255) DEFAULT NULL,
    p_diamanter_user_external_id VARCHAR(255) DEFAULT '01',
    p_type_flux VARCHAR(255) DEFAULT NULL,
    p_by_year boolean DEFAULT FALSE
)
RETURNS TABLE (
	YEAR TEXT,
    sumCarats NUMERIC,
    sumPieces INTEGER,
    sumLots INTEGER
)
AS $$
BEGIN
    RETURN QUERY
	SELECT 
		gt.year,
        sum(gt.carats)::numeric AS sumcarats,
        sum(gt.pieces)::integer AS sumpieces,
        sum(gt.lots)::integer   AS sumlots
    FROM get_stats_totals (p_customer_id::text, p_brand_id::text, p_type_flux::text,
						 p_after::date, p_before::date, FALSE, p_by_year) gt
	group by gt.year;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM product_search_index psi ORDER BY id DESC LIMIT 5;


-- ================================================================================
-- ================================================================================
SELECT * FROM get_diamanter_statistics_with_origin(
    '2024-01-01',
    '2024-08-05',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
);


SELECT * FROM public.get_diamanter_statistics_with_origin(
'2024-01-01 00:00:00', '2024-08-09 00:00:00', '00132', NULL, '01', NULL, NULL );

DROP FUNCTION public.get_diamanter_statistics_with_origin;

CREATE OR REPLACE FUNCTION public.get_diamanter_statistics_with_origin(p_after timestamp without time zone DEFAULT NULL::timestamp without time zone, p_before timestamp without time zone DEFAULT NULL::timestamp without time zone, p_customer_id character varying DEFAULT NULL::character varying, p_brand_id character varying DEFAULT NULL::character varying,  p_diamanter_user_external_id character varying DEFAULT NULL::character varying, p_type_flux character varying DEFAULT NULL::character varying, p_custbrand_id varchar DEFAULT NULL , p_by_year boolean DEFAULT false, p_with_cyberids boolean DEFAULT false)
 RETURNS TABLE(diamanterid character varying, diamanteruserexternalid character varying, diamantername character varying, diamanternametoshow character varying, year text, custbrandid text, custbranduserexternalid text, custbrandname text, custbrandnametoshow text, branduserexternalid text, brandnametoshow text, type character varying, roughsupplier text, origin text, sumlots integer, sumcarats numeric, sumpieces integer, pctcarats numeric, pctpieces numeric, pctlots numeric, cyber_ids text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_time timestamp;
    v_row_count integer;
BEGIN
--   v_start_time := clock_timestamp();
--    
--    RAISE WARNING 'Starting execution of get_diamanter_statistics_with_origin at %', v_start_time;
--    RAISE WARNING 'Input parameters: p_after=%, p_before=%, p_custbrand_id=%, p_customer_id=%, p_brand_id=%, p_diamanter_user_external_id=%, p_type_flux=%, p_by_year=%, p_with_cyberids=%',
--                 p_after, p_before, p_custbrand_id, p_customer_id, p_brand_id, p_diamanter_user_external_id, p_type_flux, p_by_year, p_with_cyberids;

    RETURN QUERY
    SELECT cast(diamanter.id AS varchar(255)) AS diamanterId,
        diamanter.user_external_id AS diamanterUserExternalId,
        diamanter.name AS diamanterName,
        diamanter.name_to_show AS diamanterNameToShow,
        gt.year::text,
        '-'::text AS customerid,
        gt.cust AS customerUserExternalId,
        coalesce(customer.name, '(unknown)')::text AS customerName,
        gt.custname::text AS customerNameToShow,
        gt.brand AS brandUserExternalId,
        gt.brandname AS brandNameToShow,
        w.psi_type AS type,
        gt.providers AS roughsupplier,
        gt.origens AS origin,
        gt.lots::integer AS sumlots,
        gt.carats::numeric AS sumcarats,
        gt.pieces::integer AS sumpieces,
        lots_pc::numeric AS pctlots,
        carats_pc::numeric AS pctcarats,
        pieces_pc::numeric AS pctpieces,
        gt.cyber_ids::text
    FROM get_stats_origin (p_customer_id::text, p_brand_id::text, p_type_flux::text, p_after::date, p_before::date, p_with_cyberids, p_by_year) gt
    LEFT JOIN cob_chain_company diamanter ON diamanter.user_external_id = coalesce(p_diamanter_user_external_id, '01')
        AND diamanter.type = 'LEVEL_1_CLIENT_COMPANY'
    LEFT JOIN cob_chain_company customer ON customer.level_1_client_company = diamanter.id
        AND customer.type = 'LEVEL_2_CLIENT_COMPANY'
        AND customer.user_external_id = gt.cust
    LEFT OUTER JOIN workflows w ON w.blockchain_name = gt.blockchain_id
    ORDER BY w.psi_type, customer.name, gt.brandname, gt.lots DESC;

--    GET DIAGNOSTICS v_row_count = ROW_COUNT;
--    
--    RAISE WARNING 'Finished execution of get_diamanter_statistics_with_origin at %. Execution time: % seconds. Rows returned: %',
--                 clock_timestamp(),
--                 EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)),
--                 v_row_count;

END;
$function$
;

