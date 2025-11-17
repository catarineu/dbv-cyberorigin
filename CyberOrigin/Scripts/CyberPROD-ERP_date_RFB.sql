
SELECT * FROM workflow_name wn; 

DELETE FROM erp_rfb;

SELECT * FROM erp_rfb      edr ORDER BY cyber_id ;

UPDATE erp_rfb SET cyber_id = CONCAT('CYR',      SUBSTRING(cyber_id, 5)) WHERE LEFT(cyber_id, 4) = 'CYOR'  RETURNING cyber_id;
UPDATE erp_rfb SET cyber_id = CONCAT('CYR01-22', SUBSTRING(cyber_id, 6)) WHERE LEFT(cyber_id, 5) = 'CYR22' RETURNING cyber_id;

-- Control CyberIDs: in PSI + NOT in ERP
SELECT psi.cyber_id, edr.cyber_id
  FROM product_search_index psi 
	   LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
  	   LEFT OUTER JOIN erp_rfb edr ON LEFT(psi.cyber_id,20)=edr.cyber_id
 WHERE superseded = FALSE
   AND ci.deleted   = FALSE AND ci.cancelled = FALSE -- NO anulats
   AND edr.cyber_id IS NULL 

-- Control CyberIDs: in ERP + NOT in PSI
SELECT blocktype AS "blocktype    .", edr.cyber_id, edr.pieces, edr.carats, edr.ref_model, edr.ref_client 
, edr.ref_fo , edr.ref_cde , edr.date_rfb, edr.brandid , edr.customerid , edr.date_cb, edr.orderdelivery 
  FROM erp_rfb edr
	   LEFT OUTER JOIN product_search_index psi ON LEFT(psi.cyber_id,20)=edr.cyber_id
	   LEFT OUTER JOIN cyber_id ci ON (ci.cyber_id=psi.lot_id)
 WHERE psi.cyber_id IS NULL
   AND (ci.deleted IS NULL OR ci.deleted = FALSE)
   AND (ci.cancelled IS NULL OR ci.cancelled = FALSE)
   AND blocktype<>'BLOCKCHAIN_00'
 ORDER BY blocktype, edr.cyber_id;

-- =============================== UPDATE DATES
--


-- ===========================================================================
-- ===========================================================================
-- Quants han d'estar a blockchain? = 1793 
SELECT COUNT(*)
  FROM erp_rfb er
 WHERE blocktype<>'BLOCKCHAIN_00';

-- EQUAL ---- (dif) + 1519 (equ) = 1765
SELECT blocktype, psi.cyber_id AS psi_cyber, edr.cyber_id AS edr_cyber, 
--       psi.date::date AS psi_date,      CASE WHEN psi.date::date =edr.date_rfb   THEN '=' ELSE edr.date_rfb::text END AS erp_date,
       psi.brand_id AS psi_brand,       CASE WHEN psi.brand_id   =edr.brandid    THEN '=' ELSE edr.brandid END AS erp_brand,
       psi.customer_id AS psi_customer, CASE WHEN psi.customer_id=edr.customerid THEN '=' ELSE edr.customerid END AS erp_customer
  FROM product_search_index psi 
  	   FULL OUTER JOIN erp_rfb edr ON LEFT(psi.cyber_id,20)=edr.cyber_id
	   LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
 WHERE superseded = FALSE AND ci.deleted = FALSE AND ci.cancelled = FALSE -- NO anulats
   AND psi.cyber_id ~ '24-0005'
   AND psi.brand_id    = edr.brandid  
   AND psi.customer_id = edr.customerid
 ORDER BY psi.cyber_id ;

-- DIFF ---- 246 (dif) + 1519 (equ) = 1765
SELECT blocktype, psi.cyber_id AS psi_cyber, -- edr.cyber_id AS adr_cyber, 
--       psi.date::date AS psi_date,      CASE WHEN psi.date::date =edr.date_rfb   THEN '=' ELSE edr.date_rfb::text END AS erp_date,
       psi.brand_id AS psi_brand,       CASE WHEN psi.brand_id   =edr.brandid    THEN '=' ELSE edr.brandid END AS erp_brand,
       psi.customer_id AS psi_customer, CASE WHEN psi.customer_id=edr.customerid THEN '=' ELSE edr.customerid END AS erp_customer
  FROM product_search_index psi 
	   LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
  	   LEFT OUTER JOIN erp_rfb edr ON LEFT(psi.cyber_id,20)=edr.cyber_id
 WHERE superseded = FALSE AND ci.deleted = FALSE AND ci.cancelled = FALSE -- NO anulats
   AND (
--        psi.date <> edr.date_rfb OR 
        psi.brand_id    <> edr.brandid OR 
        psi.customer_id <> edr.customerid
        )
 ORDER BY psi.cyber_id ;

--- UPDATE
UPDATE product_search_index SET brand_id2 = brand_id, customer_id2 = customer_id;

UPDATE product_search_index
SET 
    brand_id    = edr.brandid,
    customer_id = edr.customerid
FROM erp_rfb edr, cyber_id ci
WHERE 
    product_search_index.lot_id = ci.cyber_id
    AND LEFT(product_search_index.cyber_id, 20) = edr.cyber_id
    AND superseded = FALSE 
    AND ci.deleted = FALSE 
    AND ci.cancelled = FALSE
    AND (
        product_search_index.brand_id <> edr.brandid
        OR product_search_index.customer_id <> edr.customerid
    );

     
   

-- ===========================================================================
-- ===========================================================================
--DELETE FROM erp_date_rfb;
-- 1. Import
SELECT * FROM erp_date_rfb edr ORDER BY cyber_id ;

-- 2. Corrections
UPDATE erp_rfb
SET cyber_id = CONCAT('CYR', SUBSTRING(cyber_id, 5))
WHERE LEFT(cyber_id, 4) = 'CYOR';

UPDATE erp_rfb
SET cyber_id = CONCAT('CYR01-22', SUBSTRING(cyber_id, 6))
WHERE LEFT(cyber_id, 5) = 'CYR22'
RETURNING cyber_id;

-- Control de CyberIDs que NO estan a la llista del ERP
SELECT psi.cyber_id, edr.cyber_id
  FROM product_search_index psi 
	   LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
  	   LEFT OUTER JOIN erp_date_rfb edr ON LEFT(psi.cyber_id,20)=edr.cyber_id
 WHERE superseded = FALSE
   AND ci.deleted   = FALSE AND ci.cancelled = FALSE -- NO anulats
   AND edr.cyber_id IS NULL 

   
SELECT * FROM erp_date_rfb edr WHERE cyber_id~'23-0663-290470';
SELECT cyber_id FROM erp_date_rfb edr WHERE LEFT(cyber_id, 4) = 'CYOR';
SELECT * FROM product_search_index psi WHERE cyber_id ~'23-0663-290470';
SELECT * FROM erp_date_rfb;