SELECT  * FROM get_stats_origin (NULL, NULL, NULL, NULL, NULL, NULL, NULL);
SELECT * FROM workflows w ;

SELECT count(*) FROM product_search_index psi WHERE superseded = FALSE AND "owner"=4;

-- Diamanter='01' --> owner=4
-- CYR01-24-0025-297405-R01 => owner=7
SELECT * FROM product_search_index psi WHERE superseded = FALSE AND "owner"=4;
SELECT * FROM chain_member cm  ;
SELECT * FROM cob_chain_company ccc WHERE TYPE='LEVEL_1_CLIENT_COMPANY';
SELECT * FROM cob_chain_company ccc WHERE level1client_company_id='e02e33ea-2f13-4146-8423-016b8cfc77fc'  AND TYPE='STAKEHOLDER_COMPANY';
SELECT * FROM cob_chain_company ccc ORDER BY TYPE;



SELECT * FROM get_new_stats_DETAIL(
    p_diamanter      := NULL,
    p_customer       := NULL,
    p_brand          := NULL,
    p_type           := NULL,
    p_begin          := NULL,
    p_end            := NULL,
    p_only_nfts      := False,
    p_by_year        := False,
    p_by_origins     := False,
    p_with_cyber_ids := False
    ); --WHERE customer_namets IS NULL OR brand_namets IS NULL;

 SELECT * FROM cob_chain_company ccc WHERE user_external_id='01305';  
   
DROP FUNCTION public.get_new_stats_DETAIL;
CREATE OR REPLACE FUNCTION public.get_new_stats_DETAIL(
    -- Filters
    p_diamanter text DEFAULT NULL::text,   --
    p_customer text DEFAULT NULL::text,    --
    p_brand text DEFAULT NULL::text,       --
    p_type text DEFAULT NULL::text,        --
    p_begin date DEFAULT NULL::date,       --
    p_end date DEFAULT NULL::date,         --
    p_only_nfts boolean DEFAULT false,     --
    -- Segmentation
    p_by_year boolean DEFAULT false,       --
    p_by_origins boolean DEFAULT false,    --
    -- Extra info
    p_with_cyber_ids boolean DEFAULT false --
  ) RETURNS TABLE(
    diamanter_extid text,  -- 1
    diamanter_namets text, -- 2
    --
    year text,             -- 3
    --
    workflow_type text,    -- 4
    workflow_id text,      -- 5
    workflow_name text,    -- 6
    --
    customer_extid text,   -- 7
    customer_namets text,  -- 8
    --
    brand_extid text,      -- 9
    brand_namets text,     -- 10
    --
    origin_countries text, -- 11
    origin_providers text, -- 12
    --
    lots_sum   integer,    -- 13
    pieces_sum integer,    -- 14
    carats_sum numeric(9,2), -- 15
    nfts_sum   integer,      -- 16
    lots_pc    numeric(5,2), -- 17
    pieces_pc  numeric(5,2), -- 18
    carats_pc  numeric(5,2), -- 19
    nfts_pc    numeric(5,2), -- 20
    --
    cyber_ids text
  ) LANGUAGE plpgsql AS $function$
DECLARE
    diamanter_uuid uuid[];
    diamanter_name text;
    stakeholders   int[];
    owner_control  int;
BEGIN
	-- Busquem el diamanter
    SELECT ARRAY_AGG(id) 
      INTO diamanter_uuid 
      FROM cob_chain_company 
     WHERE user_external_id=p_diamanter 
       AND TYPE='LEVEL_1_CLIENT_COMPANY';

    -- Busquem els seus stakeholders, doncs qualsevol d'ells pot acabar sent el 'owner' del lots a PSI.
	SELECT ARRAY_AGG(chain_member_id) 
      INTO stakeholders 
	  FROM cob_chain_company ccc 
	 WHERE level1client_company_id = ANY(diamanter_uuid)
	   AND TYPE='STAKEHOLDER_COMPANY'
	   AND chain_member_id IS NOT NULL;

  	RETURN QUERY
	WITH familia AS (
	    -- Calculem una sola vegada l'última versió (deleted=false) dels TOTS els cyber_ids (pares+fills) de STEP_RECORD
		SELECT DISTINCT substring(sr.cyber_id FROM '^(.*?-R[0-9]+[0-9])') AS cyber_id, cyber_id_group_id
		  FROM step_record sr
		       LEFT OUTER JOIN cyber_id ci ON (ci.cyber_id=substring(sr.cyber_id FROM '^(.*?-R[0-9]+[0-9])'))
         WHERE ci.deleted = FALSE
	), stats_list AS (
		SELECT psi.cyber_id, psi.TYPE, psi.brand_id AS brand, psi.customer_id AS customer, psi.data_field_pieces AS pieces, psi.data_field_carats AS carats, psi.owner,
		       COALESCE(EXTRACT('year' FROM edr.date_rfb)::TEXT,'2099') AS psi_date, psi.has_nft,
		       string_agg(DISTINCT srf1.string_value, ', ' ORDER BY srf1.string_value) AS origens,
		       string_agg(DISTINCT srf2.string_value, ', ' ORDER BY srf2.string_value) AS providers
--		       string_agg(COALESCE(sr1.cyber_id,''),',') AS c1
		  FROM product_search_index psi
		       LEFT OUTER JOIN step_record sr1 
		                    ON (-- Que l'STEP_RECORD tingui el meu CyberID
		                        LEFT(sr1.cyber_id,20)=left(psi.cyber_id,20)
		                        -- Que sigui d'una revisió no cancelada (última vàlida)
		                        AND substring(sr1.cyber_id FROM '^(.*?-R[0-9]+[0-9])') IN (SELECT cyber_id FROM familia)
		                        -- i només m'interessa un PAS
							    AND sr1.role_name IN ('RoughCertification', 'Parcel Assessment')) -- psi.cyber_id=LEFT(sr2.cyber_id,20)
		       LEFT OUTER JOIN step_record sr2 
		                    ON (-- Que l'STEP_RECORD tingui el meu CyberID
		                        LEFT(sr2.cyber_id,20)=left(psi.cyber_id,20)
		           			    -- Que sigui d'una revisió no cancelada (última vàlida)
		                        AND substring(sr2.cyber_id FROM '^(.*?-R[0-9]+[0-9])') IN (SELECT cyber_id FROM familia)
		                        -- i només m'interessa un PAS
							    AND sr2.role_name IN ('RoughPurchase', 'RoughPurchasePre'))
		       LEFT OUTER JOIN step_record_fields srf1 ON srf1.step_record_id=sr1.id AND srf1.key = 'Origin'
		       LEFT OUTER JOIN step_record_fields srf2 ON srf2.step_record_id=sr2.id AND srf2.key = 'Rough_Supplier'
		       LEFT OUTER JOIN cyber_id ci     ON (ci.cyber_id=psi.lot_id)
               LEFT OUTER JOIN erp_rfb edr     ON LEFT(psi.cyber_id,20)=edr.cyber_id
		 WHERE psi.superseded = FALSE AND ci.deleted <> TRUE
		   AND substring(psi.cyber_id FROM 21 FOR 1) <> 'D'
           AND (p_type      IS NULL OR psi.TYPE         = p_type)
           AND (p_customer  IS NULL OR psi.customer_id  = p_customer)
           AND (p_brand     IS NULL OR psi.brand_id     = p_brand)
           AND (p_begin     IS NULL OR edr.date_rfb    >= p_begin)
           AND (p_end       IS NULL OR edr.date_rfb    <  p_end)
           AND (p_diamanter IS NULL OR psi.owner        = ANY(stakeholders)) 
           AND (p_only_nfts IS NOT TRUE OR has_nft = TRUE)
		 GROUP BY psi.cyber_id, psi.TYPE, psi.brand_id, psi.customer_id, psi.data_field_pieces, psi.data_field_carats, psi.has_nft, psi.owner, EXTRACT('year' FROM edr.date_rfb)::TEXT 
    ), aggreg AS (
   	-- ------------------------------------------------------------------------------------------
    -- SELECT_2: Aggregation by sublevels
    SELECT 
        -- Columnes de dades ................................................................
        CASE WHEN p_by_year THEN psi_date ELSE 'all' END AS year,
		ccc0.level1client_company_id as diamanter_id,
        wn.blockchain_name::text, 
		wn.psi_type,
        wn.name::text, 
        customer::text AS cust, 
        ccc1.name_to_show::text AS custname, 
        s.brand::text, 
        ccc2.name_to_show::text AS brandname,
        CASE WHEN p_by_origins   THEN s.origens::text ELSE NULL END AS origens,
		CASE WHEN p_by_origins THEN s.providers::text ELSE NULL END AS providers,
        count(cyber_id)::int AS lots, 
        sum(s.pieces)::int AS pieces, 
        sum(s.carats)::float AS carats,
        sum(s.has_nft::int) AS nfts,
        -- Percentatges per CUSTOMER ........................................................
        round((count(cyber_id)::float / NULLIF(SUM(count(cyber_id)) OVER (PARTITION BY CASE WHEN p_by_year THEN psi_date ELSE 'all' END, wn.blockchain_name),0))::numeric * 100,2)::float AS lots_pc,
        round((  sum(s.pieces)::float / NULLIF(SUM(sum(s.pieces))   OVER (PARTITION BY CASE WHEN p_by_year THEN psi_date ELSE 'all' END, wn.blockchain_name),0))::numeric * 100,2)::float AS pieces_pc,
        round((  sum(s.carats)::float / NULLIF(SUM(sum(s.carats))   OVER (PARTITION BY CASE WHEN p_by_year THEN psi_date ELSE 'all' END, wn.blockchain_name),0))::numeric * 100,2)::float AS carats_pc,
        coalesce(round((  sum(s.has_nft::int)::float / NULLIF(SUM(sum(s.has_nft::int)) OVER (PARTITION BY CASE WHEN p_by_year THEN psi_date ELSE 'all' END, wn.blockchain_name),0))::numeric * 100,2)::float,0) AS nfts_pc,
	    CASE
	      WHEN p_with_cyber_ids THEN string_agg(s.cyber_id, ', ' ORDER BY s.cyber_id)::text
	      ELSE NULL
        END AS cyber_ids
      FROM stats_list AS s
           LEFT JOIN cob_chain_company ccc0 ON ccc0.chain_member_id=s.owner AND ccc0.type = 'STAKEHOLDER_COMPANY'
           LEFT JOIN cob_chain_company ccc1 ON ccc1.level_1_client_company = ccc0.level1client_company_id
                                            AND ccc1.type = 'LEVEL_2_CLIENT_COMPANY' AND ccc1.user_external_id = s.customer
           LEFT JOIN cob_chain_company ccc2 ON ccc2.level_1_client_company = ccc0.level1client_company_id
                                            AND ccc2.type = 'LEVEL_2_CLIENT_COMPANY' AND ccc2.user_external_id = s.brand
           LEFT JOIN workflow_name wn       ON (wn.psi_type=s.type)
     GROUP BY GROUPING SETS (
             (CASE WHEN p_by_year    THEN psi_date          ELSE 'all' END, wn.blockchain_name, wn.psi_type, wn.name, s.customer, ccc1.name_to_show, s.brand, ccc2.name_to_show, ccc0.level1client_company_id,
			  CASE WHEN p_by_origins THEN s.origens::text   ELSE NULL  END, 
			  CASE WHEN p_by_origins THEN s.providers::text ELSE NULL  END),())
     ORDER BY CASE WHEN p_by_year THEN psi_date ELSE 'all' END, wn.blockchain_name, 
		        ROW_NUMBER() OVER (PARTITION BY wn.blockchain_name
--		        	 			   ,CASE WHEN p_brand IS NULL AND p_customer IS NULL 	 THEN '1'
--		        					     WHEN p_brand IS NULL AND p_customer IS NOT NULL THEN p_customer
--		        					     WHEN p_brand IS NOT NULL 						 THEN p_brand
--		        					     ELSE 											      p_customer END
		        					ORDER BY count(cyber_id) DESC) --, sum(s.pieces) DESC, sum(s.carats) DESC)
	)
    SELECT 
        ccc.user_external_id::text AS diamanter_extid,
        ccc.name::text             AS diamanter_namets,
        --
        gt.year::text              AS year,
        --
        gt.psi_type::text          AS workflow_type,
        gt.blockchain_name         AS workflow_id,
        gt.name                    AS workflow_name,
        --
        gt.cust                    AS customer_extid,
        gt.custname::text          AS customer_namets,
        --
        gt.brand                   AS brand_extid,
        gt.brandname               AS brand_namets,
        --
        gt.origens                 AS origin_countries,
        gt.providers               AS origin_providers,
        --
        gt.lots::integer           AS lots_sum,
        gt.pieces::integer         AS pieces_sum,
        gt.carats::numeric         AS carats_sum,
        gt.nfts::integer           AS nfts_sum,
        gt.lots_pc::numeric        AS lots_pc,
        gt.pieces_pc::numeric      AS pieces_pc,
        gt.carats_pc::numeric      AS carats_pc,
        gt.nfts_pc::numeric        AS nfts_pc,
        --
        CASE WHEN p_with_cyber_ids THEN gt.cyber_ids::text ELSE NULL END AS cyber_ids
     FROM aggreg gt
          LEFT JOIN cob_chain_company ccc ON ccc.id=gt.diamanter_id

    ORDER BY year NULLS LAST, gt.blockchain_name, gt.custname::text, gt.brandname, gt.lots DESC, gt.pieces DESC;

  END;
$function$; 