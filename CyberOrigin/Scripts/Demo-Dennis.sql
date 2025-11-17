SELECT * FROM product_search_index psi WHERE cyber_id ~ '24-0035'

SELECT cyber_id, step_record_id AS srid, public_step AS st, role_name AS step, 
       chain_member_company_name AS stakeh, KEY, value_convert_string AS value
  FROM v_step_record_and_fields vsraf 
 WHERE cyber_id  ~'CYR01-24-0035-302424'
 ORDER BY step_record_id, "timestamp"  

SELECT * FROM product_search_index psi WHERE cyber_id ~'CYR01-24-0035-302424'

SELECT * 
  FROM step_record_fields srf 
  WHERE step_record_id = 38778
 ORDER BY step_record_id, key;

SELECT * FROM step_record sr WHERE id=38887;

SELECT * FROM chain_member cm ORDER BY id;
SELECT * FROM workflows w;
SELECT * FROM chain_member cm ;
SELECT * FROM cob_chain_company ccc ORDER BY type;

-- S1.cust/brand
SELECT name, user_external_id, "type"  FROM cob_chain_company ccc WHERE TYPE='LEVEL_2_CLIENT_COMPANY' ORDER BY user_external_id ;

-- S1.Type
SELECT * FROM dynamic_enum_value dev 
 WHERE api='round-coloured-stones' AND enum_type ='Type'
 ORDER BY enum_type ;

-- S1.Next  
SELECT company_name, api_key  FROM chain_member cm ORDER BY company_name ;
