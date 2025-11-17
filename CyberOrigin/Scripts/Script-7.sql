SELECT TYPE, psi.cyber_id, brand_id2, customer_id2, final_certificate_url, customer_id2, brand_id2, ci.api_version, "date", * 
  FROM product_search_index psi 
       LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
 WHERE superseded =FALSE 
   AND ci.api_version='4'
   AND ci.api_name='diamonds-full'
  ORDER BY psi.cyber_id 


SELECT TYPE, psi.cyber_id, customer_id2, brand_id2, ci.api_version, "date", data_field_pieces, data_field_carats
  FROM product_search_index psi 
       LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
 WHERE psi.cyber_id = ANY(string_to_array('CYR01-22-0535-201476, CYR01-22-0535-201477, CYR01-22-0535-201478, CYR01-22-0537-201790, CYR01-22-0537-201791, CYR01-22-0537-201792, CYR01-22-0677-226933, CYR01-22-0677-226934, CYR01-22-0677-226935, CYR01-22-0678-226936, CYR01-22-0678-226937, CYR01-22-0678-226938',', '))
  AND superseded =FALSE 
  ORDER BY psi.cyber_id 
  

SELECT DISTINCT psi.id, sr.id AS sr_id, psi.superseded, sr.cyber_id, sr.role_name, srf.KEY, srf.string_value, date_value, srf.url_value, srf.*
  FROM step_record_fields srf
       INNER JOIN step_record sr ON sr.id=srf.step_record_id 
       LEFT OUTER JOIN product_search_index psi ON sr.product_search_index_id=psi.id
-- WHERE LEFT(sr.cyber_id,20) = ANY(string_to_array('CYR01-22-0535-201476, CYR01-22-0535-201477, CYR01-22-0535-201478, CYR01-22-0537-201790, CYR01-22-0537-201791, CYR01-22-0537-201792, CYR01-22-0677-226933, CYR01-22-0677-226934, CYR01-22-0677-226935, CYR01-22-0678-226936, CYR01-22-0678-226937, CYR01-22-0678-226938',', '))
 WHERE LEFT(sr.cyber_id,20) = 'CYR01-22-0677-226934'
--   AND srf.string_value ~ '1035'
--   AND KEY~*'Rough_[IP]'
--   AND (psi.superseded=FALSE OR psi.superseded IS NULL)
--   AND srf.date_value IS NOT NULL
--   AND sr.role_name = 'Delivery'
ORDER BY sr.cyber_id, sr.id, sr.role_name, key


SELECT * FROM step_record sr WHERE cyber_id ~'22-0677-226934'

SELECT * FROM product_search_index psi WHERE cyber_id ~'22-0677-226934'

SELECT * FROM cyber_id ci WHERE cyber_id ~'22-0677-226934' ORDER BY id DESC;

SELECT sr.cyber_id, role_name, srf.* 
  FROM step_record_fields srf 
  	   LEFT OUTER JOIN step_record sr ON sr.id=srf.step_record_id 
 WHERE string_value='10359'

 
SELECT * FROM v_register_log vrl WHERE LEFT(cyber_id,20) = 'CYR01-22-0677-226934' ORDER BY id desc


SELECT product_search_index_id  FROM step_record WHERE LEFT(cyber_id,20) = ANY(string_to_array('CYR01-22-0535-201476, CYR01-22-0535-201477, CYR01-22-0535-201478, CYR01-22-0537-201790, CYR01-22-0537-201791, CYR01-22-0537-201792, CYR01-22-0677-226933, CYR01-22-0677-226934, CYR01-22-0677-226935, CYR01-22-0678-226936, CYR01-22-0678-226937, CYR01-22-0678-226938',', '))
SELECT * FROM workflow_name wn 

/*
api                  |blockchain_name|code|name                        
---------------------+---------------+----+----------------------------
diamonds-full        |Blockchain-01  |01  |Diamonds Full               
diamonds-semi-full   |Blockchain-02  |02  |Diamonds Semi-full          
round-coloured-stones|Blockchain-10  |10  |Round Coloured Stones       
coloured-stones      |Blockchain-20  |20  |Shaped Coulored Stones      
diamonds-baguettes   |Blockchain-30  |30  |Shaped Diamond Full         
baguette-rainbow     |Blockchain-21  |21  |Shaped Multi-coloured Stones
*/


SELECT cyber_id, cyber_id_revision, step_record_id, public_step, role_name, "key", value_convert_string 
  FROM v_step_record_and_fields vsraf 
 WHERE cyber_id ~ '22-0543-202496'
 ORDER BY step_record_id, key
 
SELECT id, cyber_id, lot_id, superseded, * FROM product_search_index psi WHERE cyber_id ~'CYR01-22-0677-226934'

SELECT * FROM custbrands c  
