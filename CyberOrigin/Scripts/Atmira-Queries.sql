SELECT count(*) FROM users;

SELECT id, internal_name FROM user_custom_fields ucf ORDER BY id;


-- Llistat d'emails (per crear el correu d'avís amb CCO)
SELECT string_agg(gmail,';') FROM  (
	SELECT u.id, u."name", u.email, ucfv.string_value AS gmail
	  FROM users u 
	       INNER JOIN user_custom_field_values ucfv ON (ucfv.owner_id=u.id AND ucfv.field_id=4)
     WHERE ucfv.string_value IS NOT NULL
           AND ucfv.string_value NOT IN (SELECT gmail FROM tmp_gmails)
	 ORDER BY gmail
) a;

-- ===========================================================================
-- Consulta de gmails dels usuaris, per afegir com a excepció a Google OAuth	 
CREATE TABLE tmp_gmails3 AS 
(	SELECT now()::date AS moment, ucfv.string_value AS gmail
	  FROM users u 
	       INNER JOIN user_custom_field_values ucfv ON (ucfv.owner_id=u.id AND ucfv.field_id=4)
     WHERE ucfv.string_value IS NOT null
)

-- Eliminem els ja afegits anteriorment	 
SELECT * FROM tmp_gmails3
 WHERE gmail NOT IN (SELECT gmail FROM tmp_gmails);
   AND gmail NOT IN (SELECT gmail FROM tmp_gmails2);

  
-- ==============================================================
-- ==============================================================
SELECT	count(*), sum(param_health_num_steps) 
  FROM	atmira_token_delta
 WHERE	cyclos_ignore IS FALSE;

SELECT	DISTINCT atd.user_id
  FROM	atmira_token_delta atd
 WHERE	cyclos_ignore IS FALSE;

-- Passes de l'usuari test
SELECT cyclos_ignore, *
  FROM atmira_token_delta atd
 WHERE user_id =36
 ORDER BY cyclos_processed_timestamp DESC;

UPDATE atmira_token_delta SET cyclos_ignore=FALSE WHERE id=369;

-- Passes acumulades+AVG dels usuaris 
SELECT	user_id, u."name", count(param_health_num_steps) AS weeks, 
 		sum(param_health_num_steps), round(avg(param_health_num_steps),0) AS avg,
 		sum(atd.quantity) AS "$ATM",
 		max(cyclos_processed_timestamp), 
 		DATE_PART('week',min(cyclos_processed_timestamp)) AS min_w, email
  FROM	atmira_token_delta atd
  		LEFT OUTER JOIN users u ON (u.id=atd.user_id)
 WHERE	cyclos_ignore IS FALSE 
        AND user_id <> 4 -- Test user
GROUP BY user_id, u.name, email
--ORDER BY max(cyclos_processed_timestamp)::date DESC 
ORDER by weeks DESC, sum(param_health_num_steps) DESC

-- Passes acumulades+AVG dels usuaris 
SELECT	user_id, u."name", count(param_health_num_steps), 
 		sum(param_health_num_steps), round(avg(param_health_num_steps),0) AS avg,
 		max(cyclos_processed_timestamp)::date, 
 		DATE_PART('week',min(cyclos_processed_timestamp)) AS min_w, email
  FROM	atmira_token_delta atd
  		LEFT OUTER JOIN users u ON (u.id=atd.user_id)
 WHERE	cyclos_ignore IS FALSE 
GROUP BY user_id, u.name, email
ORDER by count DESC, sum(param_health_num_steps) DESC

-- Quants usuaris+registres per cada setmana 
WITH dades AS (
	SELECT	count(param_health_num_steps) AS regs, 
	 		DATE_PART('week',min(cyclos_processed_timestamp)) AS min_w,
	 		sum(param_health_num_steps) AS suma
	 FROM	atmira_token_delta atd
	  		LEFT OUTER JOIN users u ON (u.id=atd.user_id)
	 WHERE	cyclos_ignore IS FALSE
	GROUP BY user_id)
SELECT regs, min_w, count(*), sum(suma), round(sum(suma)/(regs*count(*)),0)
  FROM dades
 GROUP BY regs, min_w
 ORDER BY regs DESC, min_w, count


 
 SELECT * FROM user_custom_fields ucf ;


SELECT * FROM atmira_token_delta 
 WHERE cyclos_ignore IS FALSE
 ORDER BY id desc;

SELECT * FROM atmira_token_delta atd ORDER BY id desc;

SELECT atd.id, insert_timestamp, user_id || ' - ' || u.username, quantity, reason, "comment", 
       cyclos_processed, cyclos_processed_timestamp, cyclos_transfer_id, cyclos_balance_pre, cyclos_balance_post, cyclos_source_user_id, cyclos_source_balance_pre, cyclos_source_balance_post, blockchain_processed, blockchain_processed_timestamp, blockchain_transaction_id, param_qr_code, param_health_num_steps, param_office_presence_days, cyclos_original_transfer_id, cyclos_ignore, cyclos_error, cyclos_error_text, internal_comments  
  FROM atmira_token_delta atd 
       LEFT OUTER JOIN users u ON (atd.user_id=u.id)
 WHERE cyclos_ignore IS FALSE
 ORDER BY atd.id DESC 
 LIMIT 10;


WITH new_active_users AS (
	SELECT EXTRACT(WEEK FROM insert_timestamp) AS week_number, COUNT(*) AS new_users_count
	FROM (
	    SELECT user_id, MIN(insert_timestamp) AS insert_timestamp
	    FROM atmira_token_delta
	    GROUP BY user_id
	) AS first_inserts
	GROUP BY week_number
	ORDER BY week_number
),
acum_users AS (
	SELECT DATE_PART('week',u.user_activation_date) AS week_number, count(*)  AS s_users
	  FROM users u 
	 GROUP BY DATE_PART('week',u.user_activation_date), date_trunc('week', user_activation_date)::date
	 ORDER BY DATE_PART('week',u.user_activation_date)
)
SELECT DATE_PART('week',insert_timestamp) AS week, date_trunc('week', insert_timestamp)::date AS date,
	   COALESCE(ac.s_users,0) AS new_u, COALESCE(nau.new_users_count,0) AS new_w, 
	   count(*)      AS regs, sum(count(*))      OVER (ORDER BY EXTRACT(WEEK FROM insert_timestamp)) AS s_regs,
	   sum(quantity) AS atms, sum(sum(quantity)) OVER (ORDER BY EXTRACT(WEEK FROM insert_timestamp)) AS atms,
	   sum(param_health_num_steps) AS steps, count(param_qr_code) AS QRs
  FROM atmira_token_delta atd 
       LEFT OUTER JOIN new_active_users nau ON (DATE_PART('week',atd.insert_timestamp)=nau.week_number)
       LEFT OUTER JOIN acum_users       ac  ON (DATE_PART('week',atd.insert_timestamp)=ac.week_number)
 WHERE cyclos_ignore IS FALSE
 GROUP BY DATE_PART('week',insert_timestamp), new_users_count, date_trunc('week', insert_timestamp)::date, s_users
 ORDER BY DATE_PART('week',insert_timestamp), new_users_count

 
 
SELECT u.id, u.username, u.email, sum(quantity), string_agg(''||quantity,',')
  FROM atmira_token_delta atd 
       LEFT OUTER JOIN users u ON (atd.user_id=u.id)
 WHERE cyclos_ignore IS FALSE
 GROUP BY u.id, u.username, u.email
 ORDER BY sum(quantity) DESC 

-- UPDATE atmira_token_delta atd
--    SET cyclos_ignore=TRUE
--  WHERE atd.user_id=4;
 
 
 SELECT atd.id, to_char(insert_timestamp, 'YYYY-MM-DD HH24:MI'), user_id || ' - ' || u.username, quantity, reason, "comment", 
       cyclos_balance_pre, cyclos_balance_post, substr(param_qr_code,1,5), param_health_num_steps, param_office_presence_days
  FROM atmira_token_delta atd 
       LEFT OUTER JOIN users u ON (atd.user_id=u.id)
 WHERE cyclos_processed=TRUE
   AND cyclos_ignore=FALSE
 ORDER BY atd.id DESC;

-- HEALTH_STEPS_GRANT    >> S'agafa de l'app. No es pot inserir manualment
-- QR_CODE_GRANT         >> S'agafa de l'app. No es pot inserir manualment
-- SOCIAL_NETWORKS_GRANT >> Ok.
-- OFFICE_PRESENCE_GRANT >> Ok.

INSERT INTO atmira_token_delta 
(user_id, quantity, reason, "comment", param_office_presence_days, internal_comments)
VALUES 
(4, 1, 'OFFICE_PRESENCE_GRANT', 'Assistència més del 50% setmana 04/2023', 3, 'Prova assistència')


