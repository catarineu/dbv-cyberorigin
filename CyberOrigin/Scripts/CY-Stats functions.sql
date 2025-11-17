-- DROP FUNCTION public.get_stats_totals(text, text, text, date, date, bool, bool, int4);

SELECT * FROM get_stats_totals_devel (NULL,    NULL, NULL, NULL, NULL, TRUE, TRUE)
 WHERE brand='00296' 
ORDER BY brand;

WHERE blockchain_id='Blockchain-01' ORDER BY cust;

SELECT * 

SELECT TYPE, user_external_id AS ex_id, name, state, name_to_show 
  FROM cob_chain_company ccc 
 WHERE TYPE='LEVEL_2_CLIENT_COMPANY'
 ORDER BY user_external_id;

SELECT superseded, cyber_id, * 
  FROM product_search_index psi 
 WHERE
 customer_id  = '01359' OR
 customer_id2 = '01359' OR
 brand_id     = '01359' OR
 brand_id2    = '01359';



CREATE OR REPLACE FUNCTION public.get_stats_totals_devel(p_customer text DEFAULT NULL::text, p_brand text DEFAULT NULL::text, p_type text DEFAULT NULL::text, p_begin date DEFAULT NULL::date, p_end date DEFAULT NULL::date, p_include_cyber_ids boolean DEFAULT false, p_by_year boolean DEFAULT false, p_owner integer DEFAULT NULL::integer)
 RETURNS TABLE(year text, blockchain_id text, name_fr text, cust text, custname text, brand text, brandname text, lots integer, pieces integer, carats double precision, lots_pc double precision, pieces_pc double precision, carats_pc double precision, cyber_ids text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH stats_list AS (
    	-- ------------------------------------------------------------------------------------------
    	-- SELECT_1: Full list of CyberIDs with their origens+providers (only valid ones)
        SELECT psi.cyber_id, psi.TYPE, psi.brand_id AS brand, psi.customer_id AS customer, psi.data_field_pieces AS pieces, 
        	   psi.data_field_carats AS carats, COALESCE(EXTRACT('year' FROM edr.date_rfb)::TEXT,'2099') AS psi_date
          FROM product_search_index psi
               LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
               LEFT OUTER JOIN erp_date_rfb edr ON LEFT(psi.cyber_id,20)=edr.cyber_id
         WHERE psi.superseded = FALSE    -- Actius
           AND ci.deleted <> TRUE  AND substring(psi.cyber_id FROM 21 FOR 1) <> 'D'
           AND (p_type     IS NULL OR psi.TYPE         = p_type)
           AND (p_customer IS NULL OR psi.customer_id = p_customer)
           AND (p_brand    IS NULL OR psi.brand_id    = p_brand)
           AND (p_begin    IS NULL OR edr.date_rfb     >= p_begin)
           AND (p_end      IS NULL OR edr.date_rfb     <  p_end)
           AND (p_owner    IS NULL OR psi.OWNER        = p_owner)
         GROUP BY psi.cyber_id, psi.TYPE, psi.brand_id, psi.customer_id, psi.data_field_pieces, psi.data_field_carats,  COALESCE(EXTRACT('year' FROM edr.date_rfb)::TEXT,'2099')
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
		        ROW_NUMBER() OVER (PARTITION BY wn.blockchain_name, 
		        					CASE WHEN p_brand IS NULL AND p_customer IS NULL 	 THEN '1'
		        					     WHEN p_brand IS NULL AND p_customer IS NOT NULL THEN p_customer
		        					     WHEN p_brand IS NOT NULL 						 THEN p_brand
		        					     ELSE 											      p_customer
		        					END ORDER BY count(cyber_id) DESC); -- De més a menys quantitat
END;
$function$
;
