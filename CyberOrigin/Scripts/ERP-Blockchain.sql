-- =================================================
-- EXCEL de contraste + LIVRAISONS
-- =================================================
WITH tots AS (
  SELECT ec.year_erp, ec.cyberid AS erp_cyberid, 
         LEFT(psi.cyber_id, 20) AS blk_cyberid, 
         substring(psi.cyber_id, 21) AS sousgroup,
         psi.superseded,
         ec.pieces AS erp_pieces, psi.data_field_pieces AS blk_pieces, coalesce(ec.pieces = psi.data_field_pieces,FALSE) AS e1,
         ec.carats AS erp_carats, psi.data_field_carats AS blk_carats, coalesce(ec.carats = psi.data_field_carats,FALSE) AS e2,
         ec.ref_client, ec.ref_cde, ec.ref_model, ec.ref_fo, ed.pieces AS ed_pieces, ed.carats AS ed_carats, ed.cyber_id AS ed_cyber_id, ed.delivery_id AS ed_delivery_id
  FROM erp_cyberid2 ec 
 	   FULL OUTER JOIN product_search_index psi ON lower(ec.cyberid) = lower(LEFT(psi.cyber_id, 20))
					   AND ec.pieces = psi.data_field_pieces
					   AND round(ec.carats,2) BETWEEN round(psi.data_field_carats,2)-0.01 AND round(psi.data_field_carats,2)+0.01
 	   FULL OUTER JOIN erp_deliveries ed ON delivery_id=substring(psi.cyber_id, 21)
)
SELECT year_erp, rn2.api || ' ' || rn2.api_version AS api, erp_cyberid, blk_cyberid, sousgroup, ed_delivery_id,
		erp_pieces, blk_pieces, ed_pieces, e1, erp_carats, blk_carats, ed_carats, e2, ref_client, ref_cde, ref_model, ref_fo
  FROM tots
       FULL OUTER JOIN (SELECT cyber_id, api, api_version, ROW_NUMBER() OVER (PARTITION BY cyber_id ORDER BY id DESC) AS rn FROM register_log) AS rn2 ON tots.erp_cyberid=rn2.cyber_id AND rn2.rn=1
 WHERE (superseded IS NULL OR superseded=FALSE) AND 
       length(sousgroup)>1 
 --   AND (blk_cyberid='CYR01-23-0513-245736' OR erp_cyberid='CYR01-23-0513-245736')
 ORDER BY COALESCE(erp_cyberid, blk_cyberid) NULLS LAST, sousgroup NULLS LAST, erp_pieces DESC;


SELECT * FROM erp_deliveries ed WHERE delivery_id ='D267509';

-- =================================================
-- DUPLICADOS
-- =================================================
WITH special AS (
SELECT cyberid, count(*)
  FROM erp_cyberid ec 
 GROUP BY cyberid
HAVING count(*)>1) 
SELECT * 
  FROM erp_cyberid ec
 WHERE cyberid IN (SELECT cyberid FROM special)

 
-- ===================================================================================================================================================
-- ===================================================================================================================================================
-- =================================================
-- EXCEL de contraste - ERP2
-- =================================================
WITH tots AS (
  SELECT ec.year_erp, ec.cyberid AS erp_cyberid, 
         LEFT(psi.cyber_id, 20) AS blk_cyberid, 
         substring(psi.cyber_id, 21) AS sousgroup,
         psi.superseded,
         ec.pieces AS erp_pieces, psi.data_field_pieces AS blk_pieces, coalesce(ec.pieces = psi.data_field_pieces,FALSE) AS e1,
         ec.carats AS erp_carats, psi.data_field_carats AS blk_carats, coalesce(ec.carats = psi.data_field_carats,FALSE) AS e2,
         ec.ref_client, ec.ref_cde, ec.ref_model, ec.ref_fo, ec.erp_wf, psi.TYPE, psi.lot_id
  FROM erp_cyberid2 ec 
 	   FULL OUTER JOIN product_search_index psi ON lower(ec.cyberid) = lower(LEFT(psi.cyber_id, 20)) 
   AND ec.pieces = psi.data_field_pieces
--   AND ec.carats = psi.data_field_carats
   AND round(ec.carats,2) BETWEEN round(psi.data_field_carats,2)-0.01 AND round(psi.data_field_carats,2)+0.01
)
SELECT year_erp, COALESCE(wn.blockchain_name || ' ' || wn.name || ' v' || COALESCE(ci.api_version,''),rn2.api || ' ' || rn2.api_version) AS api, 
	   erp_wf AS erp_api, erp_cyberid, blk_cyberid, sousgroup, erp_pieces, blk_pieces, e1, erp_carats, blk_carats, e2, ref_client, ref_cde, ref_model, ref_fo
  FROM tots
       LEFT OUTER JOIN (SELECT cyber_id, api, api_version, ROW_NUMBER() OVER (PARTITION BY cyber_id ORDER BY id DESC) AS rn FROM register_log) AS rn2 ON tots.erp_cyberid=rn2.cyber_id AND rn2.rn=1
       LEFT OUTER JOIN workflow_name wn ON wn.psi_type=tots.TYPE
       LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=tots.lot_id
 WHERE (superseded IS NULL OR superseded=FALSE) 
--   AND (blk_cyberid='CYR01-23-0513-245736' OR erp_cyberid='CYR01-23-0513-245736')
 ORDER BY COALESCE(erp_cyberid, blk_cyberid) NULLS LAST, sousgroup NULLS LAST, erp_pieces DESC;

SELECT * FROM product_search_index psi LIMIT 5;
SELECT * FROM cyber_id ci ;

SELECT * FROM workflow_name wn 

-- =================================================
-- DUPLICADOS
-- =================================================
WITH special AS (
SELECT cyberid, count(*)
  FROM erp_cyberid ec 
 GROUP BY cyberid
HAVING count(*)>1) 
SELECT * 
  FROM erp_cyberid ec
 WHERE cyberid IN (SELECT cyberid FROM special)
