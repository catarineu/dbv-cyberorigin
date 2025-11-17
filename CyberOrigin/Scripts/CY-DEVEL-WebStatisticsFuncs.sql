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

DROP FUNCTION get_diamanter_customer_statistics;

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


SELECT * FROM 

-- ================================================================================
-- ================================================================================
DROP FUNCTION get_diamanter_summary_statistics;

SELECT * FROM get_diamanter_summary_statistics(
    '2022-01-01', -- Begin
    '2024-08-03', -- End
    NULL, -- '00132' -- Raoul Guyot
    NULL, -- '00009' -- La Montre Hermès
    NULL, -- '01'
    NULL, -- 'DIAMONDS_SEMI_FULL'
    TRUE  -- by year ?
);

DROP FUNCTION get_diamanter_summary_statistics;

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
    '2024-08-02',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
);

DROP FUNCTION get_diamanter_statistics_with_origin;

CREATE OR REPLACE FUNCTION get_diamanter_statistics_with_origin(
    p_after TIMESTAMP DEFAULT NULL,
    p_before TIMESTAMP DEFAULT NULL,
    p_custbrand_id VARCHAR(255) DEFAULT NULL,
    p_customer_id VARCHAR(255) DEFAULT NULL,
    p_brand_id VARCHAR(255) DEFAULT NULL,
    p_diamanter_user_external_id VARCHAR(255) DEFAULT NULL,
    p_type_flux VARCHAR(255) DEFAULT NULL
)
RETURNS TABLE (
    result_diamanterId VARCHAR(255),
    result_diamanterUserExternalId VARCHAR(255),
    result_diamanterName VARCHAR(255),
    result_diamanterNameToShow VARCHAR(255),
    result_custbrandId VARCHAR(255),
    result_custbrandUserExternalId VARCHAR(255),
    result_custbrandName VARCHAR(255),
    result_custbrandNameToShow VARCHAR(255),
    result_type VARCHAR(255),
    result_roughsupplier TEXT,
    result_origin TEXT,
    result_sumLots BIGINT,
    result_sumCarats NUMERIC,
    result_sumPieces BIGINT,
    result_pctCarats NUMERIC,
    result_pctPieces NUMERIC,
    result_pctLots NUMERIC
)
AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT
            CAST(diamanter.id AS VARCHAR(255)) AS s_diamanterId,
            diamanter.user_external_id AS s_diamanterUserExternalId,
            diamanter.name_to_show AS s_diamanterNameToShow,
            diamanter.name AS s_diamanterName,
            CAST(custbrand.id AS VARCHAR(255)) AS s_custbrandId,
            custbrand.user_external_id AS s_custbrandUserExternalId,
            COALESCE(custbrand.name_to_show, '(unknown)') AS s_custbrandNameToShow,
            COALESCE(custbrand.name,'(unknown)') AS s_custbrandName,
            psi.type AS s_type,
            psi.cyber_id,
            psi.lot_id AS cyberId,
            psi.data_field_carats AS carats,
            psi.data_field_pieces AS pieces,
            (
                SELECT string_agg(subq_orig.list_orig, ', ')
                FROM (
                    SELECT DISTINCT upper(srf_orig.string_value) as list_orig
                    FROM step_record sr_orig
                    LEFT JOIN step_record_fields srf_orig ON srf_orig.step_record_id = sr_orig.id AND srf_orig.key = 'Origin'
                    WHERE sr_orig.product_search_index_id = psi.id
                    AND sr_orig.role_name in ('RoughCertification', 'Parcel Assessment')
                    ORDER BY upper(srf_orig.string_value) ASC
                ) AS subq_orig
            ) AS s_origin,
            (
                SELECT string_agg(subq_supp.list_supp, ', ')
                FROM (
                    SELECT DISTINCT upper(srf_supp.string_value) as list_supp
                    FROM step_record sr_supp
                    LEFT JOIN step_record_fields srf_supp ON srf_supp.step_record_id = sr_supp.id AND srf_supp.key = 'Rough_Supplier'
                    WHERE sr_supp.product_search_index_id = psi.id
                    AND sr_supp.role_name in ('RoughPurchase','RoughPurchasePre')
                    ORDER BY upper(srf_supp.string_value) ASC
                ) AS subq_supp
            ) AS s_roughsupplier
        FROM
            cob_chain_company custbrand
            LEFT JOIN cob_chain_company diamanter ON diamanter.type = 'LEVEL_1_CLIENT_COMPANY' AND diamanter.id = custbrand.level1client_company_id
            LEFT JOIN cob_chain_company stkh ON stkh.type = 'STAKEHOLDER_COMPANY' AND stkh.level1client_company_id = diamanter.id
            LEFT JOIN chain_member cm ON cm.id = stkh.chain_member_id
            LEFT JOIN product_search_index psi ON (custbrand.user_external_id = psi.customer_id2 OR custbrand.user_external_id = psi.brand_id2) AND psi.owner = cm.id
            LEFT JOIN cob_chain_company customer ON customer.level1client_company_id = diamanter.id AND customer.type = 'LEVEL_2_CLIENT_COMPANY' AND customer.user_external_id = psi.customer_id2
        WHERE
            custbrand.type = 'LEVEL_2_CLIENT_COMPANY'
            AND psi.superseded = FALSE
            AND (p_after IS NULL OR psi.timestamp >= p_after)
            AND (p_before IS NULL OR psi.timestamp <= p_before)
            AND (p_custbrand_id IS NULL OR UPPER(custbrand.user_external_id) = UPPER(p_custbrand_id))
            AND (p_customer_id IS NULL OR UPPER(psi.customer_id2) = UPPER(p_customer_id))
            AND (p_brand_id IS NULL OR UPPER(psi.brand_id2) = UPPER(p_brand_id))
            AND (p_diamanter_user_external_id IS NULL OR UPPER(diamanter.user_external_id) = UPPER(p_diamanter_user_external_id))
            AND (p_type_flux IS NULL OR UPPER(psi.type) = UPPER(p_type_flux))
            AND UPPER(psi.cyber_id) NOT LIKE '%TEST%'
    )
    SELECT
        s_diamanterId AS result_diamanterId,
        s_diamanterUserExternalId AS result_diamanterUserExternalId,
        s_diamanterName AS result_diamanterName,
        s_diamanterNameToShow AS result_diamanterNameToShow,
        s_custbrandId AS result_custbrandId,
        s_custbrandUserExternalId AS result_custbrandUserExternalId,
        s_custbrandName AS result_custbrandName,
        s_custbrandNameToShow AS result_custbrandNameToShow,
        s_type AS result_type,
        s_roughsupplier AS result_roughsupplier,
        s_origin AS result_origin,
        COUNT(DISTINCT cyberId)::BIGINT AS result_sumLots,
        ROUND(SUM(carats), 2) AS result_sumCarats,
        ROUND(SUM(pieces), 0)::BIGINT AS result_sumPieces,
        ROUND(100 * SUM(carats) / SUM(SUM(carats)) OVER (PARTITION BY s_diamanterId, s_type, s_custbrandId), 1) AS result_pctCarats,
        ROUND(100 * SUM(pieces) / SUM(SUM(pieces)) OVER (PARTITION BY s_diamanterId, s_type, s_custbrandId), 1) AS result_pctPieces,
        ROUND(100 * COUNT(DISTINCT cyberId) / SUM(COUNT(DISTINCT cyberId)) OVER (PARTITION BY s_diamanterId, s_type, s_custbrandId), 1) AS result_pctLots
    FROM stats
    GROUP BY
        s_diamanterId,
        s_diamanterUserExternalId,
        s_diamanterName,
        s_diamanterNameToShow,
        s_custbrandId,
        s_custbrandUserExternalId,
        s_custbrandName,
        s_custbrandNameToShow,
        s_type,
        s_roughsupplier,
        s_origin
    ORDER BY
        s_type,
        s_diamanterNameToShow,
        s_custbrandId,
        s_custbrandNameToShow,
        s_roughsupplier,
        s_origin;
END;
$$ LANGUAGE plpgsql;




-- DROP FUNCTION public.get_stats_totals(text, text, text, date, date, bool, bool);

CREATE OR REPLACE FUNCTION public.get_stats_totals(p_customer text DEFAULT NULL::text, p_brand text DEFAULT NULL::text, p_type text DEFAULT NULL::text, p_begin date DEFAULT NULL::date, p_end date DEFAULT NULL::date, p_include_cyber_ids boolean DEFAULT false, p_by_year boolean DEFAULT false)
 RETURNS TABLE(year text, blockchain_id text, name_fr text, cust text, custname text, brand text, brandname text, lots integer, pieces integer, carats double precision, lots_pc double precision, pieces_pc double precision, carats_pc double precision, cyber_ids text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH stats_list AS (
    	-- ------------------------------------------------------------------------------------------
    	-- SELECT_1: Full list of CyberIDs with their origens+providers (only valid ones)
        SELECT psi.cyber_id, psi.TYPE, psi.brand_id2 AS brand, psi.customer_id2 AS customer, psi.data_field_pieces AS pieces, 
        	   psi.data_field_carats AS carats, COALESCE(EXTRACT('year' FROM edr.date_rfb)::TEXT,'2099') AS psi_date
          FROM product_search_index psi
               LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
               LEFT OUTER JOIN erp_date_rfb edr ON LEFT(psi.cyber_id,20)=edr.cyber_id
         WHERE psi.superseded = FALSE    -- Actius
           AND ci.deleted <> TRUE  AND substring(psi.cyber_id FROM 21 FOR 1) <> 'D'
           AND (p_type     IS NULL OR psi.TYPE         = p_type)
           AND (p_customer IS NULL OR psi.customer_id2 = p_customer)
           AND (p_brand    IS NULL OR psi.brand_id2    = p_brand) 
           AND (p_begin    IS NULL OR edr.date_rfb     >= p_begin) 
           AND (p_end      IS NULL OR edr.date_rfb     <  p_end) 
         GROUP BY psi.cyber_id, psi.TYPE, psi.brand_id2, psi.customer_id2, psi.data_field_pieces, psi.data_field_carats,  COALESCE(EXTRACT('year' FROM edr.date_rfb)::TEXT,'2099')
    )
   	-- ------------------------------------------------------------------------------------------
    -- SELECT_2: Aggregation by sublevels
    SELECT 
        -- Columnes de dades ................................................................
        CASE WHEN p_by_year THEN psi_date::text ELSE 'all' END AS year,
        wn.blockchain_name::text, 
        wn.name_fr::text, 
        customer::text AS cust, 
        ccc1.name_to_show::text AS custname, 
        s.brand::text, 
        ccc2.name_to_show::text AS brandname,
        count(cyber_id)::int AS lots, 
        sum(s.pieces)::int AS pieces, 
        sum(s.carats)::float AS carats,
        -- Percentatges per CUSTOMER ........................................................
        round((count(cyber_id)::float / SUM(count(cyber_id)) OVER (PARTITION BY CASE WHEN p_by_year THEN psi_date ELSE 'all' END, wn.blockchain_name))::numeric * 100,2)::float AS lots_pc,
        round((  sum(s.pieces)::float / SUM(sum(s.pieces))   OVER (PARTITION BY CASE WHEN p_by_year THEN psi_date ELSE 'all' END, wn.blockchain_name))::numeric * 100,2)::float AS pieces_pc,
        round((  sum(s.carats)::float / SUM(sum(s.carats))   OVER (PARTITION BY CASE WHEN p_by_year THEN psi_date ELSE 'all' END, wn.blockchain_name))::numeric * 100,2)::float AS carats_pc,
	    CASE
	      WHEN p_include_cyber_ids THEN string_agg(s.cyber_id, ', ' ORDER BY s.cyber_id)::text
	      ELSE NULL
        END AS cyber_ids
      FROM stats_list AS s
           LEFT JOIN cob_chain_company ccc1 ON ccc1.level1client_company_id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'  -- Diamanter '01' hardcoded
                                            AND ccc1.type = 'LEVEL_2_CLIENT_COMPANY' AND ccc1.user_external_id = s.customer
           LEFT JOIN cob_chain_company ccc2 ON ccc2.level1client_company_id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'  -- Diamanter '01' hardcoded
                                            AND ccc2.type = 'LEVEL_2_CLIENT_COMPANY' AND ccc2.user_external_id = s.brand
           LEFT JOIN workflow_name wn       ON (wn.psi_type=s.type)
     GROUP BY CASE WHEN p_by_year THEN psi_date::text ELSE 'all' END, wn.blockchain_name, wn.name_fr, s.customer, ccc1.name_to_show, s.brand, ccc2.name_to_show
     ORDER BY CASE WHEN p_by_year THEN psi_date::text ELSE 'all' END, wn.blockchain_name, 
		        ROW_NUMBER() OVER (PARTITION BY wn.blockchain_name
--		                           ,CASE WHEN p_brand IS NULL AND p_customer IS NULL 	 THEN '1'
--		        					     WHEN p_brand IS NULL AND p_customer IS NOT NULL THEN p_customer
--		        					     WHEN p_brand IS NOT NULL 						 THEN p_brand
--		        					     ELSE 											      p_customer END 
		        					ORDER BY count(cyber_id) DESC); -- De més a menys quantitat carats
END;
$function$
;
