SELECT * FROM step_record sr 

SELECT * FROM product_search_index psi WHERE cyber_id ~'CYR01-23-0557-261742';

-- Cerca del darrer cop que hem treballat amb MMA
WITH cybers AS (
	SELECT cyber_id FROM step_record sr WHERE stakeholder=6 -- MMA
), rankk AS (
	SELECT id, LEFT(cyber_id,20) AS cyber_id, bc_creation_date, role_name, stakeholder, stakeholder=6, "timestamp", product_search_index_id,
	       ROW_NUMBER() OVER (PARTITION BY LEFT(cyber_id,20), role_name ORDER BY bc_creation_date DESC) AS ranking
	  FROM step_record sr 
 	 WHERE LEFT(cyber_id,20) IN (SELECT LEFT(cyber_id,20) FROM cybers)
 	   AND cyber_id ~ 'CYR01-2'
 	   AND role_name = 'Cut'
  ORDER BY cyber_id DESC, bc_creation_date DESC
) 
SELECT * FROM rankk
  WHERE ranking=1;
