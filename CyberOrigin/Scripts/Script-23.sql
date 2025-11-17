SELECT * FROM portal.invoice_cyber_ids ORDER BY lot_id desc;
SELECT * FROM invoices;

SELECT * FROM cyber_id ORDER BY id DESC;

SELECT count(*) FROM product_search_index2;

@set cyber = 'CYR01-25-0078-352914'

	SELECT date::date, cyber_id, lot_id, data_field_carats, data_field_carats, superseded
	  FROM product_search_index psi 
	 WHERE 1=1
--	   AND cyber_id~${cyber}
	   AND superseded = FALSE
	   AND date >= '2025-01-01'


WITH lots AS (
	SELECT date::date, cyber_id, lot_id, data_field_carats, data_field_carats, superseded
	  FROM product_search_index psi 
	 WHERE 1=1
--	   AND cyber_id~${cyber}
	   AND superseded = FALSE
	   AND date >= '2025-01-01'
)
SELECT * FROM lots 
 WHERE lot_id NOT IN (SELECT lot_id FROM invoice_cyber_ids)
 ORDER BY date, cyber_id;
	 
SELECT * FROM cyber_id ci 
  WHERE cyber_id IN 
(SELECT lot_id
  FROM product_search_index psi 
 WHERE cyber_id~${cyber} AND superseded = FALSE)
 ORDER BY cyber_id;

SELECT * FROM invoice_cyber_ids ici ;
