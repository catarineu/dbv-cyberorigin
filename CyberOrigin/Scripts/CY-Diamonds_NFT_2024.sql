-- =========================================================
-- Llistat de NFTs fets i per fer
SELECT wn.code, wn."name",  
       count(CASE WHEN nft_url IS     NULL THEN 1 END) AS pending,
       count(CASE WHEN nft_url IS NOT NULL THEN 1 END) AS done
  FROM product_search_index psi
  	   LEFT OUTER JOIN cyber_id ci ON (ci.cyber_id=psi.lot_id)
  	   LEFT OUTER JOIN workflow_name wn ON wn.psi_type=psi."type" 
 WHERE 1=1
   AND psi.superseded = FALSE AND ci.DELETED <> TRUE 
 GROUP BY GROUPING SETS ((wn.code, wn.name),())
 ORDER BY wn.code;

-- =========================================================
-- Llistat per TOKENITZACIÓ
WITH 
  totals0 AS (
	SELECT psi.* 
	  FROM product_search_index psi
	       LEFT OUTER JOIN cyber_id ci ON (ci.cyber_id=psi.lot_id)
	 WHERE psi.superseded = FALSE AND ci.deleted <> TRUE 
	   AND TYPE='DIAMONDS_FULL'
--	   AND psi.cyber_id<>'CYR01-24-0103-326045'
--	   AND psi.customer_id NOT IN ('00051','01092')
	   AND psi.nft_url IS NULL 
	 ORDER BY psi."date"
	 LIMIT 250
--	SELECT psi.* 
--	  FROM product_search_index psi
--	       LEFT OUTER JOIN cyber_id ci ON (ci.cyber_id=psi.lot_id)
--	 WHERE psi.superseded = FALSE AND ci.deleted <> TRUE AND TYPE='DIAMONDS_FULL'
--	   AND psi.cyber_id='CYR01-24-0103-326045'
),
 totals1 AS (
 SELECT * 
   FROM totals0
  WHERE id NOT IN (SELECT psi_id FROM cyberids_nfts WHERE psi_id>0)
 ),
 totals2 AS (
 SELECT customer_id ||'-'|| EXTRACT('year' FROM date)  ||'-'|| wn.code AS collection, shortname, 
 		rf.timestamp, t.cyber_id, rf.group_cyber_id, rf.public_step, rf."key", regexp_replace(rf.value_convert_string, '[\n\r]+', '', 'g') AS value, t.id, t.superseded
   FROM totals1 t
   	    LEFT OUTER JOIN workflow_name wn ON wn.psi_type=t.type
   	    LEFT OUTER JOIN custbrands cb ON t.customer_id=cb.id 
        LEFT OUTER JOIN v_step_record_and_fields rf ON rf.group_cyber_id=t.cyber_id_group
 )
 SELECT * 
   FROM totals2 t2
  ORDER BY id, timestamp; -- Detall de passos (per creació de tokens)

 
-- =========================================================
-- Càlcul d'espai
WITH 
  totals0 AS (
	SELECT psi.* 
	  FROM product_search_index psi
	       LEFT OUTER JOIN cyber_id ci ON (ci.cyber_id=psi.lot_id)
	 WHERE psi.superseded = FALSE AND ci.deleted <> TRUE AND TYPE='DIAMONDS_FULL'
	   AND psi.nft_url IS NULL 
--	SELECT psi.* 
--	  FROM product_search_index psi
--	       LEFT OUTER JOIN cyber_id ci ON (ci.cyber_id=psi.lot_id)
--	 WHERE psi.superseded = FALSE AND ci.deleted <> TRUE AND TYPE='DIAMONDS_FULL'
--	   AND psi.cyber_id='CYR01-24-0103-326045'
),
 totals1 AS (
 SELECT * 
   FROM totals0
  WHERE id NOT IN (SELECT psi_id FROM cyberids_nfts WHERE psi_id>0)
 ),
 totals2 AS (
 SELECT customer_id ||'-'|| EXTRACT('year' FROM date)  ||'-'|| wn.code AS collection
   FROM totals1 t
   	    LEFT OUTER JOIN workflow_name wn ON wn.psi_type=t.type
 )
 SELECT collection, count(*) num_certifs, count(*)*53 AS mb_req, round((count(*)::numeric*53)/1024,2) AS gb_req
   FROM totals2 t2 
  GROUP BY collection
  ORDER BY count(*) DESC, collection; -- Detall de passos (per creació de tokens)
-- SELECT DISTINCT t2.id, t2.cyber_id  FROM totals2 t2 ORDER BY id;  -- Resum de PSI afectats
  
 
 
  
 
-- CONTROL que no hi hagi doble PSI per un mateix CyberID
SELECT psi.cyber_id, count(*)
  FROM product_search_index psi
       LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
 WHERE psi.superseded = FALSE    -- Actius
   AND ci.deleted <> TRUE
 GROUP BY psi.cyber_id
HAVING count(*)>1;

-- =========================================================
-- PUBLICACIÓ: : cyberids_nfts --> PSI
WITH LatestNFTs AS (
    SELECT cyber_id, token_id, token_url
    FROM (
        SELECT cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url,
               ROW_NUMBER() OVER (PARTITION BY cyber_id ORDER BY created_at DESC) AS rn
          FROM cyberids_nfts
         WHERE status = 'SUCCESS'
           AND collection_name <> 'Cyber'
    ) AS ranked_nfts
    WHERE rn = 1
    ORDER BY cyber_id
)
UPDATE product_search_index psi
SET 
    has_nft = TRUE,
    nft_url = token_url
FROM 
    cyber_id ci,
    LatestNFTs
WHERE
    ci.cyber_id = psi.lot_id
    AND psi.cyber_id = LatestNFTs.cyber_id
    AND psi.type = 'DIAMONDS_FULL'
    AND nft_url <> token_url
    AND psi.superseded = FALSE
    AND ci.deleted <> TRUE;

-- RETROMARCATGE: PSI --> cyberids_nfts
WITH tots AS (
	SELECT id, cyber_id, token_id, token_url
	FROM (
	    SELECT id, cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url,
	           ROW_NUMBER() OVER (PARTITION BY cyber_id ORDER BY created_at DESC) AS rn
          FROM cyberids_nfts
         WHERE status = 'SUCCESS'
           AND collection_name <> 'Cyber'
	) AS ranked_nfts
	WHERE rn = 1
)
UPDATE cyberids_nfts nfts
   SET psi_id = psi.id
  FROM tots t
  JOIN product_search_index psi ON psi.nft_url = t.token_url
 WHERE nfts.id = t.id
   AND (nfts.psi_id IS NULL OR nfts.psi_id != psi.id);

-- =========================================================
SELECT 
    psi.id, psi.superseded,
    psi.lot_id,
    psi.cyber_id,
    TRUE AS new_has_nft,
    'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/' || LatestNFTs.token_id || '?tokenId=' || LatestNFTs.token_id || '&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai' AS new_nft_url,
    psi.has_nft AS current_has_nft,
    psi.nft_url AS current_nft_url
FROM 
    product_search_index psi
JOIN 
    cyber_id ci ON ci.cyber_id = psi.lot_id
JOIN (
    SELECT cyber_id, token_id, token_url
    FROM (
        SELECT cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url,
               ROW_NUMBER() OVER (PARTITION BY cyber_id ORDER BY created_at DESC) AS rn
        FROM cyberids_nfts
    ) AS ranked_nfts
    WHERE rn = 1
    AND status = 'SUCCESS'
    AND collection_name <> 'Cyber'
) AS LatestNFTs ON psi.cyber_id = LatestNFTs.cyber_id
WHERE 
    psi.type='DIAMONDS_FULL'
    AND psi.superseded = FALSE
    AND ci.deleted <> TRUE
    AND psi.cyber_id = LatestNFTs.cyber_id;
   
   
   
SELECT count(*) FROM cyberids_nfts;
   

SELECT * FROM cyberids_nfts ORDER by id DESC LIMIT 10;


SELECT cyber_id, token_id, id
FROM cyberids_nfts
ORDER BY id DESC LIMIT 1;

SELECT count(*) FROM cyberids_nfts cn ;

-- ========================================================================================================================
-- ========================================================================================================================

CREATE TABLE cyberids_nfts2 AS (SELECT * FROM cyberids_nfts);

SELECT id, cyber_id, status FROM cyberids_nfts ORDER BY id DESC LIMIT 5;
SELECT id, cyber_id, status FROM cyberids_nfts2 ORDER BY id DESC LIMIT 5;

-- ========================================================================================================================
-- ========================================================================================================================

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0683-228901', '672c6a312ca1ad0dfcfa9466', 'SUCCESS', '2024-11-07T07:20:19.288Z', '2024-11-07T07:28:02.568Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c6a312ca1ad0dfcfa9466?tokenId=672c6a312ca1ad0dfcfa9466&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227400', '672c685c2ca1ad0dfcfa9423', 'SUCCESS', '2024-11-07T07:12:30.313Z', '2024-11-07T07:20:06.511Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c685c2ca1ad0dfcfa9423?tokenId=672c685c2ca1ad0dfcfa9423&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227399', '672c6682635c4850abac97aa', 'SUCCESS', '2024-11-07T07:04:35.721Z', '2024-11-07T07:12:16.571Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c6682635c4850abac97aa?tokenId=672c6682635c4850abac97aa&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227398', '672c64a84a384e960ff18ae5', 'SUCCESS', '2024-11-07T06:56:42.172Z', '2024-11-07T07:04:20.521Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c64a84a384e960ff18ae5?tokenId=672c64a84a384e960ff18ae5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227396', '672c62de2ca1ad0dfcfa9368', 'SUCCESS', '2024-11-07T06:49:04.323Z', '2024-11-07T06:56:31.340Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c62de2ca1ad0dfcfa9368?tokenId=672c62de2ca1ad0dfcfa9368&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227395', '672c6104635c4850abac96ef', 'SUCCESS', '2024-11-07T06:41:10.402Z', '2024-11-07T06:48:50.825Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c6104635c4850abac96ef?tokenId=672c6104635c4850abac96ef&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227394', '672c5f152ca1ad0dfcfa92e5', 'SUCCESS', '2024-11-07T06:32:54.813Z', '2024-11-07T06:40:55.712Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c5f152ca1ad0dfcfa92e5?tokenId=672c5f152ca1ad0dfcfa92e5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227393', '672c5d4b635c4850abac966e', 'SUCCESS', '2024-11-07T06:25:16.709Z', '2024-11-07T06:32:43.496Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c5d4b635c4850abac966e?tokenId=672c5d4b635c4850abac966e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227392', '672c5b7c2ca1ad0dfcfa9268', 'SUCCESS', '2024-11-07T06:17:33.654Z', '2024-11-07T06:25:05.890Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c5b7c2ca1ad0dfcfa9268?tokenId=672c5b7c2ca1ad0dfcfa9268&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227391', '672c59ac4a384e960ff18976', 'SUCCESS', '2024-11-07T06:09:50.402Z', '2024-11-07T06:17:18.361Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c59ac4a384e960ff18976?tokenId=672c59ac4a384e960ff18976&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227390', '672c57de2ca1ad0dfcfa91e9', 'SUCCESS', '2024-11-07T06:02:07.689Z', '2024-11-07T06:09:36.390Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c57de2ca1ad0dfcfa91e9?tokenId=672c57de2ca1ad0dfcfa91e9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227389', '672c55f92ca1ad0dfcfa91a4', 'SUCCESS', '2024-11-07T05:54:03.299Z', '2024-11-07T06:01:53.296Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c55f92ca1ad0dfcfa91a4?tokenId=672c55f92ca1ad0dfcfa91a4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227388', '672c541b635c4850abac953b', 'SUCCESS', '2024-11-07T05:46:04.890Z', '2024-11-07T05:53:51.696Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c541b635c4850abac953b?tokenId=672c541b635c4850abac953b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0680-227387', '672c524c4a384e960ff1887d', 'SUCCESS', '2024-11-07T05:38:21.720Z', '2024-11-07T05:45:50.246Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c524c4a384e960ff1887d?tokenId=672c524c4a384e960ff1887d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0679-227357', '672c5051635c4850abac94b8', 'SUCCESS', '2024-11-07T05:29:56.362Z', '2024-11-07T05:38:05.690Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c5051635c4850abac94b8?tokenId=672c5051635c4850abac94b8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0677-226935', '672c4e8c635c4850abac9477', 'SUCCESS', '2024-11-07T05:22:21.961Z', '2024-11-07T05:29:41.106Z', '00112-2022-01', '66e30e507ff111da78b3851e', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c4e8c635c4850abac9477?tokenId=672c4e8c635c4850abac9477&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0675-225568', '672c4ca8635c4850abac9432', 'SUCCESS', '2024-11-07T05:14:17.665Z', '2024-11-07T05:22:09.935Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c4ca8635c4850abac9432?tokenId=672c4ca8635c4850abac9432&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0675-225567', '672c4ab4635c4850abac93eb', 'SUCCESS', '2024-11-07T05:05:58.418Z', '2024-11-07T05:14:03.735Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c4ab4635c4850abac93eb?tokenId=672c4ab4635c4850abac93eb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0675-225566', '672c48ca2ca1ad0dfcfa8fed', 'SUCCESS', '2024-11-07T04:57:47.950Z', '2024-11-07T05:05:43.520Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c48ca2ca1ad0dfcfa8fed?tokenId=672c48ca2ca1ad0dfcfa8fed&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0675-225565', '672c46e52ca1ad0dfcfa8fa8', 'SUCCESS', '2024-11-07T04:49:42.873Z', '2024-11-07T04:57:35.677Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c46e52ca1ad0dfcfa8fa8?tokenId=672c46e52ca1ad0dfcfa8fa8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0675-225564', '672c4504635c4850abac932a', 'SUCCESS', '2024-11-07T04:41:42.407Z', '2024-11-07T04:49:27.243Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c4504635c4850abac932a?tokenId=672c4504635c4850abac932a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0675-225563', '672c432b2ca1ad0dfcfa8f27', 'SUCCESS', '2024-11-07T04:33:49.028Z', '2024-11-07T04:41:31.990Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c432b2ca1ad0dfcfa8f27?tokenId=672c432b2ca1ad0dfcfa8f27&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0675-225562', '672c41562ca1ad0dfcfa8ee4', 'SUCCESS', '2024-11-07T04:26:00.271Z', '2024-11-07T04:33:35.396Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c41562ca1ad0dfcfa8ee4?tokenId=672c41562ca1ad0dfcfa8ee4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0675-225561', '672c3f7d4a384e960ff1860e', 'SUCCESS', '2024-11-07T04:18:06.920Z', '2024-11-07T04:25:45.658Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c3f7d4a384e960ff1860e?tokenId=672c3f7d4a384e960ff1860e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0670-224191', '672c3d9d635c4850abac9231', 'SUCCESS', '2024-11-07T04:10:06.894Z', '2024-11-07T04:17:55.438Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c3d9d635c4850abac9231?tokenId=672c3d9d635c4850abac9231&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0670-224190', '672c3bb32ca1ad0dfcfa8e25', 'SUCCESS', '2024-11-07T04:01:56.819Z', '2024-11-07T04:09:54.951Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c3bb32ca1ad0dfcfa8e25?tokenId=672c3bb32ca1ad0dfcfa8e25&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0670-224189', '672c39c3635c4850abac91ac', 'SUCCESS', '2024-11-07T03:53:40.910Z', '2024-11-07T04:01:44.156Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c39c3635c4850abac91ac?tokenId=672c39c3635c4850abac91ac&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0670-224188', '672c37c44a384e960ff18509', 'SUCCESS', '2024-11-07T03:45:10.286Z', '2024-11-07T03:53:25.674Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c37c44a384e960ff18509?tokenId=672c37c44a384e960ff18509&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0670-224187', '672c35ef4a384e960ff184c6', 'SUCCESS', '2024-11-07T03:37:21.329Z', '2024-11-07T03:44:59.419Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c35ef4a384e960ff184c6?tokenId=672c35ef4a384e960ff184c6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0669-224186', '672c34102ca1ad0dfcfa8d24', 'SUCCESS', '2024-11-07T03:29:21.604Z', '2024-11-07T03:37:06.045Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c34102ca1ad0dfcfa8d24?tokenId=672c34102ca1ad0dfcfa8d24&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0669-224185', '672c32464a384e960ff18447', 'SUCCESS', '2024-11-07T03:21:44.150Z', '2024-11-07T03:29:08.006Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c32464a384e960ff18447?tokenId=672c32464a384e960ff18447&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0669-224184', '672c30714a384e960ff18404', 'SUCCESS', '2024-11-07T03:13:55.161Z', '2024-11-07T03:21:32.458Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c30714a384e960ff18404?tokenId=672c30714a384e960ff18404&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0668-224183', '672c2e9c4a384e960ff183c1', 'SUCCESS', '2024-11-07T03:06:05.445Z', '2024-11-07T03:13:41.725Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c2e9c4a384e960ff183c1?tokenId=672c2e9c4a384e960ff183c1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0668-224182', '672c2cd0635c4850abac8ffd', 'SUCCESS', '2024-11-07T02:58:26.469Z', '2024-11-07T03:05:53.138Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c2cd0635c4850abac8ffd?tokenId=672c2cd0635c4850abac8ffd&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0668-224181', '672c2ac82ca1ad0dfcfa8bed', 'SUCCESS', '2024-11-07T02:49:45.605Z', '2024-11-07T02:58:13.041Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c2ac82ca1ad0dfcfa8bed?tokenId=672c2ac82ca1ad0dfcfa8bed&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0667-224180', '672c2abd2ca1ad0dfcfa8be4', 'SUCCESS', '2024-11-07T02:49:34.941Z', '2024-11-07T02:58:13.484Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c2abd2ca1ad0dfcfa8be4?tokenId=672c2abd2ca1ad0dfcfa8be4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0667-224179', '672c2ab22ca1ad0dfcfa8bdb', 'SUCCESS', '2024-11-07T02:49:23.975Z', '2024-11-07T02:58:11.042Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c2ab22ca1ad0dfcfa8bdb?tokenId=672c2ab22ca1ad0dfcfa8bdb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0666-224178', '672c28c3635c4850abac8f70', 'SUCCESS', '2024-11-07T02:41:08.718Z', '2024-11-07T02:49:08.804Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c28c3635c4850abac8f70?tokenId=672c28c3635c4850abac8f70&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0666-224177', '672c26ee635c4850abac8f2d', 'SUCCESS', '2024-11-07T02:33:20.429Z', '2024-11-07T02:40:57.542Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c26ee635c4850abac8f2d?tokenId=672c26ee635c4850abac8f2d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0665-224176', '672c25252ca1ad0dfcfa8b1e', 'SUCCESS', '2024-11-07T02:25:42.731Z', '2024-11-07T02:33:04.885Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c25252ca1ad0dfcfa8b1e?tokenId=672c25252ca1ad0dfcfa8b1e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0665-224175', '672c23502ca1ad0dfcfa8adb', 'SUCCESS', '2024-11-07T02:17:55.009Z', '2024-11-07T02:25:31.563Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c23502ca1ad0dfcfa8adb?tokenId=672c23502ca1ad0dfcfa8adb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0665-224174', '672c21772ca1ad0dfcfa8a98', 'SUCCESS', '2024-11-07T02:10:00.373Z', '2024-11-07T02:17:41.525Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c21772ca1ad0dfcfa8a98?tokenId=672c21772ca1ad0dfcfa8a98&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0664-224173', '672c1f9c635c4850abac8e36', 'SUCCESS', '2024-11-07T02:02:06.065Z', '2024-11-07T02:09:45.471Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c1f9c635c4850abac8e36?tokenId=672c1f9c635c4850abac8e36&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0664-224172', '672c1dbe2ca1ad0dfcfa8a17', 'SUCCESS', '2024-11-07T01:54:07.528Z', '2024-11-07T02:01:52.780Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c1dbe2ca1ad0dfcfa8a17?tokenId=672c1dbe2ca1ad0dfcfa8a17&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0663-224171', '672c1be92ca1ad0dfcfa89d4', 'SUCCESS', '2024-11-07T01:46:19.157Z', '2024-11-07T01:53:52.170Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c1be92ca1ad0dfcfa89d4?tokenId=672c1be92ca1ad0dfcfa89d4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0663-224170', '672c1a1a4a384e960ff18118', 'SUCCESS', '2024-11-07T01:38:35.849Z', '2024-11-07T01:46:08.426Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c1a1a4a384e960ff18118?tokenId=672c1a1a4a384e960ff18118&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0661-224162', '672c18254a384e960ff180d1', 'SUCCESS', '2024-11-07T01:30:14.431Z', '2024-11-07T01:38:22.718Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c18254a384e960ff180d1?tokenId=672c18254a384e960ff180d1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0660-224161', '672c16504a384e960ff1808e', 'SUCCESS', '2024-11-07T01:22:25.708Z', '2024-11-07T01:30:02.674Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c16504a384e960ff1808e?tokenId=672c16504a384e960ff1808e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0659-224160', '672c14862ca1ad0dfcfa88db', 'SUCCESS', '2024-11-07T01:14:47.587Z', '2024-11-07T01:22:15.038Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c14862ca1ad0dfcfa88db?tokenId=672c14862ca1ad0dfcfa88db&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0656-223450', '672c12a64a384e960ff1800f', 'SUCCESS', '2024-11-07T01:06:47.913Z', '2024-11-07T01:14:33.416Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c12a64a384e960ff1800f?tokenId=672c12a64a384e960ff1800f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0655-222672', '672c10c7635c4850abac8c49', 'SUCCESS', '2024-11-07T00:58:48.706Z', '2024-11-07T01:06:35.436Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c10c7635c4850abac8c49?tokenId=672c10c7635c4850abac8c49&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0650-220482', '672c0eed4a384e960ff17f8e', 'SUCCESS', '2024-11-07T00:50:55.066Z', '2024-11-07T00:58:35.250Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c0eed4a384e960ff17f8e?tokenId=672c0eed4a384e960ff17f8e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0650-220481', '672c0d184a384e960ff17f4b', 'SUCCESS', '2024-11-07T00:43:05.957Z', '2024-11-07T00:50:42.015Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c0d184a384e960ff17f4b?tokenId=672c0d184a384e960ff17f4b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0650-220480', '672c0b4d2ca1ad0dfcfa87a6', 'SUCCESS', '2024-11-07T00:35:27.323Z', '2024-11-07T00:42:51.383Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c0b4d2ca1ad0dfcfa87a6?tokenId=672c0b4d2ca1ad0dfcfa87a6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0650-220479', '672c096f4a384e960ff17ecc', 'SUCCESS', '2024-11-07T00:27:28.700Z', '2024-11-07T00:35:16.665Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c096f4a384e960ff17ecc?tokenId=672c096f4a384e960ff17ecc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0650-220478', '672c07962ca1ad0dfcfa8725', 'SUCCESS', '2024-11-07T00:19:35.362Z', '2024-11-07T00:27:17.555Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c07962ca1ad0dfcfa8725?tokenId=672c07962ca1ad0dfcfa8725&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0650-220477', '672c05c12ca1ad0dfcfa86e2', 'SUCCESS', '2024-11-07T00:11:47.161Z', '2024-11-07T00:19:22.917Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c05c12ca1ad0dfcfa86e2?tokenId=672c05c12ca1ad0dfcfa86e2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0650-220476', '672c03e24a384e960ff17e0f', 'SUCCESS', '2024-11-07T00:03:48.144Z', '2024-11-07T00:11:33.132Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c03e24a384e960ff17e0f?tokenId=672c03e24a384e960ff17e0f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0650-220475', '672c01f82ca1ad0dfcfa865f', 'SUCCESS', '2024-11-06T23:55:38.056Z', '2024-11-07T00:03:35.543Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c01f82ca1ad0dfcfa865f?tokenId=672c01f82ca1ad0dfcfa865f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0650-220474', '672c00232ca1ad0dfcfa861c', 'SUCCESS', '2024-11-06T23:47:48.840Z', '2024-11-06T23:55:25.019Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672c00232ca1ad0dfcfa861c?tokenId=672c00232ca1ad0dfcfa861c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0650-220473', '672bfe59635c4850abac89e6', 'SUCCESS', '2024-11-06T23:40:11.192Z', '2024-11-06T23:47:38.166Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bfe59635c4850abac89e6?tokenId=672bfe59635c4850abac89e6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0649-220472', '672bfc84635c4850abac89a3', 'SUCCESS', '2024-11-06T23:32:21.957Z', '2024-11-06T23:40:00.431Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bfc84635c4850abac89a3?tokenId=672bfc84635c4850abac89a3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0649-220471', '672bfa9a4a384e960ff17cd8', 'SUCCESS', '2024-11-06T23:24:11.887Z', '2024-11-06T23:32:11.857Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bfa9a4a384e960ff17cd8?tokenId=672bfa9a4a384e960ff17cd8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0649-220470', '672bf8bc2ca1ad0dfcfa8523', 'SUCCESS', '2024-11-06T23:16:13.467Z', '2024-11-06T23:24:00.565Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bf8bc2ca1ad0dfcfa8523?tokenId=672bf8bc2ca1ad0dfcfa8523&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0649-220469', '672bf6eb4a384e960ff17c5b', 'SUCCESS', '2024-11-06T23:08:29.169Z', '2024-11-06T23:15:57.938Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bf6eb4a384e960ff17c5b?tokenId=672bf6eb4a384e960ff17c5b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220468', '672bf517635c4850abac88ae', 'SUCCESS', '2024-11-06T23:00:40.955Z', '2024-11-06T23:08:11.038Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bf517635c4850abac88ae?tokenId=672bf517635c4850abac88ae&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220467', '672bf3364a384e960ff17be0', 'SUCCESS', '2024-11-06T22:52:39.802Z', '2024-11-06T23:00:24.487Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bf3364a384e960ff17be0?tokenId=672bf3364a384e960ff17be0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220466', '672bf15b4a384e960ff17b9f', 'SUCCESS', '2024-11-06T22:44:44.971Z', '2024-11-06T22:52:19.752Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bf15b4a384e960ff17b9f?tokenId=672bf15b4a384e960ff17b9f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220465', '672bef7a635c4850abac87f7', 'SUCCESS', '2024-11-06T22:36:43.503Z', '2024-11-06T22:44:23.298Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bef7a635c4850abac87f7?tokenId=672bef7a635c4850abac87f7&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220464', '672beda04a384e960ff17b20', 'SUCCESS', '2024-11-06T22:28:49.933Z', '2024-11-06T22:36:31.475Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672beda04a384e960ff17b20?tokenId=672beda04a384e960ff17b20&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220463', '672bebd52ca1ad0dfcfa8382', 'SUCCESS', '2024-11-06T22:21:11.261Z', '2024-11-06T22:28:36.833Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bebd52ca1ad0dfcfa8382?tokenId=672bebd52ca1ad0dfcfa8382&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220462', '672be9db635c4850abac8738', 'SUCCESS', '2024-11-06T22:12:45.182Z', '2024-11-06T22:20:56.189Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672be9db635c4850abac8738?tokenId=672be9db635c4850abac8738&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220461', '672be7e7635c4850abac86f1', 'SUCCESS', '2024-11-06T22:04:24.929Z', '2024-11-06T22:12:31.760Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672be7e7635c4850abac86f1?tokenId=672be7e7635c4850abac86f1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220460', '672be601635c4850abac86ac', 'SUCCESS', '2024-11-06T21:56:18.693Z', '2024-11-06T22:04:12.955Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672be601635c4850abac86ac?tokenId=672be601635c4850abac86ac&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220459', '672be3fc635c4850abac8663', 'SUCCESS', '2024-11-06T21:47:42.229Z', '2024-11-06T21:56:04.919Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672be3fc635c4850abac8663?tokenId=672be3fc635c4850abac8663&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220458', '672be2202ca1ad0dfcfa823d', 'SUCCESS', '2024-11-06T21:39:45.806Z', '2024-11-06T21:47:28.125Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672be2202ca1ad0dfcfa823d?tokenId=672be2202ca1ad0dfcfa823d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220457', '672be0234a384e960ff17961', 'SUCCESS', '2024-11-06T21:31:17.606Z', '2024-11-06T21:39:33.423Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672be0234a384e960ff17961?tokenId=672be0234a384e960ff17961&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220456', '672bde1c4a384e960ff17918', 'SUCCESS', '2024-11-06T21:22:37.654Z', '2024-11-06T21:31:01.398Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bde1c4a384e960ff17918?tokenId=672bde1c4a384e960ff17918&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220455', '672bdc31635c4850abac855e', 'SUCCESS', '2024-11-06T21:14:26.525Z', '2024-11-06T21:22:24.665Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bdc31635c4850abac855e?tokenId=672bdc31635c4850abac855e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0648-220454', '672bda524a384e960ff17897', 'SUCCESS', '2024-11-06T21:06:28.319Z', '2024-11-06T21:14:10.358Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bda524a384e960ff17897?tokenId=672bda524a384e960ff17897&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0640-217464', '672bd820635c4850abac84cd', 'SUCCESS', '2024-11-06T20:57:06.070Z', '2024-11-06T21:05:02.423Z', '00296-2022-01', '66f5891d94f3ecbf4e305c79', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bd820635c4850abac84cd?tokenId=672bd820635c4850abac84cd&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0639-217454', '672bd6552ca1ad0dfcfa80be', 'SUCCESS', '2024-11-06T20:49:26.380Z', '2024-11-06T20:56:53.255Z', '00296-2022-01', '66f5891d94f3ecbf4e305c79', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bd6552ca1ad0dfcfa80be?tokenId=672bd6552ca1ad0dfcfa80be&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0637-216998', '672bd4774a384e960ff177da', 'SUCCESS', '2024-11-06T20:41:29.437Z', '2024-11-06T20:49:12.126Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bd4774a384e960ff177da?tokenId=672bd4774a384e960ff177da&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0637-216997', '672bd2952ca1ad0dfcfa803d', 'SUCCESS', '2024-11-06T20:33:28.052Z', '2024-11-06T20:41:13.476Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bd2952ca1ad0dfcfa803d?tokenId=672bd2952ca1ad0dfcfa803d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0636-216996', '672bd0b2635c4850abac83d4', 'SUCCESS', '2024-11-06T20:25:24.841Z', '2024-11-06T20:33:12.368Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bd0b2635c4850abac83d4?tokenId=672bd0b2635c4850abac83d4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0636-216995', '672bcecc635c4850abac838f', 'SUCCESS', '2024-11-06T20:17:17.759Z', '2024-11-06T20:25:10.719Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bcecc635c4850abac838f?tokenId=672bcecc635c4850abac838f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0636-216994', '672bcce12ca1ad0dfcfa7f7c', 'SUCCESS', '2024-11-06T20:09:07.137Z', '2024-11-06T20:17:05.506Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bcce12ca1ad0dfcfa7f7c?tokenId=672bcce12ca1ad0dfcfa7f7c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0636-216993', '672bcaf64a384e960ff1769d', 'SUCCESS', '2024-11-06T20:00:56.205Z', '2024-11-06T20:08:55.875Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bcaf64a384e960ff1769d?tokenId=672bcaf64a384e960ff1769d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0636-216992', '672bc9162ca1ad0dfcfa7ef9', 'SUCCESS', '2024-11-06T19:52:55.526Z', '2024-11-06T20:00:40.173Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bc9162ca1ad0dfcfa7ef9?tokenId=672bc9162ca1ad0dfcfa7ef9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0635-216991', '672bc7212ca1ad0dfcfa7eb2', 'SUCCESS', '2024-11-06T19:44:35.132Z', '2024-11-06T19:52:39.437Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bc7212ca1ad0dfcfa7eb2?tokenId=672bc7212ca1ad0dfcfa7eb2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0634-216990', '672bc5324a384e960ff175da', 'SUCCESS', '2024-11-06T19:36:20.012Z', '2024-11-06T19:44:22.336Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bc5324a384e960ff175da?tokenId=672bc5324a384e960ff175da&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0634-216989', '672bc337635c4850abac820c', 'SUCCESS', '2024-11-06T19:27:53.476Z', '2024-11-06T19:36:06.611Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bc337635c4850abac820c?tokenId=672bc337635c4850abac820c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0634-216988', '672bc1584a384e960ff17555', 'SUCCESS', '2024-11-06T19:19:54.201Z', '2024-11-06T19:27:40.087Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bc1584a384e960ff17555?tokenId=672bc1584a384e960ff17555&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0629-215828', '672bbf6e635c4850abac8189', 'SUCCESS', '2024-11-06T19:11:43.713Z', '2024-11-06T19:19:41.664Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bbf6e635c4850abac8189?tokenId=672bbf6e635c4850abac8189&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0628-215824', '672bbd98635c4850abac8146', 'SUCCESS', '2024-11-06T19:03:54.465Z', '2024-11-06T19:11:30.891Z', '00296-2022-01', '66f5891d94f3ecbf4e305c79', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bbd98635c4850abac8146?tokenId=672bbd98635c4850abac8146&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0627-215823', '672bbbc84a384e960ff17498', 'SUCCESS', '2024-11-06T18:56:10.057Z', '2024-11-06T19:03:37.837Z', '00296-2022-01', '66f5891d94f3ecbf4e305c79', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bbbc84a384e960ff17498?tokenId=672bbbc84a384e960ff17498&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0626-215451', '672bb9ef635c4850abac80c7', 'SUCCESS', '2024-11-06T18:48:16.487Z', '2024-11-06T18:55:57.750Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bb9ef635c4850abac80c7?tokenId=672bb9ef635c4850abac80c7&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0625-215349', '672bb8052ca1ad0dfcfa7cbb', 'SUCCESS', '2024-11-06T18:40:07.216Z', '2024-11-06T18:48:02.283Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bb8052ca1ad0dfcfa7cbb?tokenId=672bb8052ca1ad0dfcfa7cbb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0625-215348', '672bb6202ca1ad0dfcfa7c76', 'SUCCESS', '2024-11-06T18:32:02.062Z', '2024-11-06T18:39:52.139Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bb6202ca1ad0dfcfa7c76?tokenId=672bb6202ca1ad0dfcfa7c76&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215286', '672bb412635c4850abac8000', 'SUCCESS', '2024-11-06T18:23:15.649Z', '2024-11-06T18:31:48.734Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bb412635c4850abac8000?tokenId=672bb412635c4850abac8000&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215285', '672bb2272ca1ad0dfcfa7bed', 'SUCCESS', '2024-11-06T18:15:04.889Z', '2024-11-06T18:22:59.182Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bb2272ca1ad0dfcfa7bed?tokenId=672bb2272ca1ad0dfcfa7bed&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215284', '672bb0414a384e960ff17317', 'SUCCESS', '2024-11-06T18:06:59.298Z', '2024-11-06T18:14:51.006Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bb0414a384e960ff17317?tokenId=672bb0414a384e960ff17317&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215283', '672baf6f2ca1ad0dfcfa7b8e', 'SUCCESS', '2024-11-06T18:03:28.309Z', '2024-11-06T18:06:47.136Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672baf6f2ca1ad0dfcfa7b8e?tokenId=672baf6f2ca1ad0dfcfa7b8e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215282', '672bad892ca1ad0dfcfa7b49', 'SUCCESS', '2024-11-06T17:55:23.122Z', '2024-11-06T18:03:13.062Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bad892ca1ad0dfcfa7b49?tokenId=672bad892ca1ad0dfcfa7b49&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215281', '672bab952ca1ad0dfcfa7b02', 'SUCCESS', '2024-11-06T17:47:02.712Z', '2024-11-06T17:55:09.984Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672bab952ca1ad0dfcfa7b02?tokenId=672bab952ca1ad0dfcfa7b02&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215280', '672ba9902ca1ad0dfcfa7ab9', 'SUCCESS', '2024-11-06T17:38:26.247Z', '2024-11-06T17:46:49.469Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ba9902ca1ad0dfcfa7ab9?tokenId=672ba9902ca1ad0dfcfa7ab9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215279', '672ba7b0635c4850abac7e63', 'SUCCESS', '2024-11-06T17:30:25.907Z', '2024-11-06T17:38:14.866Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ba7b0635c4850abac7e63?tokenId=672ba7b0635c4850abac7e63&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215278', '672ba5da635c4850abac7e20', 'SUCCESS', '2024-11-06T17:22:36.007Z', '2024-11-06T17:30:14.598Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ba5da635c4850abac7e20?tokenId=672ba5da635c4850abac7e20&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215277', '672ba3fa4a384e960ff1717e', 'SUCCESS', '2024-11-06T17:14:35.705Z', '2024-11-06T17:22:21.872Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ba3fa4a384e960ff1717e?tokenId=672ba3fa4a384e960ff1717e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215276', '672ba1f54a384e960ff17135', 'SUCCESS', '2024-11-06T17:05:59.256Z', '2024-11-06T17:14:22.859Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ba1f54a384e960ff17135?tokenId=672ba1f54a384e960ff17135&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215275', '672ba0014a384e960ff170ee', 'SUCCESS', '2024-11-06T16:57:38.364Z', '2024-11-06T17:05:47.038Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ba0014a384e960ff170ee?tokenId=672ba0014a384e960ff170ee&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215274', '672b9e3c4a384e960ff170ad', 'SUCCESS', '2024-11-06T16:50:05.354Z', '2024-11-06T16:57:26.010Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b9e3c4a384e960ff170ad?tokenId=672b9e3c4a384e960ff170ad&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215273', '672b9c2d2ca1ad0dfcfa78fc', 'SUCCESS', '2024-11-06T16:41:18.788Z', '2024-11-06T16:49:51.212Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b9c2d2ca1ad0dfcfa78fc?tokenId=672b9c2d2ca1ad0dfcfa78fc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215272', '672b9a2d635c4850abac7c9b', 'SUCCESS', '2024-11-06T16:32:47.325Z', '2024-11-06T16:41:04.404Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b9a2d635c4850abac7c9b?tokenId=672b9a2d635c4850abac7c9b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215271', '672b9838635c4850abac7c54', 'SUCCESS', '2024-11-06T16:24:25.982Z', '2024-11-06T16:32:32.951Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b9838635c4850abac7c54?tokenId=672b9838635c4850abac7c54&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215270', '672b96494a384e960ff16fa2', 'SUCCESS', '2024-11-06T16:16:10.412Z', '2024-11-06T16:24:14.914Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b96494a384e960ff16fa2?tokenId=672b96494a384e960ff16fa2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215269', '672b94742ca1ad0dfcfa77f9', 'SUCCESS', '2024-11-06T16:08:21.896Z', '2024-11-06T16:15:56.158Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b94742ca1ad0dfcfa77f9?tokenId=672b94742ca1ad0dfcfa77f9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215268', '672b9289635c4850abac7b93', 'SUCCESS', '2024-11-06T16:00:10.768Z', '2024-11-06T16:08:04.982Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b9289635c4850abac7b93?tokenId=672b9289635c4850abac7b93&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0624-215267', '672b90a82ca1ad0dfcfa7776', 'SUCCESS', '2024-11-06T15:52:10.217Z', '2024-11-06T15:59:56.100Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b90a82ca1ad0dfcfa7776?tokenId=672b90a82ca1ad0dfcfa7776&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214519', '672b8ece635c4850abac7b12', 'SUCCESS', '2024-11-06T15:44:16.214Z', '2024-11-06T15:51:59.395Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b8ece635c4850abac7b12?tokenId=672b8ece635c4850abac7b12&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214518', '672b8ce54a384e960ff16e67', 'SUCCESS', '2024-11-06T15:36:06.945Z', '2024-11-06T15:44:05.545Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b8ce54a384e960ff16e67?tokenId=672b8ce54a384e960ff16e67&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214517', '672b8b014a384e960ff16e22', 'SUCCESS', '2024-11-06T15:28:02.799Z', '2024-11-06T15:35:52.409Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b8b014a384e960ff16e22?tokenId=672b8b014a384e960ff16e22&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214516', '672b8912635c4850abac7a4f', 'SUCCESS', '2024-11-06T15:19:47.636Z', '2024-11-06T15:27:50.055Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b8912635c4850abac7a4f?tokenId=672b8912635c4850abac7a4f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214515', '672b87284a384e960ff16d9d', 'SUCCESS', '2024-11-06T15:11:37.483Z', '2024-11-06T15:19:32.549Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b87284a384e960ff16d9d?tokenId=672b87284a384e960ff16d9d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214514', '672b853e4a384e960ff16d58', 'SUCCESS', '2024-11-06T15:03:28.038Z', '2024-11-06T15:11:25.739Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b853e4a384e960ff16d58?tokenId=672b853e4a384e960ff16d58&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214513', '672b83602ca1ad0dfcfa75bb', 'SUCCESS', '2024-11-06T14:55:29.454Z', '2024-11-06T15:03:13.736Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b83602ca1ad0dfcfa75bb?tokenId=672b83602ca1ad0dfcfa75bb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214512', '672b817b2ca1ad0dfcfa7576', 'SUCCESS', '2024-11-06T14:47:25.183Z', '2024-11-06T14:55:18.609Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b817b2ca1ad0dfcfa7576?tokenId=672b817b2ca1ad0dfcfa7576&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214511', '672b7f572ca1ad0dfcfa7529', 'SUCCESS', '2024-11-06T14:38:17.065Z', '2024-11-06T14:47:11.967Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b7f572ca1ad0dfcfa7529?tokenId=672b7f572ca1ad0dfcfa7529&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214510', '672b7d78635c4850abac78cc', 'SUCCESS', '2024-11-06T14:30:17.984Z', '2024-11-06T14:38:05.349Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b7d78635c4850abac78cc?tokenId=672b7d78635c4850abac78cc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214509', '672b7b7a4a384e960ff16c11', 'SUCCESS', '2024-11-06T14:21:48.074Z', '2024-11-06T14:30:05.092Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b7b7a4a384e960ff16c11?tokenId=672b7b7a4a384e960ff16c11&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214508', '672b797c2ca1ad0dfcfa7462', 'SUCCESS', '2024-11-06T14:13:18.192Z', '2024-11-06T14:21:35.412Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b797c2ca1ad0dfcfa7462?tokenId=672b797c2ca1ad0dfcfa7462&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214507', '672b77634a384e960ff16b84', 'SUCCESS', '2024-11-06T14:04:21.134Z', '2024-11-06T14:13:06.186Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b77634a384e960ff16b84?tokenId=672b77634a384e960ff16b84&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0620-214506', '672b753b635c4850abac77b7', 'SUCCESS', '2024-11-06T13:55:08.488Z', '2024-11-06T14:04:06.116Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b753b635c4850abac77b7?tokenId=672b753b635c4850abac77b7&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0619-214505', '672b732d4a384e960ff16af3', 'SUCCESS', '2024-11-06T13:46:22.933Z', '2024-11-06T13:54:53.252Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b732d4a384e960ff16af3?tokenId=672b732d4a384e960ff16af3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0619-214504', '672b715f2ca1ad0dfcfa7351', 'SUCCESS', '2024-11-06T13:38:40.636Z', '2024-11-06T13:46:08.703Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b715f2ca1ad0dfcfa7351?tokenId=672b715f2ca1ad0dfcfa7351&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0619-214503', '672b707c635c4850abac7714', 'SUCCESS', '2024-11-06T13:34:54.345Z', '2024-11-06T13:38:27.415Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b707c635c4850abac7714?tokenId=672b707c635c4850abac7714&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0619-214502', '672b6e932ca1ad0dfcfa72ee', 'SUCCESS', '2024-11-06T13:26:44.729Z', '2024-11-06T13:34:38.622Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b6e932ca1ad0dfcfa72ee?tokenId=672b6e932ca1ad0dfcfa72ee&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0619-214501', '672b6c6a4a384e960ff16a0e', 'SUCCESS', '2024-11-06T13:17:32.114Z', '2024-11-06T13:26:30.224Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b6c6a4a384e960ff16a0e?tokenId=672b6c6a4a384e960ff16a0e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0619-214500', '672b6a4b2ca1ad0dfcfa725b', 'SUCCESS', '2024-11-06T13:08:29.160Z', '2024-11-06T13:17:16.983Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b6a4b2ca1ad0dfcfa725b?tokenId=672b6a4b2ca1ad0dfcfa725b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0619-214499', '672b685b635c4850abac7603', 'SUCCESS', '2024-11-06T13:00:12.455Z', '2024-11-06T13:08:14.871Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b685b635c4850abac7603?tokenId=672b685b635c4850abac7603&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0619-214498', '672b6675635c4850abac75be', 'SUCCESS', '2024-11-06T12:52:06.984Z', '2024-11-06T12:59:59.003Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b6675635c4850abac75be?tokenId=672b6675635c4850abac75be&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0618-214497', '672b64854a384e960ff16905', 'SUCCESS', '2024-11-06T12:43:51.740Z', '2024-11-06T12:51:54.576Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b64854a384e960ff16905?tokenId=672b64854a384e960ff16905&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0617-214496', '672b62724a384e960ff168ba', 'SUCCESS', '2024-11-06T12:34:59.425Z', '2024-11-06T12:43:40.095Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b62724a384e960ff168ba?tokenId=672b62724a384e960ff168ba&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0617-214495', '672b6028635c4850abac74e9', 'SUCCESS', '2024-11-06T12:25:14.288Z', '2024-11-06T12:34:44.922Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b6028635c4850abac74e9?tokenId=672b6028635c4850abac74e9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0617-214494', '672b5e4d2ca1ad0dfcfa70cc', 'SUCCESS', '2024-11-06T12:17:19.404Z', '2024-11-06T12:25:01.937Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b5e4d2ca1ad0dfcfa70cc?tokenId=672b5e4d2ca1ad0dfcfa70cc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0615-213230', '672b5c734a384e960ff167ef', 'SUCCESS', '2024-11-06T12:09:25.062Z', '2024-11-06T12:17:08.320Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b5c734a384e960ff167ef?tokenId=672b5c734a384e960ff167ef&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0612-213210', '672b5c5d635c4850abac7466', 'FAILED', '2024-11-06T12:09:19.119Z', '2024-11-06T12:09:44.014Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b5c5d635c4850abac7466?tokenId=672b5c5d635c4850abac7466&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0612-213209', '672b5a68635c4850abac741f', 'SUCCESS', '2024-11-06T12:00:41.761Z', '2024-11-06T12:08:50.092Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b5a68635c4850abac741f?tokenId=672b5a68635c4850abac741f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0612-213208', '672b5863635c4850abac73d6', 'SUCCESS', '2024-11-06T11:52:05.277Z', '2024-11-06T12:00:28.121Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b5863635c4850abac73d6?tokenId=672b5863635c4850abac73d6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0612-213207', '672b567e635c4850abac7391', 'SUCCESS', '2024-11-06T11:44:00.387Z', '2024-11-06T11:51:53.153Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b567e635c4850abac7391?tokenId=672b567e635c4850abac7391&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0612-213204', '672b54af4a384e960ff166ec', 'SUCCESS', '2024-11-06T11:36:16.920Z', '2024-11-06T11:43:47.237Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b54af4a384e960ff166ec?tokenId=672b54af4a384e960ff166ec&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0612-213203', '672b52ca2ca1ad0dfcfa6f4f', 'SUCCESS', '2024-11-06T11:28:12.603Z', '2024-11-06T11:36:04.814Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b52ca2ca1ad0dfcfa6f4f?tokenId=672b52ca2ca1ad0dfcfa6f4f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0607-211134', '672b50fb635c4850abac72d6', 'SUCCESS', '2024-11-06T11:20:28.436Z', '2024-11-06T11:28:00.759Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b50fb635c4850abac72d6?tokenId=672b50fb635c4850abac72d6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0607-211133', '672b4f152ca1ad0dfcfa6ed0', 'SUCCESS', '2024-11-06T11:12:22.559Z', '2024-11-06T11:20:01.711Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b4f152ca1ad0dfcfa6ed0?tokenId=672b4f152ca1ad0dfcfa6ed0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0607-211132', '672b4d33635c4850abac7255', 'SUCCESS', '2024-11-06T11:04:20.587Z', '2024-11-06T11:12:08.422Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b4d33635c4850abac7255?tokenId=672b4d33635c4850abac7255&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0607-211131', '672b4cb62ca1ad0dfcfa6e7f', 'SUCCESS', '2024-11-06T11:02:16.418Z', '2024-11-06T11:10:31.229Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b4cb62ca1ad0dfcfa6e7f?tokenId=672b4cb62ca1ad0dfcfa6e7f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0607-211130', '672b4acb4a384e960ff165a5', 'SUCCESS', '2024-11-06T10:54:04.429Z', '2024-11-06T11:02:04.773Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b4acb4a384e960ff165a5?tokenId=672b4acb4a384e960ff165a5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0606-211129', '672b48eb2ca1ad0dfcfa6dfc', 'SUCCESS', '2024-11-06T10:46:04.985Z', '2024-11-06T10:53:50.653Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b48eb2ca1ad0dfcfa6dfc?tokenId=672b48eb2ca1ad0dfcfa6dfc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0606-211128', '672b471a635c4850abac718a', 'SUCCESS', '2024-11-06T10:38:20.066Z', '2024-11-06T10:45:48.482Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b471a635c4850abac718a?tokenId=672b471a635c4850abac718a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0606-211127', '672b45412ca1ad0dfcfa6d7d', 'SUCCESS', '2024-11-06T10:30:26.492Z', '2024-11-06T10:38:07.467Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b45412ca1ad0dfcfa6d7d?tokenId=672b45412ca1ad0dfcfa6d7d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0606-211126', '672b4381635c4850abac710d', 'SUCCESS', '2024-11-06T10:22:58.417Z', '2024-11-06T10:30:12.541Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b4381635c4850abac710d?tokenId=672b4381635c4850abac710d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0606-211125', '672b41a14a384e960ff16472', 'SUCCESS', '2024-11-06T10:14:59.056Z', '2024-11-06T10:22:44.759Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b41a14a384e960ff16472?tokenId=672b41a14a384e960ff16472&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0605-211124', '672b3fcc4a384e960ff1642f', 'SUCCESS', '2024-11-06T10:07:09.773Z', '2024-11-06T10:14:43.995Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b3fcc4a384e960ff1642f?tokenId=672b3fcc4a384e960ff1642f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0605-211123', '672b3de74a384e960ff163ea', 'SUCCESS', '2024-11-06T09:59:04.770Z', '2024-11-06T10:06:54.893Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b3de74a384e960ff163ea?tokenId=672b3de74a384e960ff163ea&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0605-211122', '672b3c0c635c4850abac7012', 'SUCCESS', '2024-11-06T09:51:09.920Z', '2024-11-06T09:58:50.224Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b3c0c635c4850abac7012?tokenId=672b3c0c635c4850abac7012&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0605-211121', '672b3a28635c4850abac6fcd', 'SUCCESS', '2024-11-06T09:43:05.512Z', '2024-11-06T09:50:58.189Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b3a28635c4850abac6fcd?tokenId=672b3a28635c4850abac6fcd&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0605-211120', '672b3853635c4850abac6f8a', 'SUCCESS', '2024-11-06T09:35:16.542Z', '2024-11-06T09:42:50.061Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b3853635c4850abac6f8a?tokenId=672b3853635c4850abac6f8a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0604-211119', '672b3684635c4850abac6f47', 'SUCCESS', '2024-11-06T09:27:33.793Z', '2024-11-06T09:35:03.968Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b3684635c4850abac6f47?tokenId=672b3684635c4850abac6f47&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0604-211118', '672b349f635c4850abac6f02', 'SUCCESS', '2024-11-06T09:19:29.244Z', '2024-11-06T09:27:18.088Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b349f635c4850abac6f02?tokenId=672b349f635c4850abac6f02&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0604-211117', '672b32ba635c4850abac6ebd', 'SUCCESS', '2024-11-06T09:11:24.329Z', '2024-11-06T09:19:14.827Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b32ba635c4850abac6ebd?tokenId=672b32ba635c4850abac6ebd&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0602-211113', '672b30cb2ca1ad0dfcfa6ad8', 'SUCCESS', '2024-11-06T09:03:08.840Z', '2024-11-06T09:11:08.117Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b30cb2ca1ad0dfcfa6ad8?tokenId=672b30cb2ca1ad0dfcfa6ad8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0602-211112', '672b2f062ca1ad0dfcfa6a97', 'SUCCESS', '2024-11-06T08:55:35.473Z', '2024-11-06T09:02:57.850Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b2f062ca1ad0dfcfa6a97?tokenId=672b2f062ca1ad0dfcfa6a97&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0602-211111', '672b2d3c635c4850abac6e02', 'SUCCESS', '2024-11-06T08:47:57.777Z', '2024-11-06T08:55:21.223Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b2d3c635c4850abac6e02?tokenId=672b2d3c635c4850abac6e02&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209614', '672b2b56635c4850abac6dbd', 'SUCCESS', '2024-11-06T08:39:51.955Z', '2024-11-06T08:47:41.459Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b2b56635c4850abac6dbd?tokenId=672b2b56635c4850abac6dbd&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209613', '672b29672ca1ad0dfcfa69d8', 'SUCCESS', '2024-11-06T08:31:36.913Z', '2024-11-06T08:39:40.172Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b29672ca1ad0dfcfa69d8?tokenId=672b29672ca1ad0dfcfa69d8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209612', '672b278b4a384e960ff16107', 'SUCCESS', '2024-11-06T08:23:41.162Z', '2024-11-06T08:31:22.062Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b278b4a384e960ff16107?tokenId=672b278b4a384e960ff16107&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209611', '672b25a1635c4850abac6cfc', 'SUCCESS', '2024-11-06T08:15:30.367Z', '2024-11-06T08:23:29.716Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b25a1635c4850abac6cfc?tokenId=672b25a1635c4850abac6cfc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209603', '672b23b24a384e960ff16082', 'SUCCESS', '2024-11-06T08:07:15.603Z', '2024-11-06T08:15:16.619Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b23b24a384e960ff16082?tokenId=672b23b24a384e960ff16082&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209602', '672b21cd4a384e960ff1603d', 'SUCCESS', '2024-11-06T07:59:10.857Z', '2024-11-06T08:07:01.831Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b21cd4a384e960ff1603d?tokenId=672b21cd4a384e960ff1603d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209601', '672b1ff4635c4850abac6c3b', 'SUCCESS', '2024-11-06T07:51:17.552Z', '2024-11-06T07:58:58.922Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b1ff4635c4850abac6c3b?tokenId=672b1ff4635c4850abac6c3b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0596-208311', '672b1e0f635c4850abac6bf6', 'SUCCESS', '2024-11-06T07:43:13.029Z', '2024-11-06T07:51:07.125Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b1e0f635c4850abac6bf6?tokenId=672b1e0f635c4850abac6bf6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0596-208310', '672b1c214a384e960ff15f7c', 'SUCCESS', '2024-11-06T07:34:58.544Z', '2024-11-06T07:42:57.714Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b1c214a384e960ff15f7c?tokenId=672b1c214a384e960ff15f7c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0596-208309', '672b1a37635c4850abac6b71', 'SUCCESS', '2024-11-06T07:26:48.573Z', '2024-11-06T07:34:42.497Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b1a37635c4850abac6b71?tokenId=672b1a37635c4850abac6b71&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0596-208308', '672b18574a384e960ff15ef9', 'SUCCESS', '2024-11-06T07:18:48.377Z', '2024-11-06T07:26:35.972Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b18574a384e960ff15ef9?tokenId=672b18574a384e960ff15ef9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0594-208168', '672b167c635c4850abac6af0', 'SUCCESS', '2024-11-06T07:10:54.668Z', '2024-11-06T07:18:36.805Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b167c635c4850abac6af0?tokenId=672b167c635c4850abac6af0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0592-207912', '672b1498635c4850abac6aab', 'SUCCESS', '2024-11-06T07:02:49.980Z', '2024-11-06T07:10:42.134Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b1498635c4850abac6aab?tokenId=672b1498635c4850abac6aab&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0592-207911', '672b12d4635c4850abac6a6a', 'SUCCESS', '2024-11-06T06:55:17.415Z', '2024-11-06T07:02:34.981Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b12d4635c4850abac6a6a?tokenId=672b12d4635c4850abac6a6a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0591-207910', '672b10ff635c4850abac6a27', 'SUCCESS', '2024-11-06T06:47:28.888Z', '2024-11-06T06:55:02.301Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b10ff635c4850abac6a27?tokenId=672b10ff635c4850abac6a27&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0590-207909', '672b0f1f4a384e960ff15dc4', 'SUCCESS', '2024-11-06T06:39:29.273Z', '2024-11-06T06:47:17.215Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b0f1f4a384e960ff15dc4?tokenId=672b0f1f4a384e960ff15dc4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0590-207908', '672b0d35635c4850abac69a4', 'SUCCESS', '2024-11-06T06:31:18.646Z', '2024-11-06T06:39:16.588Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b0d35635c4850abac69a4?tokenId=672b0d35635c4850abac69a4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0589-207907', '672b0b5c635c4850abac6961', 'SUCCESS', '2024-11-06T06:23:25.439Z', '2024-11-06T06:31:05.737Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b0b5c635c4850abac6961?tokenId=672b0b5c635c4850abac6961&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0589-207906', '672b09622ca1ad0dfcfa65b9', 'SUCCESS', '2024-11-06T06:14:59.516Z', '2024-11-06T06:23:09.830Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b09622ca1ad0dfcfa65b9?tokenId=672b09622ca1ad0dfcfa65b9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0588-207905', '672b078e2ca1ad0dfcfa6576', 'SUCCESS', '2024-11-06T06:07:11.698Z', '2024-11-06T06:14:47.194Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b078e2ca1ad0dfcfa6576?tokenId=672b078e2ca1ad0dfcfa6576&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0587-207904', '672b05ae635c4850abac68a0', 'SUCCESS', '2024-11-06T05:59:12.847Z', '2024-11-06T06:06:58.213Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b05ae635c4850abac68a0?tokenId=672b05ae635c4850abac68a0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0587-207903', '672b03d52ca1ad0dfcfa64f5', 'SUCCESS', '2024-11-06T05:51:18.784Z', '2024-11-06T05:59:01.571Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b03d52ca1ad0dfcfa64f5?tokenId=672b03d52ca1ad0dfcfa64f5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0582-207606', '672b0013635c4850abac67da', 'SUCCESS', '2024-11-06T05:35:16.903Z', '2024-11-06T05:43:06.624Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672b0013635c4850abac67da?tokenId=672b0013635c4850abac67da&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0582-207605', '672afe04635c4850abac678f', 'SUCCESS', '2024-11-06T05:26:30.753Z', '2024-11-06T05:35:04.744Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672afe04635c4850abac678f?tokenId=672afe04635c4850abac678f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0582-207604', '672afbea2ca1ad0dfcfa63ea', 'SUCCESS', '2024-11-06T05:17:31.502Z', '2024-11-06T05:26:13.352Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672afbea2ca1ad0dfcfa63ea?tokenId=672afbea2ca1ad0dfcfa63ea&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0582-207603', '672af9dc635c4850abac6700', 'SUCCESS', '2024-11-06T05:08:45.505Z', '2024-11-06T05:17:17.777Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672af9dc635c4850abac6700?tokenId=672af9dc635c4850abac6700&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0582-207602', '672af7f22ca1ad0dfcfa6361', 'SUCCESS', '2024-11-06T05:00:35.511Z', '2024-11-06T05:08:34.667Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672af7f22ca1ad0dfcfa6361?tokenId=672af7f22ca1ad0dfcfa6361&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0579-207566', '672af6174a384e960ff15a89', 'SUCCESS', '2024-11-06T04:52:40.583Z', '2024-11-06T05:00:22.115Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672af6174a384e960ff15a89?tokenId=672af6174a384e960ff15a89&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0579-207565', '672af4334a384e960ff15a44', 'SUCCESS', '2024-11-06T04:44:36.470Z', '2024-11-06T04:52:30.407Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672af4334a384e960ff15a44?tokenId=672af4334a384e960ff15a44&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0579-207564', '672af2542ca1ad0dfcfa62a2', 'SUCCESS', '2024-11-06T04:36:37.440Z', '2024-11-06T04:44:21.129Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672af2542ca1ad0dfcfa62a2?tokenId=672af2542ca1ad0dfcfa62a2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0579-207563', '672af055635c4850abac65c1', 'SUCCESS', '2024-11-06T04:28:07.266Z', '2024-11-06T04:36:22.363Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672af055635c4850abac65c1?tokenId=672af055635c4850abac65c1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0579-207562', '672aee66635c4850abac657a', 'SUCCESS', '2024-11-06T04:19:51.552Z', '2024-11-06T04:27:52.313Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672aee66635c4850abac657a?tokenId=672aee66635c4850abac657a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0577-207533', '672aec864a384e960ff15943', 'SUCCESS', '2024-11-06T04:11:51.625Z', '2024-11-06T04:19:38.966Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672aec864a384e960ff15943?tokenId=672aec864a384e960ff15943&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0577-207532', '672aeab04a384e960ff15900', 'SUCCESS', '2024-11-06T04:04:01.855Z', '2024-11-06T04:11:36.989Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672aeab04a384e960ff15900?tokenId=672aeab04a384e960ff15900&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0577-207531', '672ae8d5635c4850abac64bd', 'SUCCESS', '2024-11-06T03:56:06.583Z', '2024-11-06T04:03:47.693Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ae8d5635c4850abac64bd?tokenId=672ae8d5635c4850abac64bd&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0577-207530', '672ae6fa2ca1ad0dfcfa6127', 'SUCCESS', '2024-11-06T03:48:12.125Z', '2024-11-06T03:55:54.583Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ae6fa2ca1ad0dfcfa6127?tokenId=672ae6fa2ca1ad0dfcfa6127&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0577-207529', '672ae52a635c4850abac643e', 'SUCCESS', '2024-11-06T03:40:28.552Z', '2024-11-06T03:47:57.683Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ae52a635c4850abac643e?tokenId=672ae52a635c4850abac643e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0577-207528', '672ae3584a384e960ff15809', 'SUCCESS', '2024-11-06T03:32:42.806Z', '2024-11-06T03:40:16.175Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ae3584a384e960ff15809?tokenId=672ae3584a384e960ff15809&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207523', '672ae1892ca1ad0dfcfa606e', 'SUCCESS', '2024-11-06T03:24:59.030Z', '2024-11-06T03:32:26.466Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ae1892ca1ad0dfcfa606e?tokenId=672ae1892ca1ad0dfcfa606e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207522', '672adfbb635c4850abac6385', 'SUCCESS', '2024-11-06T03:17:16.415Z', '2024-11-06T03:24:47.048Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672adfbb635c4850abac6385?tokenId=672adfbb635c4850abac6385&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207521', '672addeb4a384e960ff15750', 'SUCCESS', '2024-11-06T03:09:32.867Z', '2024-11-06T03:17:01.346Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672addeb4a384e960ff15750?tokenId=672addeb4a384e960ff15750&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207520', '672adc1b2ca1ad0dfcfa5fb5', 'SUCCESS', '2024-11-06T03:01:49.123Z', '2024-11-06T03:09:18.173Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672adc1b2ca1ad0dfcfa5fb5?tokenId=672adc1b2ca1ad0dfcfa5fb5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207519', '672ada514a384e960ff156d3', 'SUCCESS', '2024-11-06T02:54:11.358Z', '2024-11-06T03:01:35.792Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ada514a384e960ff156d3?tokenId=672ada514a384e960ff156d3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207518', '672ad887635c4850abac6292', 'SUCCESS', '2024-11-06T02:46:33.487Z', '2024-11-06T02:53:57.943Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ad887635c4850abac6292?tokenId=672ad887635c4850abac6292&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207517', '672ad6b2635c4850abac624f', 'SUCCESS', '2024-11-06T02:38:43.579Z', '2024-11-06T02:46:17.422Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ad6b2635c4850abac624f?tokenId=672ad6b2635c4850abac624f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207516', '672ad4dc635c4850abac620c', 'SUCCESS', '2024-11-06T02:30:54.469Z', '2024-11-06T02:38:31.407Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ad4dc635c4850abac620c?tokenId=672ad4dc635c4850abac620c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207515', '672ad2ed4a384e960ff155da', 'SUCCESS', '2024-11-06T02:22:38.274Z', '2024-11-06T02:30:37.894Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ad2ed4a384e960ff155da?tokenId=672ad2ed4a384e960ff155da&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207514', '672ad1184a384e960ff15597', 'SUCCESS', '2024-11-06T02:14:49.436Z', '2024-11-06T02:22:23.303Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ad1184a384e960ff15597?tokenId=672ad1184a384e960ff15597&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207513', '672acf472ca1ad0dfcfa5e0a', 'SUCCESS', '2024-11-06T02:07:05.187Z', '2024-11-06T02:14:35.967Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672acf472ca1ad0dfcfa5e0a?tokenId=672acf472ca1ad0dfcfa5e0a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207512', '672acd6c4a384e960ff15518', 'SUCCESS', '2024-11-06T01:59:09.417Z', '2024-11-06T02:06:52.189Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672acd6c4a384e960ff15518?tokenId=672acd6c4a384e960ff15518&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207511', '672acb80635c4850abac60d3', 'SUCCESS', '2024-11-06T01:50:57.429Z', '2024-11-06T01:58:53.864Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672acb80635c4850abac60d3?tokenId=672acb80635c4850abac60d3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207510', '672ac9ba635c4850abac6092', 'SUCCESS', '2024-11-06T01:43:24.541Z', '2024-11-06T01:50:41.713Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ac9ba635c4850abac6092?tokenId=672ac9ba635c4850abac6092&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207509', '672ac7d5635c4850abac604d', 'SUCCESS', '2024-11-06T01:35:19.168Z', '2024-11-06T01:43:07.970Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ac7d5635c4850abac604d?tokenId=672ac7d5635c4850abac604d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207508', '672ac5f1635c4850abac6008', 'SUCCESS', '2024-11-06T01:27:14.994Z', '2024-11-06T01:35:04.038Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ac5f1635c4850abac6008?tokenId=672ac5f1635c4850abac6008&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207507', '672ac3f72ca1ad0dfcfa5c91', 'SUCCESS', '2024-11-06T01:18:48.687Z', '2024-11-06T01:27:00.875Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ac3f72ca1ad0dfcfa5c91?tokenId=672ac3f72ca1ad0dfcfa5c91&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0564-204499', '672ac23d4a384e960ff153a3', 'SUCCESS', '2024-11-06T01:11:26.808Z', '2024-11-06T01:18:33.716Z', '01092-2022-01', '6710ee1b635c4850abac4b9b', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ac23d4a384e960ff153a3?tokenId=672ac23d4a384e960ff153a3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204280', '672ac05c2ca1ad0dfcfa5c14', 'SUCCESS', '2024-11-06T01:03:25.885Z', '2024-11-06T01:11:12.142Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ac05c2ca1ad0dfcfa5c14?tokenId=672ac05c2ca1ad0dfcfa5c14&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204279', '672abe7c635c4850abac5f0d', 'SUCCESS', '2024-11-06T00:55:25.762Z', '2024-11-06T01:03:11.785Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672abe7c635c4850abac5f0d?tokenId=672abe7c635c4850abac5f0d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204278', '672abca6635c4850abac5eca', 'SUCCESS', '2024-11-06T00:47:36.069Z', '2024-11-06T00:55:13.038Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672abca6635c4850abac5eca?tokenId=672abca6635c4850abac5eca&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204277', '672ababc2ca1ad0dfcfa5b55', 'SUCCESS', '2024-11-06T00:39:25.937Z', '2024-11-06T00:47:22.136Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ababc2ca1ad0dfcfa5b55?tokenId=672ababc2ca1ad0dfcfa5b55&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204276', '672ab8e24a384e960ff1526a', 'SUCCESS', '2024-11-06T00:31:31.693Z', '2024-11-06T00:39:11.749Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ab8e24a384e960ff1526a?tokenId=672ab8e24a384e960ff1526a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204275', '672ab6f34a384e960ff15223', 'SUCCESS', '2024-11-06T00:23:17.031Z', '2024-11-06T00:31:17.593Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ab6f34a384e960ff15223?tokenId=672ab6f34a384e960ff15223&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204274', '672ab5142ca1ad0dfcfa5a96', 'SUCCESS', '2024-11-06T00:15:17.756Z', '2024-11-06T00:23:02.481Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ab5142ca1ad0dfcfa5a96?tokenId=672ab5142ca1ad0dfcfa5a96&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204273', '672ab3302ca1ad0dfcfa5a51', 'SUCCESS', '2024-11-06T00:07:13.732Z', '2024-11-06T00:15:02.675Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ab3302ca1ad0dfcfa5a51?tokenId=672ab3302ca1ad0dfcfa5a51&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204272', '672ab14f635c4850abac5d4f', 'SUCCESS', '2024-11-05T23:59:12.918Z', '2024-11-06T00:07:01.915Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672ab14f635c4850abac5d4f?tokenId=672ab14f635c4850abac5d4f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204271', '672aaf4f4a384e960ff15122', 'SUCCESS', '2024-11-05T23:50:41.234Z', '2024-11-05T23:58:58.935Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672aaf4f4a384e960ff15122?tokenId=672aaf4f4a384e960ff15122&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0544-202726', '672aad85635c4850abac5ccc', 'SUCCESS', '2024-11-05T23:43:03.442Z', '2024-11-05T23:50:28.001Z', '00296-2022-01', '66f5891d94f3ecbf4e305c79', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672aad85635c4850abac5ccc?tokenId=672aad85635c4850abac5ccc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0544-202725', '672aabb64a384e960ff150a5', 'SUCCESS', '2024-11-05T23:35:20.356Z', '2024-11-05T23:42:48.696Z', '00296-2022-01', '66f5891d94f3ecbf4e305c79', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672aabb64a384e960ff150a5?tokenId=672aabb64a384e960ff150a5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0530-201385', '672aa9e14a384e960ff15062', 'SUCCESS', '2024-11-05T23:27:31.188Z', '2024-11-05T23:35:08.475Z', '01092-2022-01', '6710ee1b635c4850abac4b9b', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/672aa9e14a384e960ff15062?tokenId=672aa9e14a384e960ff15062&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209613', '671198984a384e960ff14d6f', 'SUCCESS', '2024-10-17T23:07:05.984Z', '2024-10-17T23:14:36.241Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671198984a384e960ff14d6f?tokenId=671198984a384e960ff14d6f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209612', '671196d22ca1ad0dfcfa5620', 'SUCCESS', '2024-10-17T22:59:32.029Z', '2024-10-17T23:06:50.752Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671196d22ca1ad0dfcfa5620?tokenId=671196d22ca1ad0dfcfa5620&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209611', '671195112ca1ad0dfcfa55df', 'SUCCESS', '2024-10-17T22:52:02.979Z', '2024-10-17T22:59:18.497Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671195112ca1ad0dfcfa55df?tokenId=671195112ca1ad0dfcfa55df&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209603', '671193564a384e960ff14cba', 'SUCCESS', '2024-10-17T22:44:39.730Z', '2024-10-17T22:51:52.081Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671193564a384e960ff14cba?tokenId=671193564a384e960ff14cba&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209602', '671191954a384e960ff14c79', 'SUCCESS', '2024-10-17T22:37:10.518Z', '2024-10-17T22:44:28.713Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671191954a384e960ff14c79?tokenId=671191954a384e960ff14c79&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209601', '67118fc0635c4850abac5845', 'SUCCESS', '2024-10-17T22:29:20.947Z', '2024-10-17T22:36:59.562Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67118fc0635c4850abac5845?tokenId=67118fc0635c4850abac5845&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0596-208311', '67118fab4a384e960ff14c32', 'SUCCESS', '2024-10-17T22:29:00.755Z', '2024-10-18T12:14:06.602Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67118fab4a384e960ff14c32?tokenId=67118fab4a384e960ff14c32&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0596-208310', '67118f9c635c4850abac5838', 'SUCCESS', '2024-10-17T22:28:45.721Z', '2024-10-21T10:13:35.311Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67118f9c635c4850abac5838?tokenId=67118f9c635c4850abac5838&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0596-208309', '67118f8c2ca1ad0dfcfa5520', 'SUCCESS', '2024-10-17T22:28:29.743Z', '2024-10-21T10:22:17.743Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67118f8c2ca1ad0dfcfa5520?tokenId=67118f8c2ca1ad0dfcfa5520&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0596-208308', '67118f28635c4850abac5821', 'SUCCESS', '2024-10-17T22:26:49.703Z', '2024-10-18T12:24:04.430Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67118f28635c4850abac5821?tokenId=67118f28635c4850abac5821&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0594-208168', '67118d692ca1ad0dfcfa54d0', 'SUCCESS', '2024-10-17T22:19:22.696Z', '2024-10-17T22:26:37.208Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67118d692ca1ad0dfcfa54d0?tokenId=67118d692ca1ad0dfcfa54d0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0592-207912', '67118bad635c4850abac57a6', 'SUCCESS', '2024-10-17T22:11:58.497Z', '2024-10-17T22:19:08.669Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67118bad635c4850abac57a6?tokenId=67118bad635c4850abac57a6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0592-207911', '671189ec635c4850abac5765', 'SUCCESS', '2024-10-17T22:04:29.301Z', '2024-10-17T22:11:43.284Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671189ec635c4850abac5765?tokenId=671189ec635c4850abac5765&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0591-207910', '671188214a384e960ff14b2f', 'SUCCESS', '2024-10-17T21:56:50.962Z', '2024-10-17T22:04:19.713Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671188214a384e960ff14b2f?tokenId=671188214a384e960ff14b2f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0590-207909', '671186664a384e960ff14af0', 'SUCCESS', '2024-10-17T21:49:28.265Z', '2024-10-17T21:56:41.957Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671186664a384e960ff14af0?tokenId=671186664a384e960ff14af0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0590-207908', '671184a4635c4850abac56b0', 'SUCCESS', '2024-10-17T21:41:57.876Z', '2024-10-17T21:49:08.838Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671184a4635c4850abac56b0?tokenId=671184a4635c4850abac56b0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0589-207907', '671182e1635c4850abac566f', 'SUCCESS', '2024-10-17T21:34:26.610Z', '2024-10-17T21:41:42.977Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671182e1635c4850abac566f?tokenId=671182e1635c4850abac566f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0589-207906', '671180f72ca1ad0dfcfa532d', 'SUCCESS', '2024-10-17T21:26:16.337Z', '2024-10-17T21:34:12.779Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671180f72ca1ad0dfcfa532d?tokenId=671180f72ca1ad0dfcfa532d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0588-207905', '67117f24635c4850abac55ee', 'SUCCESS', '2024-10-17T21:18:29.589Z', '2024-10-17T21:25:51.019Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67117f24635c4850abac55ee?tokenId=67117f24635c4850abac55ee&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0587-207904', '67117d5f4a384e960ff149c1', 'SUCCESS', '2024-10-17T21:10:56.509Z', '2024-10-17T21:18:16.676Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67117d5f4a384e960ff149c1?tokenId=67117d5f4a384e960ff149c1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0587-207903', '67117b992ca1ad0dfcfa5276', 'SUCCESS', '2024-10-17T21:03:22.957Z', '2024-10-17T21:10:44.930Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67117b992ca1ad0dfcfa5276?tokenId=67117b992ca1ad0dfcfa5276&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0582-207606', '671179dc4a384e960ff14946', 'SUCCESS', '2024-10-17T20:55:57.937Z', '2024-10-17T21:03:07.647Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671179dc4a384e960ff14946?tokenId=671179dc4a384e960ff14946&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0582-207605', '6711781d635c4850abac54fd', 'SUCCESS', '2024-10-17T20:48:30.499Z', '2024-10-17T20:55:44.577Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/6711781d635c4850abac54fd?tokenId=6711781d635c4850abac54fd&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0582-207604', '671176484a384e960ff148c8', 'SUCCESS', '2024-10-17T20:40:41.597Z', '2024-10-17T20:48:19.352Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671176484a384e960ff148c8?tokenId=671176484a384e960ff148c8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0577-207530', '67117610635c4850abac54b2', 'SUCCESS', '2024-10-17T20:39:45.447Z', '2024-10-17T20:47:41.123Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67117610635c4850abac54b2?tokenId=67117610635c4850abac54b2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0577-207529', '6711744e2ca1ad0dfcfa5181', 'SUCCESS', '2024-10-17T20:32:15.857Z', '2024-10-17T20:39:32.405Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/6711744e2ca1ad0dfcfa5181?tokenId=6711744e2ca1ad0dfcfa5181&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0577-207528', '6711727e2ca1ad0dfcfa513e', 'SUCCESS', '2024-10-17T20:24:32.133Z', '2024-10-17T20:32:05.840Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/6711727e2ca1ad0dfcfa513e?tokenId=6711727e2ca1ad0dfcfa513e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207523', '6711708b4a384e960ff14804', 'SUCCESS', '2024-10-17T20:16:12.707Z', '2024-10-17T20:24:18.009Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/6711708b4a384e960ff14804?tokenId=6711708b4a384e960ff14804&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207522', '67116ec12ca1ad0dfcfa50bb', 'SUCCESS', '2024-10-17T20:08:35.030Z', '2024-10-17T20:15:59.088Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67116ec12ca1ad0dfcfa50bb?tokenId=67116ec12ca1ad0dfcfa50bb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207521', '67116cea4a384e960ff14785', 'SUCCESS', '2024-10-17T20:00:43.325Z', '2024-10-17T20:08:19.194Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67116cea4a384e960ff14785?tokenId=67116cea4a384e960ff14785&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207520', '67116b0d2ca1ad0dfcfa503a', 'SUCCESS', '2024-10-17T19:52:46.489Z', '2024-10-17T20:00:28.247Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67116b0d2ca1ad0dfcfa503a?tokenId=67116b0d2ca1ad0dfcfa503a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207519', '671169434a384e960ff14706', 'SUCCESS', '2024-10-17T19:45:08.782Z', '2024-10-17T19:52:33.962Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671169434a384e960ff14706?tokenId=671169434a384e960ff14706&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207518', '67116779635c4850abac52c9', 'SUCCESS', '2024-10-17T19:37:30.480Z', '2024-10-17T19:44:48.546Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67116779635c4850abac52c9?tokenId=67116779635c4850abac52c9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207517', '671165a74a384e960ff14689', 'SUCCESS', '2024-10-17T19:29:45.494Z', '2024-10-17T19:37:12.086Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671165a74a384e960ff14689?tokenId=671165a74a384e960ff14689&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207516', '671163d74a384e960ff14646', 'SUCCESS', '2024-10-17T19:22:01.667Z', '2024-10-17T19:29:31.167Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671163d74a384e960ff14646?tokenId=671163d74a384e960ff14646&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207515', '67116201635c4850abac520e', 'SUCCESS', '2024-10-17T19:14:11.158Z', '2024-10-17T19:21:50.460Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67116201635c4850abac520e?tokenId=67116201635c4850abac520e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207514', '671160274a384e960ff145c5', 'SUCCESS', '2024-10-17T19:06:17.350Z', '2024-10-17T19:14:01.058Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671160274a384e960ff145c5?tokenId=671160274a384e960ff145c5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207513', '67115e51635c4850abac518d', 'SUCCESS', '2024-10-17T18:58:27.053Z', '2024-10-17T19:06:04.551Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67115e51635c4850abac518d?tokenId=67115e51635c4850abac518d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207512', '67115c992ca1ad0dfcfa4e55', 'SUCCESS', '2024-10-17T18:51:06.856Z', '2024-10-17T18:58:14.231Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67115c992ca1ad0dfcfa4e55?tokenId=67115c992ca1ad0dfcfa4e55&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207511', '67115ac44a384e960ff1450c', 'SUCCESS', '2024-10-17T18:43:17.749Z', '2024-10-17T18:50:43.686Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67115ac44a384e960ff1450c?tokenId=67115ac44a384e960ff1450c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207510', '671158d52ca1ad0dfcfa4dd4', 'SUCCESS', '2024-10-17T18:35:02.728Z', '2024-10-17T18:42:57.539Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671158d52ca1ad0dfcfa4dd4?tokenId=671158d52ca1ad0dfcfa4dd4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207509', '671156fe4a384e960ff14489', 'SUCCESS', '2024-10-17T18:27:11.891Z', '2024-10-17T18:34:48.086Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671156fe4a384e960ff14489?tokenId=671156fe4a384e960ff14489&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207508', '671155142ca1ad0dfcfa4d51', 'SUCCESS', '2024-10-17T18:19:01.286Z', '2024-10-17T18:26:58.326Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671155142ca1ad0dfcfa4d51?tokenId=671155142ca1ad0dfcfa4d51&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0576-207507', '67115338635c4850abac5019', 'SUCCESS', '2024-10-17T18:11:05.574Z', '2024-10-17T18:18:50.497Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67115338635c4850abac5019?tokenId=67115338635c4850abac5019&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0564-204499', '6711518c4a384e960ff143ce', 'SUCCESS', '2024-10-17T18:03:57.787Z', '2024-10-17T18:10:53.807Z', '01092-2022-01', '6710ee1b635c4850abac4b9b', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/6711518c4a384e960ff143ce?tokenId=6711518c4a384e960ff143ce&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204280', '67114fa02ca1ad0dfcfa4c96', 'SUCCESS', '2024-10-17T17:55:45.961Z', '2024-10-17T18:03:44.207Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67114fa02ca1ad0dfcfa4c96?tokenId=67114fa02ca1ad0dfcfa4c96&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204279', '67114dcb4a384e960ff1434b', 'SUCCESS', '2024-10-17T17:47:57.203Z', '2024-10-17T17:55:32.658Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67114dcb4a384e960ff1434b?tokenId=67114dcb4a384e960ff1434b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204278', '67114c1b635c4850abac4f26', 'SUCCESS', '2024-10-17T17:40:44.789Z', '2024-10-17T17:47:45.901Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67114c1b635c4850abac4f26?tokenId=67114c1b635c4850abac4f26&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204277', '67114a574a384e960ff142d0', 'SUCCESS', '2024-10-17T17:33:12.696Z', '2024-10-17T17:40:34.986Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67114a574a384e960ff142d0?tokenId=67114a574a384e960ff142d0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204276', '671148a64a384e960ff14291', 'SUCCESS', '2024-10-17T17:25:59.851Z', '2024-10-17T17:32:58.477Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671148a64a384e960ff14291?tokenId=671148a64a384e960ff14291&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204275', '67114701635c4850abac4e75', 'SUCCESS', '2024-10-17T17:18:59.076Z', '2024-10-17T17:25:50.197Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67114701635c4850abac4e75?tokenId=67114701635c4850abac4e75&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204274', '6711454b635c4850abac4e36', 'SUCCESS', '2024-10-17T17:11:41.001Z', '2024-10-17T17:18:43.334Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/6711454b635c4850abac4e36?tokenId=6711454b635c4850abac4e36&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204273', '671143902ca1ad0dfcfa4afa', 'SUCCESS', '2024-10-17T17:04:17.228Z', '2024-10-17T17:11:27.223Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671143902ca1ad0dfcfa4afa?tokenId=671143902ca1ad0dfcfa4afa&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204272', '671141d8635c4850abac4dba', 'SUCCESS', '2024-10-17T16:56:58.085Z', '2024-10-17T17:04:04.328Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671141d8635c4850abac4dba?tokenId=671141d8635c4850abac4dba&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0557-204271', '6711400d2ca1ad0dfcfa4a7c', 'SUCCESS', '2024-10-17T16:49:18.568Z', '2024-10-17T16:56:43.125Z', '00051-2022-01', '66fed6c0590a603ac0e6c6c9', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/6711400d2ca1ad0dfcfa4a7c?tokenId=6711400d2ca1ad0dfcfa4a7c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0544-202726', '671115114a384e960ff14121', 'SUCCESS', '2024-10-17T13:45:55.399Z', '2024-10-17T13:53:14.610Z', '00296-2022-01', '66f5891d94f3ecbf4e305c79', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671115114a384e960ff14121?tokenId=671115114a384e960ff14121&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0544-202725', '67110968635c4850abac4cf5', 'SUCCESS', '2024-10-17T12:56:10.156Z', '2024-10-17T13:03:10.353Z', '00296-2022-01', '66f5891d94f3ecbf4e305c79', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/67110968635c4850abac4cf5?tokenId=67110968635c4850abac4cf5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0530-201385', '671106c82ca1ad0dfcfa49eb', 'SUCCESS', '2024-10-17T12:44:57.948Z', '2024-10-17T12:51:52.144Z', '01092-2022-01', '6710ee1b635c4850abac4b9b', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/671106c82ca1ad0dfcfa49eb?tokenId=671106c82ca1ad0dfcfa49eb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0603-211116', '66ff1c4c6397a8a76222021f', 'SUCCESS', '2024-10-03T22:35:58.393Z', '2024-10-03T22:44:28.995Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff1c4c6397a8a76222021f?tokenId=66ff1c4c6397a8a76222021f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0603-211115', '66ff1a60e7bdfa8b2f3dad2f', 'SUCCESS', '2024-10-03T22:27:46.339Z', '2024-10-03T22:35:45.350Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff1a60e7bdfa8b2f3dad2f?tokenId=66ff1a60e7bdfa8b2f3dad2f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0603-211114', '66ff1855590a603ac0e6cc9b', 'SUCCESS', '2024-10-03T22:19:03.230Z', '2024-10-03T22:27:32.617Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff1855590a603ac0e6cc9b?tokenId=66ff1855590a603ac0e6cc9b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209610', '66ff1665590a603ac0e6cc54', 'SUCCESS', '2024-10-03T22:10:47.080Z', '2024-10-03T22:18:51.958Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff1665590a603ac0e6cc54?tokenId=66ff1665590a603ac0e6cc54&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209609', '66ff14866397a8a762220118', 'SUCCESS', '2024-10-03T22:02:48.186Z', '2024-10-03T22:10:33.523Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff14866397a8a762220118?tokenId=66ff14866397a8a762220118&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209608', '66ff12a0e7bdfa8b2f3dac28', 'SUCCESS', '2024-10-03T21:54:41.957Z', '2024-10-03T22:02:34.539Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff12a0e7bdfa8b2f3dac28?tokenId=66ff12a0e7bdfa8b2f3dac28&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209607', '66ff10ba590a603ac0e6cb91', 'SUCCESS', '2024-10-03T21:46:35.626Z', '2024-10-03T21:54:31.359Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff10ba590a603ac0e6cb91?tokenId=66ff10ba590a603ac0e6cb91&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209606', '66ff0ed46397a8a762220055', 'SUCCESS', '2024-10-03T21:38:29.624Z', '2024-10-03T21:46:21.854Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff0ed46397a8a762220055?tokenId=66ff0ed46397a8a762220055&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209605', '66ff0cdfe7bdfa8b2f3dab63', 'SUCCESS', '2024-10-03T21:30:08.695Z', '2024-10-03T21:38:18.595Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff0cdfe7bdfa8b2f3dab63?tokenId=66ff0cdfe7bdfa8b2f3dab63&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209604', '66ff0aede7bdfa8b2f3dab1c', 'SUCCESS', '2024-10-03T21:21:51.475Z', '2024-10-03T21:29:55.508Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff0aede7bdfa8b2f3dab1c?tokenId=66ff0aede7bdfa8b2f3dab1c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209599', '66ff09116397a8a76221ff90', 'SUCCESS', '2024-10-03T21:13:55.076Z', '2024-10-03T21:21:35.852Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff09116397a8a76221ff90?tokenId=66ff09116397a8a76221ff90&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0599-209598', '66ff072be7bdfa8b2f3daa99', 'SUCCESS', '2024-10-03T21:05:48.743Z', '2024-10-03T21:13:44.482Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff072be7bdfa8b2f3daa99?tokenId=66ff072be7bdfa8b2f3daa99&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0595-208302', '66ff071d590a603ac0e6ca4c', 'SUCCESS', '2024-10-03T21:05:34.436Z', '2024-10-10T13:39:24.618Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff071d590a603ac0e6ca4c?tokenId=66ff071d590a603ac0e6ca4c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0581-207589', '66ff06dae7bdfa8b2f3daa7d', 'SUCCESS', '2024-10-03T21:05:32.421Z', '2024-10-10T14:12:29.650Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff06dae7bdfa8b2f3daa7d?tokenId=66ff06dae7bdfa8b2f3daa7d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0593-207913', '66ff070e6397a8a76221ff45', 'SUCCESS', '2024-10-03T21:05:19.646Z', '2024-10-11T08:46:38.772Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff070e6397a8a76221ff45?tokenId=66ff070e6397a8a76221ff45&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0581-207629', '66ff0700e7bdfa8b2f3daa85', 'SUCCESS', '2024-10-03T21:05:05.543Z', '2024-10-11T09:21:06.503Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff0700e7bdfa8b2f3daa85?tokenId=66ff0700e7bdfa8b2f3daa85&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0581-207590', '66ff06ed6397a8a76221ff38', 'SUCCESS', '2024-10-03T21:04:46.545Z', '2024-10-11T09:28:36.562Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff06ed6397a8a76221ff38?tokenId=66ff06ed6397a8a76221ff38&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0581-207588', '66ff06cb6397a8a76221ff2d', 'SUCCESS', '2024-10-03T21:04:12.538Z', '2024-10-11T10:00:15.355Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff06cb6397a8a76221ff2d?tokenId=66ff06cb6397a8a76221ff2d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0581-207587', '66ff06bc590a603ac0e6ca37', 'SUCCESS', '2024-10-03T21:03:58.098Z', '2024-10-11T10:00:24.204Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff06bc590a603ac0e6ca37?tokenId=66ff06bc590a603ac0e6ca37&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0581-207586', '66ff06ace7bdfa8b2f3daa6e', 'SUCCESS', '2024-10-03T21:03:41.400Z', '2024-10-11T10:11:03.154Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff06ace7bdfa8b2f3daa6e?tokenId=66ff06ace7bdfa8b2f3daa6e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0580-207577', '66ff0698590a603ac0e6ca2a', 'SUCCESS', '2024-10-03T21:03:21.812Z', '2024-10-11T10:39:48.660Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff0698590a603ac0e6ca2a?tokenId=66ff0698590a603ac0e6ca2a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0580-207576', '66ff06846397a8a76221ff1a', 'SUCCESS', '2024-10-03T21:03:01.339Z', '2024-10-11T10:11:02.579Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff06846397a8a76221ff1a?tokenId=66ff06846397a8a76221ff1a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0580-207575', '66ff0674590a603ac0e6ca1d', 'SUCCESS', '2024-10-03T21:02:46.165Z', '2024-10-11T10:00:24.165Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff0674590a603ac0e6ca1d?tokenId=66ff0674590a603ac0e6ca1d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0578-207545', '66ff0665e7bdfa8b2f3daa5b', 'SUCCESS', '2024-10-03T21:02:31.335Z', '2024-10-11T10:00:24.294Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff0665e7bdfa8b2f3daa5b?tokenId=66ff0665e7bdfa8b2f3daa5b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0578-207544', '66ff06586397a8a76221ff0b', 'SUCCESS', '2024-10-03T21:02:17.632Z', '2024-10-11T10:11:14.020Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff06586397a8a76221ff0b?tokenId=66ff06586397a8a76221ff0b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0575-207506', '66ff0649590a603ac0e6ca0e', 'SUCCESS', '2024-10-03T21:02:03.092Z', '2024-10-11T10:00:24.705Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff0649590a603ac0e6ca0e?tokenId=66ff0649590a603ac0e6ca0e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0573-207208', '66ff042e6397a8a76221febc', 'SUCCESS', '2024-10-03T20:53:03.885Z', '2024-10-03T21:01:49.899Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff042e6397a8a76221febc?tokenId=66ff042e6397a8a76221febc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0573-207207', '66ff0230e7bdfa8b2f3da9c8', 'SUCCESS', '2024-10-03T20:44:34.102Z', '2024-10-03T20:52:48.318Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff0230e7bdfa8b2f3da9c8?tokenId=66ff0230e7bdfa8b2f3da9c8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0573-207206', '66ff003fe7bdfa8b2f3da981', 'SUCCESS', '2024-10-03T20:36:16.476Z', '2024-10-03T20:44:21.785Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ff003fe7bdfa8b2f3da981?tokenId=66ff003fe7bdfa8b2f3da981&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0573-207205', '66feff7ae7bdfa8b2f3da960', 'SUCCESS', '2024-10-03T20:32:59.462Z', '2024-10-03T20:36:04.943Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66feff7ae7bdfa8b2f3da960?tokenId=66feff7ae7bdfa8b2f3da960&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0573-207204', '66fefe8e590a603ac0e6c909', 'SUCCESS', '2024-10-03T20:29:03.422Z', '2024-10-03T20:32:48.395Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fefe8e590a603ac0e6c909?tokenId=66fefe8e590a603ac0e6c909&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0572-207198', '66fefd58590a603ac0e6c8e6', 'SUCCESS', '2024-10-03T20:23:53.850Z', '2024-10-03T20:27:16.560Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fefd58590a603ac0e6c8e6?tokenId=66fefd58590a603ac0e6c8e6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0572-207197', '66fefb9b6397a8a76221fdc1', 'SUCCESS', '2024-10-03T20:16:28.489Z', '2024-10-03T20:19:59.058Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fefb9b6397a8a76221fdc1?tokenId=66fefb9b6397a8a76221fdc1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0572-207196', '66fefa306397a8a76221fd9e', 'SUCCESS', '2024-10-03T20:10:25.842Z', '2024-10-03T20:13:51.121Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fefa306397a8a76221fd9e?tokenId=66fefa306397a8a76221fd9e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0571-207192', '66fef7ec6397a8a76221fd7b', 'SUCCESS', '2024-10-03T20:00:46.140Z', '2024-10-03T20:04:08.876Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef7ec6397a8a76221fd7b?tokenId=66fef7ec6397a8a76221fd7b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0571-207191', '66fef70ae7bdfa8b2f3da8ad', 'SUCCESS', '2024-10-03T19:56:59.739Z', '2024-10-03T20:00:25.454Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef70ae7bdfa8b2f3da8ad?tokenId=66fef70ae7bdfa8b2f3da8ad&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0571-207190', '66fef61ce7bdfa8b2f3da888', 'SUCCESS', '2024-10-03T19:53:01.564Z', '2024-10-03T19:56:40.126Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef61ce7bdfa8b2f3da888?tokenId=66fef61ce7bdfa8b2f3da888&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0563-204496', '66fef6086397a8a76221fd36', 'SUCCESS', '2024-10-03T19:52:41.269Z', '2024-10-17T09:19:21.300Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef6086397a8a76221fd36?tokenId=66fef6086397a8a76221fd36&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0563-204495', '66fef5fbe7bdfa8b2f3da87b', 'SUCCESS', '2024-10-03T19:52:28.231Z', '2024-10-17T09:28:46.333Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef5fbe7bdfa8b2f3da87b?tokenId=66fef5fbe7bdfa8b2f3da87b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0563-204494', '66fef51c6397a8a76221fd0f', 'SUCCESS', '2024-10-03T19:48:45.203Z', '2024-10-03T19:52:18.560Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef51c6397a8a76221fd0f?tokenId=66fef51c6397a8a76221fd0f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0563-204493', '66fef442e7bdfa8b2f3da83a', 'SUCCESS', '2024-10-03T19:45:07.571Z', '2024-10-03T19:48:32.762Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef442e7bdfa8b2f3da83a?tokenId=66fef442e7bdfa8b2f3da83a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0563-204492', '66fef3716397a8a76221fcd0', 'SUCCESS', '2024-10-03T19:41:39.434Z', '2024-10-03T19:44:54.644Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef3716397a8a76221fcd0?tokenId=66fef3716397a8a76221fcd0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0563-204491', '66fef292590a603ac0e6c7d7', 'SUCCESS', '2024-10-03T19:37:56.092Z', '2024-10-03T19:41:27.428Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef292590a603ac0e6c7d7?tokenId=66fef292590a603ac0e6c7d7&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0563-204490', '66fef1366397a8a76221fc8f', 'SUCCESS', '2024-10-03T19:32:08.733Z', '2024-10-03T19:35:38.121Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef1366397a8a76221fc8f?tokenId=66fef1366397a8a76221fc8f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0563-204489', '66fef03a590a603ac0e6c792', 'SUCCESS', '2024-10-03T19:27:56.473Z', '2024-10-03T19:31:53.131Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fef03a590a603ac0e6c792?tokenId=66fef03a590a603ac0e6c792&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202867', '66feef5ee7bdfa8b2f3da79f', 'SUCCESS', '2024-10-03T19:24:15.532Z', '2024-10-03T19:27:43.164Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66feef5ee7bdfa8b2f3da79f?tokenId=66feef5ee7bdfa8b2f3da79f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202866', '66feee4c590a603ac0e6c74b', 'SUCCESS', '2024-10-03T19:19:41.972Z', '2024-10-03T19:24:00.541Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66feee4c590a603ac0e6c74b?tokenId=66feee4c590a603ac0e6c74b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202863', '66feed70e7bdfa8b2f3da758', 'SUCCESS', '2024-10-03T19:16:02.499Z', '2024-10-03T19:19:29.998Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66feed70e7bdfa8b2f3da758?tokenId=66feed70e7bdfa8b2f3da758&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202855', '66feec8ae7bdfa8b2f3da733', 'SUCCESS', '2024-10-03T19:12:11.688Z', '2024-10-03T19:15:47.524Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66feec8ae7bdfa8b2f3da733?tokenId=66feec8ae7bdfa8b2f3da733&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0504-198519', '66feebb7590a603ac0e6c6ee', 'SUCCESS', '2024-10-03T19:08:41.231Z', '2024-10-03T19:11:59.088Z', '00296-2022-01', '66f5891d94f3ecbf4e305c79', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66feebb7590a603ac0e6c6ee?tokenId=66feebb7590a603ac0e6c6ee&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-24-0103-326045', '66fe83026397a8a76221fb94', 'SUCCESS', '2024-10-03T11:41:55.919Z', '2024-10-03T11:44:55.073Z', '00121-2024-01', '66fe7f3d6397a8a76221fb68', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66fe83026397a8a76221fb94?tokenId=66fe83026397a8a76221fb94&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0562-204480', '66f5e0d041f7336e4a4a9c03', 'SUCCESS', '2024-09-26T22:31:45.493Z', '2024-09-26T22:34:43.817Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5e0d041f7336e4a4a9c03?tokenId=66f5e0d041f7336e4a4a9c03&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0562-204479', '66f5dffb41f7336e4a4a9be0', 'SUCCESS', '2024-09-26T22:28:12.557Z', '2024-09-26T22:31:31.889Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5dffb41f7336e4a4a9be0?tokenId=66f5dffb41f7336e4a4a9be0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0562-204478', '66f5df1f94f3ecbf4e3067c0', 'SUCCESS', '2024-09-26T22:24:32.721Z', '2024-09-26T22:27:57.831Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5df1f94f3ecbf4e3067c0?tokenId=66f5df1f94f3ecbf4e3067c0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0561-204473', '66f5de5e41f7336e4a4a9ba3', 'SUCCESS', '2024-09-26T22:21:19.499Z', '2024-09-26T22:24:18.715Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5de5e41f7336e4a4a9ba3?tokenId=66f5de5e41f7336e4a4a9ba3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0561-204472', '66f5dd9294f3ecbf4e306785', 'SUCCESS', '2024-09-26T22:17:55.749Z', '2024-09-26T22:21:07.829Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5dd9294f3ecbf4e306785?tokenId=66f5dd9294f3ecbf4e306785&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0561-204471', '66f5dcbc41f7336e4a4a9b66', 'SUCCESS', '2024-09-26T22:14:22.142Z', '2024-09-26T22:17:37.472Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5dcbc41f7336e4a4a9b66?tokenId=66f5dcbc41f7336e4a4a9b66&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0560-204470', '66f5dbd394f3ecbf4e306744', 'SUCCESS', '2024-09-26T22:10:28.640Z', '2024-09-26T22:14:09.537Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5dbd394f3ecbf4e306744?tokenId=66f5dbd394f3ecbf4e306744&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0560-204469', '66f5dafe94f3ecbf4e306721', 'SUCCESS', '2024-09-26T22:06:55.685Z', '2024-09-26T22:10:18.609Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5dafe94f3ecbf4e306721?tokenId=66f5dafe94f3ecbf4e306721&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0559-204467', '66f5da1f1294209357f07a7e', 'SUCCESS', '2024-09-26T22:03:13.097Z', '2024-09-26T22:06:38.022Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5da1f1294209357f07a7e?tokenId=66f5da1f1294209357f07a7e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0559-204466', '66f5d95441f7336e4a4a9aed', 'SUCCESS', '2024-09-26T21:59:49.498Z', '2024-09-26T22:03:01.717Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d95441f7336e4a4a9aed?tokenId=66f5d95441f7336e4a4a9aed&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0559-204465', '66f5d88a94f3ecbf4e3066c8', 'SUCCESS', '2024-09-26T21:56:27.977Z', '2024-09-26T21:59:41.248Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d88a94f3ecbf4e3066c8?tokenId=66f5d88a94f3ecbf4e3066c8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0559-204464', '66f5d7bf1294209357f07a27', 'SUCCESS', '2024-09-26T21:53:04.396Z', '2024-09-26T21:56:14.041Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d7bf1294209357f07a27?tokenId=66f5d7bf1294209357f07a27&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0559-204463', '66f5d6ef94f3ecbf4e30668b', 'SUCCESS', '2024-09-26T21:49:36.553Z', '2024-09-26T21:52:55.284Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d6ef94f3ecbf4e30668b?tokenId=66f5d6ef94f3ecbf4e30668b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202865', '66f5d61994f3ecbf4e306668', 'SUCCESS', '2024-09-26T21:46:02.430Z', '2024-09-26T21:49:24.100Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d61994f3ecbf4e306668?tokenId=66f5d61994f3ecbf4e306668&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202864', '66f5d53d1294209357f079cc', 'SUCCESS', '2024-09-26T21:42:22.844Z', '2024-09-26T21:45:47.410Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d53d1294209357f079cc?tokenId=66f5d53d1294209357f079cc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202862', '66f5d46c1294209357f079ab', 'SUCCESS', '2024-09-26T21:38:53.889Z', '2024-09-26T21:42:11.496Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d46c1294209357f079ab?tokenId=66f5d46c1294209357f079ab&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202861', '66f5d3a51294209357f0798a', 'SUCCESS', '2024-09-26T21:35:34.529Z', '2024-09-26T21:38:38.002Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d3a51294209357f0798a?tokenId=66f5d3a51294209357f0798a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202860', '66f5d2f494f3ecbf4e3065f7', 'SUCCESS', '2024-09-26T21:32:37.407Z', '2024-09-26T21:35:24.451Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d2f494f3ecbf4e3065f7?tokenId=66f5d2f494f3ecbf4e3065f7&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202859', '66f5d2191294209357f0794f', 'SUCCESS', '2024-09-26T21:28:59.055Z', '2024-09-26T21:32:24.452Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d2191294209357f0794f?tokenId=66f5d2191294209357f0794f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202858', '66f5d1541294209357f0792e', 'SUCCESS', '2024-09-26T21:25:41.661Z', '2024-09-26T21:28:48.088Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d1541294209357f0792e?tokenId=66f5d1541294209357f0792e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202857', '66f5d08594f3ecbf4e30659e', 'SUCCESS', '2024-09-26T21:22:14.714Z', '2024-09-26T21:25:31.742Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5d08594f3ecbf4e30659e?tokenId=66f5d08594f3ecbf4e30659e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202854', '66f5ceee41f7336e4a4a9981', 'SUCCESS', '2024-09-26T21:15:28.092Z', '2024-09-26T21:18:32.437Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5ceee41f7336e4a4a9981?tokenId=66f5ceee41f7336e4a4a9981&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202853', '66f5ce0d1294209357f078b9', 'SUCCESS', '2024-09-26T21:11:42.358Z', '2024-09-26T21:15:14.930Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5ce0d1294209357f078b9?tokenId=66f5ce0d1294209357f078b9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202852', '66f5cd4241f7336e4a4a9942', 'SUCCESS', '2024-09-26T21:08:20.097Z', '2024-09-26T21:11:31.203Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5cd4241f7336e4a4a9942?tokenId=66f5cd4241f7336e4a4a9942&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202850', '66f5cb8c94f3ecbf4e3064ea', 'SUCCESS', '2024-09-26T21:01:01.320Z', '2024-09-26T21:04:37.095Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5cb8c94f3ecbf4e3064ea?tokenId=66f5cb8c94f3ecbf4e3064ea&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202849', '66f5ca9c1294209357f07840', 'SUCCESS', '2024-09-26T20:57:01.671Z', '2024-09-26T21:00:42.704Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5ca9c1294209357f07840?tokenId=66f5ca9c1294209357f07840&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202848', '66f5c9cb94f3ecbf4e3064a9', 'SUCCESS', '2024-09-26T20:53:33.203Z', '2024-09-26T20:56:51.882Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c9cb94f3ecbf4e3064a9?tokenId=66f5c9cb94f3ecbf4e3064a9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202847', '66f5c8f741f7336e4a4a98ad', 'SUCCESS', '2024-09-26T20:50:01.352Z', '2024-09-26T20:53:20.412Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c8f741f7336e4a4a98ad?tokenId=66f5c8f741f7336e4a4a98ad&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202846', '66f5c8281294209357f077e7', 'SUCCESS', '2024-09-26T20:46:33.386Z', '2024-09-26T20:49:51.280Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c8281294209357f077e7?tokenId=66f5c8281294209357f077e7&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202845', '66f5c75794f3ecbf4e306450', 'SUCCESS', '2024-09-26T20:43:04.652Z', '2024-09-26T20:46:23.349Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c75794f3ecbf4e306450?tokenId=66f5c75794f3ecbf4e306450&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0547-202844', '66f5c68741f7336e4a4a9854', 'SUCCESS', '2024-09-26T20:39:36.591Z', '2024-09-26T20:42:51.485Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c68741f7336e4a4a9854?tokenId=66f5c68741f7336e4a4a9854&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0538-202218', '66f5c5c041f7336e4a4a9833', 'SUCCESS', '2024-09-26T20:36:17.074Z', '2024-09-26T20:39:25.105Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c5c041f7336e4a4a9833?tokenId=66f5c5c041f7336e4a4a9833&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0532-201392', '66f5c4fa41f7336e4a4a9812', 'SUCCESS', '2024-09-26T20:32:59.612Z', '2024-09-26T20:36:06.269Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c4fa41f7336e4a4a9812?tokenId=66f5c4fa41f7336e4a4a9812&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201281', '66f5c43441f7336e4a4a97f1', 'SUCCESS', '2024-09-26T20:29:41.888Z', '2024-09-26T20:32:45.891Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c43441f7336e4a4a97f1?tokenId=66f5c43441f7336e4a4a97f1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201280', '66f5c36f41f7336e4a4a97d0', 'SUCCESS', '2024-09-26T20:26:24.551Z', '2024-09-26T20:29:32.621Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c36f41f7336e4a4a97d0?tokenId=66f5c36f41f7336e4a4a97d0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201276', '66f5c29841f7336e4a4a97ad', 'SUCCESS', '2024-09-26T20:22:49.792Z', '2024-09-26T20:26:12.026Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c29841f7336e4a4a97ad?tokenId=66f5c29841f7336e4a4a97ad&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201275', '66f5c1a91294209357f07706', 'SUCCESS', '2024-09-26T20:18:50.205Z', '2024-09-26T20:22:38.490Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c1a91294209357f07706?tokenId=66f5c1a91294209357f07706&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201266', '66f5c1601294209357f076f5', 'SUCCESS', '2024-09-26T20:17:37.423Z', '2024-09-26T20:18:37.610Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c1601294209357f076f5?tokenId=66f5c1601294209357f076f5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201263', '66f5c1161294209357f076e4', 'SUCCESS', '2024-09-26T20:16:24.670Z', '2024-09-26T20:17:23.531Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c1161294209357f076e4?tokenId=66f5c1161294209357f076e4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0527-201004', '66f5c0cd1294209357f076d3', 'SUCCESS', '2024-09-26T20:15:10.617Z', '2024-09-26T20:16:11.021Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c0cd1294209357f076d3?tokenId=66f5c0cd1294209357f076d3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0524-199971', '66f5c0051294209357f076b2', 'SUCCESS', '2024-09-26T20:11:51.020Z', '2024-09-26T20:14:58.039Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5c0051294209357f076b2?tokenId=66f5c0051294209357f076b2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0524-199970', '66f5bf2094f3ecbf4e306335', 'SUCCESS', '2024-09-26T20:08:01.675Z', '2024-09-26T20:11:31.458Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5bf2094f3ecbf4e306335?tokenId=66f5bf2094f3ecbf4e306335&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0517-199502', '66f5bed994f3ecbf4e306324', 'SUCCESS', '2024-09-26T20:06:50.368Z', '2024-09-26T20:07:49.692Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5bed994f3ecbf4e306324?tokenId=66f5bed994f3ecbf4e306324&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0517-199501', '66f5be9094f3ecbf4e306313', 'SUCCESS', '2024-09-26T20:05:37.851Z', '2024-09-26T20:06:36.650Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5be9094f3ecbf4e306313?tokenId=66f5be9094f3ecbf4e306313&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0517-199500', '66f5bdf994f3ecbf4e3062f8', 'SUCCESS', '2024-09-26T20:03:07.308Z', '2024-09-26T20:05:26.975Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5bdf994f3ecbf4e3062f8?tokenId=66f5bdf994f3ecbf4e3062f8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0517-199499', '66f5bd2841f7336e4a4a96ee', 'SUCCESS', '2024-09-26T19:59:38.167Z', '2024-09-26T20:02:56.455Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5bd2841f7336e4a4a96ee?tokenId=66f5bd2841f7336e4a4a96ee&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0517-199498', '66f5bc5341f7336e4a4a96cb', 'SUCCESS', '2024-09-26T19:56:04.912Z', '2024-09-26T19:59:24.677Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5bc5341f7336e4a4a96cb?tokenId=66f5bc5341f7336e4a4a96cb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0517-199497', '66f5bb8794f3ecbf4e30629f', 'SUCCESS', '2024-09-26T19:52:40.467Z', '2024-09-26T19:55:50.693Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5bb8794f3ecbf4e30629f?tokenId=66f5bb8794f3ecbf4e30629f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0517-199496', '66f5bab194f3ecbf4e30627c', 'SUCCESS', '2024-09-26T19:49:06.696Z', '2024-09-26T19:52:28.543Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5bab194f3ecbf4e30627c?tokenId=66f5bab194f3ecbf4e30627c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0517-199495', '66f5b9d71294209357f075db', 'SUCCESS', '2024-09-26T19:45:28.506Z', '2024-09-26T19:48:56.300Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b9d71294209357f075db?tokenId=66f5b9d71294209357f075db&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0517-199494', '66f5b8fb41f7336e4a4a9654', 'SUCCESS', '2024-09-26T19:41:49.311Z', '2024-09-26T19:45:15.864Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b8fb41f7336e4a4a9654?tokenId=66f5b8fb41f7336e4a4a9654&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0517-199493', '66f5b82694f3ecbf4e30621f', 'SUCCESS', '2024-09-26T19:38:15.643Z', '2024-09-26T19:41:36.306Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b82694f3ecbf4e30621f?tokenId=66f5b82694f3ecbf4e30621f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198755', '66f5b75c41f7336e4a4a9617', 'SUCCESS', '2024-09-26T19:34:53.565Z', '2024-09-26T19:38:04.153Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b75c41f7336e4a4a9617?tokenId=66f5b75c41f7336e4a4a9617&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198752', '66f5b6901294209357f07566', 'SUCCESS', '2024-09-26T19:31:30.497Z', '2024-09-26T19:34:40.133Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b6901294209357f07566?tokenId=66f5b6901294209357f07566&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198509', '66f5b5c394f3ecbf4e3061c8', 'SUCCESS', '2024-09-26T19:28:05.018Z', '2024-09-26T19:31:17.994Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b5c394f3ecbf4e3061c8?tokenId=66f5b5c394f3ecbf4e3061c8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198508', '66f5b4ee94f3ecbf4e3061a5', 'SUCCESS', '2024-09-26T19:24:32.111Z', '2024-09-26T19:27:51.034Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b4ee94f3ecbf4e3061a5?tokenId=66f5b4ee94f3ecbf4e3061a5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198507', '66f5b41d1294209357f0750d', 'SUCCESS', '2024-09-26T19:21:03.549Z', '2024-09-26T19:24:18.276Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b41d1294209357f0750d?tokenId=66f5b41d1294209357f0750d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198506', '66f5b34194f3ecbf4e306166', 'SUCCESS', '2024-09-26T19:17:22.808Z', '2024-09-26T19:20:47.245Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b34194f3ecbf4e306166?tokenId=66f5b34194f3ecbf4e306166&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0500-198482', '66f5b2601294209357f074cc', 'SUCCESS', '2024-09-26T19:13:38.306Z', '2024-09-26T19:17:10.405Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b2601294209357f074cc?tokenId=66f5b2601294209357f074cc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0500-198481', '66f5b18c1294209357f074a9', 'SUCCESS', '2024-09-26T19:10:05.828Z', '2024-09-26T19:13:27.038Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b18c1294209357f074a9?tokenId=66f5b18c1294209357f074a9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198007', '66f5b0b71294209357f07486', 'SUCCESS', '2024-09-26T19:06:32.999Z', '2024-09-26T19:09:55.100Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5b0b71294209357f07486?tokenId=66f5b0b71294209357f07486&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198006', '66f5afdd1294209357f07463', 'SUCCESS', '2024-09-26T19:02:55.818Z', '2024-09-26T19:06:16.988Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5afdd1294209357f07463?tokenId=66f5afdd1294209357f07463&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198005', '66f5af0b41f7336e4a4a94fa', 'SUCCESS', '2024-09-26T18:59:25.505Z', '2024-09-26T19:02:39.688Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5af0b41f7336e4a4a94fa?tokenId=66f5af0b41f7336e4a4a94fa&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198004', '66f5ae3c94f3ecbf4e3060b7', 'SUCCESS', '2024-09-26T18:55:58.064Z', '2024-09-26T18:59:14.479Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5ae3c94f3ecbf4e3060b7?tokenId=66f5ae3c94f3ecbf4e3060b7&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198003', '66f5ad7041f7336e4a4a94bd', 'SUCCESS', '2024-09-26T18:52:34.274Z', '2024-09-26T18:55:46.306Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5ad7041f7336e4a4a94bd?tokenId=66f5ad7041f7336e4a4a94bd&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198001', '66f5abeb94f3ecbf4e306062', 'SUCCESS', '2024-09-26T18:46:04.568Z', '2024-09-26T18:49:01.210Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5abeb94f3ecbf4e306062?tokenId=66f5abeb94f3ecbf4e306062&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198000', '66f5ab291294209357f073b7', 'SUCCESS', '2024-09-26T18:42:50.659Z', '2024-09-26T18:45:48.954Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5ab291294209357f073b7?tokenId=66f5ab291294209357f073b7&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196319', '66f5aa6741f7336e4a4a9450', 'SUCCESS', '2024-09-26T18:39:37.284Z', '2024-09-26T18:42:37.989Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5aa6741f7336e4a4a9450?tokenId=66f5aa6741f7336e4a4a9450&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196318', '66f5a98e1294209357f0737a', 'SUCCESS', '2024-09-26T18:35:59.658Z', '2024-09-26T18:39:23.924Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5a98e1294209357f0737a?tokenId=66f5a98e1294209357f0737a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196317', '66f5a8c494f3ecbf4e305ff1', 'SUCCESS', '2024-09-26T18:32:37.285Z', '2024-09-26T18:35:47.556Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5a8c494f3ecbf4e305ff1?tokenId=66f5a8c494f3ecbf4e305ff1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196316', '66f5a7e941f7336e4a4a93f5', 'SUCCESS', '2024-09-26T18:28:59.185Z', '2024-09-26T18:32:23.085Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5a7e941f7336e4a4a93f5?tokenId=66f5a7e941f7336e4a4a93f5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196315', '66f5a71a94f3ecbf4e305fb2', 'SUCCESS', '2024-09-26T18:25:31.204Z', '2024-09-26T18:28:47.122Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5a71a94f3ecbf4e305fb2?tokenId=66f5a71a94f3ecbf4e305fb2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196314', '66f5a65041f7336e4a4a93b8', 'SUCCESS', '2024-09-26T18:22:09.932Z', '2024-09-26T18:25:19.995Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5a65041f7336e4a4a93b8?tokenId=66f5a65041f7336e4a4a93b8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198006', '66f597c81294209357f07132', 'SUCCESS', '2024-09-26T17:20:09.128Z', '2024-09-26T18:05:58.183Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f597c81294209357f07132?tokenId=66f597c81294209357f07132&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198005', '66f597b394f3ecbf4e305dd0', 'SUCCESS', '2024-09-26T17:19:48.361Z', '2024-09-26T18:02:44.081Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f597b394f3ecbf4e305dd0?tokenId=66f597b394f3ecbf4e305dd0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198004', '66f597a41294209357f07125', 'SUCCESS', '2024-09-26T17:19:33.788Z', '2024-09-26T17:54:37.669Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f597a41294209357f07125?tokenId=66f597a41294209357f07125&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198003', '66f5978f94f3ecbf4e305dc3', 'SUCCESS', '2024-09-26T17:19:13.369Z', '2024-09-26T17:50:12.587Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5978f94f3ecbf4e305dc3?tokenId=66f5978f94f3ecbf4e305dc3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198002', '66f596aa41f7336e4a4a9201', 'SUCCESS', '2024-09-26T17:15:23.885Z', '2024-09-26T17:18:59.575Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f596aa41f7336e4a4a9201?tokenId=66f596aa41f7336e4a4a9201&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198001', '66f595c094f3ecbf4e305d80', 'SUCCESS', '2024-09-26T17:11:29.639Z', '2024-09-26T17:15:13.018Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f595c094f3ecbf4e305d80?tokenId=66f595c094f3ecbf4e305d80&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198000', '66f594ea94f3ecbf4e305d5d', 'SUCCESS', '2024-09-26T17:07:56.140Z', '2024-09-26T17:11:16.808Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f594ea94f3ecbf4e305d5d?tokenId=66f594ea94f3ecbf4e305d5d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196319', '66f5940f1294209357f070a4', 'SUCCESS', '2024-09-26T17:04:16.388Z', '2024-09-26T17:07:42.413Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5940f1294209357f070a4?tokenId=66f5940f1294209357f070a4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196318', '66f5932a1294209357f0707f', 'SUCCESS', '2024-09-26T17:00:27.717Z', '2024-09-26T17:04:02.639Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5932a1294209357f0707f?tokenId=66f5932a1294209357f0707f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196317', '66f5923d41f7336e4a4a9166', 'SUCCESS', '2024-09-26T16:56:30.903Z', '2024-09-26T17:00:12.524Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5923d41f7336e4a4a9166?tokenId=66f5923d41f7336e4a4a9166&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196316', '66f5914d1294209357f0703a', 'SUCCESS', '2024-09-26T16:52:30.736Z', '2024-09-26T16:56:19.630Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f5914d1294209357f0703a?tokenId=66f5914d1294209357f0703a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196315', '66f590741294209357f07017', 'SUCCESS', '2024-09-26T16:48:54.388Z', '2024-09-26T16:52:18.155Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f590741294209357f07017?tokenId=66f590741294209357f07017&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196314', '66f58f901294209357f06ff2', 'SUCCESS', '2024-09-26T16:45:05.847Z', '2024-09-26T16:48:44.135Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66f58f901294209357f06ff2?tokenId=66f58f901294209357f06ff2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0545-202819', '66ed67201294209357f05fc4', 'SUCCESS', '2024-09-20T12:14:25.831Z', '2024-09-20T14:40:14.605Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed67201294209357f05fc4?tokenId=66ed67201294209357f05fc4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0545-202818', '66ed671141f7336e4a4a80b5', 'SUCCESS', '2024-09-20T12:14:10.583Z', '2024-09-23T01:06:41.957Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed671141f7336e4a4a80b5?tokenId=66ed671141f7336e4a4a80b5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0540-202268', '66ed670494f3ecbf4e304c26', 'SUCCESS', '2024-09-20T12:13:57.977Z', '2024-09-23T09:33:32.722Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed670494f3ecbf4e304c26?tokenId=66ed670494f3ecbf4e304c26&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0540-202267', '66ed66f41294209357f05fb5', 'SUCCESS', '2024-09-20T12:13:41.666Z', '2024-09-23T10:26:45.673Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed66f41294209357f05fb5?tokenId=66ed66f41294209357f05fb5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0539-202233', '66ed66e641f7336e4a4a80a6', 'SUCCESS', '2024-09-20T12:13:27.436Z', '2024-09-23T09:37:30.439Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed66e641f7336e4a4a80a6?tokenId=66ed66e641f7336e4a4a80a6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0539-202232', '66ed66d21294209357f05fa8', 'SUCCESS', '2024-09-20T12:13:07.874Z', '2024-09-23T09:41:06.124Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed66d21294209357f05fa8?tokenId=66ed66d21294209357f05fa8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0539-202231', '66ed66bf94f3ecbf4e304c13', 'SUCCESS', '2024-09-20T12:12:48.764Z', '2024-09-23T09:45:05.609Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed66bf94f3ecbf4e304c13?tokenId=66ed66bf94f3ecbf4e304c13&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0538-202220', '66ed66b01294209357f05f9b', 'SUCCESS', '2024-09-20T12:12:33.905Z', '2024-09-23T09:49:21.013Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed66b01294209357f05f9b?tokenId=66ed66b01294209357f05f9b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0538-202219', '66ed66a141f7336e4a4a8093', 'SUCCESS', '2024-09-20T12:12:18.139Z', '2024-09-23T09:52:56.963Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed66a141f7336e4a4a8093?tokenId=66ed66a141f7336e4a4a8093&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0538-202218', '66ed669194f3ecbf4e304c04', 'SUCCESS', '2024-09-20T12:12:03.643Z', '2024-09-24T16:59:36.708Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed669194f3ecbf4e304c04?tokenId=66ed669194f3ecbf4e304c04&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0538-202217', '66ed66841294209357f05f8c', 'SUCCESS', '2024-09-20T12:11:49.428Z', '2024-09-23T10:00:46.001Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed66841294209357f05f8c?tokenId=66ed66841294209357f05f8c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0538-202216', '66ed667541f7336e4a4a8084', 'SUCCESS', '2024-09-20T12:11:34.875Z', '2024-09-23T10:04:44.569Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed667541f7336e4a4a8084?tokenId=66ed667541f7336e4a4a8084&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0534-201409', '66ed66621294209357f05f7f', 'SUCCESS', '2024-09-20T12:11:15.982Z', '2024-09-23T01:20:47.784Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed66621294209357f05f7f?tokenId=66ed66621294209357f05f7f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0531-201389', '66ed665341f7336e4a4a8077', 'SUCCESS', '2024-09-20T12:11:00.440Z', '2024-09-23T01:20:49.274Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed665341f7336e4a4a8077?tokenId=66ed665341f7336e4a4a8077&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0531-201388', '66ed65c21294209357f05f62', 'SUCCESS', '2024-09-20T12:08:35.263Z', '2024-09-23T01:28:32.335Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed65c21294209357f05f62?tokenId=66ed65c21294209357f05f62&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201279', '66ed65a041f7336e4a4a8058', 'SUCCESS', '2024-09-20T12:08:01.398Z', '2024-09-23T01:36:02.704Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed65a041f7336e4a4a8058?tokenId=66ed65a041f7336e4a4a8058&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201278', '66ed659294f3ecbf4e304bd9', 'SUCCESS', '2024-09-20T12:07:47.505Z', '2024-09-23T01:40:55.689Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed659294f3ecbf4e304bd9?tokenId=66ed659294f3ecbf4e304bd9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201277', '66ed657d41f7336e4a4a804b', 'SUCCESS', '2024-09-20T12:07:26.351Z', '2024-09-23T01:44:35.959Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed657d41f7336e4a4a804b?tokenId=66ed657d41f7336e4a4a804b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201274', '66ed656e94f3ecbf4e304bcc', 'SUCCESS', '2024-09-20T12:07:11.087Z', '2024-09-23T01:48:26.763Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed656e94f3ecbf4e304bcc?tokenId=66ed656e94f3ecbf4e304bcc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201273', '66ed655f1294209357f05f4d', 'SUCCESS', '2024-09-20T12:06:56.023Z', '2024-09-23T01:52:30.547Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed655f1294209357f05f4d?tokenId=66ed655f1294209357f05f4d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201272', '66ed655041f7336e4a4a803c', 'SUCCESS', '2024-09-20T12:06:41.193Z', '2024-09-23T01:56:10.548Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed655041f7336e4a4a803c?tokenId=66ed655041f7336e4a4a803c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201271', '66ed653b1294209357f05f40', 'SUCCESS', '2024-09-20T12:06:21.070Z', '2024-09-23T08:06:52.968Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed653b1294209357f05f40?tokenId=66ed653b1294209357f05f40&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201270', '66ed652b41f7336e4a4a802f', 'SUCCESS', '2024-09-20T12:06:04.832Z', '2024-09-23T08:11:11.047Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed652b41f7336e4a4a802f?tokenId=66ed652b41f7336e4a4a802f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201269', '66ed65161294209357f05f33', 'SUCCESS', '2024-09-20T12:05:43.138Z', '2024-09-23T08:15:10.556Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed65161294209357f05f33?tokenId=66ed65161294209357f05f33&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201268', '66ed650194f3ecbf4e304bb3', 'SUCCESS', '2024-09-20T12:05:22.436Z', '2024-09-23T08:19:07.641Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed650194f3ecbf4e304bb3?tokenId=66ed650194f3ecbf4e304bb3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201267', '66ed64f11294209357f05f26', 'SUCCESS', '2024-09-20T12:05:05.979Z', '2024-09-23T08:23:09.043Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed64f11294209357f05f26?tokenId=66ed64f11294209357f05f26&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201265', '66ed64dc94f3ecbf4e304ba6', 'SUCCESS', '2024-09-20T12:04:45.184Z', '2024-09-23T08:26:41.107Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed64dc94f3ecbf4e304ba6?tokenId=66ed64dc94f3ecbf4e304ba6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0528-201264', '66ed64cc1294209357f05f19', 'SUCCESS', '2024-09-20T12:04:29.995Z', '2024-09-23T08:30:43.608Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed64cc1294209357f05f19?tokenId=66ed64cc1294209357f05f19&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0527-201005', '66ed64a641f7336e4a4a8014', 'SUCCESS', '2024-09-20T12:03:51.921Z', '2024-09-23T08:33:28.187Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed64a641f7336e4a4a8014?tokenId=66ed64a641f7336e4a4a8014&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0527-201003', '66ed64831294209357f05f0a', 'SUCCESS', '2024-09-20T12:03:16.042Z', '2024-09-23T08:34:37.856Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed64831294209357f05f0a?tokenId=66ed64831294209357f05f0a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0522-199955', '66ed647094f3ecbf4e304b93', 'SUCCESS', '2024-09-20T12:02:57.648Z', '2024-09-23T10:08:24.778Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed647094f3ecbf4e304b93?tokenId=66ed647094f3ecbf4e304b93&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0522-199954', '66ed645f1294209357f05efd', 'SUCCESS', '2024-09-20T12:02:40.468Z', '2024-09-23T10:12:15.382Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed645f1294209357f05efd?tokenId=66ed645f1294209357f05efd&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0522-199953', '66ed644794f3ecbf4e304b86', 'SUCCESS', '2024-09-20T12:02:16.693Z', '2024-09-23T10:16:16.308Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed644794f3ecbf4e304b86?tokenId=66ed644794f3ecbf4e304b86&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0518-199738', '66ed64371294209357f05ef0', 'SUCCESS', '2024-09-20T12:02:00.986Z', '2024-09-23T08:35:58.156Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed64371294209357f05ef0?tokenId=66ed64371294209357f05ef0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0518-199737', '66ed642194f3ecbf4e304b79', 'SUCCESS', '2024-09-20T12:01:38.481Z', '2024-09-23T08:37:11.313Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed642194f3ecbf4e304b79?tokenId=66ed642194f3ecbf4e304b79&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198760', '66ed64141294209357f05ee3', 'SUCCESS', '2024-09-20T12:01:25.524Z', '2024-09-23T08:38:20.401Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed64141294209357f05ee3?tokenId=66ed64141294209357f05ee3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198759', '66ed640441f7336e4a4a7ff5', 'SUCCESS', '2024-09-20T12:01:09.535Z', '2024-09-23T08:39:24.715Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed640441f7336e4a4a7ff5?tokenId=66ed640441f7336e4a4a7ff5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198758', '66ed63f694f3ecbf4e304b6a', 'SUCCESS', '2024-09-20T12:00:55.883Z', '2024-09-23T08:40:41.029Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed63f694f3ecbf4e304b6a?tokenId=66ed63f694f3ecbf4e304b6a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198757', '66ed63e71294209357f05ed4', 'SUCCESS', '2024-09-20T12:00:40.892Z', '2024-09-23T08:41:52.332Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed63e71294209357f05ed4?tokenId=66ed63e71294209357f05ed4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198756', '66ed63d841f7336e4a4a7fe6', 'SUCCESS', '2024-09-20T12:00:25.861Z', '2024-09-23T08:43:09.730Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed63d841f7336e4a4a7fe6?tokenId=66ed63d841f7336e4a4a7fe6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198755', '66ed636994f3ecbf4e304b4f', 'SUCCESS', '2024-09-20T11:58:34.716Z', '2024-09-24T17:22:00.809Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed636994f3ecbf4e304b4f?tokenId=66ed636994f3ecbf4e304b4f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198754', '66ed62ba41f7336e4a4a7fb9', 'SUCCESS', '2024-09-20T11:55:39.286Z', '2024-09-20T11:58:23.436Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed62ba41f7336e4a4a7fb9?tokenId=66ed62ba41f7336e4a4a7fb9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198753', '66ed61f61294209357f05e8b', 'SUCCESS', '2024-09-20T11:52:24.546Z', '2024-09-20T11:55:25.238Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed61f61294209357f05e8b?tokenId=66ed61f61294209357f05e8b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0507-198663', '66ed614c41f7336e4a4a7f82', 'SUCCESS', '2024-09-20T11:49:33.739Z', '2024-09-20T11:52:14.741Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed614c41f7336e4a4a7f82?tokenId=66ed614c41f7336e4a4a7f82&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0507-198662', '66ed608394f3ecbf4e304ae8', 'SUCCESS', '2024-09-20T11:46:12.829Z', '2024-09-20T11:49:08.091Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed608394f3ecbf4e304ae8?tokenId=66ed608394f3ecbf4e304ae8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0507-198661', '66ed5fb71294209357f05e3a', 'SUCCESS', '2024-09-20T11:42:49.351Z', '2024-09-20T11:46:02.790Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed5fb71294209357f05e3a?tokenId=66ed5fb71294209357f05e3a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0507-198660', '66ed5f7941f7336e4a4a7f3f', 'SUCCESS', '2024-09-20T11:41:46.627Z', '2024-09-20T11:42:38.660Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed5f7941f7336e4a4a7f3f?tokenId=66ed5f7941f7336e4a4a7f3f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0537-201792', '66ed0b921294209357f05dd4', 'SUCCESS', '2024-09-20T05:43:47.785Z', '2024-09-20T05:46:55.639Z', '00112-2022-01', '66e30e507ff111da78b3851e', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed0b921294209357f05dd4?tokenId=66ed0b921294209357f05dd4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0537-201791', '66ed0ada1294209357f05db5', 'SUCCESS', '2024-09-20T05:40:43.966Z', '2024-09-20T05:43:31.913Z', '00112-2022-01', '66e30e507ff111da78b3851e', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed0ada1294209357f05db5?tokenId=66ed0ada1294209357f05db5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0537-201790', '66ed0a1a94f3ecbf4e304a2b', 'SUCCESS', '2024-09-20T05:37:31.559Z', '2024-09-20T05:40:32.309Z', '00112-2022-01', '66e30e507ff111da78b3851e', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed0a1a94f3ecbf4e304a2b?tokenId=66ed0a1a94f3ecbf4e304a2b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0535-201478', '66ed095494f3ecbf4e304a0a', 'SUCCESS', '2024-09-20T05:34:13.621Z', '2024-09-20T05:37:21.346Z', '01193-2022-01', '66e30ea919013510e44654d8', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed095494f3ecbf4e304a0a?tokenId=66ed095494f3ecbf4e304a0a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0532-201392', '66ed09451294209357f05d78', 'SUCCESS', '2024-09-20T05:33:58.157Z', '2024-09-24T17:26:41.677Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed09451294209357f05d78?tokenId=66ed09451294209357f05d78&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0524-199971', '66ed093541f7336e4a4a7e96', 'SUCCESS', '2024-09-20T05:33:42.612Z', '2024-09-24T17:05:05.183Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed093541f7336e4a4a7e96?tokenId=66ed093541f7336e4a4a7e96&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0524-199970', '66ed09221294209357f05d6b', 'SUCCESS', '2024-09-20T05:33:23.652Z', '2024-09-24T17:10:02.940Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed09221294209357f05d6b?tokenId=66ed09221294209357f05d6b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0523-199964', '66ed08de94f3ecbf4e3049f1', 'SUCCESS', '2024-09-20T05:32:16.057Z', '2024-09-20T05:33:11.608Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed08de94f3ecbf4e3049f1?tokenId=66ed08de94f3ecbf4e3049f1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0523-199963', '66ed088c41f7336e4a4a7e77', 'SUCCESS', '2024-09-20T05:30:54.148Z', '2024-09-20T05:32:04.624Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed088c41f7336e4a4a7e77?tokenId=66ed088c41f7336e4a4a7e77&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0523-199962', '66ed083f94f3ecbf4e3049d4', 'SUCCESS', '2024-09-20T05:29:36.854Z', '2024-09-20T05:30:41.704Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed083f94f3ecbf4e3049d4?tokenId=66ed083f94f3ecbf4e3049d4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0521-199948', '66ed07f994f3ecbf4e3049c3', 'SUCCESS', '2024-09-20T05:28:26.248Z', '2024-09-20T05:29:24.492Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed07f994f3ecbf4e3049c3?tokenId=66ed07f994f3ecbf4e3049c3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0520-199943', '66ed07b641f7336e4a4a7e52', 'SUCCESS', '2024-09-20T05:27:20.006Z', '2024-09-20T05:28:15.759Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed07b641f7336e4a4a7e52?tokenId=66ed07b641f7336e4a4a7e52&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0520-199942', '66ed077041f7336e4a4a7e41', 'SUCCESS', '2024-09-20T05:26:08.929Z', '2024-09-20T05:27:09.200Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed077041f7336e4a4a7e41?tokenId=66ed077041f7336e4a4a7e41&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0520-199941', '66ed072841f7336e4a4a7e30', 'SUCCESS', '2024-09-20T05:24:57.769Z', '2024-09-20T05:25:56.803Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed072841f7336e4a4a7e30?tokenId=66ed072841f7336e4a4a7e30&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0516-199307', '66ed06551294209357f05d02', 'SUCCESS', '2024-09-20T05:21:26.816Z', '2024-09-20T05:24:42.936Z', '00017-2022-01', '66e30e4ca3071766bd27dcf7', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed06551294209357f05d02?tokenId=66ed06551294209357f05d02&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198752', '66ed064741f7336e4a4a7e0b', 'SUCCESS', '2024-09-20T05:21:12.938Z', '2024-09-24T17:29:05.690Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed064741f7336e4a4a7e0b?tokenId=66ed064741f7336e4a4a7e0b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198510', '66ed063694f3ecbf4e30497e', 'SUCCESS', '2024-09-20T05:20:55.762Z', '2024-09-23T12:16:24.733Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed063694f3ecbf4e30497e?tokenId=66ed063694f3ecbf4e30497e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198509', '66ed06281294209357f05cf3', 'SUCCESS', '2024-09-20T05:20:41.176Z', '2024-09-24T17:33:23.099Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed06281294209357f05cf3?tokenId=66ed06281294209357f05cf3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198508', '66ed061a41f7336e4a4a7dfc', 'SUCCESS', '2024-09-20T05:20:27.953Z', '2024-09-24T17:39:02.157Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed061a41f7336e4a4a7dfc?tokenId=66ed061a41f7336e4a4a7dfc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198507', '66ed060294f3ecbf4e30496f', 'SUCCESS', '2024-09-20T05:20:03.791Z', '2024-09-24T17:39:32.286Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed060294f3ecbf4e30496f?tokenId=66ed060294f3ecbf4e30496f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198506', '66ed05f51294209357f05ce4', 'SUCCESS', '2024-09-20T05:19:50.589Z', '2024-09-24T17:39:42.871Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed05f51294209357f05ce4?tokenId=66ed05f51294209357f05ce4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0502-198498', '66ed05b194f3ecbf4e30495c', 'SUCCESS', '2024-09-20T05:18:42.803Z', '2024-09-20T05:19:36.002Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed05b194f3ecbf4e30495c?tokenId=66ed05b194f3ecbf4e30495c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0502-198497', '66ed05641294209357f05cc9', 'SUCCESS', '2024-09-20T05:17:25.884Z', '2024-09-20T05:18:29.868Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed05641294209357f05cc9?tokenId=66ed05641294209357f05cc9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0502-198496', '66ed052194f3ecbf4e304941', 'SUCCESS', '2024-09-20T05:16:18.452Z', '2024-09-20T05:17:15.257Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed052194f3ecbf4e304941?tokenId=66ed052194f3ecbf4e304941&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198001', '66ed049541f7336e4a4a7dad', 'SUCCESS', '2024-09-20T05:16:08.960Z', '2024-09-24T17:51:18.213Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed049541f7336e4a4a7dad?tokenId=66ed049541f7336e4a4a7dad&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198008', '66ed05141294209357f05cb6', 'SUCCESS', '2024-09-20T05:16:05.250Z', '2024-09-23T12:15:06.069Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed05141294209357f05cb6?tokenId=66ed05141294209357f05cb6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198007', '66ed050094f3ecbf4e304934', 'SUCCESS', '2024-09-20T05:15:45.625Z', '2024-09-24T17:55:30.168Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed050094f3ecbf4e304934?tokenId=66ed050094f3ecbf4e304934&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198006', '66ed04f31294209357f05ca9', 'SUCCESS', '2024-09-20T05:15:32.069Z', '2024-09-24T18:02:01.699Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed04f31294209357f05ca9?tokenId=66ed04f31294209357f05ca9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198005', '66ed04e441f7336e4a4a7dc2', 'SUCCESS', '2024-09-20T05:15:17.442Z', '2024-09-24T18:07:45.533Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed04e441f7336e4a4a7dc2?tokenId=66ed04e441f7336e4a4a7dc2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198004', '66ed04d01294209357f05c9c', 'SUCCESS', '2024-09-20T05:14:57.598Z', '2024-09-24T18:20:40.665Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed04d01294209357f05c9c?tokenId=66ed04d01294209357f05c9c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198003', '66ed04bb94f3ecbf4e304921', 'SUCCESS', '2024-09-20T05:14:37.008Z', '2024-09-24T18:26:48.455Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed04bb94f3ecbf4e304921?tokenId=66ed04bb94f3ecbf4e304921&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198002', '66ed04a841f7336e4a4a7db1', 'SUCCESS', '2024-09-20T05:14:17.689Z', '2024-09-24T18:32:11.706Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed04a841f7336e4a4a7db1?tokenId=66ed04a841f7336e4a4a7db1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198000', '66ed048494f3ecbf4e304912', 'SUCCESS', '2024-09-20T05:13:42.013Z', '2024-09-24T19:14:42.249Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed048494f3ecbf4e304912?tokenId=66ed048494f3ecbf4e304912&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197998', '66ed042694f3ecbf4e304901', 'SUCCESS', '2024-09-20T05:12:07.029Z', '2024-09-20T05:13:05.511Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed042694f3ecbf4e304901?tokenId=66ed042694f3ecbf4e304901&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197997', '66ed03de94f3ecbf4e3048f0', 'SUCCESS', '2024-09-20T05:10:55.737Z', '2024-09-20T05:11:55.185Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed03de94f3ecbf4e3048f0?tokenId=66ed03de94f3ecbf4e3048f0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197996', '66ed039594f3ecbf4e3048df', 'SUCCESS', '2024-09-20T05:09:43.324Z', '2024-09-20T05:10:45.436Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed039594f3ecbf4e3048df?tokenId=66ed039594f3ecbf4e3048df&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197995', '66ed03531294209357f05c63', 'SUCCESS', '2024-09-20T05:08:36.622Z', '2024-09-20T05:09:33.443Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed03531294209357f05c63?tokenId=66ed03531294209357f05c63&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197994', '66ed030694f3ecbf4e3048c4', 'SUCCESS', '2024-09-20T05:07:19.230Z', '2024-09-20T05:08:23.163Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed030694f3ecbf4e3048c4?tokenId=66ed030694f3ecbf4e3048c4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0112-197974', '66ed02bd94f3ecbf4e3048b3', 'SUCCESS', '2024-09-20T05:06:06.590Z', '2024-09-20T05:07:05.013Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed02bd94f3ecbf4e3048b3?tokenId=66ed02bd94f3ecbf4e3048b3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0112-197973', '66ed02791294209357f05c3e', 'SUCCESS', '2024-09-20T05:04:59.276Z', '2024-09-20T05:05:53.246Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed02791294209357f05c3e?tokenId=66ed02791294209357f05c3e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0112-197972', '66ed022a94f3ecbf4e304898', 'SUCCESS', '2024-09-20T05:03:40.224Z', '2024-09-20T05:04:43.652Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed022a94f3ecbf4e304898?tokenId=66ed022a94f3ecbf4e304898&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0112-197971', '66ed01e91294209357f05c23', 'SUCCESS', '2024-09-20T05:02:34.263Z', '2024-09-20T05:03:31.409Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed01e91294209357f05c23?tokenId=66ed01e91294209357f05c23&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0110-197489', '66ed015494f3ecbf4e304875', 'SUCCESS', '2024-09-20T05:00:07.306Z', '2024-09-20T05:02:15.626Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed015494f3ecbf4e304875?tokenId=66ed015494f3ecbf4e304875&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0110-197488', '66ed008941f7336e4a4a7d1c', 'SUCCESS', '2024-09-20T04:56:42.840Z', '2024-09-20T04:59:52.003Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ed008941f7336e4a4a7d1c?tokenId=66ed008941f7336e4a4a7d1c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0110-197487', '66ecffcd1294209357f05bd6', 'SUCCESS', '2024-09-20T04:53:34.680Z', '2024-09-20T04:56:30.973Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ecffcd1294209357f05bd6?tokenId=66ecffcd1294209357f05bd6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197440', '66ecff841294209357f05bc5', 'SUCCESS', '2024-09-20T04:52:21.730Z', '2024-09-20T04:53:22.779Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ecff841294209357f05bc5?tokenId=66ecff841294209357f05bc5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197439', '66ecfeab94f3ecbf4e304814', 'SUCCESS', '2024-09-20T04:48:44.926Z', '2024-09-20T04:52:09.686Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ecfeab94f3ecbf4e304814?tokenId=66ecfeab94f3ecbf4e304814&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197438', '66ecfddf41f7336e4a4a7cbb', 'SUCCESS', '2024-09-20T04:45:21.268Z', '2024-09-20T04:48:30.372Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ecfddf41f7336e4a4a7cbb?tokenId=66ecfddf41f7336e4a4a7cbb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197437', '66ecfd0941f7336e4a4a7c98', 'SUCCESS', '2024-09-20T04:41:46.942Z', '2024-09-20T04:45:07.789Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ecfd0941f7336e4a4a7c98?tokenId=66ecfd0941f7336e4a4a7c98&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0110-197487', '66ec9d1b41f7336e4a4a7c3b', 'SUCCESS', '2024-09-19T21:52:28.985Z', '2024-09-19T21:55:52.087Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec9d1b41f7336e4a4a7c3b?tokenId=66ec9d1b41f7336e4a4a7c3b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197440', '66ec9d0d94f3ecbf4e30477b', 'SUCCESS', '2024-09-19T21:52:14.903Z', '2024-09-24T19:20:43.161Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec9d0d94f3ecbf4e30477b?tokenId=66ec9d0d94f3ecbf4e30477b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197439', '66ec9cf241f7336e4a4a7c2e', 'SUCCESS', '2024-09-19T21:51:47.756Z', '2024-09-24T19:24:55.959Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec9cf241f7336e4a4a7c2e?tokenId=66ec9cf241f7336e4a4a7c2e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197438', '66ec9cdf94f3ecbf4e30476e', 'SUCCESS', '2024-09-19T21:51:28.519Z', '2024-09-24T19:29:24.797Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec9cdf94f3ecbf4e30476e?tokenId=66ec9cdf94f3ecbf4e30476e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197437', '66ec9cca41f7336e4a4a7c21', 'SUCCESS', '2024-09-19T21:51:07.719Z', '2024-09-24T19:33:21.432Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec9cca41f7336e4a4a7c21?tokenId=66ec9cca41f7336e4a4a7c21&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0110-197487', '66ec9c3194f3ecbf4e30475d', 'SUCCESS', '2024-09-19T21:48:34.962Z', '2024-10-17T09:36:22.765Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec9c3194f3ecbf4e30475d?tokenId=66ec9c3194f3ecbf4e30475d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197440', '66ec9c1e41f7336e4a4a7c12', 'SUCCESS', '2024-09-19T21:48:15.827Z', '2024-09-24T19:37:30.641Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec9c1e41f7336e4a4a7c12?tokenId=66ec9c1e41f7336e4a4a7c12&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197439', '66ec9c1194f3ecbf4e304750', 'SUCCESS', '2024-09-19T21:48:02.654Z', '2024-09-24T19:41:20.175Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec9c1194f3ecbf4e304750?tokenId=66ec9c1194f3ecbf4e304750&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197438', '66ec9c041294209357f05af6', 'SUCCESS', '2024-09-19T21:47:49.285Z', '2024-09-24T19:45:55.900Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec9c041294209357f05af6?tokenId=66ec9c041294209357f05af6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197437', '66ec9bf441f7336e4a4a7c03', 'SUCCESS', '2024-09-19T21:47:33.968Z', '2024-09-24T19:49:55.898Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec9bf441f7336e4a4a7c03?tokenId=66ec9bf441f7336e4a4a7c03&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0501-198490', '66ec99e141f7336e4a4a7be2', 'SUCCESS', '2024-09-19T21:38:43.077Z', '2024-09-19T21:41:45.821Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec99e141f7336e4a4a7be2?tokenId=66ec99e141f7336e4a4a7be2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0501-198489', '66ec99291294209357f05ab8', 'SUCCESS', '2024-09-19T21:35:38.298Z', '2024-09-19T21:38:34.635Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec99291294209357f05ab8?tokenId=66ec99291294209357f05ab8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0501-198488', '66ec98741294209357f05a99', 'SUCCESS', '2024-09-19T21:32:37.853Z', '2024-09-19T21:35:25.079Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec98741294209357f05a99?tokenId=66ec98741294209357f05a99&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0109-197483', '66ec97bb94f3ecbf4e3046df', 'SUCCESS', '2024-09-19T21:29:32.973Z', '2024-09-19T21:32:28.699Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec97bb94f3ecbf4e3046df?tokenId=66ec97bb94f3ecbf4e3046df&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0109-197482', '66ec96e81294209357f05a5e', 'SUCCESS', '2024-09-19T21:26:01.473Z', '2024-09-19T21:29:18.142Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec96e81294209357f05a5e?tokenId=66ec96e81294209357f05a5e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0109-197481', '66ec963641f7336e4a4a7b5f', 'SUCCESS', '2024-09-19T21:23:04.356Z', '2024-09-19T21:25:50.394Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec963641f7336e4a4a7b5f?tokenId=66ec963641f7336e4a4a7b5f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0108-197477', '66ec957794f3ecbf4e30468c', 'SUCCESS', '2024-09-19T21:19:52.877Z', '2024-09-19T21:22:52.952Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec957794f3ecbf4e30468c?tokenId=66ec957794f3ecbf4e30468c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0108-197476', '66ec94c294f3ecbf4e30466d', 'SUCCESS', '2024-09-19T21:16:51.555Z', '2024-09-19T21:19:40.027Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec94c294f3ecbf4e30466d?tokenId=66ec94c294f3ecbf4e30466d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0108-197475', '66ec940c94f3ecbf4e30464e', 'SUCCESS', '2024-09-19T21:13:49.296Z', '2024-09-19T21:16:39.380Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec940c94f3ecbf4e30464e?tokenId=66ec940c94f3ecbf4e30464e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0107-197468', '66ec934594f3ecbf4e30462d', 'SUCCESS', '2024-09-19T21:10:30.506Z', '2024-09-19T21:13:34.242Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec934594f3ecbf4e30462d?tokenId=66ec934594f3ecbf4e30462d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0107-197467', '66ec92851294209357f059c3', 'SUCCESS', '2024-09-19T21:07:19.234Z', '2024-09-19T21:10:19.793Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec92851294209357f059c3?tokenId=66ec92851294209357f059c3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0107-197466', '66ec91cb94f3ecbf4e3045f4', 'SUCCESS', '2024-09-19T21:04:12.913Z', '2024-09-19T21:07:09.759Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec91cb94f3ecbf4e3045f4?tokenId=66ec91cb94f3ecbf4e3045f4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0106-197457', '66ec910694f3ecbf4e3045d3', 'SUCCESS', '2024-09-19T21:00:56.033Z', '2024-09-19T21:04:01.585Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec910694f3ecbf4e3045d3?tokenId=66ec910694f3ecbf4e3045d3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0106-197456', '66ec904094f3ecbf4e3045b2', 'SUCCESS', '2024-09-19T20:57:37.611Z', '2024-09-19T21:00:41.958Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec904094f3ecbf4e3045b2?tokenId=66ec904094f3ecbf4e3045b2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0106-197455', '66ec8f7b94f3ecbf4e304591', 'SUCCESS', '2024-09-19T20:54:20.876Z', '2024-09-19T20:57:27.323Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec8f7b94f3ecbf4e304591?tokenId=66ec8f7b94f3ecbf4e304591&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0106-197454', '66ec8ec794f3ecbf4e304572', 'SUCCESS', '2024-09-19T20:51:20.221Z', '2024-09-19T20:54:10.356Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec8ec794f3ecbf4e304572?tokenId=66ec8ec794f3ecbf4e304572&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0106-197453', '66ec8dfe41f7336e4a4a7a42', 'SUCCESS', '2024-09-19T20:47:59.979Z', '2024-09-19T20:51:12.103Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec8dfe41f7336e4a4a7a42?tokenId=66ec8dfe41f7336e4a4a7a42&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197213', '66ec8d4e94f3ecbf4e304539', 'SUCCESS', '2024-09-19T20:45:03.409Z', '2024-09-19T20:47:49.035Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec8d4e94f3ecbf4e304539?tokenId=66ec8d4e94f3ecbf4e304539&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197212', '66ec8c8994f3ecbf4e304518', 'SUCCESS', '2024-09-19T20:41:46.850Z', '2024-09-19T20:44:52.726Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec8c8994f3ecbf4e304518?tokenId=66ec8c8994f3ecbf4e304518&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197211', '66ec8bbe41f7336e4a4a79ef', 'SUCCESS', '2024-09-19T20:38:23.779Z', '2024-09-19T20:41:36.001Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec8bbe41f7336e4a4a79ef?tokenId=66ec8bbe41f7336e4a4a79ef&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197210', '66ec8af841f7336e4a4a79ce', 'SUCCESS', '2024-09-19T20:35:06.009Z', '2024-09-19T20:38:10.020Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec8af841f7336e4a4a79ce?tokenId=66ec8af841f7336e4a4a79ce&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197209', '66ec8a3341f7336e4a4a79ad', 'SUCCESS', '2024-09-19T20:31:48.592Z', '2024-09-19T20:34:52.681Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec8a3341f7336e4a4a79ad?tokenId=66ec8a3341f7336e4a4a79ad&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197208', '66ec897c41f7336e4a4a798e', 'SUCCESS', '2024-09-19T20:28:46.062Z', '2024-09-19T20:31:32.820Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec897c41f7336e4a4a798e?tokenId=66ec897c41f7336e4a4a798e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197207', '66ec88c741f7336e4a4a796f', 'SUCCESS', '2024-09-19T20:25:44.746Z', '2024-09-19T20:28:35.711Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec88c741f7336e4a4a796f?tokenId=66ec88c741f7336e4a4a796f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196319', '66ec88b61294209357f05870', 'SUCCESS', '2024-09-19T20:25:27.737Z', '2024-09-24T20:31:34.041Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec88b61294209357f05870?tokenId=66ec88b61294209357f05870&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196318', '66ec88a794f3ecbf4e30448d', 'SUCCESS', '2024-09-19T20:25:12.635Z', '2024-09-24T20:27:52.004Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec88a794f3ecbf4e30448d?tokenId=66ec88a794f3ecbf4e30448d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196317', '66ec889941f7336e4a4a7960', 'SUCCESS', '2024-09-19T20:24:58.595Z', '2024-09-24T20:23:17.631Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec889941f7336e4a4a7960?tokenId=66ec889941f7336e4a4a7960&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196316', '66ec888594f3ecbf4e304480', 'SUCCESS', '2024-09-19T20:24:38.749Z', '2024-09-24T20:13:31.846Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec888594f3ecbf4e304480?tokenId=66ec888594f3ecbf4e304480&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196315', '66ec886b1294209357f0585d', 'SUCCESS', '2024-09-19T20:24:12.874Z', '2024-09-24T20:09:37.993Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec886b1294209357f0585d?tokenId=66ec886b1294209357f0585d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196314', '66ec87961294209357f0583a', 'SUCCESS', '2024-09-19T20:20:39.439Z', '2024-09-24T20:02:06.558Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec87961294209357f0583a?tokenId=66ec87961294209357f0583a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196313', '66ec86e11294209357f0581b', 'SUCCESS', '2024-09-19T20:17:38.540Z', '2024-09-19T20:20:26.363Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec86e11294209357f0581b?tokenId=66ec86e11294209357f0581b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196312', '66ec861041f7336e4a4a7903', 'SUCCESS', '2024-09-19T20:14:10.264Z', '2024-09-19T20:17:23.307Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec861041f7336e4a4a7903?tokenId=66ec861041f7336e4a4a7903&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196311', '66ec855c41f7336e4a4a78e4', 'SUCCESS', '2024-09-19T20:11:09.400Z', '2024-09-19T20:14:01.154Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec855c41f7336e4a4a78e4?tokenId=66ec855c41f7336e4a4a78e4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196310', '66ec82eb41f7336e4a4a78b6', 'SUCCESS', '2024-09-19T20:00:44.931Z', '2024-09-19T20:04:06.164Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec82eb41f7336e4a4a78b6?tokenId=66ec82eb41f7336e4a4a78b6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196309', '66ec821f1294209357f057a1', 'SUCCESS', '2024-09-19T19:57:21.099Z', '2024-09-19T20:00:34.354Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec821f1294209357f057a1?tokenId=66ec821f1294209357f057a1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196308', '66ec814e41f7336e4a4a7879', 'SUCCESS', '2024-09-19T19:53:51.526Z', '2024-09-19T19:57:07.923Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec814e41f7336e4a4a7879?tokenId=66ec814e41f7336e4a4a7879&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196307', '66ec80921294209357f05766', 'SUCCESS', '2024-09-19T19:50:43.624Z', '2024-09-19T19:53:40.445Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec80921294209357f05766?tokenId=66ec80921294209357f05766&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196306', '66ec7fb994f3ecbf4e304382', 'SUCCESS', '2024-09-19T19:47:06.809Z', '2024-09-19T19:50:32.875Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec7fb994f3ecbf4e304382?tokenId=66ec7fb994f3ecbf4e304382&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196305', '66ec7eef41f7336e4a4a7822', 'SUCCESS', '2024-09-19T19:43:45.016Z', '2024-09-19T19:46:54.863Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec7eef41f7336e4a4a7822?tokenId=66ec7eef41f7336e4a4a7822&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196304', '66ec7e241294209357f0570d', 'SUCCESS', '2024-09-19T19:40:22.256Z', '2024-09-19T19:43:34.329Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec7e241294209357f0570d?tokenId=66ec7e241294209357f0570d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196303', '66ec7d6894f3ecbf4e30432d', 'SUCCESS', '2024-09-19T19:37:14.004Z', '2024-09-19T19:40:10.969Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec7d6894f3ecbf4e30432d?tokenId=66ec7d6894f3ecbf4e30432d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196303', '66ec6c4394f3ecbf4e304312', 'SUCCESS', '2024-09-19T18:24:04.323Z', '2024-09-24T19:53:41.927Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec6c4394f3ecbf4e304312?tokenId=66ec6c4394f3ecbf4e304312&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196302', '66ec6b8d41f7336e4a4a77bb', 'SUCCESS', '2024-09-19T18:21:03.126Z', '2024-09-19T18:23:48.330Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec6b8d41f7336e4a4a77bb?tokenId=66ec6b8d41f7336e4a4a77bb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196301', '66ec6ac341f7336e4a4a779a', 'SUCCESS', '2024-09-19T18:17:40.861Z', '2024-09-19T18:20:46.018Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec6ac341f7336e4a4a779a?tokenId=66ec6ac341f7336e4a4a779a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0099-196274', '66ec6a041294209357f0568e', 'SUCCESS', '2024-09-19T18:14:30.125Z', '2024-09-19T18:17:29.219Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec6a041294209357f0568e?tokenId=66ec6a041294209357f0568e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0099-196273', '66ec69471294209357f0566f', 'SUCCESS', '2024-09-19T18:11:20.303Z', '2024-09-19T18:14:09.737Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec69471294209357f0566f?tokenId=66ec69471294209357f0566f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0099-196272', '66ec68721294209357f0564c', 'SUCCESS', '2024-09-19T18:07:48.136Z', '2024-09-19T18:11:07.549Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec68721294209357f0564c?tokenId=66ec68721294209357f0564c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0099-196271', '66ec67bd1294209357f0562d', 'SUCCESS', '2024-09-19T18:04:46.772Z', '2024-09-19T18:07:35.991Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec67bd1294209357f0562d?tokenId=66ec67bd1294209357f0562d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0099-196270', '66ec66e141f7336e4a4a7711', 'SUCCESS', '2024-09-19T18:01:06.203Z', '2024-09-19T18:04:33.476Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec66e141f7336e4a4a7711?tokenId=66ec66e141f7336e4a4a7711&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0098-196264', '66ec66111294209357f055ec', 'SUCCESS', '2024-09-19T17:57:38.773Z', '2024-09-19T18:00:55.837Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec66111294209357f055ec?tokenId=66ec66111294209357f055ec&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0098-196263', '66ec654294f3ecbf4e304223', 'SUCCESS', '2024-09-19T17:54:11.602Z', '2024-09-19T17:57:26.373Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec654294f3ecbf4e304223?tokenId=66ec654294f3ecbf4e304223&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197439', '66ec60d51294209357f055a9', 'SUCCESS', '2024-09-19T17:35:18.376Z', '2024-09-19T17:38:29.097Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec60d51294209357f055a9?tokenId=66ec60d51294209357f055a9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197439', '66ec5f9694f3ecbf4e3041eb', 'SUCCESS', '2024-09-19T17:29:59.532Z', '2024-09-19T17:33:11.195Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec5f9694f3ecbf4e3041eb?tokenId=66ec5f9694f3ecbf4e3041eb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197439', '66ec5f4f94f3ecbf4e3041e2', 'SUCCESS', '2024-09-19T17:28:49.450Z', '2024-09-19T17:31:58.695Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec5f4f94f3ecbf4e3041e2?tokenId=66ec5f4f94f3ecbf4e3041e2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197439', '66ec5f291294209357f0558e', 'SUCCESS', '2024-09-19T17:28:10.873Z', '2024-09-19T17:31:20.967Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec5f291294209357f0558e?tokenId=66ec5f291294209357f0558e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197439', '66ec5b9f1294209357f05537', 'SUCCESS', '2024-09-19T17:13:05.280Z', '2024-09-19T17:16:07.880Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66ec5b9f1294209357f05537?tokenId=66ec5b9f1294209357f05537&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0537-201792', '66e4a06419013510e4465a85', 'SUCCESS', '2024-09-13T20:28:21.105Z', '2024-09-17T10:53:42.833Z', '00112-2022-01', '66e30e507ff111da78b3851e', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4a06419013510e4465a85?tokenId=66e4a06419013510e4465a85&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0537-201791', '66e4a0107ff111da78b38ace', 'SUCCESS', '2024-09-13T20:26:58.604Z', '2024-09-17T11:30:13.586Z', '00112-2022-01', '66e30e507ff111da78b3851e', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4a0107ff111da78b38ace?tokenId=66e4a0107ff111da78b38ace&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0537-201790', '66e49fbca3071766bd27e2ab', 'SUCCESS', '2024-09-13T20:25:33.789Z', '2024-09-17T11:32:36.212Z', '00112-2022-01', '66e30e507ff111da78b3851e', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49fbca3071766bd27e2ab?tokenId=66e49fbca3071766bd27e2ab&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0532-201392', '66e49eec7ff111da78b38a80', 'SUCCESS', '2024-09-13T20:22:13.087Z', '2024-09-17T11:33:04.645Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49eec7ff111da78b38a80?tokenId=66e49eec7ff111da78b38a80&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0524-199970', '66e49e44a3071766bd27e261', 'SUCCESS', '2024-09-13T20:19:17.183Z', '2024-09-17T11:33:37.627Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49e44a3071766bd27e261?tokenId=66e49e44a3071766bd27e261&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0523-199964', '66e49df07ff111da78b38a53', 'SUCCESS', '2024-09-13T20:17:53.237Z', '2024-09-17T11:34:24.096Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49df07ff111da78b38a53?tokenId=66e49df07ff111da78b38a53&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0523-199963', '66e49d9c19013510e44659e0', 'SUCCESS', '2024-09-13T20:16:29.012Z', '2024-09-17T11:35:33.308Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49d9c19013510e44659e0?tokenId=66e49d9c19013510e44659e0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0521-199948', '66e49cea19013510e44659b6', 'SUCCESS', '2024-09-13T20:13:31.925Z', '2024-09-17T11:36:31.751Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49cea19013510e44659b6?tokenId=66e49cea19013510e44659b6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0520-199942', '66e49c44a3071766bd27e1eb', 'SUCCESS', '2024-09-13T20:10:45.804Z', '2024-09-17T11:36:46.627Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49c44a3071766bd27e1eb?tokenId=66e49c44a3071766bd27e1eb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0520-199941', '66e49be77ff111da78b389e1', 'SUCCESS', '2024-09-13T20:09:12.477Z', '2024-09-17T11:36:54.955Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49be77ff111da78b389e1?tokenId=66e49be77ff111da78b389e1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0516-199307', '66e49b8d19013510e4465967', 'SUCCESS', '2024-09-13T20:07:41.999Z', '2024-09-17T11:37:05.950Z', '00017-2022-01', '66e30e4ca3071766bd27dcf7', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49b8d19013510e4465967?tokenId=66e49b8d19013510e4465967&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0508-198752', '66e49b31a3071766bd27e1a3', 'SUCCESS', '2024-09-13T20:06:12.921Z', '2024-09-17T11:37:12.980Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49b31a3071766bd27e1a3?tokenId=66e49b31a3071766bd27e1a3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198509', '66e49a75a3071766bd27e17e', 'SUCCESS', '2024-09-13T20:03:02.346Z', '2024-09-17T11:37:23.721Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49a75a3071766bd27e17e?tokenId=66e49a75a3071766bd27e17e&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198508', '66e49a2019013510e4465919', 'SUCCESS', '2024-09-13T20:01:37.161Z', '2024-09-17T11:37:31.840Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49a2019013510e4465919?tokenId=66e49a2019013510e4465919&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198507', '66e499c87ff111da78b38963', 'SUCCESS', '2024-09-13T20:00:12.088Z', '2024-09-17T11:37:36.355Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e499c87ff111da78b38963?tokenId=66e499c87ff111da78b38963&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0503-198506', '66e4997b7ff111da78b3895a', 'SUCCESS', '2024-09-13T19:58:55.475Z', '2024-09-17T11:37:42.867Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4997b7ff111da78b3895a?tokenId=66e4997b7ff111da78b3895a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0502-198498', '66e49920a3071766bd27e12d', 'SUCCESS', '2024-09-13T19:57:21.889Z', '2024-09-17T11:38:00.975Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49920a3071766bd27e12d?tokenId=66e49920a3071766bd27e12d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0502-198497', '66e498d5a3071766bd27e124', 'SUCCESS', '2024-09-13T19:56:06.539Z', '2024-09-17T11:42:13.459Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e498d5a3071766bd27e124?tokenId=66e498d5a3071766bd27e124&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0502-198496', '66e4987819013510e44658c5', 'SUCCESS', '2024-09-13T19:54:33.296Z', '2024-09-17T11:42:46.902Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4987819013510e44658c5?tokenId=66e4987819013510e44658c5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198007', '66e497b8a3071766bd27e0e2', 'SUCCESS', '2024-09-13T19:51:21.630Z', '2024-09-17T11:42:21.324Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e497b8a3071766bd27e0e2?tokenId=66e497b8a3071766bd27e0e2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198006', '66e4976519013510e446587c', 'SUCCESS', '2024-09-13T19:49:58.820Z', '2024-09-17T11:42:30.269Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4976519013510e446587c?tokenId=66e4976519013510e446587c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198005', '66e497137ff111da78b388cd', 'SUCCESS', '2024-09-13T19:48:35.895Z', '2024-09-17T11:43:33.249Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e497137ff111da78b388cd?tokenId=66e497137ff111da78b388cd&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198004', '66e496bca3071766bd27e091', 'SUCCESS', '2024-09-13T19:47:11.215Z', '2024-09-17T11:45:35.364Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e496bca3071766bd27e091?tokenId=66e496bca3071766bd27e091&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198003', '66e4966da3071766bd27e085', 'SUCCESS', '2024-09-13T19:45:50.853Z', '2024-09-17T11:46:05.572Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4966da3071766bd27e085?tokenId=66e4966da3071766bd27e085&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198002', '66e4961a19013510e4465828', 'SUCCESS', '2024-09-13T19:44:27.170Z', '2024-09-17T11:46:41.816Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4961a19013510e4465828?tokenId=66e4961a19013510e4465828&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198001', '66e495ba7ff111da78b38876', 'SUCCESS', '2024-09-13T19:42:51.059Z', '2024-09-17T11:46:49.473Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e495ba7ff111da78b38876?tokenId=66e495ba7ff111da78b38876&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-198000', '66e49563a3071766bd27e034', 'SUCCESS', '2024-09-13T19:41:24.326Z', '2024-09-17T11:46:56.076Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49563a3071766bd27e034?tokenId=66e49563a3071766bd27e034&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197999', '66e4950d19013510e44657d7', 'SUCCESS', '2024-09-13T19:39:58.520Z', '2024-09-17T11:47:04.486Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4950d19013510e44657d7?tokenId=66e4950d19013510e44657d7&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197998', '66e494ba7ff111da78b38825', 'SUCCESS', '2024-09-13T19:38:35.769Z', '2024-09-17T11:47:10.125Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e494ba7ff111da78b38825?tokenId=66e494ba7ff111da78b38825&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197997', '66e49462a3071766bd27dfe3', 'SUCCESS', '2024-09-13T19:37:07.331Z', '2024-09-17T11:47:17.477Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e49462a3071766bd27dfe3?tokenId=66e49462a3071766bd27dfe3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197996', '66e4940c19013510e4465786', 'SUCCESS', '2024-09-13T19:35:41.383Z', '2024-09-17T11:47:43.068Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4940c19013510e4465786?tokenId=66e4940c19013510e4465786&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197995', '66e493ac7ff111da78b387d4', 'SUCCESS', '2024-09-13T19:34:13.613Z', '2024-09-17T11:53:48.929Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e493ac7ff111da78b387d4?tokenId=66e493ac7ff111da78b387d4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0113-197994', '66e493547ff111da78b387b9', 'SUCCESS', '2024-09-13T19:32:37.708Z', '2024-09-17T11:54:02.536Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e493547ff111da78b387b9?tokenId=66e493547ff111da78b387b9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0112-197974', '66e492f419013510e446573b', 'SUCCESS', '2024-09-13T19:31:01.428Z', '2024-09-17T11:58:30.245Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e492f419013510e446573b?tokenId=66e492f419013510e446573b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0112-197973', '66e4927da3071766bd27df68', 'SUCCESS', '2024-09-13T19:29:12.787Z', '2024-09-17T11:58:41.107Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4927da3071766bd27df68?tokenId=66e4927da3071766bd27df68&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0112-197972', '66e4921319013510e4465705', 'SUCCESS', '2024-09-13T19:27:16.224Z', '2024-09-17T11:58:49.815Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4921319013510e4465705?tokenId=66e4921319013510e4465705&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0112-197971', '66e491bca3071766bd27df32', 'SUCCESS', '2024-09-13T19:25:49.004Z', '2024-09-17T11:59:28.634Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e491bca3071766bd27df32?tokenId=66e491bca3071766bd27df32&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0110-197489', '66e491657ff111da78b38738', 'SUCCESS', '2024-09-13T19:24:22.825Z', '2024-09-17T11:59:10.088Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e491657ff111da78b38738?tokenId=66e491657ff111da78b38738&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0110-197488', '66e4911219013510e44656b4', 'SUCCESS', '2024-09-13T19:22:59.185Z', '2024-09-17T12:00:07.564Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4911219013510e44656b4?tokenId=66e4911219013510e44656b4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0110-197487', '66e490baa3071766bd27dee1', 'SUCCESS', '2024-09-13T19:21:31.609Z', '2024-09-17T12:00:33.739Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e490baa3071766bd27dee1?tokenId=66e490baa3071766bd27dee1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197440', '66e4906d7ff111da78b386fc', 'SUCCESS', '2024-09-13T19:20:15.432Z', '2024-09-17T12:02:08.754Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e4906d7ff111da78b386fc?tokenId=66e4906d7ff111da78b386fc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197438', '66e48fb119013510e446565d', 'SUCCESS', '2024-09-13T19:17:06.468Z', '2024-09-13T19:17:29.972Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e48fb119013510e446565d?tokenId=66e48fb119013510e446565d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0105-197437', '66e48f5d7ff111da78b386ab', 'SUCCESS', '2024-09-13T19:15:42.677Z', '2024-09-13T19:16:02.198Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66e48f5d7ff111da78b386ab?tokenId=66e48f5d7ff111da78b386ab&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0109-197481', '66da981119013510e4464bca', 'SUCCESS', '2024-09-06T05:50:10.403Z', '2024-09-06T05:50:25.087Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66da981119013510e4464bca?tokenId=66da981119013510e4464bca&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196316', '66da98107ff111da78b37c0c', 'SUCCESS', '2024-09-06T05:50:09.209Z', '2024-09-06T05:50:24.732Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66da98107ff111da78b37c0c?tokenId=66da98107ff111da78b37c0c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0109-197482', '66da980fa3071766bd27d408', 'SUCCESS', '2024-09-06T05:50:07.702Z', '2024-09-06T05:50:22.304Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66da980fa3071766bd27d408?tokenId=66da980fa3071766bd27d408&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0098-196263', '66da97e3a3071766bd27d3ff', 'SUCCESS', '2024-09-06T05:49:24.301Z', '2024-09-06T05:49:39.149Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66da97e3a3071766bd27d3ff?tokenId=66da97e3a3071766bd27d3ff&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0098-196263', '66da92b27ff111da78b37c03', 'SUCCESS', '2024-09-06T05:27:16.161Z', '2024-09-06T05:27:32.339Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66da92b27ff111da78b37c03?tokenId=66da92b27ff111da78b37c03&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0501-198490', '66d9daeaa3071766bd27d255', 'SUCCESS', '2024-09-05T16:23:06.693Z', '2024-09-05T16:23:23.857Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9daeaa3071766bd27d255?tokenId=66d9daeaa3071766bd27d255&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0501-198489', '66d9dae819013510e4464a03', 'SUCCESS', '2024-09-05T16:23:05.536Z', '2024-09-05T16:23:21.989Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dae819013510e4464a03?tokenId=66d9dae819013510e4464a03&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-22-0501-198488', '66d9dae77ff111da78b37a28', 'SUCCESS', '2024-09-05T16:23:04.277Z', '2024-09-05T16:23:19.401Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dae77ff111da78b37a28?tokenId=66d9dae77ff111da78b37a28&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0109-197483', '66d9dadca3071766bd27d24c', 'SUCCESS', '2024-09-05T16:23:03.016Z', '2024-09-05T16:23:20.127Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dadca3071766bd27d24c?tokenId=66d9dadca3071766bd27d24c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0108-197477', '66d9dac17ff111da78b37a1f', 'SUCCESS', '2024-09-05T16:22:26.861Z', '2024-09-05T18:28:06.234Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dac17ff111da78b37a1f?tokenId=66d9dac17ff111da78b37a1f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0108-197476', '66d9dac0a3071766bd27d23f', 'SUCCESS', '2024-09-05T16:22:25.401Z', '2024-09-05T18:28:32.331Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dac0a3071766bd27d23f?tokenId=66d9dac0a3071766bd27d23f&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0108-197475', '66d9dabe19013510e44649f6', 'SUCCESS', '2024-09-05T16:22:23.986Z', '2024-09-05T18:29:49.283Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dabe19013510e44649f6?tokenId=66d9dabe19013510e44649f6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0107-197468', '66d9dabd7ff111da78b37a16', 'SUCCESS', '2024-09-05T16:22:22.377Z', '2024-09-05T18:30:29.552Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dabd7ff111da78b37a16?tokenId=66d9dabd7ff111da78b37a16&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0107-197467', '66d9dabca3071766bd27d236', 'SUCCESS', '2024-09-05T16:22:21.073Z', '2024-09-05T18:31:02.306Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dabca3071766bd27d236?tokenId=66d9dabca3071766bd27d236&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0107-197466', '66d9dabb19013510e44649ed', 'SUCCESS', '2024-09-05T16:22:19.822Z', '2024-09-05T16:23:16.933Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dabb19013510e44649ed?tokenId=66d9dabb19013510e44649ed&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0106-197457', '66d9daba7ff111da78b37a0d', 'SUCCESS', '2024-09-05T16:22:18.817Z', '2024-09-05T16:23:11.498Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9daba7ff111da78b37a0d?tokenId=66d9daba7ff111da78b37a0d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0106-197456', '66d9dab9a3071766bd27d22d', 'SUCCESS', '2024-09-05T16:22:17.708Z', '2024-09-05T18:31:27.540Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dab9a3071766bd27d22d?tokenId=66d9dab9a3071766bd27d22d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0106-197455', '66d9dab819013510e44649e4', 'SUCCESS', '2024-09-05T16:22:16.613Z', '2024-09-11T11:48:57.686Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dab819013510e44649e4?tokenId=66d9dab819013510e44649e4&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0106-197454', '66d9dab67ff111da78b37a04', 'SUCCESS', '2024-09-05T16:22:15.593Z', '2024-09-05T16:22:33.094Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dab67ff111da78b37a04?tokenId=66d9dab67ff111da78b37a04&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0106-197453', '66d9dab5a3071766bd27d224', 'SUCCESS', '2024-09-05T16:22:14.384Z', '2024-09-05T16:22:38.096Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dab5a3071766bd27d224?tokenId=66d9dab5a3071766bd27d224&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197213', '66d9dab419013510e44649db', 'SUCCESS', '2024-09-05T16:22:12.888Z', '2024-09-05T16:22:33.153Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dab419013510e44649db?tokenId=66d9dab419013510e44649db&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197212', '66d9dab27ff111da78b379fb', 'SUCCESS', '2024-09-05T16:22:11.696Z', '2024-09-05T16:22:38.090Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dab27ff111da78b379fb?tokenId=66d9dab27ff111da78b379fb&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197211', '66d9dab1a3071766bd27d21b', 'SUCCESS', '2024-09-05T16:22:10.069Z', '2024-09-05T16:22:42.945Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dab1a3071766bd27d21b?tokenId=66d9dab1a3071766bd27d21b&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197210', '66d9dab019013510e44649d2', 'SUCCESS', '2024-09-05T16:22:08.916Z', '2024-09-05T16:22:25.167Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9dab019013510e44649d2?tokenId=66d9dab019013510e44649d2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197209', '66d9daae7ff111da78b379f2', 'SUCCESS', '2024-09-05T16:22:07.783Z', '2024-09-05T16:22:25.508Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9daae7ff111da78b379f2?tokenId=66d9daae7ff111da78b379f2&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197208', '66d9daada3071766bd27d212', 'SUCCESS', '2024-09-05T16:22:06.568Z', '2024-09-05T16:22:23.378Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9daada3071766bd27d212?tokenId=66d9daada3071766bd27d212&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0102-197207', '66d9daac19013510e44649c9', 'SUCCESS', '2024-09-05T16:22:05.437Z', '2024-09-05T16:22:21.208Z', '00132-2022-01', '66d9bf3519013510e4464854', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9daac19013510e44649c9?tokenId=66d9daac19013510e44649c9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196319', '66d9daab7ff111da78b379e9', 'SUCCESS', '2024-09-05T16:22:04.362Z', '2024-09-05T18:33:11.788Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9daab7ff111da78b379e9?tokenId=66d9daab7ff111da78b379e9&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196318', '66d9daaaa3071766bd27d209', 'SUCCESS', '2024-09-05T16:22:03.168Z', '2024-09-05T18:36:48.767Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9daaaa3071766bd27d209?tokenId=66d9daaaa3071766bd27d209&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196317', '66d9daa419013510e44649c0', 'SUCCESS', '2024-09-05T16:22:02.029Z', '2024-09-05T18:41:36.240Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9daa419013510e44649c0?tokenId=66d9daa419013510e44649c0&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196314', '66d9da9019013510e44649b7', 'SUCCESS', '2024-09-05T16:21:37.271Z', '2024-09-05T18:42:49.746Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da9019013510e44649b7?tokenId=66d9da9019013510e44649b7&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196313', '66d9da8f7ff111da78b379dc', 'SUCCESS', '2024-09-05T16:21:36.047Z', '2024-09-05T18:43:28.200Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da8f7ff111da78b379dc?tokenId=66d9da8f7ff111da78b379dc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196312', '66d9da8ea3071766bd27d1fc', 'SUCCESS', '2024-09-05T16:21:34.988Z', '2024-09-05T18:44:12.873Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da8ea3071766bd27d1fc?tokenId=66d9da8ea3071766bd27d1fc&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196311', '66d9da8c19013510e44649ae', 'SUCCESS', '2024-09-05T16:21:33.698Z', '2024-09-05T18:44:41.660Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da8c19013510e44649ae?tokenId=66d9da8c19013510e44649ae&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196310', '66d9da8b7ff111da78b379d3', 'SUCCESS', '2024-09-05T16:21:32.410Z', '2024-09-05T18:45:40.804Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da8b7ff111da78b379d3?tokenId=66d9da8b7ff111da78b379d3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196309', '66d9da8aa3071766bd27d1f3', 'SUCCESS', '2024-09-05T16:21:31.297Z', '2024-09-05T18:47:48.021Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da8aa3071766bd27d1f3?tokenId=66d9da8aa3071766bd27d1f3&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196308', '66d9da8919013510e44649a5', 'SUCCESS', '2024-09-05T16:21:30.166Z', '2024-09-05T18:48:20.648Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da8919013510e44649a5?tokenId=66d9da8919013510e44649a5&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196307', '66d9da877ff111da78b379ca', 'SUCCESS', '2024-09-05T16:21:28.668Z', '2024-09-05T18:49:15.852Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da877ff111da78b379ca?tokenId=66d9da877ff111da78b379ca&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196306', '66d9da86a3071766bd27d1ea', 'SUCCESS', '2024-09-05T16:21:27.431Z', '2024-09-05T18:50:08.806Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da86a3071766bd27d1ea?tokenId=66d9da86a3071766bd27d1ea&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196305', '66d9da8519013510e446499c', 'SUCCESS', '2024-09-05T16:21:26.368Z', '2024-09-11T11:37:27.146Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da8519013510e446499c?tokenId=66d9da8519013510e446499c&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196304', '66d9da847ff111da78b379c1', 'SUCCESS', '2024-09-05T16:21:25.098Z', '2024-09-11T11:49:31.809Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da847ff111da78b379c1?tokenId=66d9da847ff111da78b379c1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196303', '66d9da82a3071766bd27d1e1', 'SUCCESS', '2024-09-05T16:21:23.388Z', '2024-09-05T16:21:48.841Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da82a3071766bd27d1e1?tokenId=66d9da82a3071766bd27d1e1&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196302', '66d9da8119013510e4464993', 'SUCCESS', '2024-09-05T16:21:22.069Z', '2024-09-05T16:21:43.668Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da8119013510e4464993?tokenId=66d9da8119013510e4464993&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0100-196301', '66d9da807ff111da78b379b8', 'SUCCESS', '2024-09-05T16:21:21.026Z', '2024-09-05T16:21:53.676Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da807ff111da78b379b8?tokenId=66d9da807ff111da78b379b8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0099-196274', '66d9da7ea3071766bd27d1d8', 'SUCCESS', '2024-09-05T16:21:19.738Z', '2024-09-05T16:21:37.553Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da7ea3071766bd27d1d8?tokenId=66d9da7ea3071766bd27d1d8&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0099-196273', '66d9da7d19013510e446498a', 'SUCCESS', '2024-09-05T16:21:18.490Z', '2024-09-05T16:21:36.720Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da7d19013510e446498a?tokenId=66d9da7d19013510e446498a&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0099-196272', '66d9da7c7ff111da78b379af', 'SUCCESS', '2024-09-05T16:21:17.383Z', '2024-09-05T16:21:37.231Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da7c7ff111da78b379af?tokenId=66d9da7c7ff111da78b379af&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0099-196271', '66d9da7ba3071766bd27d1cf', 'SUCCESS', '2024-09-05T16:21:16.271Z', '2024-09-05T16:21:35.260Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da7ba3071766bd27d1cf?tokenId=66d9da7ba3071766bd27d1cf&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0099-196270', '66d9da7a19013510e4464981', 'SUCCESS', '2024-09-05T16:21:15.188Z', '2024-09-05T16:21:33.499Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da7a19013510e4464981?tokenId=66d9da7a19013510e4464981&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0098-196264', '66d9da787ff111da78b379a6', 'SUCCESS', '2024-09-05T16:21:13.800Z', '2024-09-05T16:21:32.658Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da787ff111da78b379a6?tokenId=66d9da787ff111da78b379a6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0098-196263', '66d9da77a3071766bd27d1c6', 'SUCCESS', '2024-09-05T16:21:12.388Z', '2024-09-05T16:21:32.076Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da77a3071766bd27d1c6?tokenId=66d9da77a3071766bd27d1c6&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0098-196263', '66d9da5719013510e4464978', 'SUCCESS', '2024-09-05T16:20:40.577Z', '2024-09-05T16:20:56.149Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9da5719013510e4464978?tokenId=66d9da5719013510e4464978&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0098-196263', '66d9d9d57ff111da78b3799d', 'SUCCESS', '2024-09-05T16:18:30.915Z', '2024-09-05T16:18:49.691Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9d9d57ff111da78b3799d?tokenId=66d9d9d57ff111da78b3799d&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

INSERT INTO cyberids_nfts (cyber_id, token_id, status, created_at, updated_at, collection_name, collection_id, token_url)
VALUES ('CYR01-21-0098-196263', '66d9c25aa3071766bd27d0de', 'SUCCESS', '2024-09-05T14:38:19.295Z', '2024-09-05T14:38:34.534Z', '00009-2022-01', '66d9c0e07ff111da78b3789d', 'https://prptl.io/-/u3ijq-oaaaa-aaaap-ahw4q-cai/collection/-/user-view.html#/66d9c25aa3071766bd27d0de?tokenId=66d9c25aa3071766bd27d0de&canisterId=u3ijq-oaaaa-aaaap-ahw4q-cai')
ON CONFLICT (cyber_id, token_id) 
DO UPDATE 
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at,
    collection_name = EXCLUDED.collection_name,
    collection_id = EXCLUDED.collection_id,
    token_url = EXCLUDED.token_url
WHERE (cyberids_nfts.status <> EXCLUDED.status OR cyberids_nfts.updated_at <> EXCLUDED.updated_at)
      OR (cyberids_nfts.status IS NULL AND EXCLUDED.status IS NOT NULL)
      OR (cyberids_nfts.updated_at IS NULL AND EXCLUDED.updated_at IS NOT NULL);

