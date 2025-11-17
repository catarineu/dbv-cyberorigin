SELECT
	customer_id2, ccc1.name_to_show AS custname, 
	brand_id2,    ccc2.name_to_show AS brandname, superseded AS ss,
	count(*)--, string_agg(psi.cyber_id,', ') 
FROM
	product_Search_index psi
	LEFT OUTER JOIN cob_chain_company ccc1 ON (ccc1.user_external_id=psi.customer_id2)
	LEFT OUTER JOIN cob_chain_company ccc2 ON (ccc2.user_external_id=psi.brand_id2)
WHERE (customer_id2 <> 'customerId' OR customer_id2 IS NULL)
      AND superseded = FALSE 
GROUP BY GROUPING SETS ((customer_id2, ccc1.name_to_show, brand_id2, ccc2.name_to_show, ss),())
ORDER BY customer_id2, brand_id2, ss;

SELECT DISTINCT TYPE FROM cob_chain_company ccc; 

SELECT w.blockchain_name, psi.TYPE, count(*) AS num, sum(psi.data_field_pieces) AS pieces, sum(data_field_carats) AS carats
  FROM product_Search_index psi 
       LEFT OUTER JOIN workflows w ON (psi.TYPE=w.psi_type)
 WHERE superseded IS FALSE 
 GROUP BY psi."type", w.blockchain_name 
 ORDER BY blockchain_name;

 SELECT * FROM workflows w
   

--CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
--SELECT uuid_generate_v4();
-- Inserció massiva de brands/customers a partir d'una taula tmp proveïda per Gil
IINSERT INTO cob_chain_company ("type", id, optlock, created, name, state, user_external_id, level_1_client_company, level1client_company_id, name_to_show)
(SELECT 'LEVEL_2_CLIENT_COMPANY', uuid_generate_v4(), 0, now(), nom, 'CREATING', codi, 'e02e33ea-2f13-4146-8423-016b8cfc77fc', 'e02e33ea-2f13-4146-8423-016b8cfc77fc', nom
  FROM tmp_dades td 
 WHERE codi NOT IN (SELECT user_external_id FROM cob_chain_company ccc));

SELECT id, optlock, created, name, state, user_external_id, level_1_client_company, level1client_company_id, name_to_show
  FROM cob_chain_company ccc
 WHERE TYPE='LEVEL_2_CLIENT_COMPANY';



-- Estadística 1: Suma carats, pieces, lots POR CADA diamantaire
-- PARAMS: fecha_ini, fecha_fin, diaman
SELECT
	ccc.name AS diamantaire, psi.type,
	sum(psi.data_field_carats) AS sum_carats,
	round(100*sum(psi.data_field_carats)/sum(sum(psi.data_field_carats)) OVER (PARTITION BY ccc.name),1) || '%' AS pc,
	sum(psi.data_field_pieces) AS sum_pieces,
	round(100*sum(psi.data_field_pieces)/sum(sum(psi.data_field_pieces)) OVER (PARTITION BY ccc.name),1) || '%' AS pp,
	count(*) AS sum_lots,
	round(100*count(*)/sum(count(*)) OVER (PARTITION BY ccc.name),1) || '%' AS pl
FROM
	product_Search_index psi
	LEFT JOIN chain_member ccc ON (ccc.id=psi."owner")
GROUP BY ccc.name, psi.type
ORDER BY ccc.name, psi.type

SELECT * FROM chain_member cm

-- =============================================================================================
-- =============================================================================================
-- Estadística 2A: Suma carats, pieces, lots POR CADA diamantaire/RoughPurchase
-- PARAMS: fecha_ini, fecha_fin, 
SELECT
	cm.company_name AS diamantaire, psi.type, psi.customer_id2 || ' - ' || coalesce(ccc.name_to_show,'(unknown)') AS customer, srf.string_value AS origin,
	sum(psi.data_field_carats) AS sum_carats, 
	round(100*sum(psi.data_field_carats)/sum(sum(psi.data_field_carats)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.customer_id2),1) || '%' AS pc,
	sum(psi.data_field_pieces) AS sum_pieces,
	round(100*sum(psi.data_field_pieces)/sum(sum(psi.data_field_pieces)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.customer_id2),1) || '%' AS pp,
	count(*) AS sum_lots,
	round(100*count(*)/sum(count(*)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.customer_id2),1) || '%' AS pl
FROM
	product_Search_index psi
	INNER JOIN step_record sr ON sr.product_search_index_id = psi.id
	INNER JOIN step_record_fields srf ON srf.step_record_id = sr.id
	LEFT JOIN chain_member cm ON psi."owner" = cm.id
	LEFT JOIN cob_chain_company ccc ON ccc.user_external_id=psi.customer_id2 AND ccc."type"='LEVEL_2_CLIENT_COMPANY'
WHERE
	sr.role_name = 'RoughPurchase'
	AND srf."key"='Rough_Supplier'
	AND psi.customer_id2 <> 'customerId'
	AND psi."timestamp" BETWEEN '2023-01-01' AND '2024-01-01'
GROUP BY GROUPING SETS ((cm.company_name, psi.TYPE, psi.customer_id2, ccc.name_to_show, srf.string_value),())
ORDER BY cm.company_name, psi.TYPE, psi.customer_id2, ccc.name_to_show, srf.string_value

-- Estadística 2A2: Suma carats, pieces, lots POR CADA diamantaire/RoughPurchase
-- PARAMS: fecha_ini, fecha_fin, Workflow_type(1/all)
SELECT
	cm.company_name AS diamantaire, psi.type, psi.customer_id2 || ' - ' || coalesce(ccc.name_to_show,'(unknown)') AS customer,
	sum(psi.data_field_carats) AS sum_carats, 
	round(100*sum(psi.data_field_carats)/sum(sum(psi.data_field_carats)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.customer_id2),1) || '%' AS pc,
	sum(psi.data_field_pieces) AS sum_pieces,
	round(100*sum(psi.data_field_pieces)/sum(sum(psi.data_field_pieces)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.customer_id2),1) || '%' AS pp,
	count(*) AS sum_lots,
	round(100*count(*)/sum(count(*)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.customer_id2),1) || '%' AS pl
FROM
	product_Search_index psi
	INNER JOIN step_record sr ON sr.product_search_index_id = psi.id
	INNER JOIN step_record_fields srf ON srf.step_record_id = sr.id
	LEFT JOIN chain_member cm ON psi."owner" = cm.id
	LEFT JOIN cob_chain_company ccc ON ccc.user_external_id=psi.customer_id2 AND ccc."type"='LEVEL_2_CLIENT_COMPANY'
WHERE
	sr.role_name = 'RoughPurchase'
	AND srf."key"='Rough_Supplier'
	AND psi.customer_id2 <> 'customerId'
	AND psi."timestamp" BETWEEN '2023-01-01' AND '2024-10-01'
GROUP BY GROUPING SETS ((cm.company_name, psi.TYPE, psi.customer_id2, ccc.name_to_show),())
ORDER BY cm.company_name, psi.TYPE, psi.customer_id2, ccc.name_to_show

-- =============================================================================================
-- =============================================================================================
-- Estadística 2B: Suma carats, pieces, lots POR CADA diamantaire/RoughPurchase
SELECT
	cm.company_name AS diamantaire, psi.type, psi.brand_id2 || ' - ' || coalesce(ccc.name_to_show,'(unknown)') AS brand, 
	string_agg(DISTINCT srf.string_value, ', ' ORDER BY srf.string_value) AS origin,
	sum(psi.data_field_carats) AS sum_carats, 
	round(100*sum(psi.data_field_carats)/sum(sum(psi.data_field_carats)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.brand_id2),1) || '%' AS pc,
	sum(psi.data_field_pieces) AS sum_pieces,
	round(100*sum(psi.data_field_pieces)/sum(sum(psi.data_field_pieces)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.brand_id2),1) || '%' AS pp,
	count(*) AS sum_lots,
	round(100*count(*)/sum(count(*)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.brand_id2),1) || '%' AS pl
FROM
	product_Search_index psi
	INNER JOIN step_record sr ON sr.product_search_index_id = psi.id
	INNER JOIN step_record_fields srf ON srf.step_record_id = sr.id
	LEFT JOIN chain_member cm ON psi."owner" = cm.id
	LEFT JOIN cob_chain_company ccc ON ccc.user_external_id=psi.customer_id2 AND ccc."type"='LEVEL_2_CLIENT_COMPANY'
WHERE
	sr.role_name = 'RoughPurchase'
	AND psi.TYPE <> 'DIAMONDS'
	AND srf."key"='Rough_Supplier'
    AND psi."timestamp" BETWEEN '2023-01-01' AND '2024-01-25'
--	AND psi."timestamp" BETWEEN '2022-01-01' AND '2022-10-01'
GROUP BY GROUPING SETS ((cm.company_name, psi.TYPE, psi.brand_id2, ccc.name_to_show),())
ORDER BY cm.company_name, psi.TYPE, psi.brand_id2, ccc.name_to_show
	

SELECT LEFT(cyber_id, 20), role_name, KEY, string_agg(DISTINCT string_value, ', ' ORDER BY string_value) AS origin
  FROM step_record sr 
       LEFT OUTER JOIN step_record_fields srf ON srf.step_record_id = sr.id
WHERE sr.role_name = 'RoughPurchase'
	AND srf."key"='Rough_Supplier'
	AND bc_creation_date BETWEEN '2023-01-01' AND '2024-01-01'
    AND cyber_id ~'^CYR01-23-0553'
GROUP BY LEFT(cyber_id, 20), role_name, KEY
ORDER BY LEFT(cyber_id, 20)

-- CYR01-23-0553-260111

-- =============================================================================================
-- =============================================================================================
-- Estadística 3: Suma carats, pieces, lots POR CADA stakeholder
SELECT
	cm.company_name AS diamantaire, psi.type, psi.customer_id2 || ' - ' || coalesce(ccc.name_to_show,'(unknown)') AS client, srf.string_value AS origin,
	sum(psi.data_field_carats) AS sum_carats, 
	round(100*sum(psi.data_field_carats)/sum(sum(psi.data_field_carats)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.customer_id2),1) || '%' AS pc,
	sum(psi.data_field_pieces) AS sum_pieces,
	round(100*sum(psi.data_field_pieces)/sum(sum(psi.data_field_pieces)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.customer_id2),1) || '%' AS pp,
	count(*) AS sum_lots,
	round(100*count(*)/sum(count(*)) OVER (PARTITION BY cm.company_name, psi.TYPE, psi.customer_id2),1) || '%' AS pl
FROM
	product_Search_index psi
	INNER JOIN step_record sr ON sr.product_search_index_id = psi.id
	INNER JOIN step_record_fields srf ON srf.step_record_id = sr.id
	LEFT JOIN chain_member cm ON psi."owner" = cm.id
	LEFT JOIN cob_chain_company ccc ON ccc.user_external_id=psi.customer_id2 AND ccc."type"='LEVEL_2_CLIENT_COMPANY'
WHERE
	sr.role_name = 'RoughPurchase'
	AND srf."key"='Rough_Supplier'
	AND psi.customer_id2 <> 'customerId'
--	AND psi."timestamp" BETWEEN '2022-01-01' AND '2022-10-01'
GROUP BY GROUPING SETS ((cm.company_name, psi.TYPE, psi.customer_id2, ccc.name_to_show, srf.string_value),())
ORDER BY cm.company_name, psi.TYPE, psi.customer_id2, ccc.name_to_show, srf.string_value




