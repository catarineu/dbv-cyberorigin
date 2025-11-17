SET plan_cache_mode = force_custom_plan;
SELECT * 
  FROM get_new_stats_detail_test('01', NULL, NULL, NULL, '2023-01-01', '2024-12-31', FALSE, FALSE, TRUE, FALSE)
 ORDER BY diamanter_extid, workflow_id, brand_extid, brand_extid, pieces_sum DESC;

SET plan_cache_mode = force_custom_plan;
SELECT * 
  FROM get_new_stats_detail('01', NULL, NULL, NULL, '2022-01-01', '2025-12-31', FALSE, FALSE, TRUE, TRUE)
 ORDER BY diamanter_extid, workflow_id, customer_extid, brand_extid, pieces_sum DESC;

SELECT type FROM product_search_index psi; 
SELECT * FROM custbrands;
