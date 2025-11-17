SELECT 
    YEAR, workflow_id  ,workflow_name, customer_extid AS cust_id,customer_namets ,brand_extid AS brand_id,brand_namets,
    origin_countries,origin_providers,
	  lots_sum, pieces_sum, carats_sum, nfts_sum --, cyber_ids
 FROM get_new_stats_detail  (NULL, NULL, NULL, NULL, '2023-01-01', '2025-03-15', FALSE, FALSE, FALSE, TRUE);

SELECT cyber_id, date, customer_id, * 
  FROM product_search_index psi 
 WHERE customer_id ='00314' 
   AND superseded =FALSE
 ORDER BY date DESC ;

SELECT "type", cyber_id, lot_id, customer_id, brand_id, "date", data_field_pieces AS df_pieces,
		superseded AS ss, has_nft, is_only_one_production AS oop, nft_outdated, input_cyberid_references, internal_cyber_id, data_field_component, data_field_serial_number, data_field_photo, data_field_video, data_field_alloy, data_field_quantity, data_field_weight 
  FROM product_search_index psi 
 WHERE "type" ='LEATHER_GOODS_COMPONENTS'
--   AND superseded = FALSE;

SELECT * FROM product_search_index psi WHERE internal_cyber_id ='CYR01-TEST99v1-00001-R08';

SELECT * FROM workflow_name wn ORDER BY code;