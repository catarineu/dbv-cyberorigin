@set cyber = 'CYR01-25-0100-356240'

SELECT date, cyber_id, lot_id, superseded
  FROM product_search_index psi 
 WHERE cyber_id~${cyber} AND superseded = FALSE
 ORDER BY cyber_id;

SELECT * FROM cyber_id ci 
  WHERE cyber_id IN 
(SELECT lot_id
  FROM product_search_index psi 
 WHERE cyber_id~${cyber} AND superseded = FALSE)
 ORDER BY cyber_id;


