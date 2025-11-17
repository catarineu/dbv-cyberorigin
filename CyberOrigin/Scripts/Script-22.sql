SELECT blockchain_name, name, name_fr FROM workflow_name ORDER BY code;

WITH wfs AS (
    SELECT psi_type FROM workflow_name wn WHERE code IN ('01','02', '03', '10', '20')
  ), lots AS (
        SELECT psi."type" AS wftype, date::date, psi.cyber_id, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats
        FROM product_search_index psi
        LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
        WHERE psi.superseded=FALSE AND ci.deleted <> TRUE
        AND psi.TYPE IN (SELECT psi_type FROM wfs)
        AND date >= '2025-05-01' 
        AND (psi.group_record_type IS NULL OR psi.group_record_type <> 'GROUP_MOVEMENT')
      ), calc AS (
        SELECT wftype, date, cyber_id, pieces, carats
        FROM lots
      ), tot AS (
        SELECT EXTRACT(YEAR FROM date) AS year, EXTRACT(MONTH FROM date) AS month,
        wftype, cyber_id, count(cyber_id) AS num
        FROM calc
        GROUP BY GROUPING SETS ((EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date), wftype, cyber_id),
        (EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date), wftype),
        (EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date)),
        (EXTRACT(YEAR FROM date)),
        ())
        ORDER BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date), wftype, cyber_id
      ) SELECT * FROM tot
      
      
SELECT * FROM product_search_index psi WHERE date>='2025-05-01' AND superseded <> TRUE;