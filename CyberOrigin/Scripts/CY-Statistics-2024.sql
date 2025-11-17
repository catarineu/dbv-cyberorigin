-- === E1. TOTAL PER CLIENT v1 =================================================================
-- =============================================================================================
SELECT 					                                                                                
	cast(diamanter.id AS VARCHAR(255)) 				AS diamanterId,                                        
	diamanter.user_external_id  	   				AS diamanterUserExternalId,                            
	diamanter.name_to_show 			   				AS diamanterNameToShow,                                
	diamanter.name		 			  				AS diamanterName,                                      		
	cast(customer.id		AS VARCHAR(255))		AS customerId,                                         
	psi.customer_id  								AS customerUserExternalId,                    		   
	coalesce(customer.name_to_show,'(unknown)')		AS customerNameToShow,                                 
	coalesce(customer.name,'(unknown)')	 			AS customerName,                                       
	psi.type									    AS type,	                                           
	sum(psi.data_field_carats) 						AS sumCarats,                                          
	round(100*sum(psi.data_field_carats)/sum(sum(psi.data_field_carats))                                   
			OVER (PARTITION BY diamanter.name_to_show, psi.TYPE, psi.customer_id),1)  AS pctCarats,        
	sum(psi.data_field_pieces) 														  AS sumPieces,        
	round(100*sum(psi.data_field_pieces)/sum(sum(psi.data_field_pieces))                                   
			OVER (PARTITION BY diamanter.name_to_show, psi.TYPE, psi.customer_id),1)  AS pctPieces,        
	count(*) 																		  AS sumLots,		   
	round(100*count(*)/sum(count(*))                                                                       
			OVER (PARTITION BY diamanter.name_to_show, psi.TYPE, psi.customer_id),1)  AS pctLots           
 FROM                                                                                                    
	product_search_index psi                                                                               		
	LEFT JOIN chain_member cm ON psi.owner = cm.id                                                         
	LEFT JOIN cob_chain_company stkh		                                                               
		ON stkh.chain_member_id = cm.id 					                               
			and stkh.type='STAKEHOLDER_COMPANY'                                                            
	LEFT JOIN cob_chain_company diamanter 	                                                               
		ON diamanter.id = stkh.level1client_company_id                                         
			and diamanter.type = 'LEVEL_1_CLIENT_COMPANY'                                               
	LEFT JOIN cob_chain_company customer 	                                                               
		ON customer.level_1_client_company 	= diamanter.id  			                                   
			and customer.type = 'LEVEL_2_CLIENT_COMPANY'	                                           
			and customer.user_external_id = psi.customer_id                                                
 WHERE                                                                                                   		
  (CAST(CAST(:after 	AS varchar(255) ) AS timestamp) is null										       
     or psi.timestamp >= CAST(CAST(:after   	AS varchar(255) )	AS timestamp) ) 					   
  AND (CAST(CAST(:before 	AS varchar(255) ) AS timestamp) is null										   
     or psi.timestamp <= CAST(CAST(:before   	AS varchar(255) )	AS timestamp) ) 				   	   
  AND (:customerId is null 																			   
	   or UPPER(psi.customer_id2)	     		= UPPER(CAST( :customerId AS varchar(255) ) )) 			   
  AND (:brandId is null 																			   	   
	   or UPPER(psi.brand_id2)	     			= UPPER(CAST( :brandId AS varchar(255) ) )) 			   
  AND (:diamanterUserExternalId is null 																   
	   or UPPER(diamanter.user_external_id)	    = UPPER(CAST( :diamanterUserExternalId AS varchar(255) ) ))
  AND (:typeFlux is null 																   				   
	   or UPPER(psi.type)	    = UPPER(CAST( :typeFlux AS varchar(255) ) ))							   
  AND UPPER(psi.cyber_id)	    not like '%TEST%'														   
 GROUP BY 										                           							   
	cast(diamanter.id AS VARCHAR(255)),				                                                       
	diamanter.user_external_id, 	   				                                                       
	diamanter.name_to_show,			   				                                                       
	diamanter.name,		 			  				                                                       		
	cast(customer.id AS VARCHAR(255)),		                                                       
	psi.customer_id, 								                                                       
	coalesce(customer.name_to_show,'(unknown)'),
	coalesce(customer.name,'(unknown)'),
	psi.type									             	                                           
 ORDER BY diamanter.name_to_show, psi.TYPE, psi.customer_id, coalesce(customer.name_to_show,'(unknown)') 

-- === E2. TOTAL PER CLIENT v2 =================================================================
-- =============================================================================================
  SELECT 					                                                                               			
	coalesce( sum( psi.data_field_carats  ), 0) AS sumCarats,                                              
	coalesce( sum( psi.data_field_pieces  ), 0)	AS sumPieces,        				                       
	count(*) AS sumLots		                                                                               
 FROM                                                                                                    
	product_search_index psi                                                                               			
	LEFT JOIN chain_member cm                                                                              
		ON psi.owner = cm.id                                                                               
	LEFT JOIN cob_chain_company stkh		                                                               
		ON stkh.chain_member_id = cm.id 	                 				                               
			AND stkh.type='STAKEHOLDER_COMPANY'                                                            
	LEFT JOIN cob_chain_company diamanter 	                                                               
		ON diamanter.id  = stkh.level1client_company_id                                                    
			AND diamanter.type = 'LEVEL_1_CLIENT_COMPANY'                                                  
	LEFT JOIN cob_chain_company customer 	                                                               
		ON customer.level_1_client_company = diamanter.id        			                               
			AND customer.type = 'LEVEL_2_CLIENT_COMPANY'	                                               
			AND customer.user_external_id = psi.customer_id                                                
 WHERE                                                                                                   
  (CAST(CAST(:after 	AS varchar(255) ) AS timestamp) is null										       
     or psi.timestamp >= CAST(CAST(:after  	AS varchar(255) )	AS timestamp) ) 					   
  AND (CAST(CAST(:before 	AS varchar(255) ) AS timestamp) is null										   
     or psi.timestamp <= CAST(CAST(:before   	AS varchar(255) )	AS timestamp) ) 				   	   
  AND (:customerId IS NULL 																			   
	   or UPPER(psi.customer_id2) = UPPER(CAST( :customerId AS varchar(255) ) )) 			               
  AND (:brandId IS NULL 																			   	   
	   or UPPER(psi.brand_id2) = UPPER(CAST( :brandId AS varchar(255) ) )) 			                       
  AND (:diamanterUserExternalId IS NULL 																   
	   or UPPER(diamanter.user_external_id) = UPPER(CAST( :diamanterUserExternalId AS varchar(255) ) ))    
  AND (:typeFlux IS NULL 																   				   
	   OR UPPER(psi.type) = UPPER(CAST( :typeFlux AS varchar(255) ) ))							           
  AND UPPER(psi.cyber_id)	    not like '%TEST%'					

-- === E3. TOTAL PER CLIENT AMB DETALL =========================================================
-- =============================================================================================
@set AFTER='2019-01-01'
@set BEFORE='2025-01-01'

SELECT cyber_id
  FROM cyber_id ci 
 WHERE cyber_id_group_id = (SELECT id FROM cyber_id ci2 WHERE cyber_id='CYR01-23-0511-245732-R04') 
   AND cancelled = FALSE 
	 
-- CYR01-24-0012-295649-R01
-- CYR01-23-0511-245732P18-R02
   

SELECT * FROM cyber_id ci WHERE deleted=FALSE AND cyber_id  NOT IN 
 (SELECT lot_id FROM product_search_index psi WHERE superseded=false);

SELECT * FROM product_search_index psi WHERE cyber_id ~'CYR01-23-0528-251578'; 


SELECT ci.cyber_id, ci.deleted
  FROM cyber_id ci 
 WHERE ci.deleted =FALSE 
   AND ci.cyber_id='CYR01-21-0098-196263-R02'
   ORDER BY ci.cyber_id ;

SELECT psi.cyber_id, psi.lot_id, superseded
  FROM product_search_index psi  
 WHERE LEFT(psi.lot_id,20)~LEFT('CYR01-23-0512-245734P17-R02',20);

WITH familia AS (
    -- Calculem una sola vegada l'última versió (deleted=false) dels TOTS els cyber_ids de STEP_RECORD
	SELECT DISTINCT substring(sr.cyber_id FROM '^(.*?-R[0-9]+[0-9])') AS cyber_id, cyber_id_group_id
	  FROM step_record sr
	       LEFT OUTER JOIN cyber_id ci ON (ci.cyber_id=substring(sr.cyber_id FROM '^(.*?-R[0-9]+[0-9])') AND ci.deleted = FALSE)
)	 
SELECT psi.cyber_id, psi.TYPE, psi.brand_id2 AS brand, psi.customer_id2 AS customer, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats,
       string_agg(DISTINCT srf1.string_value, ', ' ORDER BY srf1.string_value) AS origens,
       string_agg(DISTINCT srf2.string_value, ', ' ORDER BY srf2.string_value) AS providers,
       string_agg(COALESCE(sr1.cyber_id,''),',') AS c1
  FROM product_search_index psi
       LEFT OUTER JOIN step_record sr1 
                    ON (-- Que l'STEP_RECORD sigui d'un pas del meu CyberID
                        LEFT(sr1.cyber_id,20)=LEFT(psi.cyber_id,20)
                        -- Que sigui membre de l'última versió
                        AND substring(sr1.cyber_id FROM '^(.*?-R[0-9]+[0-9])') IN (SELECT cyber_id FROM familia)
                        -- i només m'interessa un PAS
					    AND sr1.role_name IN ('RoughCertification', 'Parcel Assessment')) -- psi.cyber_id=LEFT(sr2.cyber_id,20)
       LEFT OUTER JOIN step_record sr2 
                    ON (-- Que l'STEP_RECORD sigui d'un pas del meu CyberID
                        LEFT(sr2.cyber_id,20)=LEFT(psi.cyber_id,20)
           			    -- Que sigui membre de l'última versió
                        AND substring(sr2.cyber_id FROM '^(.*?-R[0-9]+[0-9])') IN (SELECT cyber_id FROM familia)
                        -- i només m'interessa un PAS
					    AND sr2.role_name IN ('RoughPurchase', 'RoughPurchasePre'))
       LEFT OUTER JOIN step_record_fields srf1 ON srf1.step_record_id=sr1.id AND srf1.key = 'Origin'
       LEFT OUTER JOIN step_record_fields srf2 ON srf2.step_record_id=sr2.id AND srf2.key = 'Rough_Supplier'
       LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
 WHERE psi.superseded = FALSE    -- Actius
   AND psi.cyber_id ~ '^CYR01-'  -- No són TEST ni errors
   AND ci.deleted   = FALSE AND ci.cancelled = FALSE -- Que el PARE NO estigui anulat tampoc
 GROUP BY psi.cyber_id, psi.TYPE, psi.brand_id2, psi.customer_id2, psi.data_field_pieces, psi.data_field_carats

SELECT cyber_id, *
  FROM step_record sr
 WHERE sr.cyber_id ~'CYR01-21-0098-196264'
 
 
 
 
-- ORIGENS INDIRECTES 
SELECT psi.cyber_id, psi.TYPE, psi.brand_id2 AS brand, psi.customer_id2 AS customer, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats,
       string_agg(DISTINCT srf1.string_value, ', ' ORDER BY srf1.string_value) AS origens,
       string_agg(DISTINCT srf2.string_value, ', ' ORDER BY srf2.string_value) AS providers
  FROM product_search_index psi
       LEFT OUTER JOIN step_record sr1 
                    ON sr1.cyber_id ~ ( SELECT string_agg('^'||cyber_id,'|' ORDER BY cyber_id) AS cybs
										  FROM cyber_id ci 
										 WHERE cyber_id_group_id = (SELECT id FROM cyber_id ci2 WHERE cyber_id='CYR01-23-0511-245732-R04') 
										   AND cancelled = FALSE )
					   AND sr1.role_name IN ('RoughCertification', 'Parcel Assessment') -- psi.cyber_id=LEFT(sr2.cyber_id,20)
       LEFT OUTER JOIN step_record sr2 
       				ON sr2.cyber_id ~ ( SELECT string_agg('^'||cyber_id,'|' ORDER BY cyber_id) AS cybs
										  FROM cyber_id ci 
										 WHERE cyber_id_group_id = (SELECT id FROM cyber_id ci2 WHERE cyber_id='CYR01-23-0511-245732-R04') 
										   AND cancelled = FALSE )
           			   AND sr2.role_name IN ('RoughPurchase', 'RoughPurchasePre')
       LEFT OUTER JOIN step_record_fields srf1 ON srf1.step_record_id=sr1.id AND srf1.key = 'Origin'
       LEFT OUTER JOIN step_record_fields srf2 ON srf2.step_record_id=sr2.id AND srf2.key = 'Rough_Supplier'
       LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
 WHERE psi.superseded = FALSE    -- Actius
   AND psi.cyber_id ~ '^CYR01-'  -- No són TEST ni errors
   AND ci.deleted   = FALSE AND ci.cancelled = FALSE -- NO anulats
 GROUP BY psi.cyber_id, psi.TYPE, psi.brand_id2, psi.customer_id2, psi.data_field_pieces, psi.data_field_carats
 
         
SELECT * FROM cyber_id ci WHERE cyber_id ~ 'CYR01-21-0104-197420'

SELECT * FROM step_record
WHERE 'CYR01-22-0620-214506-R02'=LEFT(cyber_id,24)

SELECT * FROM step_record_fields srf WHERE step_record_id IN (15506, 15507, 23637, 30454, 32974) ORDER BY step_record_id, key

-- ===================================================================================================================
-- ===================================================================================================================
-- DIAMONDS_FULL -- Estadística bona 
SELECT * FROM cyber_id LIMIT 5;

	SELECT psi.cyber_id, psi.lot_id, psi.TYPE, psi.brand_id2 AS brand, psi.customer_id2 AS customer, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats,
		   string_agg(DISTINCT srf1.string_value, ', ' ORDER BY srf1.string_value) AS origens,
		   string_agg(DISTINCT srf2.string_value, ', ' ORDER BY srf2.string_value) AS providers
	  FROM product_search_index psi
	   	   LEFT OUTER JOIN step_record sr1 			 ON psi.lot_id=LEFT(sr1.cyber_id,24) AND sr1.role_name  IN ('RoughCertification', 'Parcel Assessment')
	   	   LEFT OUTER JOIN step_record sr2 			 ON psi.lot_id=LEFT(sr2.cyber_id,24) AND sr2.role_name  IN ('RoughPurchase', 'RoughPurchasePre')
	   	   LEFT OUTER JOIN step_record_fields srf1   ON srf1.step_record_id=sr1.id AND srf1.key = 'Origin'
	   	   LEFT OUTER JOIN step_record_fields srf2   ON srf2.step_record_id=sr2.id AND srf2.key = 'Rough_Supplier'
           LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
	 WHERE psi.superseded = FALSE 
	   AND psi.cyber_id ~ '^CYR01-'
	   AND ci.deleted   = FALSE AND ci.cancelled = FALSE -- NO anulats
	 GROUP BY psi.cyber_id, psi.lot_id, psi.TYPE, psi.brand_id2, psi.customer_id2, psi.data_field_pieces, psi.data_field_carats, sr1.role_name, srf1."key", sr2.role_name, srf2."key"
	 ORDER BY psi.TYPE, psi.cyber_id, sr1.role_name, srf1.KEY  
  
	SELECT psi.cyber_id, psi.lot_id, psi.TYPE, psi.brand_id2 AS brand, psi.customer_id2 AS customer, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats,
		   string_agg(DISTINCT srf1.string_value, ', ' ORDER BY srf1.string_value) AS origens,
		   string_agg(DISTINCT srf2.string_value, ', ' ORDER BY srf2.string_value) AS providers
	  FROM product_search_index psi
	   	   LEFT OUTER JOIN step_record sr1 			 ON sr1.cyber_id=(SELECT cyber_id FROM cyber_id cy11 WHERE cy11.id=(SELECT cyber_id_group_id FROM cyber_id cy21 WHERE LEFT(cy21.cyber_id,24)=psi.lot_id)) AND sr1.role_name  IN ('RoughCertification', 'Parcel Assessment')
	   	   LEFT OUTER JOIN step_record sr2 			 ON sr2.cyber_id=(SELECT cyber_id FROM cyber_id cy12 WHERE cy12.id=(SELECT cyber_id_group_id FROM cyber_id cy22 WHERE LEFT(cy22.cyber_id,24)=psi.lot_id)) AND sr2.role_name  IN ('RoughPurchase', 'RoughPurchasePre')
	   	   LEFT OUTER JOIN step_record_fields srf1   ON srf1.step_record_id=sr1.id AND srf1.key = 'Origin'
	   	   LEFT OUTER JOIN step_record_fields srf2   ON srf2.step_record_id=sr2.id AND srf2.key = 'Rough_Supplier'
           LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
	 WHERE psi.superseded = FALSE 
	   AND psi.cyber_id ~ '^CYR01-'
	   AND ci.deleted   = FALSE AND ci.cancelled = FALSE -- NO anulats
	 GROUP BY psi.cyber_id, psi.lot_id, psi.TYPE, psi.brand_id2, psi.customer_id2, psi.data_field_pieces, psi.data_field_carats, sr1.role_name, srf1."key", sr2.role_name, srf2."key"
	 ORDER BY psi.TYPE, psi.cyber_id, sr1.role_name, srf1.KEY  
  	 
	 
	 (SELECT cyber_id FROM cyber_id WHERE LEFT(cyber_group_id,24)=psi.lot_id)
	 
	 
WITH stats_list AS (
	SELECT psi.cyber_id, psi.TYPE, psi.brand_id2 AS brand, psi.customer_id2 AS customer, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats,
		   string_agg(DISTINCT srf1.string_value, ', ' ORDER BY srf1.string_value) AS origens,
		   string_agg(DISTINCT srf2.string_value, ', ' ORDER BY srf2.string_value) AS providers
	  FROM product_search_index psi
	   	   LEFT OUTER JOIN step_record sr1 			 ON psi.cyber_id=LEFT(sr1.cyber_id,20) AND sr1.role_name  IN ('RoughCertification', 'Parcel Assessment')
	   	   LEFT OUTER JOIN step_record sr2 			 ON psi.cyber_id=LEFT(sr2.cyber_id,20) AND sr2.role_name  IN ('RoughPurchase', 'RoughPurchasePre')
	   	   LEFT OUTER JOIN step_record_fields srf1   ON srf1.step_record_id=sr1.id AND srf1.key = 'Origin'
	   	   LEFT OUTER JOIN step_record_fields srf2   ON srf2.step_record_id=sr2.id AND srf2.key = 'Rough_Supplier'
	 WHERE psi.superseded = FALSE 
	   AND psi.cyber_id ~ '^CYR01-'
	 GROUP BY psi.cyber_id, psi.TYPE, psi.brand_id2, psi.customer_id2, psi.data_field_pieces, psi.data_field_carats, sr1.role_name, srf1."key", sr2.role_name, srf2."key"
	 ORDER BY psi.cyber_id, sr1.role_name, srf1.KEY
)
SELECT substring(stats.cyber_id,7,2) AS year, stats.type, customer AS cust, ccc1.name_to_show AS custname, brand, ccc2.name_to_show AS brandname,
	   origens, providers,
	   count(cyber_id) AS lots, sum(pieces) AS pieces, sum(carats) AS carats,
	   string_agg(stats.cyber_id, ', ' ORDER BY stats.cyber_id) AS cyber_ids
  FROM stats_list AS stats
   	   LEFT JOIN cob_chain_company ccc1 ON  ccc1.level1client_company_id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'
   	    		  AND ccc1.type = 'LEVEL_2_CLIENT_COMPANY' AND ccc1.user_external_id = stats.customer
   	   LEFT JOIN cob_chain_company ccc2 ON  ccc2.level1client_company_id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'
   	    		  AND ccc2.type = 'LEVEL_2_CLIENT_COMPANY' AND ccc2.user_external_id = stats.brand
 WHERE stats.cyber_id ~ '^CYR01-'
   AND customer='00132' OR brand='00132' -- RAOUL GUIYOT
 GROUP BY GROUPING SETS ((substring(stats.cyber_id,7,2), stats.type, customer, ccc1.name_to_show, brand, ccc2.name_to_show, origens, providers),
 						 (substring(stats.cyber_id,7,2), stats.type),
 						 (substring(stats.cyber_id,7,2)),
 						 ())
 ORDER BY substring(stats.cyber_id,7,2), stats.type, customer, brand, ROW_NUMBER() OVER (PARTITION BY stats.type, customer, brand ORDER BY count(cyber_id) DESC)


 
-- Tipus de lots + count + LIST(cyber_id)
SELECT superseded, left(cyber_id,6), count(*)
  FROM product_search_index psi 
 GROUP BY superseded, left(cyber_id,6)
-- WHERE psi.superseded = FALSE AND psi.cyber_id ~ '^CYR01-'


-- Cancel/Delete son redundants (eliminar un d'ells)
-- Cancel/Delete NULL = FALSE
-- Superseded -> Cancel PERO Cancel NO-> superseeded
-- 
 SELECT CASE WHEN (GROUPING(group_record_type) = 1) THEN '→️ ' ELSE '' END || TYPE AS type,
 		group_record_type,  count(DISTINCT psi.cyber_id), count(DISTINCT ci.cyber_id), 
 		sum(CASE WHEN ci.cancelled IS NULL OR ci.cancelled=FALSE THEN 1 ELSE 0 END) AS cansum,
 		sum(CASE WHEN ci.deleted   IS NULL OR ci.deleted=FALSE   THEN 1 ELSE 0 END) AS delsum,
 		string_agg(DISTINCT psi.cyber_id,', ' ORDER BY psi.cyber_id) zaqw 2 
   FROM product_search_index psi
        LEFT OUTER JOIN cyber_id ci ON (ci.cyber_id=psi.lot_id)
  WHERE superseded = FALSE AND psi.cyber_id ~ '^CYR01-'
  GROUP BY GROUPING SETS ((psi.TYPE, group_record_type),(psi.TYPE),())
  ORDER BY psi.type

  
--  WITH stats AS (
	SELECT
--	    diamanter.id AS diamanterId,
		diamanter.user_external_id AS d_id,
		psi.timestamp,
--	    diamanter.name_to_show AS d_name,
--		diamanter.name AS diamanterName,
--	    CAST(custbrand.id AS VARCHAR(255)) AS custbrandId,
		custbrand.user_external_id AS cb_id,
		COALESCE(custbrand.name_to_show, '(unknown)') AS cb_nameTS,
--	    COALESCE(custbrand.name,         '(unknown)') AS cb_name,
		psi.type              AS type,
		psi.cyber_id          AS cyber_id,
		psi.lot_id            AS cyber_id_long,
		psi.data_field_carats AS carats,
		psi.data_field_pieces AS pieces,
		---
		(SELECT string_agg(DISTINCT    upper(srf_orig.string_value), ', ' 
							  ORDER BY upper(srf_orig.string_value)) AS list_orig
		   FROM step_record sr_orig
		        LEFT JOIN step_record_fields srf_orig ON srf_orig.step_record_id = sr_orig.id AND srf_orig.key = 'Origin'
		  WHERE sr_orig.product_search_index_id = psi.id AND
		        sr_orig.role_name IN ('RoughCertification', 'Parcel Assessment')
		  GROUP BY  product_search_index_id) AS origin, 
		 ---
		(SELECT string_agg(DISTINCT   upper(srf_supp.string_value), ', ' 
		 					 ORDER BY upper(srf_supp.string_value)) AS list_supp
		   FROM step_record sr_supp
		        LEFT JOIN step_record_fields srf_supp ON srf_supp.step_record_id = sr_supp.id AND srf_supp.key = 'Rough_Supplier'
		  WHERE sr_supp.product_search_index_id = psi.id AND
		        sr_supp.role_name IN ('RoughPurchase', 'RoughPurchasePre')
		  GROUP BY product_search_index_id) AS roughsupplier              
		 ---
	FROM                                                                                                                                                  
		cob_chain_company custbrand                                                                                                                       
		LEFT JOIN cob_chain_company diamanter ON diamanter.type = 'LEVEL_1_CLIENT_COMPANY' AND diamanter.id = custbrand.level1client_company_id                                                                                      
		LEFT JOIN cob_chain_company stkh      ON	  stkh.type = 'STAKEHOLDER_COMPANY'    AND stkh.level1client_company_id = diamanter.id                                                                                           
		LEFT JOIN chain_member cm             ON	cm.id = stkh.chain_member_id                                                                                                              
		LEFT JOIN product_search_index psi    ON (custbrand.user_external_id = psi.customer_id2   OR  custbrand.user_external_id = psi.brand_id2) AND psi.owner = cm.id                                                                                                                     
		LEFT JOIN cob_chain_company customer  ON  customer.level1client_company_id = diamanter.id AND                                                                                          
												  customer.type = 'LEVEL_2_CLIENT_COMPANY'        AND customer.user_external_id = psi.customer_id2                                                                                          
   WHERE                                                                                                                                             
		 custbrand.type = 'LEVEL_2_CLIENT_COMPANY'                                                                                                     
	 AND psi.superseded = FALSE                                                                                                                    
	 AND ${AFTER}::timestamp        IS NULL OR psi.timestamp 					>= ${AFTER}::timestamp
	 AND ${BEFORE}::timestamp       IS NULL OR psi.timestamp 					<  ${BEFORE}::timestamp         
	 AND ${custbrandId}				IS NULL OR UPPER(custbrand.user_external_id) = UPPER(${custbrandId})                   
	 AND ${customerId} 			   	IS NULL OR UPPER(psi.customer_id2) 			 = UPPER(${customerId})                              
	 AND ${brandId} 			   	IS NULL OR UPPER(psi.brand_id2)    	 	     = UPPER(${brandId})                              
	 AND ${diamanterUserExternalId} IS NULL OR UPPER(diamanter.user_external_id) = UPPER(${diamanterUserExternalId})       
	 AND ${typeFlux}                IS NULL OR UPPER(psi.type)					 = UPPER(${typeFlux})                                        
	 AND UPPER(psi.cyber_id)	    not like '%TEST%'	
	ORDER BY timestamp DESC;
	 
) 
SELECT diamanterId, diamanterUserExternalId, diamanterName, diamanterNameToShow,                                                                     
       custbrandId, custbrandUserExternalId, custbrandName, custbrandNameToShow,                                                                       
       type, roughsupplier, origin,                                                                                                                    
  	   count(DISTINCT cyberid) AS sumLots,                                                                                                             
  	   round(sum(carats),2)    AS sumCarats,                                                                                                              
  	   round(sum(pieces),0)    AS sumPieces,                                                                                                              
  	   round(100 * round(sum(carats),2)/ sum(round(sum(carats),2))       OVER (PARTITION BY diamanterId, type, custbrandId), 1) AS pctCarats,                
	   round(100 * round(sum(pieces),0)/ sum(round(sum(pieces),0))       OVER (PARTITION BY diamanterId, type, custbrandId), 1) AS pctPieces,                   
	   round(100 * count(distinct cyberid)/ sum(count(distinct cyberid)) OVER (PARTITION BY diamanterId, type, custbrandId), 1) AS pctLots            
  FROM stats                                                                                                                                            
 GROUP BY diamanterId, diamanterUserExternalId, diamanterName, diamanterNameToShow,                                                                   
		  custbrandId, custbrandUserExternalId, custbrandName, custbrandNameToShow,                                                                  
		  type, roughsupplier, origin                                                                                                                
 ORDER BY TYPE, diamanterNameToShow, custbrandId, custbrandNameToShow,  roughsupplier, origin                                                                                                    

 
 
-- === E4. TOTAL PER CLIENT AMB DETALL =========================================================
-- =============================================================================================
  SELECT 					                                                                               					
	UPPER(srf.string_value)						    AS roughSupplier,                                      
	UPPER(srf_orig.string_value)					AS origin,                                             				
	count(1)										AS sumLots                                  		   				
 FROM                                                                                                    
	product_search_index psi                                                                               
	INNER JOIN step_record sr ON sr.product_search_index_id = psi.id                                       
	INNER JOIN step_record_fields srf ON srf.step_record_id = sr.id                                        
	INNER JOIN step_record sr_orig ON sr_orig.product_search_index_id = psi.id  						   
      AND sr_orig.in_batch_id  =  sr.out_batch_id														   
	INNER JOIN step_record_fields srf_orig ON srf_orig.step_record_id = sr_orig.id                         
	LEFT JOIN chain_member cm ON psi.owner = cm.id                                                         
	LEFT JOIN cob_chain_company stkh		                                                               
		ON stkh.chain_member_id 				= cm.id 					                                
			and stkh.type='STAKEHOLDER_COMPANY'                                                            
	LEFT JOIN cob_chain_company diamanter 	                                                               
		ON diamanter.id 			= stkh.level1client_company_id                                         
			and diamanter.type    = 'LEVEL_1_CLIENT_COMPANY'                                               
	LEFT JOIN cob_chain_company customer 	                                                               
		ON customer.level1client_company_id 	= diamanter.id  			                               
			and customer.type     = 'LEVEL_2_CLIENT_COMPANY'	                                           
			and customer.user_external_id = psi.customer_id                                                
 WHERE    																							   
  (CAST(CAST(:after 	AS varchar(255) ) AS timestamp) is null										       
     or psi.timestamp >= CAST(CAST(:after   	AS varchar(255) )	AS timestamp) ) 					   
  AND (CAST(CAST(:before 	AS varchar(255) ) AS timestamp) is null										   
     or psi.timestamp <= CAST(CAST(:before   	AS varchar(255) )	AS timestamp) ) 				   	   
  AND (:customerId is null 																			   
	   or UPPER(psi.customer_id)	     		= UPPER(CAST( :customerId AS varchar(255) ) )) 			   
  AND (:diamanterUserExternalId is null 																   
	   or UPPER(diamanter.user_external_id)	    = UPPER(CAST( :diamanterUserExternalId AS varchar(255) ))) 
  AND (:typeFlux is null 																   				   
	   or UPPER(psi.type)	    = UPPER(CAST( :typeFlux AS varchar(255) ) ))							   
	AND sr.role_name = 'RoughPurchase'                                                                     
	AND srf.key='Rough_Supplier'                                                                           
	AND sr_orig.role_name = 'RoughCertification'                                                           
	AND srf_orig.key='Origin'                                                                              
  AND UPPER(psi.cyber_id)	    not like '%TEST%'														   
 GROUP BY 										                           							   				
	UPPER(srf.string_value)	,                                                                              
	UPPER(srf_orig.string_value)	                                                                       
 ORDER BY UPPER(srf.string_value), UPPER(srf_orig.string_value)										   

 
-- HERMES PARIS (00314)
-- HERMES       (00009)
-- RAOUL GUYOT  (00132)

SELECT user_external_id, name, name_to_show  
  FROM cob_chain_company ccc 
 WHERE "type" = 'LEVEL_2_CLIENT_COMPANY'
 ORDER BY user_external_id  ;


SELECT TYPE, * FROM product_search_index psi  LIMIT 5;




