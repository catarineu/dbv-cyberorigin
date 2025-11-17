--  https://prptl.io/-/  {canisterPrincipalId}  /collection/-/user-view.html#/  {tokenId}?tokenId={tokenId}  &canisterId={canisterPrincipalId}
------------------
-- Llista els tokens amb URL equivocada
SELECT 
    cyber_id,
    token_id,
    collection_id,
    token_url,
    nc.principalid,
    -- Show what the correct URL should be
    'https://prptl.io/-/' || nc.principalid || 
    '/collection/-/user-view.html#/' || token_id || 
    '?tokenId=' || token_id || 
    '&canisterId=' || nc.principalid AS expected_url
FROM 
    cyberids_nfts cn
    JOIN nft_collections nc ON cn.collection_id = nc.id
WHERE 
    cn.token_url != 
    'https://prptl.io/-/' || nc.principalid || 
    '/collection/-/user-view.html#/' || cn.token_id || 
    '?tokenId=' || cn.token_id || 
    '&canisterId=' || nc.principalid;

-- Corregeix els tokens amb URL equivocada
UPDATE cyberids_nfts cn
SET 
    token_url = 'https://prptl.io/-/' || nc.principalid || 
                '/collection/-/user-view.html#/' || cn.token_id || 
                '?tokenId=' || cn.token_id || 
                '&canisterId=' || nc.principalid,
    updated_at = CURRENT_TIMESTAMP
FROM 
    nft_collections nc
WHERE 
    cn.collection_id = nc.id
    AND cn.token_url != 
        'https://prptl.io/-/' || nc.principalid || 
        '/collection/-/user-view.html#/' || cn.token_id || 
        '?tokenId=' || cn.token_id || 
        '&canisterId=' || nc.principalid;

--- -------------

SELECT DISTINCT cyber_id 
  FROM cyberids_nfts cn
 WHERE status='SUCCESS';

SELECT cyber_id, status, collection_name, psi_id
  FROM cyberids_nfts cn
 WHERE cyber_id IN (
	SELECT DISTINCT cyber_id 
	  FROM cyberids_nfts cn
	 WHERE status = 'SUCCESS'
	   AND cyber_id NOT IN (
	   SELECT cyber_id 
	      FROM cyberids_nfts c2 
	     WHERE c2.status = 'SUCCESS' 
	       AND c2.psi_id IS NOT NULL
	)
) ORDER BY cyber_id;

-- CYR01-22-0641-218982
SELECT cyber_id, TYPE
  FROM product_search_index psi
 WHERE psi.cyber_id='CYR01-22-0641-218982'

 







