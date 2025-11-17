--                     (cust, brand,   type, s_year?,  cyber_ids?) 
SELECT * FROM get_stats(NULL, '00009', NULL, TRUE); -- FALSE
SELECT * FROM get_stats(NULL, '00314', NULL, TRUE, TRUE); -- FALSE
SELECT * FROM get_stats('00132', NULL, NULL, TRUE, TRUE); -- FALSE

--                           (cust, brand, type, s_year?, cyber_ids?) 
SELECT * FROM get_stats(); /* NULL, NULL,  NULL, FALSE,   FALSE */
 
DROP FUNCTION get_stats;
CREATE OR REPLACE FUNCTION get_stats(
    p_customer TEXT DEFAULT NULL,
    p_brand TEXT DEFAULT NULL,
    p_type TEXT DEFAULT NULL,
    p_by_year BOOLEAN DEFAULT FALSE,
    p_include_cyber_ids BOOLEAN DEFAULT NULL 
)
RETURNS TABLE (
    level TEXT,
    year TEXT,
    type TEXT,
    cust TEXT,
    custname TEXT,
    brand TEXT,
    brandname TEXT,
    origens TEXT,
    providers TEXT,
    lots INTEGER,
    pieces INTEGER,
    carats FLOAT,
    lots_pc FLOAT,
    pieces_pc FLOAT,
    carats_pc FLOAT,
    cyber_ids TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH stats_list AS (
    	-- ------------------------------------------------------------------------------------------
    	-- SELECT_1: Full list of CyberIDs with their origens+providers (only valid ones)
        SELECT psi.cyber_id, psi.TYPE, psi.brand_id2 AS brand, psi.customer_id2 AS customer, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats,
               string_agg(DISTINCT srf1.string_value, ', ' ORDER BY srf1.string_value) AS origens,
               string_agg(DISTINCT srf2.string_value, ', ' ORDER BY srf2.string_value) AS providers
          FROM product_search_index psi
               LEFT OUTER JOIN step_record sr1 ON psi.lot_id=LEFT(sr1.cyber_id,24) AND sr1.role_name IN ('RoughCertification', 'Parcel Assessment')
               LEFT OUTER JOIN step_record sr2 ON psi.lot_id=LEFT(sr2.cyber_id,24) AND sr2.role_name IN ('RoughPurchase', 'RoughPurchasePre')
               LEFT OUTER JOIN step_record_fields srf1 ON srf1.step_record_id=sr1.id AND srf1.key = 'Origin'
               LEFT OUTER JOIN step_record_fields srf2 ON srf2.step_record_id=sr2.id AND srf2.key = 'Rough_Supplier'
               LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
         WHERE psi.superseded = FALSE    -- Actius
           AND psi.cyber_id ~ '^CYR01-'  -- Actius i NO són TEST ni errors
           AND ci.deleted   = FALSE AND ci.cancelled = FALSE -- NO anulats
           AND (p_type     IS NULL OR psi.TYPE         = p_type)
           AND (p_customer IS NULL OR psi.customer_id2 = p_customer)
           AND (p_brand    IS NULL OR psi.brand_id2    = p_brand)
         GROUP BY psi.cyber_id, psi.TYPE, psi.brand_id2, psi.customer_id2, psi.data_field_pieces, psi.data_field_carats
    )
   	-- ------------------------------------------------------------------------------------------
    -- SELECT_2: Aggregation by sublevels
    SELECT 
    	-- Nivell de SUBTOTAL (pel marcatge de colors en Excel)..............................
        CASE
            WHEN GROUPING(CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END) = 1 AND GROUPING(s.type) = 1 AND GROUPING(s.customer) = 1 AND GROUPING(s.brand) = 1 THEN 'xxx'
            WHEN GROUPING(CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END) = 0 AND GROUPING(s.type) = 1 AND GROUPING(s.customer) = 1 AND GROUPING(s.brand) = 1 THEN 'xx'
            WHEN GROUPING(CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END) = 0 AND GROUPING(s.type) = 0 AND GROUPING(s.customer) = 1 AND GROUPING(s.brand) = 1 THEN 'x'
            WHEN GROUPING(CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END) = 0 AND GROUPING(s.type) = 0 AND GROUPING(s.customer) = 0 AND GROUPING(s.brand) = 1 THEN 'x'
            ELSE '.'
        END AS level,
        -- Columnes de dades ................................................................
        CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END AS year,
        s.TYPE::text, 
        customer::text AS cust, 
        ccc1.name_to_show::text AS custname, 
        s.brand::text, 
        ccc2.name_to_show::text AS brandname,
        s.origens::text, 
        s.providers::text,
        count(cyber_id)::int AS lots, 
        sum(s.pieces)::int AS pieces, 
        sum(s.carats)::float AS carats,
        -- Percentatges per CUSTOMER ........................................................
        round((count(cyber_id)::float / SUM(count(cyber_id)) OVER 
        	(PARTITION BY (CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END, s.type, s.customer)))::numeric * 100,2)::float AS lots_pc,
        round((sum(s.pieces)::float / SUM(sum(s.pieces)) OVER 
        	(PARTITION BY (CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END, s.type, s.customer)))::numeric * 100,2)::float AS pieces_pc,
        round((sum(s.carats)::float / SUM(sum(s.carats)) OVER 
        	(PARTITION BY (CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END, s.type, s.customer)))::numeric * 100,2)::float AS carats_pc,
	    CASE
	      WHEN p_include_cyber_ids THEN string_agg(s.cyber_id, ', ' ORDER BY s.cyber_id)::text
	      ELSE NULL
        END AS cyber_ids
      FROM stats_list AS s
           LEFT JOIN cob_chain_company ccc1 ON ccc1.level1client_company_id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'  -- Diamanter '01' hardcoded
                                            AND ccc1.type = 'LEVEL_2_CLIENT_COMPANY' AND ccc1.user_external_id = s.customer
           LEFT JOIN cob_chain_company ccc2 ON ccc2.level1client_company_id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'  -- Diamanter '01' hardcoded
                                            AND ccc2.type = 'LEVEL_2_CLIENT_COMPANY' AND ccc2.user_external_id = s.brand
     GROUP BY GROUPING SETS (
        (CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END, s.type, s.customer, ccc1.name_to_show, s.brand, ccc2.name_to_show, s.origens, s.providers),
        (CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END, s.type),
        (CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END),
        ()
     )
     ORDER BY 
        CASE WHEN p_by_year THEN substring(s.cyber_id,7,2) ELSE 'all' END, 
        s.type, 
        s.customer, 
        s.brand, 
        ROW_NUMBER() OVER (PARTITION BY s.type, s.customer, s.brand ORDER BY count(cyber_id) DESC); -- De més a menys quantitat
END;
$$ LANGUAGE plpgsql;
