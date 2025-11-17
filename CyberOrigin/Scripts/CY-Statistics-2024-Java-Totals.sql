-- Consulta com a la web
SELECT
    blockchain_id,
    cust  || ' - ' || custname AS cust,
    brand || ' - ' || brandname AS brand,
    lots ,  lots_pc || ' %' AS lots_pc,
    carats, carats_pc || ' %' AS carats_pc,
    pieces, pieces_pc || ' %' AS pieces_pc,
    cyber_ids
FROM get_stats_totals(NULL, NULL,  NULL, NULL,   NULL,  TRUE); -- NULL, NULL,  NULL, NULL,   NULL, *TRUE

-- FILTRES ==============================================================================
--                              cust, brand, type, begin?, end?,  cyber_ids?, by_year?, Diamanter
-- FILTRES ==============================================================================
SELECT 
        cast(diamanter.id AS VARCHAR(255)) AS diamanterId,
        diamanter.user_external_id AS diamanterUserExternalId,
        diamanter.name_to_show AS diamanterNameToShow,
        diamanter.name AS diamanterName, '-' AS customerid,
        gt.cust AS customerUserExternalId,
        coalesce(customer.name_to_show,'(unknown)') AS customerNameToShow,
        coalesce(customer.name,'(unknown)') AS customerName, 
        w.psi_type,
        gt.carats AS sumcarats, carats_pc AS pctcarats,
        gt.pieces AS sumpieces, pieces_pc AS pctpieces,
        gt.lots   AS sumlots,   lots_pc   AS pctlots
  FROM get_stats_totals (NULL, NULL, NULL, '2024-01-01', '2024-04-02', FALSE, FALSE) gt
		LEFT JOIN chain_member cm ON gt.psi_owner = cm.id
		LEFT JOIN cob_chain_company stkh
		    ON stkh.chain_member_id = cm.id
		    and stkh.type='STAKEHOLDER_COMPANY'
		LEFT JOIN cob_chain_company diamanter
		    ON diamanter.id = stkh.level1client_company_id
		    and diamanter.type = 'LEVEL_1_CLIENT_COMPANY'
	    LEFT JOIN cob_chain_company customer
		    ON customer.level_1_client_company = diamanter.id
		    and customer.type = 'LEVEL_2_CLIENT_COMPANY'
		    and customer.user_external_id = gt.cust
		LEFT OUTER JOIN workflows w ON w.blockchain_name=gt.blockchain_id;

SELECT * FROM workflows w 
SELECT * FROM chain_member cm ORDER BY id;

SELECT * FROM get_stats_totals (NULL, '00112', NULL, NULL, NULL, TRUE, TRUE); -- NULL, NULL,   NULL,  FALSE
SELECT * FROM get_stats_totals ('00112', NULL, NULL, NULL, NULL, TRUE, TRUE); 
SELECT * FROM get_stats_totals (NULL,    NULL, NULL, NULL, NULL, TRUE, TRUE)
 WHERE cust='00296' OR brand='00296'; -- Audemars Piguet

 SELECT user_external_id, name_to_show
   FROM cob_chain_company ccc 
  WHERE TYPE='LEVEL_2_CLIENT_COMPANY' ORDER BY user_external_id ;
 
 
 SELECT blockchain_id, name_fr, cust, custname, brand, brandname, lots, LEFT (cyber_ids, 50) AS cyber_ids
   FROM get_stats_totals2 (NULL,    NULL, NULL, NULL, NULL, TRUE, TRUE);
   
 SELECT cust, custname, brand, brandname, sum(lots) AS lots
  FROM get_stats_totals (NULL,    NULL, NULL, NULL, NULL, FALSE, FALSE)
  GROUP BY cust, custname, brand, brandname
  ORDER BY cust;   
  
-- Llista de brands/customers amb SUMs de certs anys
 SELECT blockchain_id, name_fr, cust AS customer, custname, brand AS "brand   .", brandname, 
        sum(lots) AS lots, sum(pieces) AS pieces, round(sum(carats)::numeric,2) AS carats
   FROM get_stats_totals (NULL,    NULL, NULL, NULL, NULL, TRUE, TRUE)
   WHERE YEAR IN ('2023','2024')
   GROUP BY blockchain_id, name_fr, cust, custname, brand, brandname
   ORDER BY blockchain_id, name_fr, cust, custname, brand, brandname;
 
  
 SELECT psi.cyber_id, final_certificate_url 
   FROM product_search_index psi
        LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
 WHERE psi.superseded = FALSE AND ci.deleted = FALSE
   AND psi.cyber_id IN ('CYR01-22-0504-198519', 'CYR01-22-0544-202725', 'CYR01-22-0544-202726', 'CYR01-22-0586-207751', 'CYR01-22-0627-215823',
'CYR01-22-0628-215824', 'CYR01-22-0639-217454', 'CYR01-22-0640-217464', 'CYR01-22-0681-227756', 'CYR01-22-0722-237607', 'CYR01-23-0557-261742')
 
SELECT sum(lots) FROM get_stats_totals (NULL, NULL, NULL, NULL, NULL, TRUE, TRUE); -- NULL, NULL, NULL,   NULL,  FALSE 


SELECT cyber_id, data_field_pieces, data_field_carats, data_field_diameter_min, data_field_diameter_max 
FROM product_search_index psi 
WHERE cyber_id  IN ('CYR01-22-0537-201790', 'CYR01-22-0537-201791', 'CYR01-22-0537-201792', 'CYR01-22-0677-226933', 'CYR01-22-0677-226934', 'CYR01-22-0677-226935',
'CYR01-22-0678-226936', 'CYR01-22-0678-226937', 'CYR01-22-0678-226938')
  AND superseded = false


SELECT cyber_id, customer_id, customer_id2 , brand_id, brand_id2  
FROM product_search_index psi 
WHERE cyber_id  IN ('CYR01-22-0677-226935', 'CYR01-22-0678-226938')
  AND superseded = false
  
  
  
-- ============== ESTADISTIQUES WEB
--(1) El filtre tipus és psi.type (DIAMONDS_FULL), si la web envia una altra cosa. Convertir amb:
SELECT psi_type FROM workflows w WHERE id = '01';
-- SELECT * FROM workflows w WHERE psi_type='DIAMONDS_FULL';

--(2) El filtre diamanter és chain_member.id (4) --> LEFT OUTER JOIN(x) cob_chain_company chainMMber->level1->user_ext_id 
SELECT TYPE, id, name, user_external_id, chain_member_id, level1client_company_id, name_to_show FROM cob_chain_company ccc WHERE name ~* 'gil' ORDER BY type;



-- Consulta totals
SELECT sum(lots), sum(pieces), sum(carats) 
  FROM get_stats_totals (NULL, NULL, 'DIAMONDS_FULL', '2024-01-01', '2024-05-09', FALSE, FALSE);

 
--                              cust, brand, type,  begin?     , end?        ,  cyber_ids?, by_year?, Diamanter
SELECT * FROM get_stats_totals (NULL, NULL , '01', '2023-01-01', '2024-05-09', FALSE      , FALSE   , NULL);


SELECT * FROM get_stats_totals (NULL, NULL, NULL, '2023-01-01', '2024-05-09', TRUE, TRUE, NULL);
SELECT * FROM get_stats_totals (NULL, NULL, NULL, NULL, NULL, TRUE, FALSE, NULL);-- WHERE cust='00112'

SELECT * FROM product_search_index psi WHERE cyber_id ='CYR01-22-0678-226936'


--   
--
--
--
--
--
--


 ==========================================================================================
-- ==========================================================================================
 SELECT cast(diamanter.id AS varchar(255)) AS diamanterId,
		diamanter.user_external_id AS diamanterUserExternalId,
		diamanter.name_to_show AS
		diamanterNameToShow,
		diamanter.name AS diamanterName,
		cast(customer.id AS varchar(255)) AS customerId,
		psi.customer_id AS customerUserExternalId,
		coalesce(customer.name_to_show,
		'(unknown)') AS customerNameToShow,
		coalesce(customer.name,
		'(unknown)') AS customerName,
		psi.type AS type,
		sum(psi.data_field_carats) AS sumCarats,
		round(100 * sum(psi.data_field_carats) / sum(sum(psi.data_field_carats))
		 	OVER (PARTITION BY diamanter.name_to_show, psi.TYPE,	psi.customer_id), 1) AS pctCarats,
		sum(psi.data_field_pieces) AS sumPieces,
		round(100 * sum(psi.data_field_pieces) / sum(sum(psi.data_field_pieces)) 
			OVER (PARTITION BY diamanter.name_to_show, psi.TYPE, psi.customer_id), 1) AS pctPieces,
		count(*) AS sumLots,
		round(100 * count(*) / sum(count(*)) 
			OVER (PARTITION BY diamanter.name_to_show, psi.TYPE, psi.customer_id), 1) AS pctLots
FROM product_search_index psi
    LEFT JOIN chain_member cm ON psi.owner = cm.id
    LEFT JOIN cob_chain_company stkh ON stkh.chain_member_id = cm.id AND stkh.type = 'STAKEHOLDER_COMPANY'
    LEFT JOIN cob_chain_company diamanter ON diamanter.id = stkh.level1client_company_id  AND diamanter.type = 'LEVEL_1_CLIENT_COMPANY'
    LEFT JOIN cob_chain_company customer ON customer.level_1_client_company = diamanter.id AND customer.type = 'LEVEL_2_CLIENT_COMPANY' AND customer.user_external_id = psi.customer_id
WHERE UPPER(psi.cyber_id) NOT LIKE '%TEST%'
--  AND (CAST(CAST(:after AS varchar(255)) AS timestamp) IS NULL   OR psi.timestamp >= CAST(CAST(:after AS varchar(255)) AS timestamp))
--  AND (CAST(CAST(:before AS varchar(255)) AS timestamp) IS NULL  OR psi.timestamp <= CAST(CAST(:before AS varchar(255)) AS timestamp))
--  AND (:customerId IS NULL OR UPPER(psi.customer_id2) = UPPER(CAST(:customerId AS varchar(255))))
--  AND (:brandId IS NULL OR UPPER(psi.brand_id2) = UPPER(CAST(:brandId AS varchar(255))))
--  AND (:diamanterUserExternalId IS NULL OR UPPER(diamanter.user_external_id) = UPPER(CAST(:diamanterUserExternalId AS varchar(255))))
--  AND (:typeFlux IS NULL OR UPPER(psi.type) = UPPER(CAST(:typeFlux AS varchar(255))))
GROUP BY cast(diamanter.id AS varchar(255)),
 diamanter.user_external_id,
 diamanter.name_to_show,
 diamanter.name,
 cast(customer.id AS varchar(255)),
 psi.customer_id,
 coalesce(customer.name_to_show, '(unknown)'),
 coalesce(customer.name, '(unknown)'),
 psi.type
ORDER BY diamanter.name_to_show,
 psi.TYPE,
 psi.customer_id,
 coalesce(customer.name_to_show, '(unknown)')

 SELECT * FROM product_search_index psi LIMIT 5;

SELECT * FROM chain_member cm ;
SELECT * FROM chain_member_vottun_id cmvi ;
SELECT * FROM cob_chain_company ccc WHERE name ~* 'gil' ORDER BY type;

SELECT coalesce(sum(psi.data_field_carats), 0) AS sumCarats, 
	   coalesce(sum(psi.data_field_pieces), 0) AS sumPieces, 
	   count(*) AS sumLots
FROM product_search_index psi
    LEFT JOIN chain_member cm ON psi.owner = cm.id
    LEFT JOIN cob_chain_company stkh ON stkh.chain_member_id = cm.id        AND stkh.type = 'STAKEHOLDER_COMPANY'
    LEFT JOIN cob_chain_company diamanter ON diamanter.id = stkh.level1client_company_id   AND diamanter.type = 'LEVEL_1_CLIENT_COMPANY'
    LEFT JOIN cob_chain_company customer ON customer.level_1_client_company = diamanter.id AND  customer.type = 'LEVEL_2_CLIENT_COMPANY' AND customer.user_external_id = psi.customer_id
WHERE UPPER(psi.cyber_id) NOT LIKE '%TEST%'
--AND (CAST(CAST(:after AS varchar(255)) AS timestamp) IS NULL OR psi.timestamp >= CAST(CAST(:after AS varchar(255)) AS timestamp))
--AND (CAST(CAST(:before AS varchar(255)) AS timestamp) IS NULL  OR psi.timestamp <= CAST(CAST(:before AS varchar(255)) AS timestamp))
--AND (:customerId IS NULL    OR UPPER(psi.customer_id2) = UPPER(CAST(:customerId AS varchar(255))))
--AND (:brandId IS NULL       OR UPPER(psi.brand_id2) = UPPER(CAST(:brandId AS varchar(255))))
--AND (:diamanterUserExternalId IS NULL   OR UPPER(diamanter.user_external_id) = UPPER(CAST(:diamanterUserExternalId AS varchar(255))))
--AND (:typeFlux IS NULL      OR UPPER(psi.type) = UPPER(CAST(:typeFlux AS varchar(255))))

   
 


DROP FUNCTION public.get_stats_totals2;

CREATE OR REPLACE FUNCTION public.get_stats_totals2(p_customer text DEFAULT NULL::text, p_brand text DEFAULT NULL::text, p_type text DEFAULT NULL::text, p_begin date DEFAULT NULL::date, p_end date DEFAULT NULL::date, p_include_cyber_ids boolean DEFAULT false, p_by_year boolean DEFAULT false)
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
               LEFT OUTER JOIN erp_rfb edr ON LEFT(psi.cyber_id,20)=edr.cyber_id
         WHERE psi.superseded = FALSE    -- Actius
           AND ci.deleted <> TRUE  AND substring(psi.cyber_id FROM 21 FOR 1) <> 'D'
           AND (p_type     IS NULL OR psi.TYPE         = p_type)
           AND (p_customer IS NULL OR psi.customer_id = p_customer)
           AND (p_brand    IS NULL OR psi.brand_id    = p_brand) 
           AND (p_begin    IS NULL OR edr.date_rfb     >= p_begin) 
           AND (p_end      IS NULL OR edr.date_rfb     <  p_end) 
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
		        ROW_NUMBER() OVER (PARTITION BY wn.blockchain_name
--		                           ,CASE WHEN p_brand IS NULL AND p_customer IS NULL 	 THEN '1'
--		        					     WHEN p_brand IS NULL AND p_customer IS NOT NULL THEN p_customer
--		        					     WHEN p_brand IS NOT NULL 						 THEN p_brand
--		        					     ELSE 											      p_customer END 
		        					ORDER BY count(cyber_id) DESC, sum(s.pieces) desc, sum(s.carats) desc); -- De més a menys quantitat carats
END;
$function$
;

