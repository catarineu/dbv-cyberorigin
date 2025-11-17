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
--                                  cust, brand, type, begin?, end?,  cyber_ids?, by_year?, Diamanter
-- FILTRES ==============================================================================
SELECT * FROM get_new_stats_detail2
('01', NULL, '00009', NULL, '2024-01-01', '2024-12-31', FALSE, FALSE, TRUE, FALSE); -- NULL, NULL,   NULL,  FALSE


SELECT * FROM get_stats_totals  (NULL,    NULL, NULL, NULL, NULL, FALSE, TRUE);


SET plan_cache_mode = force_custom_plan;
SELECT json_agg(t) FROM (
SELECT *
 FROM get_new_stats_detail  ('01', NULL, '01399', NULL, '2023-01-01', '2024-01-01', FALSE, FALSE, TRUE, FALSE)
) t;
                                        						-- p_only_nfts, p_by_year, p_by_origins, p_with_cyber_ids 


SELECT blockchain_id, name_fr, cust, custname, brand, brandname, sum(lots), sum(pieces), string_agg(cyber_ids,',') 
  FROM get_stats_totals (NULL,    NULL, NULL, NULL, NULL, FALSE, FALSE)
 GROUP BY blockchain_id, name_fr, cust, custname, brand, brandname
 ORDER by cust, brand, blockchain_id;


SELECT * FROM get_stats_totals (NULL,    NULL, NULL, NULL, NULL, TRUE, TRUE)
 WHERE cust='00009' OR brand='00009'; -- Audemars Piguet

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

   
 
