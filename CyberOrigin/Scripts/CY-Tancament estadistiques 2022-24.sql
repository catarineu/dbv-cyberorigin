
SELECT blocktype, cyber_id, date_rfb, customerid, brandid, pieces, carats, ref_client, ref_fo, ref_cde
  FROM erp_date_rfb edr 
 WHERE (blocktype IS NOT NULL AND blocktype <> 'No Blockchain')
   AND cyber_id NOT IN 
	(SELECT LEFT(psi.cyber_id,20) 
	   FROM product_search_index psi 
 	      LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
	  WHERE psi.superseded = FALSE AND ci.deleted = FALSE)
 ORDER BY blocktype, cyber_id ;
	  
SELECT LEFT(psi.cyber_id,20) 
	   FROM product_search_index psi 
 	      LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
	  WHERE psi.superseded = FALSE AND ci.deleted = FALSE
	  ORDER BY LEFT(psi.cyber_id,20) 