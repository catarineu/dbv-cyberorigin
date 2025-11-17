SELECT * 
FROM get_new_stats_detail(
                            '01', NULL, NULL, NULL, '2021-01-01'::date, '2024-12-31'::date, false, true, true, false
                        )