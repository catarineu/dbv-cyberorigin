SET plan_cache_mode = force_custom_plan;

SELECT *
  FROM get_new_stats_detail(
    '01', NULL, NULL, NULL, '2024-01-01'::date, '2024-12-31'::date, false, true, false, false
) 
WHERE
	customer_extid='00009' OR brand_extid='00009';

