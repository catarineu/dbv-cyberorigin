SELECT * FROM workflow_name wn ORDER BY code;
-- gold-full
-- leather-goods-components

SELECT * 
  FROM register_log rl
-- WHERE api='leather-goods-components'
 ORDER BY id DESC 
 LIMIT 300;

SELECT TYPE, chain_member_id, name, api_key 
  FROM cob_chain_company
 WHERE state='ACTIVE'
 ORDER BY TYPE, name;


SELECT id, company_name, api_key  
  FROM chain_member cm 
 ORDER BY company_name ;



INSERT INTO public.field_mapping_value 
(api, api_version, field, hidden, step_name, visible_in_summary, send_field, order_field) 
VALUES
('leather-goods-components', '1', 'product_material', false, 'ORDER', true, true, 
 (SELECT COALESCE(MAX(order_field), 0) + 1 FROM field_mapping_value 
  WHERE api = 'leather-goods-components' AND api_version = '1' AND step_name = 'ORDER')),
('leather-goods-components', '1', 'product_stones', false, 'ORDER', true, true,
 (SELECT COALESCE(MAX(order_field), 0) + 2 FROM field_mapping_value 
  WHERE api = 'leather-goods-components' AND api_version = '1' AND step_name = 'ORDER'))
ON CONFLICT (api, api_version, step_name, field) DO NOTHING;

SELECT COALESCE(MAX(order_field), 0) + 1 FROM field_mapping_value 
  WHERE api = 'leather-goods-components' AND api_version = '1' AND step_name = 'ORDER')
  
SELECT *
  FROM field_mapping_value 
 WHERE api = 'leather-goods-components' AND step_name ='ORDER' ORDER BY api_version DESC, step_name, field 
  

