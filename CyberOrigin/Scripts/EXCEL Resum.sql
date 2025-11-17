SELECT user_external_id AS code, name_to_show  FROM cob_chain_company ccc WHERE TYPE='LEVEL_2_CLIENT_COMPANY' ORDER BY user_external_id ;

--CREATE OR REPLACE VIEW public.vw_tmp_excel AS

-- Llista de TOTES les comandes GRUP
SELECT * FROM get_group_orders();

-- Llista de les comandes STANDARD no tancades
SELECT * FROM get_standard_open_orders();





SELECT wn.blockchain_name AS blockchain, te.api, apiv, brand, ccc1.name_to_show AS brandname,
	   cust, ccc2.name_to_show AS custname, te.cyber_id "timestamp", last_step_done, group_or_std, pieces, carats, d_min_max
  FROM vw_tmp_excel te
       LEFT OUTER JOIN cyber_id ci ON ci.cyber_id = te.cyber_id 
       LEFT OUTER JOIN workflow_name wn ON wn.api=te.api
       LEFT OUTER JOIN cob_chain_company ccc1 ON ccc1.user_external_id=te.brand
       LEFT OUTER JOIN cob_chain_company ccc2 ON ccc2.user_external_id=te.cust
 WHERE cancelled IS NOT TRUE
   AND rns=1 
   AND te.public_step < wn.steps
   AND te.group_or_std='Standard'
   AND blockchain_name NOT IN ('Blockchain-10', 'Blockchain-20', 'Blockchain-30')
 ORDER BY wn.code, public_step desc, group_cyber_id;


-- Llista de GRUPS amb menys peces VALIDADES que PRODUIDES
SELECT api, te.cyber_id, d_min_max, last_step_done AS step, KEY, sum(pieces) AS pieces
  FROM tmp_excel te
       LEFT OUTER JOIN cyber_id ci ON ci.cyber_id = te.cyber_id 
 WHERE cancelled IS NOT TRUE
   AND group_or_std='Group'
   AND te.group_cyber_id NOT IN (SELECT te2.group_cyber_id FROM tmp_excel te2 WHERE te2.cyber_id~'P00' ORDER BY group_cyber_id)
 GROUP BY GROUPING SETS ((api, te.cyber_id, group_cyber_id, d_min_max,last_step_done,key), (api, group_cyber_id, d_min_max,last_step_done,key))
 ORDER BY group_cyber_id, substring(last_step_done,1,2)::int,
         (CASE WHEN length(te.cyber_id)>21 THEN 1000000+substring(te.cyber_id,22)::int
          ELSE 9999999+length(te.cyber_id) END)::int, LEFT(last_step_done,2)::int ;



SELECT vsrci.cyber_id, timestamp AS maxtime, step_record_id,
	   RANK() OVER (PARTITION BY cyber_id ORDER BY step_record_id DESC)
FROM v_step_record_cyber_id vsrci
WHERE LEFT(vsrci.cyber_id,7) = 'CYR01-2'
  AND public_step = 1
  AND cyber_id ~'23-0674'

-- Llistat de tots els lots 
SELECT * FROM tmp_excel WHERE actor='Marcs' ORDER BY api, cyber_id;

-- Llistat de lots tipus 10 i 20
SELECT * FROM tmp_excel WHERE api ~'coloured-stones' ORDER BY api, cyber_id;
