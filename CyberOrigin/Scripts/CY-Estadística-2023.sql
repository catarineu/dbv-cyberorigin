WITH stats AS (                                                                                                        
	SELECT                                                                                                         
        CAST(diamanter.id AS VARCHAR(255)) AS diamanterId,                                                         
		diamanter.user_external_id AS diamanterUserExternalId,                                                     
        diamanter.name_to_show AS diamanterNameToShow,                                                             
		diamanter.name AS diamanterName,
        CAST(custbrand.id AS VARCHAR(255)) AS custbrandId,                                                         
		custbrand.user_external_id AS custbrandUserExternalId,                                                     
		COALESCE(custbrand.name_to_show, '(unknown)') AS custbrandNameToShow,                                      
	    COALESCE(custbrand.name,'(unknown)') AS custbrandName,                                                     
		psi.type AS type, psi.cyber_id,
		UPPER(srf_suppl.string_value) AS roughSupplier,                                                                  
		UPPER(srf_orig_origin.string_value)  AS origin,                                                                    
		psi.lot_id AS cyberId,                                                                                     
		psi.data_field_carats AS carats,                                                                           
		psi.data_field_pieces AS pieces,                                                                           
		srf_carats.number_value AS RCarats,                                                                        
		srf_carats.number_value/sum(srf_carats.number_value) OVER                                                  
			(PARTITION BY diamanter.user_external_id, diamanter.name,                                              
			custbrand.user_external_id, COALESCE(custbrand.name_to_show, '(unknown)'),                             
			psi.type, psi.lot_id, psi.data_field_carats, psi.data_field_pieces) AS per1	                           
	FROM                                                                                                           
		cob_chain_company custbrand                                                                                
		LEFT JOIN cob_chain_company diamanter ON diamanter.type = 'LEVEL_1_CLIENT_COMPANY' AND diamanter.id = custbrand.level1client_company_id                                               
		LEFT JOIN cob_chain_company stkh      ON	stkh.type = 'STAKEHOLDER_COMPANY'       AND stkh.level1client_company_id = diamanter.id                                                    
		LEFT JOIN chain_member cm             ON	cm.id = stkh.chain_member_id                                                                     
		LEFT JOIN product_search_index psi    ON (custbrand.user_external_id = psi.customer_id2 OR custbrand.user_external_id = psi.brand_id2)                                                 
					                          AND psi.owner = cm.id     
		LEFT JOIN step_record sr 			     ON sr.product_search_index_id = psi.id AND sr.role_name IN ('RoughPurchase','Purchase', 'RoughPurchasePre')                                                                
		LEFT JOIN step_record_fields srf_suppl   ON srf_suppl.step_record_id  = sr.id AND srf_suppl.key  = 'Rough_Supplier'                                                                      
		LEFT JOIN step_record_fields srf_carats  ON srf_carats.step_record_id = sr.id AND srf_carats.key = 'Rough_Carats'
		LEFT JOIN step_record sr_orig            ON	sr_orig.product_search_index_id = psi.id AND sr_orig.in_batch_id = sr.out_batch_id    
		                         															 AND sr_orig.role_name IN ('RoughCertification', 'Parcel Assessment')
		LEFT JOIN step_record_fields srf_orig_origin ON	srf_orig_origin.step_record_id = sr_orig.id  AND srf_orig_origin.key = 'Origin'                                                                
		LEFT JOIN cob_chain_company customer   ON	customer.level1client_company_id = diamanter.id                                                    
											  AND customer.type = 'LEVEL_2_CLIENT_COMPANY'    AND customer.user_external_id = psi.customer_id2                                                   
	WHERE                                                                                                          
		custbrand.type = 'LEVEL_2_CLIENT_COMPANY'
		AND psi.superseded = FALSE 
	    AND ( CAST(CAST(:after  AS varchar(255)) AS timestamp) IS NULL OR psi.timestamp >= CAST(CAST(:after AS varchar(255) ) AS timestamp))
	    AND ( CAST(CAST(:before AS varchar(255)) AS timestamp) IS NULL OR psi.timestamp <= CAST(CAST(:before AS varchar(255) ) AS timestamp))                              
	    AND ( :custbrandId			   IS NULL OR UPPER(custbrand.user_external_id) = UPPER(CAST( :custbrandId AS varchar(255) ) ))                
	    AND ( :customerId 			   IS NULL OR UPPER(psi.customer_id2) = UPPER(CAST( :customerId AS varchar(255) ) ))                           
	    AND ( :diamanterUserExternalId IS NULL OR UPPER(diamanter.user_external_id) = UPPER(CAST( :diamanterUserExternalId AS varchar(255) ) ))    
	    AND ( :typeFlux                IS NULL OR UPPER(psi.type) = UPPER(CAST( :typeFlux AS varchar(255) ) ))                                   
    )
SELECT diamanterId, diamanterUserExternalId AS id, diamanterName, 
		diamanterNameToShow AS name,                                   
       custbrandId AS brandid, custbrandUserExternalId AS ext_id, custbrandName, 
       custbrandNameToShow,                                       
       type, roughsupplier, origin,                                                                                
       count(distinct cyberid) AS sumLots,                                                                         
       round(sum(carats*per1),2) AS sumCarats,                                                                     
       round(sum(pieces*per1),0) AS sumPieces,                                                                     
       round(100 * round(sum(carats*per1),2)/ sum(round(sum(carats*per1),2)) OVER (PARTITION BY diamanterId, type, custbrandId), 1) AS pctCarats,                                   
	   round(100 * round(sum(pieces*per1),0)/ sum(round(sum(pieces*per1),0)) OVER (PARTITION BY diamanterId, type, custbrandId), 1) AS pctPieces,                                   
	   round(100 * count(distinct cyberid)/ sum(count(distinct cyberid))     OVER (PARTITION BY diamanterId, type, custbrandId), 1) AS pctLots,
	   string_agg(cyber_id,',')
  FROM stats                                                                                                       
 GROUP BY  GROUPING SETS ((diamanterId, diamanterUserExternalId, diamanterName, diamanterNameToShow,                                        
 		   custbrandId, custbrandUserExternalId, custbrandName, custbrandNameToShow,                                            
 		   type, roughsupplier, origin),(TYPE), ())
ORDER BY   TYPE, diamanterNameToShow, custbrandId, custbrandNameToShow,  roughsupplier, origin;
 

-- Validació 1: Els subtotals que donen els GROUPING SETS per TYPE han de coincidir amb aquests resultats
SELECT
	superseded,
	OWNER,
	TYPE,
	count(*),
	sum(data_field_pieces) AS pieces,
	sum(data_field_carats) AS carats
	-- string_agg(cyber_id,',') 
FROM  product_search_index psi
WHERE psi.superseded = FALSE
      AND substring(cyber_id,1,4)<>'TEST'
GROUP BY	superseded,	OWNER,	TYPE
ORDER BY	OWNER,	TYPE, superseded


-- Validació 2: Agafem les KEY adeqüades dels STEPS correctes
-- 1) Generar llistat amb aquest SQL, 2) Marcar els camps escollits, 3) Validar que és correcte
SELECT
	psi."type", sr.role_name, srf.KEY, count(*) --, string_agg(COALESCE(psi.cyber_id,'--'),',') 
FROM
	step_record sr
	LEFT JOIN product_search_index psi ON (psi.id=sr.product_search_index_id)
	LEFT JOIN step_record_fields srf ON (srf.step_record_id = sr.id)
GROUP BY psi."type", sr.role_name, srf.KEY
ORDER BY psi."type", sr.role_name, srf.KEY;


-- ==================================================
-- Consultes auxiliars
-- ==================================================
SELECT
	psi."type", count(*)
FROM
	step_record sr
	LEFT JOIN product_search_index psi ON (psi.id=sr.product_search_index_id)
-- WHERE	role_name = 'RoughPurchase'
GROUP BY type;

SELECT
	psi."type", count(*)
FROM
	step_record sr
	LEFT JOIN product_search_index psi ON (psi.id=sr.product_search_index_id)
 WHERE	role_name IN ('RoughPurchase','Purchase', 'RoughPurchasePre')
GROUP BY type
ORDER BY TYPE;


SELECT
	psi."type", sr.role_name, srf.KEY, count(*) --, string_agg(COALESCE(psi.cyber_id,'--'),',') 
FROM
	step_record sr
	LEFT JOIN product_search_index psi ON (psi.id=sr.product_search_index_id)
	LEFT JOIN step_record_fields srf ON (srf.step_record_id = sr.id)
GROUP BY psi."type", sr.role_name, srf.KEY
ORDER BY psi."type", sr.role_name, srf.KEY;


SELECT
	psi."type", role_name, count(*)
FROM
	step_record sr
	LEFT JOIN product_search_index psi ON (psi.id=sr.product_search_index_id)
-- WHERE	role_name = 'RoughPurchase'
GROUP BY TYPE, role_name
ORDER BY TYPE, role_name ;





