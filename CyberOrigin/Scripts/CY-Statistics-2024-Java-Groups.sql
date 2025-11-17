--                                  cust, brand,       type, begin?, end?,  cyber_ids? 
SELECT * FROM get_stats_java_groups(NULL, '00314'); -- NULL, NULL,   NULL,  FALSE 
SELECT * FROM get_stats_java_groups('00132'); -- NULL, NULL, NULL,   NULL,  FALSE 

--                                        cust, brand, type, begin?, end?,  cyber_ids?
SELECT
    blockchain_id,
    cust  || ' - ' || custname AS cust,
    brand || ' - ' || brandname AS brand,
    lots ,  lots_pc || ' %' AS lots_pc,
    carats, carats_pc || ' %' AS carats_pc,
    pieces, pieces_pc || ' %' AS pieces_pc,
    cyber_ids
  FROM get_stats_java_groups(NULL, NULL,  NULL, NULL,   NULL,  TRUE); -- NULL, NULL,  NULL, NULL,   NULL, *TRUE

SELECT * FROM get_stats_java_groups(NULL, NULL,'DIAMONDS_FULL');      -- NULL, NULL,  *'DIAMONDS_FULL', NULL,   NULL,  FALSE 
SELECT * FROM get_stats_java_groups();								  -- NULL, NULL,  NULL, NULL,   NULL,  FALSE 

SELECT psi.cyber_id,  psi.TYPE, psi.group_record_type, psi.brand_id2 AS brand, psi.customer_id2 AS customer, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats
  FROM product_search_index psi
 WHERE psi.superseded = FALSE    -- Actius
   AND psi.cyber_id ~ '^CYR01-'  -- No són TEST ni errors
   AND psi.TYPE = 'DIAMONDS_FULL'
 ORDER BY cyber_id, group_record_type ;

SELECT psi.cyber_id,  psi.TYPE, group_record_type, psi.brand_id2 AS brand, psi.customer_id2 AS customer, 
		CASE WHEN psi.group_record_type='GROUP_DELIVERY' THEN psi.data_field_pieces ELSE 0 END AS del_pieces, 
		CASE WHEN psi.group_record_type='GROUP_MOVEMENT' THEN psi.data_field_pieces ELSE 0 END AS mov_pieces, 
		CASE WHEN psi.group_record_type IS NULL          THEN psi.data_field_pieces ELSE 0 END AS gen_pieces, 
		psi.data_field_carats AS carats
  FROM product_search_index psi
 WHERE psi.superseded = FALSE    -- Actius
   AND psi.cyber_id ~ '^CYR01-'  -- No són TEST ni errors
   AND psi.TYPE = 'DIAMONDS_FULL'
 ORDER BY cyber_id, "timestamp"  ;

------------------------------------------------------------
-- group_movement: Per veure PRODS / DELIVERIES de groups
--
-- Connectant 'group_movement' = PSI.CyberID_Group
SELECT psi.cyber_id AS psi_cyber_id, NOT psi.is_only_one_production AS is_group, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats,
	   substring(split_part(gm.cyber_id, '-R', 1),21) AS op,  gm.pieces AS pcs, gm.carats AS car, to_char(gm.timestamp, 'yyyy-mm-dd HH:MI') AS moment
  FROM product_search_index psi
  	   LEFT OUTER JOIN group_movement gm ON (psi.cyber_id_group=gm.cyber_id_group)
       LEFT OUTER JOIN cyber_id ci       ON (ci.cyber_id=psi.lot_id)
 WHERE psi.superseded = FALSE AND psi.cyber_id ~ '^CYR01-'
   AND ci.deleted   = FALSE AND ci.cancelled = FALSE -- NO anulats
   AND psi.is_only_one_production = FALSE
 ORDER BY gm.cyber_id_group, gm.id;


SELECT  wn.blockchain_name::text, wn.name_fr::text, 
	    psi.cyber_id, NOT psi.is_only_one_production AS is_group, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats,
--		gm.cyber_id_group, --split_part(gm.cyber_id, '-R', 1) AS cyber_id, 
		string_agg(CASE WHEN gm.movement_type='PRODUCTION' THEN substring(split_part(gm.cyber_id, '-R', 1),21)||' ' ELSE '' END,'') AS pro_ids, 
		sum(CASE WHEN gm.movement_type='PRODUCTION' THEN gm.pieces ELSE 0 END) AS pro_pieces, 
		sum(CASE WHEN gm.movement_type='PRODUCTION' THEN gm.carats ELSE 0 END) AS pro_carats, 
		string_agg(CASE WHEN gm.movement_type='VALIDATION' THEN substring(split_part(gm.cyber_id, '-R', 1),21)||' ' ELSE '' END,'') AS val_ids, 
		sum(CASE WHEN gm.movement_type='VALIDATION' THEN gm.pieces ELSE 0 END) AS val_pieces, 
		sum(CASE WHEN gm.movement_type='VALIDATION' THEN gm.carats ELSE 0 END) AS val_carats, 
		string_agg(CASE WHEN gm.movement_type='DELIVERY' THEN substring(split_part(gm.cyber_id, '-R', 1),21)||' ' ELSE '' END,'') AS del_ids, 
		sum(CASE WHEN gm.movement_type='DELIVERY'   THEN -gm.pieces ELSE 0 END) AS del_pieces, 
		sum(CASE WHEN gm.movement_type='DELIVERY'   THEN -gm.carats ELSE 0 END) AS del_carats
  FROM product_search_index psi
  	   LEFT OUTER JOIN group_movement gm ON (psi.cyber_id_group=gm.cyber_id_group)
       LEFT OUTER JOIN cyber_id ci       ON (ci.cyber_id=psi.lot_id)
       LEFT JOIN workflow_name wn        ON (wn.psi_type=psi.type)
 WHERE psi.superseded = FALSE AND psi.cyber_id ~ '^CYR01-'
   AND ci.deleted   = FALSE AND ci.cancelled = FALSE -- NO anulats
 GROUP BY wn.blockchain_name, wn.name_fr, psi.cyber_id, psi.is_only_one_production, psi.group_record_type, psi.data_field_pieces, psi.data_field_carats, gm.cyber_id_group--, gm.cyber_id
 ORDER BY psi.is_only_one_production, gm.cyber_id_group


 
 
SELECT * FROM cyber_id ci WHERE cyber_id ~'CYR01-23-0511-245732' AND cancelled = FALSE ORDER BY id; 


WITH productions AS (
	SELECT string_agg('^'||cyber_id,'|' ORDER BY cyber_id) AS cybs
	  FROM cyber_id ci 
	 WHERE cyber_id_group_id = (SELECT id FROM cyber_id ci2 WHERE cyber_id='CYR01-23-0511-245732-R04') 
	   AND cancelled = FALSE 
)
SELECT lot_id, srf.KEY, srf.string_value
  FROM step_record sr
       LEFT OUTER JOIN step_record_fields srf ON srf.step_record_id=sr.id AND srf.key = 'Origin'
 WHERE cyber_id ~ (SELECT cybs FROM productions)
   AND sr.role_name IN ('RoughCertification', 'Parcel Assessment');

 
 
DROP FUNCTION get_stats_java_groups;
CREATE OR REPLACE FUNCTION get_stats_java_groups(
    p_customer TEXT DEFAULT NULL,
    p_brand TEXT DEFAULT NULL,
    p_type TEXT DEFAULT NULL,
    p_begin DATE DEFAULT NULL,
    p_end DATE DEFAULT NULL,
    p_include_cyber_ids BOOLEAN DEFAULT NULL 
)
RETURNS TABLE (
    blockchain_id TEXT,
    name_fr TEXT,
    cust TEXT,
    custname TEXT,
    brand TEXT,
    brandname TEXT,
    lots INTEGER,
    pieces INTEGER,
    carats FLOAT,
    lots_pc FLOAT,
    pieces_pc FLOAT,
    carats_pc FLOAT,
    cyber_ids TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH stats_list AS (
    	-- ------------------------------------------------------------------------------------------
    	-- SELECT_1: Full list of CyberIDs with their origens+providers (only valid ones)
        SELECT psi.cyber_id, psi.TYPE, psi.brand_id2 AS brand, psi.customer_id2 AS customer, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats
          FROM product_search_index psi
         WHERE psi.superseded = FALSE    -- Actius
           AND psi.cyber_id ~ '^CYR01-'  -- No són TEST ni errors
           AND (p_type     IS NULL OR psi.TYPE         = p_type)
           AND (p_customer IS NULL OR psi.customer_id2 = p_customer)
           AND (p_brand    IS NULL OR psi.brand_id2    = p_brand)
           AND (p_begin    IS NULL OR psi.timestamp    >= p_begin)
           AND (p_end      IS NULL OR psi.timestamp    <  p_end)
         GROUP BY psi.cyber_id, psi.TYPE, psi.brand_id2, psi.customer_id2, psi.data_field_pieces, psi.data_field_carats
    )
   	-- ------------------------------------------------------------------------------------------
    -- SELECT_2: Aggregation by sublevels
    SELECT 
        -- Columnes de dades ................................................................
        wn.blockchain_name::text, 
        wn.name_fr::text, 
        customer::text AS cust, 
        ccc1.name_to_show::text AS custname, 
        s.brand::text, 
        ccc2.name_to_show::text AS brandname,
        count(cyber_id)::int AS lots, 
        sum(s.pieces)::int AS pieces, 
        sum(s.carats)::float AS carats,
        -- Percentatges per CUSTOMER ........................................................
        round((count(cyber_id)::float / SUM(count(cyber_id)) OVER (PARTITION BY wn.blockchain_name, s.customer))::numeric * 100,2)::float AS lots_pc,
        round((  sum(s.pieces)::float / SUM(sum(s.pieces))   OVER (PARTITION BY wn.blockchain_name, s.customer))::numeric * 100,2)::float AS pieces_pc,
        round((  sum(s.carats)::float / SUM(sum(s.carats))   OVER (PARTITION BY wn.blockchain_name, s.customer))::numeric * 100,2)::float AS carats_pc,
	    CASE
	      WHEN p_include_cyber_ids THEN string_agg(s.cyber_id, ', ' ORDER BY s.cyber_id)::text
	      ELSE NULL
        END AS cyber_ids
      FROM stats_list AS s
           LEFT JOIN cob_chain_company ccc1 ON ccc1.level1client_company_id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'  -- Diamanter '01' hardcoded
                                            AND ccc1.type = 'LEVEL_2_CLIENT_COMPANY' AND ccc1.user_external_id = s.customer
           LEFT JOIN cob_chain_company ccc2 ON ccc2.level1client_company_id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'  -- Diamanter '01' hardcoded
                                            AND ccc2.type = 'LEVEL_2_CLIENT_COMPANY' AND ccc2.user_external_id = s.brand
           LEFT JOIN workflow_name wn       ON (wn.psi_type=s.type)
     GROUP BY wn.blockchain_name, wn.name_fr, s.customer, ccc1.name_to_show, s.brand, ccc2.name_to_show
     ORDER BY wn.blockchain_name, 
		        ROW_NUMBER() OVER (PARTITION BY wn.blockchain_name, 
		        					CASE WHEN p_brand IS NULL AND p_customer IS NULL 	 THEN '1'
		        					     WHEN p_brand IS NULL AND p_customer IS NOT NULL THEN p_customer
		        					     WHEN p_brand IS NOT NULL 						 THEN p_brand
		        					     ELSE 											      p_customer
		        					END ORDER BY count(cyber_id) DESC); -- De més a menys quantitat
END;
$$ LANGUAGE plpgsql;
