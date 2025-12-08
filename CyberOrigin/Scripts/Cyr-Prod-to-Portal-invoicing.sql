SELECT blockchain_name, name, name_fr FROM workflow_name ORDER BY code;

WITH wfs AS (
    -- Select relevant workflow types
    SELECT psi_type, 'WF'||code||' - '||name_fr AS nicetype
    FROM public.workflow_name wn 
    WHERE code IN ('01','02', '03', '10', '20')
)
    -- Get base data from factory tables
    SELECT 
        wfs.nicetype AS wftype, 
        date::date, 
        psi.cyber_id, 
        psi.data_field_pieces AS pieces, 
        psi.data_field_carats AS carats
    FROM public.product_search_index psi
    LEFT OUTER JOIN public.cyber_id ci ON ci.cyber_id = psi.lot_id
    INNER JOIN wfs ON wfs.psi_type=psi.TYPE
    WHERE psi.superseded = FALSE 
        AND ci.deleted <> TRUE
        AND (psi.group_record_type IS NULL OR psi.group_record_type <> 'GROUP_MOVEMENT')
        

SELECT max(date) FROM product_search_index psi WHERE date>='2025-05-01' AND superseded <> TRUE;

-- ===============================================================
-- 1. CONSULTA ÚLTIMA DATA (portal)
SELECT max(date),count(*) FROM product_search_index psi WHERE superseded <> TRUE AND date>='2025-09-01';

-- 1. TRASPAS psi (prod)
SELECT * FROM product_search_index psi WHERE date>='2025-01-01' AND superseded <> TRUE;
-->> Exportar amb SQL i inserir a Portal.BD

-- 2. TRASPAS cyber_id
SELECT * FROM cyber_id ci WHERE ci.cyber_id IN (SELECT psi.lot_id FROM product_search_index psi WHERE date>='2025-01-01' AND superseded <> TRUE);
-->> Exportar amb SQL i inserir a Portal.BD

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

SELECT invoice_number, invoice_month,
       cyber_id, workflow_type, pieces, carats, amount
  FROM portal.invoice_cyber_ids ici 
       LEFT OUTER JOIN portal.invoices pi ON pi.id=ici.invoice_id 
 ORDER BY invoice_number, cyber_id ;

