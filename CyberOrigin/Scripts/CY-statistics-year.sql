/*
 * 	La Montre Hermès	DIAMONDS_FULL	DE BEERS SINGAPORE			MIXED		14	25.82	13475
	La Montre Hermès	DIAMONDS_FULL	OKAVANGO DIAMOND COMPANY	BOTSWANA	322	1976.49	772588
	La Montre Hermès	DIAMONDS_FULL	RIO TINTO					CANADA		8	5.20	243
	La Montre Hermès	DIAMONDS_FULL											344	2007.51	786306
	Raoul Guyot			DIAMONDS_FULL	DE BEERS SINGAPORE			MIXED		6	4.84	688
	Raoul Guyot			DIAMONDS_FULL	OKAVANGO DIAMOND COMPANY	BOTSWANA	155	1761.70	142475
	Raoul Guyot			DIAMONDS_FULL	RIO TINTO					CANADA		13	152.42	9752
	Raoul Guyot			DIAMONDS_FULL											174	1918.96	152915
 */

WITH stats AS (
	SELECT
		diamanter.user_external_id AS DId,
		diamanter.name AS DName,
		psi.customer_id AS CId,
		COALESCE(customer.name_to_show, '(unknown)') AS CName,
		psi.type AS TYPE,
		UPPER(srf.string_value) AS roughSupplier,
		UPPER(srf_orig.string_value) AS origin,
		psi.lot_id AS cyberId,
		psi.data_field_carats AS carats,
		psi.data_field_pieces AS pieces,
		srf_carats.number_value AS RCarats,
		srf_carats.number_value/sum(srf_carats.number_value) OVER 
			(PARTITION BY diamanter.user_external_id, diamanter.name, psi.customer_id, 
			COALESCE(customer.name_to_show, '(unknown)'), psi.type,	
			psi.lot_id, psi.data_field_carats, psi.data_field_pieces, psi.data_field_pieces) AS per1
	FROM
		product_search_index psi 
		INNER JOIN step_record sr 		  		 ON sr.product_search_index_id = psi.id
		INNER JOIN step_record_fields srf 		 ON srf.step_record_id = sr.id
		INNER JOIN step_record_fields srf_carats ON	srf_carats.step_record_id = sr.id 		 AND srf_carats."key" = 'Rough_Carats'
		INNER JOIN step_record sr_orig 			 ON	sr_orig.product_search_index_id = psi.id AND sr_orig.in_batch_id = sr.out_batch_id
		INNER JOIN step_record_fields srf_orig   ON	srf_orig.step_record_id = sr_orig.id
		INNER JOIN step_record_fields srf_orig_carats ON srf_orig_carats.step_record_id = sr_orig.id AND srf_orig_carats."key" = 'Rough_Carats'
		LEFT JOIN chain_member cm 				 ON	psi.owner = cm.id
		LEFT JOIN cob_chain_company stkh		 ON	stkh.chain_member_id = cm.id AND stkh.type = 'STAKEHOLDER_COMPANY'
		LEFT JOIN cob_chain_company diamanter	 ON	diamanter.id = stkh.level1client_company_id	AND diamanter.type = 'LEVEL_1_CLIENT_COMPANY'
		LEFT JOIN cob_chain_company customer	 ON	customer.level1client_company_id = diamanter.id	AND customer.type = 'LEVEL_2_CLIENT_COMPANY' AND customer.user_external_id = psi.customer_id
	WHERE
		sr.role_name = 'RoughPurchase'
		AND srf.key = 'Rough_Supplier'
		AND sr_orig.role_name = 'RoughCertification'
		AND srf_orig.key = 'Origin'
		AND psi."timestamp" BETWEEN '2022-01-01' AND '2023-01-01'
		)
SELECT cname, TYPE, roughsupplier, origin, count(cyberid), 
	   round(sum(carats*per1),2) AS c1, round(sum(pieces*per1),0) AS p1
  FROM stats
GROUP BY GROUPING SETS ((cname, TYPE, roughsupplier, origin),(cname, TYPE))
ORDER BY cname, roughsupplier, origin;

-- =============================================================================================================
-- =============================================================================================================

WITH stats AS (
	SELECT
		diamanter.user_external_id AS DId,
		diamanter.name AS DName,
		psi.customer_id AS CId,
		COALESCE(customer.name_to_show, '(unknown)') AS CName,
		psi.type AS TYPE,
		UPPER(srf.string_value) AS roughSupplier,
		UPPER(srf_orig.string_value) AS origin,
		psi.lot_id AS cyberId,
		psi.data_field_carats AS carats,
		psi.data_field_pieces AS pieces,
		srf_carats.number_value AS RCarats,
		srf_carats.number_value/sum(srf_carats.number_value) OVER 
			(PARTITION BY diamanter.user_external_id, diamanter.name, psi.customer_id, 
			COALESCE(customer.name_to_show, '(unknown)'), psi.type,	
			psi.lot_id, psi.data_field_carats, psi.data_field_pieces, psi.data_field_pieces) AS per1
	FROM
		product_search_index psi 
		INNER JOIN step_record sr 		  		 ON sr.product_search_index_id = psi.id
		INNER JOIN step_record_fields srf 		 ON srf.step_record_id = sr.id
		INNER JOIN step_record_fields srf_carats ON	srf_carats.step_record_id = sr.id 		 AND srf_carats."key" = 'Rough_Carats'
		INNER JOIN step_record sr_orig 			 ON	sr_orig.product_search_index_id = psi.id AND sr_orig.in_batch_id = sr.out_batch_id
		INNER JOIN step_record_fields srf_orig   ON	srf_orig.step_record_id = sr_orig.id
		INNER JOIN step_record_fields srf_orig_carats ON srf_orig_carats.step_record_id = sr_orig.id AND srf_orig_carats."key" = 'Rough_Carats'
		LEFT JOIN chain_member cm 				 ON	psi.owner = cm.id
		LEFT JOIN cob_chain_company stkh		 ON	stkh.chain_member_id = cm.id AND stkh.type = 'STAKEHOLDER_COMPANY'
		LEFT JOIN cob_chain_company diamanter	 ON	diamanter.id = stkh.level1client_company_id	AND diamanter.type = 'LEVEL_1_CLIENT_COMPANY'
		LEFT JOIN cob_chain_company customer	 ON	customer.level1client_company_id = diamanter.id	AND customer.type = 'LEVEL_2_CLIENT_COMPANY' AND customer.user_external_id = psi.customer_id
	WHERE
		sr.role_name = 'RoughPurchase'
		AND srf.key = 'Rough_Supplier'
		AND sr_orig.role_name = 'RoughCertification'
		AND srf_orig.key = 'Origin'
		AND psi."timestamp" BETWEEN '2022-01-01' AND '2023-01-01'
		)
SELECT cname, TYPE, roughsupplier, origin, count(cyberid), 
	   round(sum(carats*per1),2) AS c1, round(sum(pieces*per1),0) AS p1
  FROM stats
GROUP BY GROUPING SETS ((cname, TYPE, roughsupplier, origin),(cname, TYPE))
ORDER BY cname, roughsupplier, origin;


-- =============================================================================================================
-- =============================================================================================================

SELECT
	CAST(diamanter.id AS VARCHAR(255)) AS diamanterId,
	diamanter.user_external_id AS diamanterUserExternalId,
	diamanter.name_to_show AS diamanterNameToShow,
	diamanter.name AS diamanterName,
	CAST(customer.id AS VARCHAR(255)) AS customerId,
	psi.customer_id AS customerUserExternalId,
	COALESCE(customer.name_to_show, '(unknown)') AS customerNameToShow,
	COALESCE(customer.name, '(unknown)') AS customerName,
	psi.type AS TYPE,
	UPPER(srf.string_value) AS roughSupplier,
	UPPER(srf_orig.string_value) AS origin,
	psi.lot_id AS cyberId,
	psi.data_field_carats AS carats,
	psi.data_field_pieces AS pieces,
	sr.out_batch_id,
	sr_orig.out_batch_id,
	srf_carats."key",
	srf_carats.number_value AS RoughPurchase_carats,
	srf_orig_carats."key",
	srf_orig_carats.number_value AS RoughCertification_carats,
	CASE
		WHEN psi.cyber_id IN (
			'CYR01-21-0098-196263', 'CYR01-21-0100-196319', 'CYR01-22-0508-198752', 'CYR01-22-0508-198755'
		) THEN TRUE
		ELSE FALSE
	END AS filas_duplicadas
FROM
	product_search_index psi 
	INNER JOIN step_record sr 		  		 ON sr.product_search_index_id = psi.id
	INNER JOIN step_record_fields srf 		 ON srf.step_record_id = sr.id
	INNER JOIN step_record_fields srf_carats ON	srf_carats.step_record_id = sr.id 		 AND srf_carats."key" = 'Rough_Carats'
	INNER JOIN step_record sr_orig 			 ON	sr_orig.product_search_index_id = psi.id AND sr_orig.in_batch_id = sr.out_batch_id
	INNER JOIN step_record_fields srf_orig   ON	srf_orig.step_record_id = sr_orig.id
	INNER JOIN step_record_fields srf_orig_carats ON srf_orig_carats.step_record_id = sr_orig.id AND srf_orig_carats."key" = 'Rough_Carats'
	LEFT JOIN chain_member cm 				 ON	psi.owner = cm.id
	LEFT JOIN cob_chain_company stkh		 ON	stkh.chain_member_id = cm.id AND stkh.type = 'STAKEHOLDER_COMPANY'
	LEFT JOIN cob_chain_company diamanter	 ON	diamanter.id = stkh.level1client_company_id	AND diamanter.type = 'LEVEL_1_CLIENT_COMPANY'
	LEFT JOIN cob_chain_company customer	 ON	customer.level1client_company_id = diamanter.id	AND customer.type = 'LEVEL_2_CLIENT_COMPANY' AND customer.user_external_id = psi.customer_id
WHERE
	sr.role_name = 'RoughPurchase'
	AND srf.key = 'Rough_Supplier'
	AND sr_orig.role_name = 'RoughCertification'
	AND srf_orig.key = 'Origin'
	-- and psi.cyber_id in ('CYR01-21-0098-196263', 'CYR01-21-0100-196319', 'CYR01-22-0508-198752', 'CYR01-22-0508-198755')
	AND psi."timestamp" BETWEEN '2022-01-01' AND '2023-01-01'
ORDER BY
	CASE
		WHEN psi.cyber_id IN (
			'CYR01-21-0098-196263', 'CYR01-21-0100-196319', 'CYR01-22-0508-198752', 'CYR01-22-0508-198755'
		) THEN TRUE
		ELSE FALSE
	END DESC,
	psi.lot_id	