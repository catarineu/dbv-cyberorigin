 SELECT psi."type" AS wftype, date::date, psi.cyber_id, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats
   FROM product_search_index psi
        LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
  WHERE psi.superseded=FALSE AND ci.deleted <> TRUE
    AND psi.cyber_id ~'22-0739'
 
WITH const AS (
	SELECT 50 AS vp0, 0.30 AS vp1, 0.15 AS vp2, 0.09 AS vp3, 
		               300 AS  p1, 2000 AS p2, 
		   50 AS vc0,   50 AS vc1,   15 AS vc2,    5 AS vc3,
		                 1 AS  c1,   10 AS c2
   ), wfs AS (
     SELECT psi_type FROM workflow_name wn WHERE code IN ('01','02', '03', '10', '20')
   ), lots AS (
     SELECT psi."type" AS wftype, date::date, psi.cyber_id, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats
     FROM product_search_index psi
     LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
     WHERE psi.superseded=FALSE AND ci.deleted <> TRUE
     AND psi.TYPE IN (SELECT psi_type FROM wfs)
     AND date BETWEEN '2024-01-01' AND '2026-01-01'
     AND (psi.group_record_type IS NULL OR psi.group_record_type <> 'GROUP_MOVEMENT')
   ), calc AS (
     SELECT wftype, date, cyber_id, pieces, carats,
     GREATEST(vp0,LEAST(p1,pieces)*vp1) + LEAST(p2,GREATEST(0,pieces-p1))*vp2 + GREATEST(0,pieces-p2)*vp3 AS ppieces,
     GREATEST(vc0,LEAST(c1,carats)*vc1) + LEAST(c2,GREATEST(0,carats-c1))*vc2 + GREATEST(0,carats-c2)*vc3 AS pcarats
     FROM lots
     CROSS JOIN const c
   ), tot AS (
     SELECT EXTRACT(YEAR FROM date) AS year, EXTRACT(MONTH FROM date) AS month,
     wftype, cyber_id, count(cyber_id) AS num, sum(pieces) AS pieces, sum(carats) AS carats,
     to_char(round(sum(ppieces)), '9G999G999') AS sp,
     to_char(round(sum(pcarats)), '9G999G999') AS sc,
     to_char(round(sum(ppieces+pcarats)), '9G999G999') AS total
     FROM calc
     GROUP BY GROUPING SETS ((EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date), wftype, cyber_id),
     (EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date), wftype),
     (EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date)),
     (EXTRACT(YEAR FROM date)),
     ())
     ORDER BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date), wftype, cyber_id
   ) SELECT * FROM tot WHERE wftype IS NULL AND cyber_id IS NULL;

SELECT psi."type" AS wftype, date::date, psi.cyber_id, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats
     FROM product_search_index psi
     LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
     WHERE psi.superseded=FALSE AND ci.deleted <> TRUE
      AND date > '2025-01-01'
 
