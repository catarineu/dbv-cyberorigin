SELECT psi.cyber_id, lower(TYPE), customer_id, brand_id, psi.data_field_diameter_min, psi.data_field_diameter_max, psi.ref_fab_order, psi.ref_customer 
  FROM product_search_index psi 
	   LEFT OUTER JOIN cyber_id ci ON ci.cyber_id = psi.lot_id 
 WHERE superseded=FALSE 
   AND cancelled IS NOT TRUE
   AND brand_id IS NULL;

SELECT customer_id, brand_id, cancelled, count(*)
  FROM product_search_index psi 
	   LEFT OUTER JOIN cyber_id ci ON ci.cyber_id = psi.lot_id 
 WHERE superseded=FALSE 
   AND cancelled IS NOT TRUE
 GROUP BY customer_id, brand_id, cancelled
 ORDER BY customer_id;

-- ============= Correcció de brand =============
-- UPDATE product_search_index psi
--   SET brand_id='00314'
--  FROM cyber_id ci 
-- WHERE ci.cyber_id = psi.lot_id  AND brand_id IS NULL  AND superseded=FALSE;
--   AND customer_id='00132'

-- =====================================================================================
-- cust-brand COUNTER (CHANGES)
SELECT wn.blockchain_name, psi."type",
	psi.customer_id  || ' - ' || COALESCE(ccc1.name_to_show, '') AS cust,
	psi.customer_id2 || ' - ' || COALESCE(ccc2.name_to_show, '') AS cust2,
	psi.brand_id     || ' - ' || COALESCE(ccc3.name_to_show, '') AS brand,
	psi.brand_id2    || ' - ' || COALESCE(ccc4.name_to_show, '') AS brand2,
    count(1), STRING_AGG(psi.cyber_id,', ' ORDER BY cyber_id) AS cyber_id
FROM product_search_index psi
    LEFT OUTER JOIN cob_chain_company ccc1 ON ccc1."type" = 'LEVEL_2_CLIENT_COMPANY' AND ccc1.user_external_id = psi.customer_id
    LEFT OUTER JOIN cob_chain_company ccc2 ON ccc2."type" = 'LEVEL_2_CLIENT_COMPANY' AND ccc2.user_external_id = psi.customer_id2
    LEFT OUTER JOIN cob_chain_company ccc3 ON ccc3."type" = 'LEVEL_2_CLIENT_COMPANY' AND ccc3.user_external_id = psi.brand_id
    LEFT OUTER JOIN cob_chain_company ccc4 ON ccc4."type" = 'LEVEL_2_CLIENT_COMPANY' AND ccc4.user_external_id = psi.brand_id2
    LEFT OUTER JOIN workflow_name wn ON wn.psi_type=psi.type
WHERE psi.superseded = FALSE
  AND cyber_id NOT ILIKE '%TEST%' AND cyber_id ILIKE 'CYR%'
  AND (customer_id<>customer_id2 OR brand_id<>brand_id2)
GROUP BY wn.blockchain_name, psi."type", cust2, brand2,customer_id, brand_id, ccc1.name_to_show, ccc3.name_to_show
ORDER BY psi."type", cust2

SELECT * FROM workflow_name wn 

-- =====================================================================================
-- cust-brand COUNTER (FULL)
SELECT wn.blockchain_name, psi."type",
	psi.customer_id2 || ' - ' || COALESCE(ccc2.name_to_show, '') AS cust2,
	psi.brand_id2    || ' - ' || COALESCE(ccc4.name_to_show, '') AS brand2,
    count(1)
    , STRING_AGG(psi.cyber_id,', ' ORDER BY cyber_id) AS cyber_id
FROM product_search_index psi
    LEFT OUTER JOIN cob_chain_company ccc2 ON ccc2."type" = 'LEVEL_2_CLIENT_COMPANY' AND ccc2.user_external_id = psi.customer_id2
    LEFT OUTER JOIN cob_chain_company ccc4 ON ccc4."type" = 'LEVEL_2_CLIENT_COMPANY' AND ccc4.user_external_id = psi.brand_id2
    LEFT OUTER JOIN workflow_name wn ON wn.psi_type=psi.TYPE
WHERE psi.superseded = FALSE
  AND cyber_id NOT ILIKE '%TEST%' AND cyber_id ILIKE 'CYR%' 
GROUP BY wn.blockchain_name, psi."type", ccc2.name_to_show, ccc4.name_to_show, customer_id2, brand_id2
ORDER BY psi."type", ccc2.name_to_show, ccc4.name_to_show

-- =====================================================================================
-- cust2-brand2 COUNTER (clean)
SELECT
	psi.brand_id2    || ' - ' || COALESCE(ccc4.name_to_show, '') AS brand,
	psi.customer_id2 || ' - ' || COALESCE(ccc2.name_to_show, '') AS customer,
	psi."type" AS blockchain,
	count(1) --, STRING_AGG(psi.cyber_id,', ') AS cyber_id
FROM product_search_index psi
    LEFT OUTER JOIN cob_chain_company ccc2 ON ccc2."type" = 'LEVEL_2_CLIENT_COMPANY' AND ccc2.user_external_id = psi.customer_id2
    LEFT OUTER JOIN cob_chain_company ccc4 ON ccc4."type" = 'LEVEL_2_CLIENT_COMPANY' AND ccc4.user_external_id = psi.brand_id2
WHERE psi.superseded = FALSE
  AND cyber_id NOT ILIKE '%TEST%' AND cyber_id ILIKE 'CYR%'
GROUP BY GROUPING SETS (
	(ccc2.name_to_show, ccc4.name_to_show, customer_id2, brand_id2, psi."type"),
	())
ORDER BY ccc4.name_to_show, blockchain;



-- =====================================================================================
-- Only cust-brand list
SELECT
	psi.TYPE, 
	psi.customer_id2, COALESCE(ccc1.name_to_show, 'unkown') AS name_cust2,
	psi.brand_id2,    COALESCE(ccc2.name_to_show, 'unkown') AS name_brand2, 
	count(*)
FROM product_search_index psi
    LEFT OUTER JOIN cob_chain_company ccc1 ON ccc1."type" = 'LEVEL_2_CLIENT_COMPANY' AND ccc1.user_external_id = psi.customer_id2
    LEFT OUTER JOIN cob_chain_company ccc2 ON ccc2."type" = 'LEVEL_2_CLIENT_COMPANY' AND ccc2.user_external_id = psi.brand_id2
WHERE psi.superseded = FALSE
  AND cyber_id ~ '^CYR01-' 
GROUP BY psi.TYPE, psi.customer_id2, psi.brand_id2, name_cust2, name_brand2
ORDER BY psi.TYPE, psi.customer_id2, psi.brand_id2

  

-- =====================================================
-- Cust-brand transformation
-- =====================================================
UPDATE product_Search_index SET brand_id2=brand_id, customer_id2=customer_id;

SELECT psi.cyber_id, customer_id, customer_id2, brand_id, brand_id2 
  FROM product_Search_index psi
       LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
 WHERE psi.superseded = FALSE AND ci.deleted = FALSE
   AND customer_id2='00389' AND brand_id2<>'00389'; -- La Montre Hermès


UPDATE product_Search_index SET brand_id2='00009'  WHERE customer_id2='00009' AND brand_id2<>'00009' AND superseded=FALSE; -- La Montre Hermès
UPDATE product_Search_index SET brand_id2='00017'  WHERE customer_id2='00017' AND brand_id2<>'00017' AND cyber_id<>'CYR01-22-0516-199307' AND superseded=FALSE; -- Cornu & Cie → Arnold & Son
UPDATE product_Search_index SET brand_id2='00432'  WHERE customer_id2='00017' AND brand_id2<>'00432' AND cyber_id='CYR01-22-0516-199307' AND superseded=FALSE; -- Cornu & Cie → Arnold & Son
UPDATE product_Search_index SET brand_id2='00277'  WHERE customer_id2='00051' AND brand_id2<>'00277' AND superseded=FALSE; -- Orolux      → Louis Vuitton
UPDATE product_Search_index SET brand_id2='00314'  WHERE customer_id2='00132' AND brand_id2<>'00314' AND superseded=FALSE; -- Raoul Guyot → Hermès Paris
UPDATE product_Search_index SET brand_id2='00314'  WHERE customer_id2='00098' AND brand_id2<>'00314' AND superseded=FALSE; -- Silvant     → Hermès Paris
UPDATE product_Search_index SET brand_id2='00296'  WHERE customer_id2='00296' AND brand_id2<>'00296' AND superseded=FALSE; -- Jaeger-Lecoultre
UPDATE product_Search_index SET brand_id2='00370'  WHERE customer_id2='00370' AND brand_id2<>'00370' AND superseded=FALSE; -- Pibor
UPDATE product_Search_index SET brand_id2='00389'  WHERE customer_id2='00389' AND brand_id2<>'00389' AND superseded=FALSE; -- Du Pont
UPDATE product_Search_index SET brand_id2='01092'  WHERE customer_id2='01092' AND brand_id2<>'01092' AND superseded=FALSE; -- Guenat
UPDATE product_Search_index SET brand_id2='01105'  WHERE customer_id2='01105' AND brand_id2<>'01105' AND superseded=FALSE; -- Czapek
UPDATE product_Search_index SET brand_id2='01115'  WHERE customer_id2='01115' AND brand_id2<>'01115' AND superseded=FALSE; -- Delvaux
UPDATE product_Search_index SET brand_id2='00277'  WHERE customer_id2='01305' AND brand_id2<>'00277' AND superseded=FALSE; -- BBHG        → Louis Vuitton
UPDATE product_Search_index SET brand_id2='00112', customer_id2='00112' WHERE customer_id='01359' AND (brand_id2<>'00112' OR customer_id2<>'00112') AND superseded=FALSE; -- AUDEM PIGUET → Audemars Piguet
UPDATE product_Search_index SET brand_id2='00112', customer_id2='00112' WHERE customer_id='01193' AND (brand_id2<>'00112' OR customer_id2<>'00112') AND superseded=FALSE; -- Bangerter    → Audemars Piguet
UPDATE product_Search_index SET brand_id2='00314', customer_id2='00132' WHERE customer_id2 IS NULL AND brand_id2='00132' AND (brand_id2<>'00314' OR customer_id2<>'00132') AND superseded=FALSE; -- Raoul Guyot → Hermès Paris
UPDATE product_Search_index SET customer_id2='01092'  WHERE customer_id2 IS NULL AND brand_id2='01092' AND customer_id2<>'01092' AND superseded=FALSE; -- Guenat
UPDATE product_search_index SET brand_id2='00389', customer_id2='00389' WHERE cyber_id IN ('CYR01-23-0515-246462', 'CYR01-23-0515-246460', 'CYR01-23-0515-246459', 'CYR01-23-0515-246461') AND superseded=FALSE;
UPDATE product_search_index SET brand_id2='01092', customer_id2='01092' WHERE cyber_id IN ('CYR01-23-0571-267115', 'CYR01-23-0571-267118', 'CYR01-23-0571-267117', 'CYR01-23-0571-267116') AND superseded=FALSE;


-- Llista de codis
SELECT user_external_id, name, name_to_show  
  FROM cob_chain_company ccc 
 WHERE "type" = 'LEVEL_2_CLIENT_COMPANY'
 ORDER BY user_external_id  ;













