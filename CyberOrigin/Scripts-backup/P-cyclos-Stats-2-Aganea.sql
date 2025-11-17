SELECT	mask,	rotate_bits
FROM
	id_cipher_rounds
ORDER BY
	order_index;

SELECT	*
FROM	accounts
WHERE	number ~* '10207842';

-- INFORME #2 -- Usuaris del sistema per mes
SELECT
     mes, 
     aut, sum(aut) over (order by mes) as s_aut,
     emp, sum(emp) over (order by mes) as s_emp,
     ent, sum(ent) over (order by mes) as s_ent,
     par, sum(par) over (order by mes) as s_par,
     aut+emp+ent+par as total, sum(aut+emp+ent+par) over (order by mes) as s_total
FROM (
	SELECT 
		date_trunc('month', u.creation_date)::date as mes,
		sum(case when g.id=16 then 1 else 0 end) as aut,
		sum(case when g.id=17 then 1 else 0 end) as emp,
		sum(case when g.id=18 then 1 else 0 end) as ent,
		sum(case when g.id=19 then 1 else 0 end) as par
	FROM 
		users u 
		LEFT OUTER JOIN user_group_logs ugl on	(ugl.user_id = u.id)
		LEFT OUTER JOIN "groups" g on	(ugl.group_id = g.id)
	WHERE 
		u.network_id =2 -- Vilawatt live
		AND creation_date > '2019-06-01' -- Official kick-off date
	GROUP BY date_trunc('month', creation_date)::date 
	) a
order BY mes;


select id, name, email, status from users
where
	network_id =2; -- Vilawatt live

select
	u.username, u.status, u."name", u.email, u.user_activation_date, ucf.id, ucf."name" as camp,
--	ucfv.string_value, ucfv.boolean_value, ucfv.date_value, decimal_value,
	coalesce(ucfv.string_value,'') || coalesce(case when ucfv.boolean_value is null then '' when ucfv.boolean_value then '<true>' else '<false>' end,'') ||
	coalesce(ucfv.date_value::date::varchar,'') || coalesce(ucfv.decimal_value::varchar,'') as valor
from
	users u 
	left outer join user_custom_field_values ucfv on (ucfv.owner_id=u.id)
	left outer join user_custom_fields ucf on (ucf.id=ucfv.field_id)
where
	u.network_id =2 -- Vilawatt live
	and u.user_activation_date between '2022-04-01' and '2022-05-01'
	and u.id=4928
order by 
	ucfv.date_value, username, id;

select * from users u 
	where u."name" ~*'carrico';


-- ============================================================
-- AGANEA -- LLISTAT DADES USUARIS
-- ============================================================
@set a_any    = 2022
@set a_mes    = 6

SELECT
	"name", status, registration_confirmation_date, user_activation_date, creation_date, idu, username, email, 
	string_agg(naix,'') as naix, string_agg(DNI,'') as DNI, 
	string_agg(Rao,'') as Rao, string_agg(NIF,'') as NIF, 
	string_agg(TR_Nom,'') as TR_Nom, string_agg(TR_Cog1,'') as TR_Cog1,
	string_agg(TR_DNI,'') as TR_DNI, string_agg(TR_NIF,'') as TR_NIF, string_agg(TR_Naix,'') as TR_Naix,
	string_agg(dir1,'') as dir1, string_agg(dir2,'') as dir2, string_agg(dir3,'') as dir3,
	string_agg(dir4,'') as dir4, string_agg(dir5,'') as dir5
FROM (
	SELECT
		u.id as idu, u.username, u, u.status, u."name", u.email, 
		u.registration_confirmation_date, u.user_activation_date, u.creation_date,
		ucf.id, ucf."name" as camp,
		case when ucfv.field_id=21 then ucfv.date_value::date::varchar else NULL end as naix,
		case when ucfv.field_id=23 then ucfv.string_value else NULL end as DNI,
		case when ucfv.field_id=33 then ucfv.string_value else NULL end as Rao,
		case when ucfv.field_id=44 then ucfv.string_value else NULL end as NIF,
		case when ucfv.field_id=37 then ucfv.string_value else NULL end as TR_Nom,
		case when ucfv.field_id=38 then ucfv.string_value else NULL end as TR_Cog1,
		case when ucfv.field_id=42 then ucfv.string_value else NULL end as TR_DNI,
		case when ucfv.field_id=67 then ucfv.string_value else NULL end as TR_NIF,
		case when ucfv.field_id=40 then ucfv.date_value::date::varchar else NULL end as TR_Naix,
		case when ucfv.field_id=77 then ucfv.string_value else NULL end as dir1,
		case when ucfv.field_id=78 then ucfv.string_value else NULL end as dir2,
		case when ucfv.field_id=79 then ucfv.string_value else NULL end as dir3,
		case when ucfv.field_id=80 then ucfv.string_value else NULL end as dir4,
		case when ucfv.field_id=81 then ucfv.string_value else NULL end as dir5,
		coalesce(ucfv.string_value,'--')||'%' as data
	FROM
		users u 
		LEFT OUTER JOIN user_custom_field_values ucfv on (ucfv.owner_id=u.id)
		LEFT OUTER JOIN user_custom_fields ucf on (ucf.id=ucfv.field_id)
	WHERE
		u.network_id =2 -- Vilawatt live
	--	and u.email IN ('cirilisay@gmail.com','hugocirili@hotmail.com')
		-- naixement, DNI, DNI-Rep, NIF, NIFTitREAL, direcc
	  	AND ucfv.field_id in (21,23,33,44,37,38,42,67,40,77,78,79,80,81)
	  	AND u.registration_confirmation_date BETWEEN make_date(${a_any},${a_mes},1) AND make_date(${a_any},${a_mes},1)+'1 month'::interval
--	  	and ucf.id = 67
	ORDER BY username, u.id
) a
--where string_value~*'%'
GROUP BY idu, username, status, "name", email, registration_confirmation_date, user_activation_date, creation_date
ORDER BY user_activation_date;

SELECT
	--u.username, u.status, u."name", u.email, ucfv.string_value as ciutat
	DISTINCT u.email, string_agg(u.username,', ') 
FROM
	users u 
	LEFT OUTER JOIN user_custom_field_values ucfv on (ucfv.owner_id=u.id)
	LEFT OUTER JOIN user_custom_fields ucf on (ucf.id=ucfv.field_id)
--	left outer join user_group_logs ugl on	(ugl.user_id = u.id)
--	left outer join "groups" g on	(ugl.group_id = g.id)
WHERE
	u.network_id =2 -- Vilawatt live
--	and u.email IN ('cirilisay@gmail.com','hugocirili@hotmail.com')
	AND ucfv.field_id IN (80)
	AND ucfv.string_value !~* 'viladecans'
GROUP BY u.email
ORDER BY email

