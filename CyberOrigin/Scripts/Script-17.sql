
SET plan_cache_mode = force_custom_plan;
SELECT diamanter_extid,diamanter_namets,year,workflow_type  ,workflow_id  ,workflow_name         ,customer_extid,customer_namets,brand_extid,brand_namets,origin_countries,origin_providers          ,lots_sum,pieces_sum,carats_sum,nfts_sum,lots_pc,pieces_pc,carats_pc,nfts_pc,cyber_ids
FROM get_new_stats_detail(
    '01', NULL, '00132', NULL, '2021-01-01'::date, '2024-12-31'::date, false, false, true, false
)


SELECT *
FROM get_new_stats_detail(
    '01', NULL, '00132', NULL, '2021-01-01'::date, '2024-12-31'::date, false, false, true, false
)