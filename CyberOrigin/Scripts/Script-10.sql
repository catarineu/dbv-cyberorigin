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
AND (CAST(CAST(:after AS varchar(255)) AS timestamp) IS NULL OR psi.timestamp >= '2024-01-01'::timestamp)
AND (CAST(CAST(:before AS varchar(255)) AS timestamp) IS NULL  OR psi.timestamp <= '2024-05-09'::timestamp)
--  AND (:customerId IS NULL OR UPPER(psi.customer_id2) = UPPER(CAST(:customerId AS varchar(255))))
--  AND (:brandId IS NULL OR UPPER(psi.brand_id2) = UPPER(CAST(:brandId AS varchar(255))))
--  AND (:diamanterUserExternalId IS NULL OR UPPER(diamanter.user_external_id) = UPPER(CAST(:diamanterUserExternalId AS varchar(255))))
--  AND (:typeFlux IS NULL OR UPPER(psi.type) = UPPER(CAST(:typeFlux AS varchar(255))))
GROUP BY GROUPING SETS ((cast(diamanter.id AS varchar(255)),
 diamanter.user_external_id,
 diamanter.name_to_show,
 diamanter.name,
 cast(customer.id AS varchar(255)),
 psi.customer_id,
 coalesce(customer.name_to_show, '(unknown)'),
 coalesce(customer.name, '(unknown)'),
 psi.TYPE),())
ORDER BY diamanter.name_to_show,
 psi.TYPE,
 psi.customer_id,
 coalesce(customer.name_to_show, '(unknown)')


SELECT * FROM product_search_index psi LIMIT 5;


SELECT id, company_name, "uuid" FROM chain_member cm ORDER BY company_name ;
SELECT TYPE, id, name, user_external_id, chain_member_id, level1client_company_id, name_to_show FROM cob_chain_company ccc WHERE name ~* 'gil' ORDER BY type;

-- SELECT 2
SELECT coalesce(sum(psi.data_field_carats), 0) AS sumCarats,
	   coalesce(sum(psi.data_field_pieces), 0) AS sumPieces, 
	   count(*) AS sumLots
FROM product_search_index psi
    LEFT JOIN chain_member cm ON psi.owner = cm.id
    LEFT JOIN cob_chain_company stkh ON stkh.chain_member_id = cm.id        AND stkh.type = 'STAKEHOLDER_COMPANY'
    LEFT JOIN cob_chain_company diamanter ON diamanter.id = stkh.level1client_company_id   AND diamanter.type = 'LEVEL_1_CLIENT_COMPANY'
    LEFT JOIN cob_chain_company customer ON customer.level_1_client_company = diamanter.id AND  customer.type = 'LEVEL_2_CLIENT_COMPANY' AND customer.user_external_id = psi.customer_id
WHERE UPPER(psi.cyber_id) NOT LIKE '%TEST%'
AND (CAST(CAST(:after AS varchar(255)) AS timestamp) IS NULL OR psi.timestamp >= '2024-01-01'::timestamp)
AND (CAST(CAST(:before AS varchar(255)) AS timestamp) IS NULL  OR psi.timestamp <= '2024-05-09'::timestamp)
--AND (:customerId IS NULL    OR UPPER(psi.customer_id2) = UPPER(CAST(:customerId AS varchar(255))))
--AND (:brandId IS NULL       OR UPPER(psi.brand_id2) = UPPER(CAST(:brandId AS varchar(255))))
--AND (:diamanterUserExternalId IS NULL   OR UPPER(diamanter.user_external_id) = UPPER(CAST(:diamanterUserExternalId AS varchar(255))))
--AND (:typeFlux IS NULL      OR UPPER(psi.type) = UPPER(CAST(:typeFlux AS varchar(255))))

   
 
 