SELECT * FROM users WHERE id=156;
SELECT * FROM get_user_points_summary(126);

SELECT * FROM user_point_movements upm WHERE user_id =126 ORDER BY id;

-- 26  , 13  , 8     , 130  , 128    , 151    , 
-- Jona, Alex, Sandra, Monya, Daniela, Daniele, Luca
INSERT INTO public.orders_card ("order", author, user_id) SELECT 'FanFront', 'Jaume', users.id FROM users WHERE id IN (9,26) ORDER BY id;
INSERT INTO public.orders_card ("order", author, user_id) SELECT 'FanBack',  'Jaume', users.id FROM users WHERE id IN (9,26) ORDER BY id;

-- Regeneració de cards a TO ALL USERS (Atenció!!)
 INSERT INTO public.orders_card ("order", author, user_id) SELECT 'FanFront', 'Jaume', users.id FROM users ORDER BY id;
 INSERT INTO public.orders_card ("order", author, user_id) SELECT 'FanBack',  'Jaume', users.id FROM users ORDER BY id;
 INSERT INTO public.orders_card ("order", author, user_id) SELECT 'Special',  'Jaume', users.id FROM users WHERE id =  4; --IS NOT NULL ;
 INSERT INTO public.orders_card ("order", author, user_id) SELECT 'Limited',  'Jaume', users.id FROM users WHERE id = 22; --IS NOT NULL ;

-- Inserció de punts
IINSERT INTO public.user_point_movements (user_id,  points_delta, actor, description, visible, id_cause, "match")
VALUES(128, 5, 'HCC Awart all', 'Playoffs 2024 Match #3 1/4', TRUE, 0, 3);

--SELECT id, full_name, email, points, level FROM users u WHERE instagram ~'morticia'
SELECT id, email, nickname, full_name, instagram, status 
  FROM users WHERE email ~* 'yigit';

SELECT id, email, nickname, full_name, instagram, status 
  FROM users WHERE id IN (142,148)

 
SELECT * FROM get_user_points_summary(142);
SELECT * FROM user_point_movements upm WHERE upm.user_id = 130 ORDER BY "timestamp" ;

SELECT event_name, customer_firstname, customer_lastname, status, email, pass_email FROM event_tickets et 
 WHERE customer_lastname ~* 'matthey' --AND customer_firstname ~* 'joh'
 ORDER BY email, event_name;

SELECT DISTINCT customer FROM event_tickets et WHERE customer  ~* 'vincent'

SELECT give_ig_comms_points();
SELECT give_ig_likes_points();
SELECT * FROM get_ig_stats();

-- Ranking
SELECT * FROM get_user_rankings();

-- Estadístiques d'usuaris/nivell
SELECT * FROM get_stats_user_levels()

-- Consulta de punts
SELECT id, email, nickname, full_name, instagram, points, level FROM users u WHERE full_name ~* 'Sieg' ORDER BY id;

 	
SELECT u.signin_ts::date AS day, 
		TO_CHAR(signin_ts::date,'Dy') AS wday,
		m.phase || ' #' || ROW_NUMBER() OVER (PARTITION BY m.phase ORDER BY m.day) AS match,
		COUNT(*) AS new_users_count
  FROM users u
       LEFT OUTER JOIN matches m ON m."day"= u.signin_ts::date AND m."result" <> 'x'
 GROUP BY u.signin_ts::date, m.phase, m.id
 ORDER BY DAY desc;


SELECT * FROM get_stats_users_by_day();
DROP FUNCTION public.get_stats_users_by_day;
CREATE OR REPLACE FUNCTION public.get_stats_users_by_day()
RETURNS TABLE (
  day DATE,
  wday TEXT,
  match TEXT,
  users BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.signin_ts::date AS day, 
    TO_CHAR(u.signin_ts::date, 'Dy') AS wday,
    m.phase || ' #' || ROW_NUMBER() OVER (PARTITION BY m.phase ORDER BY u.signin_ts::date) AS match,
    COUNT(*) AS users
  FROM 
    users u
    LEFT OUTER JOIN matches m ON m."day" = u.signin_ts::date AND m."result" <> 'x'
  GROUP BY 
    u.signin_ts::date, m.phase, m.id
  ORDER BY 
    day DESC;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM get_user_posts(26);
SELECT * FROM get_user_points_summary(26)
	
-- Post captura de Likes & Comms
SELECT * FROM give_ig_comms_points();
SELECT * FROM give_ig_likes_points();
SELECT * FROM get_ig_stats(); 

-- Llista de punts per usuari
@set card='64330f1d'
SELECT * FROM users u  WHERE 
	card_fan_front::text ~ ${card} OR 
	card_fan_back::text  ~  ${card} OR
	card_ltd_front::text  ~ ${card} OR
	card_ltd_back::text  ~ ${card} OR
	card_spc_front::text  ~ ${card} OR
	card_spc_back::text  ~ ${card};


SELECT DAY, HOUR, place, rival, scoring, RESULT FROM matches m  ORDER BY day

SELECT * FROM get_user_points_summary(8);

SELECT * FROM get_points_for_phase(26, 'DEMI')


SELECT status, count(*) FROM orders_card GROUP BY status;

-- Detall punts donats a tothom (per partit)
SELECT MATCH, actor, count(*), sum(points_delta)
  FROM user_point_movements upm 
 WHERE MATCH IS NOT NULL 
GROUP BY GROUPING SETS ((MATCH, actor),(match))
ORDER BY MATCH, actor

SELECT id,	email,	nickname AS nick,	full_name,	status,	signin_ts , points,	"level", ltd_id, spc_id
 FROM users ORDER BY id ;	

SELECT status, LEVEL, count(*) FROM users GROUP BY status, LEVEL ORDER BY status, level;
SELECT id, email, status FROM users WHERE status='PENDING';
SELECT id, email, status FROM users WHERE email ~'adrien'

--UPDATE users SET email = lower(email) WHERE;

--*** USEFULL COMMANDS ***
--
-- Regeneració targetes to SINGLE USER
INSERT INTO public.orders_card ("order", author, user_id) VALUES ('FanFront', 'Jaume', 9);
INSERT INTO public.orders_card ("order", author, user_id) VALUES ('FanBack',  'Jaume', 9);

-- Control per si hi ha algun usuari sense front-card
SELECT * FROM users WHERE card_fan_front IS NULL AND status='ACTIVE';

--INSERT INTO public.orders_brevo ("order", author, user_id) VALUES ('Update',  'Jaume', 26);

-- DEELETE FROM event_tickets;

-- Inserció de punts DELTA
INSERT INTO public.user_point_movements  
      (user_id, points_delta, actor,  description,     visible)
VALUES(      9,     -1,      'Jaume', 'Punts de test', false);


SELECT * FROM orders_card WHERE "order"='Special' AND ts_pending > '2024-02-21' ORDER BY id;

SELECT * FROM users u WHERE card_spc_front IS NOT NULL OR card_spc_back  IS NOT NULL ORDER BY id;

SELECT	id,	email,	nickname AS nick,	full_name,	status,	email_validated AS email_val, points,	"level", ltd_id, spc_id,
		LEFT(validation_token::varchar, 3) AS val_tok,	reset_token, last_ticket,	last_instagram,	last_nfc_scan,
		instagram,	favorite_player_id AS fplayer
FROM	users
WHERE 
	id  = 9
--	email ~* ''
--	nickname ~* ''
--	full_name ~* ''
;

INSERT INTO public.user_point_movements (user_id, points_delta, actor,  description,     visible)
VALUES(9, -25, 'Jaume', 'Test', FALSE );

--Jona   = 5LBE6G > 26
--Sandra = 4VGK7L >  8  sandra.brisebard@me.com
--Alex   = 29MJAP > 13  alex.gil.w@gmail.com
--Luca   = N9PVID > 27  superbadator@gmail.com

SELECT * FROM passes p WHERE email_client  ~* 'fina'
SELECT email, pass_email FROM event_tickets et WHERE pass_email  ~* 'fina'
SELECT * FROM collectid_codes ORDER BY user_id DESC;



