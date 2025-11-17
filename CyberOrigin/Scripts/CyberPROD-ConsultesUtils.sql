SELECT user_external_id, api_key FROM cob_chain_company ccc WHERE api_key IS NOT NULL ORDER BY type;
SELECT     company_name, api_key FROM chain_member cm       WHERE api_key IS NOT NULL ORDER BY company_name ;

SELECT cyber_id, ref_customer, ref_fab_order, final_certificate_id, final_certificate_url 
  FROM product_search_index psi WHERE cyber_id ='CYR01-24-0045-306064'

  
 SELECT * FROM product_search_index psi WHERE cyber_id~'23-0511' AND superseded=FALSE;
  
------------------------------------------------------------
@set cyber = 'CYR01-24-0132'
------------------------------------------------------------
-- Ensenya'm l'últim DELIVERY 'bo' del lot
SELECT psi.cyber_id, cyber_id_group, psi.lot_id, superseded, ci.deleted, psi.customer_id, psi.customer_id2, psi.brand_id, psi.brand_id2
  FROM product_search_index psi 
       LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=psi.lot_id
 WHERE psi.superseded = FALSE AND ci.deleted = FALSE
--   AND group_record_type='GROUP_DELIVERY'  -- Workflow-01 v5
--   AND (psi.customer_id <> psi.customer_id2 OR psi.brand_id <> psi.brand_id2)
 ORDER BY psi."timestamp" DESC ;


SELECT psi."timestamp", psi.cyber_id, psi.cyber_id_group, psi.lot_id, psi.superseded, psi.is_only_one_production, cyber_id_type , ci.deleted, ci.cancelled,  ci.cyber_id,ci.id, cyber_id_group_id, "exception"
  FROM product_search_index psi
       LEFT OUTER JOIN cyber_id ci ON psi.cyber_id=left(ci.cyber_id,length(psi.cyber_id))
 WHERE psi.cyber_id ~'23-0511'
 ORDER BY timestamp, ci,cyber_id_group_id , ci.cyber_id 

 
-- Ensenya'm-ho tot lo VIGENT d'un CyberID
SELECT psi."timestamp", psi.cyber_id, psi.cyber_id_group, psi.lot_id, psi.superseded, psi.is_only_one_production, cyber_id_type , ci.deleted, ci.cancelled,  ci.cyber_id,ci.id, cyber_id_group_id, "exception"
  FROM product_search_index psi
       LEFT OUTER JOIN cyber_id ci ON psi.cyber_id=left(ci.cyber_id,length(psi.cyber_id))
 WHERE psi.cyber_id ~'23-0510'
   AND psi.superseded=FALSE
 ORDER BY ci.id, ci,cyber_id_group_id , ci.cyber_id 

 
SELECT id, deleted AS del, cancelled AS canc, cyber_id, cyber_id_group_id, "timestamp", api_name, api_version AS v, revision AS rev,cyber_id_type
  FROM cyber_id ci  
 WHERE cyber_id ~ ${cyber}
 ORDER BY "timestamp" 
 
@set cyber = 'CYR01-24-0023'
 
 -- CYR01-22-0642-219025, CYR01-22-0642-219026, CYR01-22-0642-219027, CYR01-22-0642-219028, CYR01-22-0642-219029, CYR01-22-0642-219030, CYR01-22-0642-219031

WITH mmax AS (
 SELECT api, max(api_version) AS mm
  FROM dynamic_enum_value dev  
  GROUP BY api 
)
SELECT w.blockchain_name, dev.api, dev.enum_type, dev.cob_value, vottun_value, obsolete  
  FROM dynamic_enum_value dev  
       LEFT OUTER JOIN workflows w ON w.api=dev.api
 WHERE dev.api<>'admin'
   AND api_version=(SELECT mm FROM mmax WHERE mmax.api=dev.api)
--   AND enum_type NOT IN ('RsRegCountry', 'RJCStandardID')   
--   AND enum_type IN ('Type', 'Color', 'Colour', 'Cut', 'Quality')
   AND enum_type IN ('Color', 'Colour')
 ORDER BY w.blockchain_name, api_version, enum_type, cob_value ;

-- CYR01-22-0543-202496 -- 20
-- CYR01-23-0511-245732 -- 01 Grup
-- CYR01-23-0618-278949 -- 01 Estandard
SELECT * FROM cyber_id ci WHERE cyber_id~${cyber} ORDER BY cyber_id DESC; -- sr.cyber_id=psi.lot_id

 
  
-- *******************************************************************************
-- ************************************ STEPS ************************************
-- *******************************************************************************
SELECT api_name, deleted, cancelled, cyber_id, cyber_id_group_id FROM cyber_id     WHERE cyber_id ~${cyber} ORDER BY id desc;
SELECT superseded, cyber_id, cyber_id_group  FROM product_search_index psi WHERE cyber_id ~${cyber} ORDER BY id desc;

@set cyber = '23-0631'

-- register_log: Últims STEPS. Principalment per veure darrers ERRORS de pas.
	SELECT rl.id, rl.timestamp, rl.activity_name, -- api || ' v' || api_version AS api, blockchain,
		rl.cyber_id , /*lot_id_out,*/ rl.step, rl.success AS "ok?", 
--	    NOT((xpath('//amendment/text()'::text, xml_request::xml))[1]::TEXT='false') AS amendment,
--	 	timestamp_request, timestamp_response, 
		CASE WHEN ci.cancelled THEN '*** CANCELLED ***   ' ELSE '' END ||
	    COALESCE(LEFT((xpath('//faultstring/text()'::text, rl.xml_response::xml))[1]::TEXT,200),'') AS message,
	    LEFT((xpath('//errorCode/text()'::text, rl.xml_response::xml))[1]::TEXT,40) AS errorcode,
	 	rl.timestamp_response - rl.timestamp_request AS wait_time
--	    ,xml_response, xml_requests
	 FROM register_log rl
	     LEFT OUTER JOIN cyber_id ci ON (rl.lot_id_out=ci.cyber_id)
--	WHERE blockchain IN ('Blockchain-10','Blockchain-20')
	WHERE rl.cyber_id~${cyber}
--	WHERE rl.cyber_id ~ ('CYR01-22-0535-201476|CYR01-22-0535-201477|CYR01-23-0580-271976|CYR01-24-0020-297015|CYR01-24-0020-297016|CYR01-24-0041-305131|CYR01-24-0041-305132|CYR01-24-0061-310574|CYR01-24-0061-310580|CYR01-24-0061-310581|CYR01-24-0061-310582')
--	 AND step=1
--	 AND timestamp_response >= '2023-10-01'
--	 AND success = true
	ORDER BY LEFT(rl.cyber_id,20), rl.id DESC NULLS LAST ;


INSERT INTO cyber_id_white_list (cyber_id) VALUES ('CYR01-24-0049-306333');

===== CANCEL ====
--SELECT * FROM cyber_id ci WHERE cyber_id~${cyber};
--UPDATE cyber_id ci SET cancelled=TRUE, deleted=TRUE WHERE cyber_id~${cyber};

-- Carats Naturalness Control (M-Screen) (10.38) is greater than 4C Quality Control (10.37)
-- Carats validation failed. Rough purchase carats (3580.58) &lt; rough certification (0) + carats (5380.58) 

-- *******************************************************************************
-- ************************************ FIELDS ***********************************
-- *******************************************************************************
@set cyber = '21-0083'
@set cyber = 'D264661'

-- DETALL de dades enviades en passos
 SELECT  timestamp, public_step, REPLACE(role_name,'Group','Start'), KEY, LEFT(group_cyber_id,20),
         value_convert_string, cyber_id
   FROM 	v_step_record_and_fields vsraf  
  WHERE cyber_id ~ ${cyber}      
--    AND key ~*'piece'
    AND public_step IS NOT NULL 
    AND value_convert_string ~''
--    AND value_convert_string ~'http'
--    AND timestamp >'2023-12-15' 
  ORDER BY timestamp desc, public_step, KEY;
 

SELECT "timestamp", superseded, customer_id, brand_id, cyber_id, cyber_id_group, final_certificate_id FROM product_search_index psi 
 WHERE cyber_id ~'24-0048' AND superseded =FALSE ORDER BY id DESC;

SELECT * FROM step_record sr WHERE cyber_id ~${cyber};
SELECT * FROM cob_chain_company ccc ;

SELECT user_external_id, name_to_show FROM cob_chain_company ccc WHERE "type" ='LEVEL_2_CLIENT_COMPANY' ORDER BY name_to_show ;

SELECT sr.id, sr. cyber_id, ci.cyber_id, ci.deleted
  FROM step_record sr 
       LEFT OUTER JOIN cyber_id ci ON ci.cyber_id=LEFT(sr.cyber_id,length(ci.cyber_id))
    ORDER BY sr.id DESC;

SELECT * FROM v_register_log WHERE cyber_id='21-0085';
SELECT * FROM v_register_log_with_actions WHERE cyber_id='21-0085';
SELECT cyber_id, deleted, cancelled, * FROM cyber_id ci WHERE cyber_id  ~'23-0511' ORDER BY "timestamp" DESC;

--*******************************
--*** REGENERACIÓ CERTIFICATS *** 
--*******************************
-- ÚLTIM CERTIFICAT pre-BaTCH = 06163 (abans regeneració)
-----
-- INSERT INTO public.batch_correct_certs (optlock, batch_code, diamanter_id, cyber_id, certificate_id)
SELECT 0, 'PROD1', '01', psi.cyber_id, psi.final_certificate_id --, ci.deleted
  FROM product_search_index psi
       LEFT JOIN cyber_id ci ON ci.cyber_id=psi.lot_id  
 WHERE psi.superseded =FALSE AND psi."type" IN ('DIAMONDS_FULL', 'DIAMONDS_SEMI_FULL')
   AND (group_record_type IS NULL OR group_record_type='GROUP_DELIVERY')
   AND ci.deleted=FALSE 
 ORDER BY TYPE, psi.group_record_type, psi."date"


--XX 1. Ocultar CANCELLED de monitoring
--XX 2. Monitoring CYR01-22-0503-198506: en el detall no mostra darrer reset
--XX 2. Statistiques pour PSI.date
--XX 4. Validar que els 00 NO son al blckchain
--XX 7. Mirar els que no estan tancats, o reiniciats
--====================================================================================================
-- 3. 22-0569 >> Valider Jaume
-- 6. CYR01-22-0543                   blockchain 20 = Enviar automàticament des de Gil
--    CYR01-22-0601,24-0003,24-0016   blockchain 10 = Enviar automàticament des de Gil
--====================================================================================================
-- 5. Llistat de DIAMBEL vs PRIME GEMS
-- 8. Proveïdors: 22-0648-220458, 22-0677-226935
--====================================================================================================

SELECT date, EXTRACT('year' FROM date), * FROM product_search_index psi ORDER BY id DESC LIMIT 5;

-- ENUMS
WITH tot AS (
SELECT api, api_version, enum_type, cob_value, vottun_value, obsolete, RANK() OVER (PARTITION BY api ORDER BY api_version DESC) AS rrank
  FROM dynamic_enum_value dev  
  ) SELECT api, api_version, enum_type, cob_value, vottun_value, obsolete FROM tot 
     WHERE rrank=1 --AND enum_type ~*'cut' 
     ORDER BY api, api_version, cob_value
 
     

SELECT api || ' ' || api_version, timestamp::date, stakeholder_name, cyber_id_revision, group_cyber_id, 
      string_agg(public_step||'-'||KEY||'('||value_convert_string||')',', ') AS steps_data
  FROM v_step_record_and_fields vsraf 
 WHERE value_convert_string ~* 'diambel'
   AND KEY <> 'out_batch_0'
 GROUP BY api || ' ' || api_version, timestamp::Date, stakeholder_name, cyber_id_revision, group_cyber_id 
 ORDER BY COALESCE(group_cyber_id,cyber_id_revision) DESC;
 
SELECT id, email FROM chain_member cm ORDER BY id ; 

SELECT * FROM v_step_record_and_fields vsraf WHERE cyber_id ~${cyber};

 -- ===============================================================================================
 -- Correcció de NFTs 
 -- ===============================================================================================
 SELECT cyber_id, lot_id, nft_url, has_nft, * --cyber_id, TYPE, data_field_type, superseded, has_nft, nft_url
   FROM product_search_index psi
  WHERE has_nft =TRUE
  ORDER BY cyber_id, "timestamp"
  --WHERE has_nft =TRUE ;
 
SELECT * FROM cyber_id ci WHERE cyber_id~'CYR01-23-0591-272808' ORDER BY id
 
-- Ultim per lot
WITH latest_step_1 AS (
    SELECT 
        cyber_id, 
        MAX(timestamp) AS latest_step_1_timestamp
    FROM register_log
    WHERE step = 1
      AND timestamp_response >= '2023-11-25'
      AND success= true
    GROUP BY cyber_id
), steps_after_step_1 AS (
    SELECT 
        yt.cyber_id, 
        yt.step, 
        yt.timestamp, 
        yt.success,
        ROW_NUMBER() OVER (PARTITION BY LEFT(yt.cyber_id,23) ORDER BY yt.step DESC, yt.timestamp DESC) as rn,
        COUNT(*) OVER (PARTITION BY LEFT(yt.cyber_id, 23))+1 as step_count
    FROM register_log yt
    INNER JOIN latest_step_1 ls1 ON LEFT(yt.cyber_id,20) = LEFT(ls1.cyber_id,20)
    WHERE yt.timestamp >= ls1.latest_step_1_timestamp
      AND yt.success = true
)
SELECT 
    s.cyber_id, 
    s.step AS laststep, 
    s.timestamp
--    ,s.step_count AS total_steps
FROM steps_after_step_1 s
WHERE s.rn = 1
ORDER BY laststep DESC, cyber_id;


SELECT * FROM register_log WHERE register_log.blockchain='Blockchain-02' AND "timestamp" >= '2023-12-01';


-- Pieces produced (35520) + Pieces to produce (23550) &gt; than MaxPieces (44150) from group CYR01-23-0510-245730-R06

-- 35.520 + 23.550 = 59.070  > 44.150 group limit

SELECT * FROM cyber_id ci WHERE cyber_id ~ 'CYR01-23-0510-245730' ORDER BY cancelled_timestamp DESC NULLS last;


select tr.cyber_id  ,ci.cyber_id , ci."timestamp" , ci.cancelled 
from tmp_reinsert tr 
	left join 
		cyber_id ci 
			on ci.cyber_id like tr.cyber_id ||'%'
where ci.cancelled =TRUE

-- ====================
WITH lastreset AS (
    SELECT vsrci.cyber_id, max(timestamp) AS maxtime
    FROM v_step_record_cyber_id vsrci
    WHERE LEFT(vsrci.cyber_id,3) = 'CYR'
      AND timestamp >= '2023-11-10'
      AND public_step = 1 
    GROUP BY vsrci.cyber_id
), registers AS (
    SELECT 
        LEFT(vsrci.cyber_id, 20) AS cyber_id, 
        vsrci.timestamp, 
        vsrci.public_step, 
        ROW_NUMBER() OVER (PARTITION BY LEFT(vsrci.cyber_id, 20) ORDER BY vsrci.public_step DESC, vsrci.timestamp DESC) as rn,
        COUNT(*) OVER (PARTITION BY LEFT(vsrci.cyber_id, 20)) as step_count
    FROM v_step_record_cyber_id vsrci
    LEFT OUTER JOIN lastreset ON LEFT(lastreset.cyber_id,20) = LEFT(vsrci.cyber_id,20) 
    WHERE LEFT(vsrci.cyber_id,3) = 'CYR'
      AND vsrci.timestamp >= lastreset.maxtime
      AND vsrci.public_step >= 1
)
SELECT 
    r.cyber_id, 
    r.timestamp, 
    r.public_step,
    r.step_count,
    r.step_count / 11 AS numprod
FROM registers r
WHERE r.rn = 1
ORDER BY public_step DESC, step_count desc;

  
WITH lastreset AS (
    SELECT vsrci.cyber_id, max(timestamp) AS maxtime
    FROM v_step_record_cyber_id vsrci
    WHERE LEFT(vsrci.cyber_id,3) = 'CYR'
      AND timestamp >= '2023-11-10'
      AND public_step = 1 
    GROUP BY vsrci.cyber_id
), registers AS (
    SELECT 
        LEFT(vsrci.cyber_id, 24) AS cyber_id, 
        vsrci.timestamp, 
        vsrci.public_step, 
        ROW_NUMBER() OVER (PARTITION BY LEFT(vsrci.cyber_id, 23) ORDER BY vsrci.public_step DESC, vsrci.timestamp DESC) as rn,
        COUNT(*) OVER (PARTITION BY LEFT(vsrci.cyber_id, 23)) as step_count
    FROM v_step_record_cyber_id vsrci
    LEFT OUTER JOIN lastreset ON LEFT(lastreset.cyber_id,20) = LEFT(vsrci.cyber_id,20) 
    WHERE LEFT(vsrci.cyber_id,3) = 'CYR'
      AND vsrci.timestamp >= lastreset.maxtime
      AND vsrci.public_step >= 1
)
SELECT 
    r.cyber_id, 
    r.timestamp, 
    r.public_step,
    r.step_count,
    r.step_count / 11 AS numprod
FROM registers r
WHERE r.rn = 1
ORDER BY public_step DESC, step_count desc;



SELECT LEFT(vsrci.cyber_id,20), chain_member_company_name AS stakeholder, public_step, role_name, 
  FROM v_step_record_cyber_id vsrci
  WHERE "timestamp" > '2023-12-01'
    AND public_step > 1
  GROUP BY LEFT(vsrci.cyber_id,20), chain_member_company_name, public_step, role_name
  ORDER BY LEFT(vsrci.cyber_id,20), chain_member_company_name, public_step, role_name

  
  ------------------------------------------------------------
-- v_step_record_cyber_id: Detall FIELDS registrats per un lot. Què s'ha registrat a Vottun
--                         Movement(id).carats/pieces) == group_movement(id).carats/pieces
--
SELECT vsrci."timestamp", vsrci.cyber_id, vsrci.api_version, vsrci.public_step, vsrci.role_name, vsrci.chain_member_company_name AS stakeholder, vsrf."key", vsrf.value_convert_string
  FROM v_step_record_cyber_id vsrci
       LEFT OUTER JOIN v_step_record_and_fields vsrf ON (vsrci.step_record_id=vsrf.step_record_id) 
WHERE LEFT(vsrci.cyber_id,20) IN ('CYR01-23-0560-265559')
  AND vsrci."timestamp" >= '2023-11-15'
--  AND role_name ='RoughPurchase'
--  AND KEY IN ('Rough_Invoice_ID','Rough_Purchase')
ORDER BY "timestamp" desc, api_version DESC, public_step, role_name, key


------------------------------------------------------------
-- consulta camp 'Only_One_Producction' per saber de quin tipus és cada lot
--
SELECT vsrci.cyber_id, (NOT vsrf.value_convert_string::boolean) AS isGroup, "timestamp"
  FROM v_step_record_cyber_id vsrci
       LEFT OUTER JOIN v_step_record_fields vsrf ON (vsrci.step_record_id=vsrf.step_record_id) 
WHERE 
--	  cyber_id IN ('CYR01-23-0510-245730') AND
      vsrf.KEY = 'Only_One_Producction' 
  AND (NOT vsrf.value_convert_string::boolean) = TRUE 
ORDER BY cyber_id, "timestamp" DESC;

------------------------------------------------------------
-- group_movement: Per veure PRODS / DELIVERIES de groups
--
SELECT cyber_id_group, cyber_id,  movement_type AS tipus, order_id AS ordid, carats AS car, pieces AS pcs, product, id, report_uri
  FROM group_movement gm
-- WHERE LEFT(cyber_id,20) ='CYR01-23-0510-245730'
 ORDER BY "timestamp" DESC;

SELECT * from chain_member;


-- Validació que si un GRUP està Cancel·lat, també hi estan els seus fills
SELECT cg.cyber_id AS group_cid, cg.deleted AS GROUP_del, cg.cancelled AS group_can, 
	   ci.id AS subg_id, ci.cyber_id AS subg_cid, ci.deleted AS subg_del, ci.cancelled AS subg_can 
FROM cyber_id ci
    LEFT JOIN cyber_id cg ON cg.id = ci.cyber_id_group_id
WHERE cg.deleted = TRUE
   OR cg.cancelled = TRUE

   
-- Estadístiques de temps de resposta & timeouts
SELECT rl.cyber_id, rl.activity_name, rl.timestamp_request, rl.timestamp_response, rl.timestamp_response - rl.timestamp_request diff
  FROM register_log rl
 WHERE rl."timestamp" > '2023-12-18'
 ORDER BY rl.timestamp_response - rl.timestamp_request DESC;






WITH lastreset AS (
    SELECT vsrci.cyber_id, max(timestamp) AS maxtime
    FROM v_step_record_cyber_id vsrci
    WHERE LEFT(vsrci.cyber_id,3) = 'CYR'
      AND timestamp >= '2023-11-10'
      AND public_step = 1 
    GROUP BY vsrci.cyber_id
), registers AS (
    SELECT 
	    api, 
	    api_version,
        LEFT(vsrci.cyber_id, 24) AS cyber_id, 
        coalesce (LEFT(vsrci.group_cyber_id, 20), LEFT(vsrci.cyber_id, 20)) AS group_cyber_id,
        vsrci.timestamp, 
        vsrci.public_step ||' ' ||vsrci.role_name as public_step, 
        ROW_NUMBER() OVER (PARTITION BY LEFT(vsrci.cyber_id, 23) ORDER BY vsrci.public_step DESC, vsrci.timestamp DESC) as rn,
        COUNT(*) OVER (PARTITION BY LEFT(vsrci.cyber_id, 23)) as step_count
    FROM v_step_record_cyber_id vsrci
    LEFT OUTER JOIN lastreset ON LEFT(lastreset.cyber_id,20) = LEFT(vsrci.cyber_id,20) 
    WHERE LEFT(vsrci.cyber_id,3) = 'CYR'
      AND vsrci.timestamp >= lastreset.maxtime
      AND vsrci.public_step >= 1
)
SELECT 
	r.api,
	r.api_version,
    r.cyber_id, 
    r.group_cyber_id, 
    r.timestamp, 
    r.public_step,
    r.step_count
FROM registers r
WHERE r.rn = 1
and api ='diamonds-full'
and api_version ='5'
AND left(cyber_id,20)~'CYR01-24-0005'
ORDER BY group_cyber_id, cyber_id, public_step DESC, step_count desc;




SELECT * FROM v_step_record_cyber_id
WHERE left(cyber_id,20)='CYR01-21-0102-197213'
ORDER BY "timestamp" 



    SELECT vsrci.cyber_id, max(timestamp) AS maxtime
    FROM v_step_record_cyber_id vsrci
    WHERE LEFT(vsrci.cyber_id,7) = 'CYR01-2'
      AND public_step = 1 
    GROUP BY vsrci.cyber_id
    ORDER BY cyber_id desc
    
SELECT * FROM v_step_record_cyber_id vsrci WHERE cyber_id='CYR01-24-0019-296196' AND "timestamp" ='2024-01-19 11:23:35.898'
SELECT * FROM step_record WHERE cyber_id ~'CYR01-24-0019-296196' ORDER BY "timestamp" ;

SELECT * FROM v_register_log vrl WHERE cyber_id ~'23-0671' ORDER BY "timestamp" DESC;
SELECT * FROM register_log rl WHERE cyber_id ~'23-0671' ORDER BY "timestamp" DESC;
SELECT * FROM register_log rl WHERE cyber_id ~'21-0100-196306' ORDER BY "timestamp" DESC;


SELECT * FROM get_monitoring_data(); 


-- ==================================================
-- Excel de seguiment del darrer estat 'bo' de cada lot (siguin Pxx, Vxx o '')
-- ==================================================
WITH lastreset AS (
    SELECT vsrci.cyber_id, max(timestamp) AS maxtime
    FROM v_step_record_cyber_id vsrci
    WHERE LEFT(vsrci.cyber_id,7) = 'CYR01-2'
      AND public_step = 1
    GROUP BY vsrci.cyber_id
), registers AS (
    SELECT 
	    vsrci.api, 
	    vsrci.api_version,
        LEFT(vsrci.cyber_id, 23) AS cyber_id, 
        coalesce (LEFT(vsrci.group_cyber_id, 20), LEFT(vsrci.cyber_id, 20)) AS group_cyber_id,
        vsrci.timestamp,
        vsrci.public_step ,
        vsrci.public_step || ' ' ||vsrci.role_name as public_step_and_name, 
        CASE WHEN vsrci.cyber_id ~ 'P[1-9][0-9]?$' THEN max(vsrci.public_step) OVER (PARTITION BY LEFT(vsrci.cyber_id, 23)) -- Si es P de grup, mirem els seus passos
        ELSE max(vsrci.public_step) OVER (PARTITION BY LEFT(vsrci.cyber_id, 20)) END as max_st,                             -- Si NO          , mirem els passos totals
        ROW_NUMBER() OVER (PARTITION BY LEFT(vsrci.cyber_id, 23) ORDER BY vsrci.public_step DESC, vsrci.timestamp DESC) as rn,
        srf.KEY, srf.number_value AS pieces
--        srf2.KEY AS key2, srf2.number_value AS carats
    FROM v_step_record_cyber_id vsrci
    	 LEFT OUTER JOIN lastreset ON LEFT(lastreset.cyber_id,20) = LEFT(vsrci.cyber_id,20) 
    	 LEFT OUTER JOIN step_record_fields srf ON (srf.step_record_id=vsrci.step_record_id AND srf.KEY IN ('Pieces_final', 'Max_Pieces'))
--    	 LEFT OUTER JOIN step_record_fields srf2 ON (srf2.step_record_id=vsrci.step_record_id AND srf2.KEY ~* 'carat')
    	 -- REPETIR AIXO AMB CARATS
    WHERE LEFT(vsrci.cyber_id,3) = 'CYR'
      AND vsrci.timestamp >= lastreset.maxtime
      AND vsrci.public_step >= 1
)
SELECT 
	r.api,
	r.api_version,
    r.cyber_id,  
    r.group_cyber_id, 
    r.timestamp,
    r.public_step_and_name AS Last_step_done, max_st,
    case when r.public_step < 11 AND r.public_step = max_st then 'Marcs' 
         when r.public_step = 11 AND r.public_step = max_st then 'Yoan'
         when r.public_step = 12 AND r.public_step = max_st then 'Yoan'
         else '--'
    end as "actor",
    case when r.public_step < 11 AND r.public_step = max_st then 'Register steps up to 11-"Order approval"' 
         when r.public_step = 11 AND r.public_step = max_st then 'Register step 12-"Validation of production"'
         when r.public_step = 12 AND r.public_step = max_st then 'Register step 13-"Delivery"'
         else '--'
    end as "action",
    KEY, pieces
--    ,key2, carats
FROM registers r
WHERE 
     r.rn = 1
AND api ='diamonds-full'
AND api_version ='5'
--AND left(cyber_id,20)~'CYR01-21-0102-197213'
--ORDER BY left(cyber_id,20) DESC, timestamp DESC  
ORDER BY left(cyber_id,21) DESC, LPAD(substring(cyber_id from '[PV]([0-9]+)'), 3, '0') DESC NULLS LAST 

@set cyber = 'CYR01-23-0708'    

SELECT * FROM step_record_fields WHERE KEY ~* 'carat' ORDER BY step_record_id desc

-- ==================================================
-- Monitoring detallat de tot !!
-- ==================================================
WITH max1 AS (
         SELECT rl_1.cyber_id,
            max(rl_1.id) AS id
           FROM register_log rl_1
          WHERE NOT xpath_exists('//errorCode/text()'::text, rl_1.xml_response::xml) OR (xpath('//errorCode/text()'::text, rl_1.xml_response::xml))[1]::text <> 'RECORD_NOT_FOUND'::text
          GROUP BY rl_1.blockchain, rl_1.cyber_id
        ),
     res AS (
 SELECT rl.blockchain_id AS wtype,
    w.name::character varying AS wname,
    rl."timestamp",
    rl.cyber_id,
    regexp_replace(rl.lot_id_out::text, '(-R[0-9]{2}).*$'::text, '\1'::text) AS cyber_id_revision,
    rl.success,
    ci.cyber_id_type,
        CASE
            WHEN ci.cancelled OR ci.deleted THEN true
            ELSE false
        END AS cyber_id_deleted,
    cig.cyber_id AS group_cyber_id,
        CASE
            WHEN cig.cancelled OR cig.deleted THEN true
            ELSE false
        END AS group_cyber_id_deleted,
    cig.cyber_id_type AS group_cyber_id_type,
    wv.steps AS maxstep,
    case when wv.step_group_begin  is not null and rl.step between wv.step_group_begin and wv.step_group_end 
    		then wv.step_group_end 
    	 when wv.step_group_production_end is not null and rl.step between wv.step_group_production_begin and wv.step_group_production_end 
    		then step_group_production_end 
    	 when wv.step_group_verification_begin  is not null and rl.step between wv.step_group_verification_begin and wv.step_group_verification_end 
    		then step_group_verification_end 
	     when wv.step_group_delivery_begin  is not null and rl.step between wv.step_group_delivery_begin and wv.step_group_delivery_end 
    		then step_group_delivery_end
    	else wv.steps
    end  AS maxstep_group,
    rl.step,
    rl.activity_name,
    rl.api,
    rl.api_version,
    (xpath('//errorCode/text()'::text, rl.xml_response::xml))[1]::text AS errorcode,
    (xpath('//faultstring/text()'::text, rl.xml_response::xml))[1]::text AS message,
        CASE
            WHEN wv.steps = rl.step AND rl.success = true THEN 'LAST_STEP_DONE'::text
            WHEN wv.steps = rl.step AND rl.success = false THEN 'LAST_STEP_ERROR'::text
            WHEN (wv.steps - 1) = rl.step AND rl.success = true THEN 'LAST_STEP_PENDING'::text
            WHEN wv.steps > rl.step AND rl.step > 1 AND rl.success = false THEN 'MID_STEP_ERROR'::text
            WHEN (wv.steps - 1) > rl.step AND rl.step > 1 AND rl.success = true THEN 'MID_STEP_DONE'::text
            WHEN 1 = rl.step AND rl.success = true THEN 'FIRST_STEP_DONE'::text
            WHEN 1 = rl.step AND rl.success = false THEN 'FIRST_STEP_ERROR'::text
            ELSE 'UNKNOW_STATUS'::text
        END AS status,
    rl.lot_id_out AS idstepregister
   FROM register_log rl
     LEFT JOIN cyber_id ci ON ci.cyber_id::text = regexp_replace(rl.lot_id_out::text, '(-R[0-9]{2}).*$'::text, '\1'::text)
     LEFT JOIN cyber_id cig ON cig.id = ci.cyber_id_group_id
     LEFT JOIN workflow_name w ON rl.blockchain_id::bpchar = w.code
     LEFT JOIN workflow_version wv ON wv.workflow_name_id = w.id and wv.api = rl.api and wv.api_version = rl.api_version
  WHERE (rl.id IN ( SELECT max1.id
           FROM max1))
     )
	SELECT * FROM res
	 WHERE cyber_id ~ '148'
	   AND success=TRUE 
     ORDER BY wtype, left(cyber_id,20) DESC, timestamp DESC;

    
SELECT * FROM cyber_id ci WHERE cyber_id ~'24-0004';

SELECT *
  FROM v_step_record_and_fields vsraf 

SELECT DISTINCT cyber_id, KEY, value_convert_string
  FROM v_step_record_and_fields vsraf 
 WHERE KEY ~* 'only'  
   AND string_value='false'
   AND cyber_id_deleted IS FALSE 
   AND group_cyber_id_deleted IS FALSE 
  -- AND cyber_id ~'24-0004'
 ORDER BY cyber_id 

SELECT * FROM cyber_id_white_list ciwl ORDER BY cyber_id ;

--CYR01-21-0102-197212
--         1         2
--12345678901234567890

SELECT * FROM workflow_name wn;
SELECT * FROM v_register_log_detail vrld ORDER BY timestamp DESC LIMIT 100;

-- Yoan >> Enviar instruccions sobre com enviar WF-02

/*
 * Passar WF-02: (23-0708) a grups !!!
 * - Instruccions a Yoan
 * - Instruccions Marc
 */


SELECT DISTINCT cyber_id 
  FROM cyber_id ci 
 WHERE api_name ='diamonds-full' AND api_version='4'
   AND cancelled =FALSE;



SELECT * FROM product_search_index psi WHERE cyber_id  ~'CYR01-22-0648-220458'

SELECT * FROM cyber_id ci WHERE cyber_id ~'CYR01-22-0648-220458' ORDER BY id;
SELECT * FROM cyber_id ci WHERE cyber_id ~'CYR01-22-0677-226935' ORDER BY id;


SELECT * FROM step_record sr WHERE cyber_id ~'23-0637' ORDER BY id DESC;
-- Diambel vs Prime Gems



