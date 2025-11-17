

---------------------------------------------------------------
-- Obté categoria d'establiment segons taula Ubiquat
SELECT
	u.id,	
	initcap(u."name") AS nom,
	lower(username) AS usuari,
	cfv.string_value AS classe,
	sc.desc_ca 
FROM
	cyclos_users u
	LEFT JOIN cyclos_user_custom_field_values cfv 	ON	cfv.owner_id = u.id
	LEFT JOIN cyclos_user_custom_fields cf 		ON	cf.id = cfv.field_id
	LEFT JOIN stats_categories sc 				ON  sc.id = cfv.string_value
WHERE
	u.network_id  = 2
	AND cf.internal_name = 'classificationCode'
ORDER BY
	classe,	nom;


/*---------------------------------------------------------------
-- Llista dels que haurien d'estar a la llista negra pq NO viuen a VLD
SELECT cu.id, cu.username, cu."name"
  FROM cyclos_users cu 
 WHERE cu.id NOT IN 
  -- Llista dels VIUEN a Viladecans
 (SELECT u.id 
	FROM
		cyclos_users u
		LEFT OUTER JOIN cyclos_user_custom_field_values ucfv1 ON (ucfv1.owner_id = u.id)
	WHERE
		u.network_id = 2
		AND ucfv1.string_value ~* '08840'
		AND ucfv1.field_id IN (77, 78, 79, 80)
)
--AND (cu.name     ~* 'Cortés' OR cu.username ~* 'Barranco')
;*/

---------------------------------------------------------------
-- Llista dels que haurien d'estar a la llista negra... i ara no hi son (pq treballen a VLD?)
SELECT cu.id, lower(cu.username), cu.name, string_agg(ucfv2.string_value, ' ## ') AS city, cu.status
  FROM cyclos_users cu 
  LEFT OUTER JOIN cyclos_user_custom_field_values ucfv2 ON (ucfv2.owner_id = cu.id)
 WHERE cu.id NOT IN 
  -- Llista dels VIUEN a Viladecans
 (SELECT u.id 
	FROM
		cyclos_users u
		LEFT OUTER JOIN cyclos_user_custom_field_values ucfv1 ON (ucfv1.owner_id = u.id)
	WHERE
		u.network_id = 2
		AND ucfv1.string_value ~* '08840'
		AND ucfv1.field_id IN (77, 78, 79, 80)
	) 
AND cu.id NOT IN
	-- Llista dels que ara estan a la blacklist
	(SELECT id FROM api_voucher_campaign_user_blacklist avcub)
	
AND cu.id NOT IN
	-- Llista dels que han presentat proves de treballar a VLD
	(3593,4864,2178,3248,4911,4980,5093,1562,1521,1904,4698,4098,4502,2527)
AND ucfv2.field_id IN (77, 78, 79, 80)
GROUP BY cu.id, cu.username, cu.name, cu.status 
HAVING string_agg(ucfv2.string_value, ' ## ')~*'vilad'
ORDER BY username ;

---------------------------------------------------------------
-- Llista dels que tenen dret a rebre 2 bons (viuen a VLD)
SELECT u.id, idcypher(u.id)
FROM
	cyclos_users u
	LEFT OUTER JOIN cyclos_user_custom_field_values ucfv1 ON (ucfv1.owner_id = u.id)
WHERE
	u.network_id = 2
	AND ucfv1.string_value ~* '08840'
	AND ucfv1.field_id IN (77, 78, 79, 80)
	OR u.id IN
	-- Llista dels que han presentat proves de treballar a VLD
	(3593,4864,2178,3248,4911,4980,5093,1562,1521,1904,4698,4098,4502,2527);

-- Veure dades d'adreça d'un usuari
SELECT field_id, string_value
  FROM cyclos_user_custom_field_values
 WHERE owner_id=1306 AND field_id IN (77, 78, 79, 80);

-- Cerca usuari per nom/usuari
SELECT id, username, "name" FROM cyclos_users cu
WHERE (cu.name   ~* 'Barranco'
  OR cu.username ~* 'Anapg85')
 ORDER BY "name" ;

SELECT count(*) FROM api_voucher_campaign_user_blacklist avcub ;
SELECT count(*) FROM cyclos_users cu;

-- Amb docs
SELECT cu.id, cu.username, cu."name" 
FROM cyclos_users cu 
WHERE id IN (3593,4864,2178,3248,4911,4980,5093,1562,1521)
ORDER BY id;

-- Sense docs 
SELECT cu.id, cu.username, cu."name" 
FROM cyclos_users cu 
WHERE id IN (1904,4698,4098,4502,2527)
ORDER BY id;


SELECT * FROM api_voucher_campaign_quota;
@set quota_id = 2
    
-- Assignació de BONS per WHITELIST
@set quant = 2
---INSERT INTO	voucher_campaign_custom_assignment_delta
INSERT INTO	tmp_delta
   (reason, quantity, "comment", "timestamp", user_id, campaign_id, quota_id)
   (SELECT 'BW2022 3R BO', 2, '3r bo per viure a Viladecans ('||u.username||')', 
           now(), idcypher(u.id), 2, 2
	FROM
		cyclos_users u
		LEFT OUTER JOIN cyclos_user_custom_field_values ucfv1 ON (ucfv1.owner_id = u.id)
	WHERE
		u.network_id = 2
		AND ucfv1.string_value ~* '08840'
		AND ucfv1.field_id IN (77, 78, 79, 80)
	);
           
DROP TABLE tmp_delta;

CREATE TABLE tmp_delta (
	id bigserial NOT NULL,
	"comment" varchar(255) NULL,
	quantity int4 NOT NULL,
	reason varchar(255) NULL,
	"timestamp" timestamp NULL DEFAULT CURRENT_TIMESTAMP,
	user_id int8 NOT NULL,
	campaign_id int8 NOT NULL,
	quota_id int8 NOT NULL           
);

SELECT id FROM voucher_campaign_custom_assignment_delta ORDER BY ID DESC LIMIT 1;
@set delta_id = 000	

