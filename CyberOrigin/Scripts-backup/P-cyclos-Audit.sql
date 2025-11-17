SELECT field_id, string_value
  FROM user_custom_field_values
 WHERE owner_id=1306 AND field_id IN (77, 78, 79, 80);

 --------------------------------------
-- POCA RECIRCULACIÓ (29.247₩ / 435.000₩, 714 tx)  →  6.7% de recirculació      
--------------------------------------
select
	u.username, u."name", u.email, sum(t.amount ), count(t.id), string_agg(u2."name" || ' (' || t.amount ||')', ', ')
from
	users u 
	left outer join transactions t on (t.from_user_id=u.id)
	left outer join users       u2 on (u2.id=t.to_user_id)
where
	u.network_id  =  2 -- Vilawatt live
	and t.type_id = 13 
	and t.to_user_id   not in (654)      -- Xarxa
	and t.from_user_id not in (654, 609) -- Xarxa + Ajuntament
group by
	u.username, u."name", u.email
order by 
	sum(t.amount) desc nulls last, count(t.id)

--------------------------------------
-- USADORS DE BONS de FORA DE VILADECANS
--------------------------------------
select
	distinct u.username --, ucfv1.string_value as ciutat
from
	users u 
	left outer join user_custom_field_values ucfv1 on (ucfv1.owner_id=u.id and ucfv1.field_id=80)
where
	u.network_id =2 -- Vilawatt live
	and u.status='ACTIVE'
	and ucfv1.string_value !~* 'viladecan'
	and ucfv1.string_value !~* 'vioadecan'
	and ucfv1.string_value !~* 'vildecan'
	and ucfv1.string_value !~* 'Viladecsns'
	and ucfv1.string_value !~* 'Viladecnas'
	and ucfv1.string_value !~* 'Viladecas'
	and ucfv1.string_value !~* 'Viladecams'
	and ucfv1.string_value !~* 'Viladadecans'
	and ucfv1.string_value !~* 'Vilacans'
	and ucfv1.string_value !~* 'Vikadecans'
	and ucfv1.string_value !~* 'Vadecans'
order by 
	username;

select
	distinct u.username, ucfv1.string_value as ciutat
from
	users u 
	left outer join user_custom_field_values ucfv1 on (ucfv1.owner_id=u.id)
where
	u.network_id =2 -- Vilawatt live
	and u.status='ACTIVE'
	and ucfv1.field_id in (78,79)
	and (ucfv1.string_value ~* 'viladecan'
	or  ucfv1.string_value ~* 'vioadecan'
	or  ucfv1.string_value ~* 'vildecan'
	or  ucfv1.string_value ~* 'Viladecsns'
	or  ucfv1.string_value ~* 'Viladecnas'
	or  ucfv1.string_value ~* 'Viladecas'
	or  ucfv1.string_value ~* 'Viladecams'
	or  ucfv1.string_value ~* 'Viladadecans'
	or  ucfv1.string_value ~* 'Vilacans'
	or  ucfv1.string_value ~* 'Vikadecans'
	or  ucfv1.string_value ~* 'Vadecans')
order by 
	username;

select
	distinct u.username, ucfv1.string_value as ciutat
from
	users u 
	left outer join user_custom_field_values ucfv1 on (ucfv1.owner_id=u.id)
where
	u.network_id =2 -- Vilawatt live
	and u.status='ACTIVE'
	and ucfv1.field_id in (77,78)
	and ucfv1.string_value ~* 'Balmes'
	and ucfv1.string_value ~* '47'
order by 
	username;

select
	distinct u.username, ucfv1.string_value as ciutat, u.user_activation_date 
from
	users u 
	left outer join user_custom_field_values ucfv1 on (ucfv1.owner_id=u.id)
where
	u.network_id =2 -- Vilawatt live
--	and u.status='ACTIVE'
	and ucfv1.string_value ~* '08'
	and ucfv1.string_value !~* '08840'
    and ucfv1.field_id in (78,79,80)
order by 
	username; --.user_activation_date  desc;

select
	distinct u.username, ucfv1.string_value as ciutat, u.user_activation_date 
from
	users u 
	left outer join user_custom_field_values ucfv1 on (ucfv1.owner_id=u.id)
where
	u.network_id =2 -- Vilawatt live
	and u.status='ACTIVE'
	and username ~*'alexandra94'
order by 
	username; --.user_activation_date  desc;




begin;
	update user_custom_field_v set
rollback;


--------------------------------------
-- EDATS SOSPITOSES (26 <18) (261 >70)
--------------------------------------
select
	u.username, u.status, u."name", u.email, ucfv1.date_value as naixement, date_part('year', age(now(),ucfv1.date_value)) as edat, ucfv2.string_value 
from
	users u 
	left outer join user_custom_field_values ucfv1 on (ucfv1.owner_id=u.id and ucfv1.field_id=21)
	left outer join user_custom_field_values ucfv2 on (ucfv2.owner_id=u.id and ucfv2.field_id=80)
where
	u.network_id =2 -- Vilawatt live
	and ucfv1.date_value < '1951-12-01'
--	and ucfv1.date_value > '2003-12-01'
--	and u.email IN ('cirilisay@gmail.com','hugocirili@hotmail.com')
order by 
	status, date_part('year', age(now(),ucfv1.date_value)) desc nulls last;


select
	floor(date_part('year', age(now(),ucfv1.date_value))/5)*5 as edat, count(*) as num
from
	users u 
	left outer join user_custom_field_values ucfv1 on (ucfv1.owner_id=u.id and ucfv1.field_id=21)
	left outer join user_custom_field_values ucfv2 on (ucfv2.owner_id=u.id and ucfv2.field_id=80)
where
	u.network_id =2 -- Vilawatt live
	and floor(date_part('year', age(now(),ucfv1.date_value))/5)*5 >= 15
--	and ucfv1.date_value < '1951-12-01'
--	and ucfv1.date_value > '2003-12-01'
--	and u.email IN ('cirilisay@gmail.com','hugocirili@hotmail.com')
group by 
	floor(date_part('year', age(now(),ucfv1.date_value))/5)*5
order by 
	floor(date_part('year', age(now(),ucfv1.date_value))/5)*5 desc nulls last;

----------------------------
-- GENT GRAN (de fora?)
----------------------------
select
	u.username, ucf.id, ucf."name" as camp, ucfv.string_value 
from
	users u 
	left outer join user_custom_field_values ucfv on (ucfv.owner_id=u.id)
	left outer join user_custom_fields ucf on (ucf.id=ucfv.field_id)
	left outer join user_group_logs ugl on	(ugl.user_id = u.id)
	left outer join "groups" g on	(ugl.group_id = g.id)
where
	u.network_id =2 -- Vilawatt live
and	u.id=1521
--	and ucfv.field_id in (78,79)
order by 
 username, ucf.id;

select u.id, u.username, u."name", u.email, u.status 
from users u 
where u.network_id =2
order by username;

--------------------------------------------------------------------------
-- Múltiples comptes un mateix telèfon (IBAN no donat d'alta, o repetit)   889/3700 (~25%)
--------------------------------------------------------------------------
select * 
--count(*)
from (
	select
		ucfv.string_value as movil, u.username, u.email, ucfv2.string_value as nom, u.name as nom_complet, g.name as grup,
		count(*) over (partition by ucfv.string_value, g.name) as num, 
		string_agg(username, ', ') over (partition by ucfv.string_value, g.name) as usuaris
	--	string_agg(u.username || '=' || u."name",', ')
	--	date_trunc('week', u.user_activation_date)::date,
	from
		users u 
		left outer join user_custom_field_values ucfv  on (ucfv.owner_id=u.id)
		left outer join user_custom_field_values ucfv2 on (ucfv2.owner_id=u.id)
		left outer join user_group_logs ugl on	(ugl.user_id = u.id)
		left outer join "groups" g on	(ugl.group_id = g.id)
	where 
	    u.network_id =2 -- Vilawatt live
		and ucfv.field_id=82
		and ucfv2.field_id=18
		) a
where 
	num > 2
order by num desc, movil;


-- Múltiples comptes un mateix telèfon (IBAN no donat d'alta, o repetit)   889/3700 (~25%)
--------------------------------------------------------------------------
select
	u.id, u.name, ucfv.string_value as mobil, count(*), left(g.name,6), string_agg('('||u.username || ') ' || u."name",', ')
--	date_trunc('week', u.user_activation_date)::date,
from
	users u 
	left outer join user_custom_field_values ucfv on (ucfv.owner_id=u.id)
	left outer join user_group_logs ugl on	(ugl.user_id = u.id)
	left outer join "groups" g on	(ugl.group_id = g.id)
where 
	u.network_id =2 -- Vilawatt live
--	and u.id=194
group by
	u.id, u.name, ucfv.string_value, left(g.name,6)
having
	count(*)>1
order by
	count(*) desc;


select
	g.id, g.name as tipus_usuari,
--	date_trunc('week', u.user_activation_date)::date,
	count(*)
from
	users u 
	left outer join user_group_logs ugl on	(ugl.user_id = u.id)
	left outer join "groups" g on	(ugl.group_id = g.id)
where u.network_id =2 -- Vilawatt live
group by
--	date_trunc('week', user_activation_date)::date,
	g.id, g.name
order by
--	date_trunc('week', user_activation_date)::date,
	g.id, g.name;



select * from users limit 1;
select * from networks;

select
	'========================================================' as "--------------",
	u.*,
	'========================================================' as "--------------",
	ugl.*,
	'========================================================' as "--------------",
	g.*,
	'********************************************************' as "--------------",
	u."name" as nom,		
	g.name as tipus_usuari
from
	users u
left outer join user_group_logs ugl on
	(ugl.user_id = u.id)
left outer join "groups" g on
	(ugl.group_id = g.id)
limit 1;

select
	u.id as id,
	u."name" as nom,
	g.name as tipus_usuari
from
	users u
left outer join user_group_logs ugl on	(ugl.user_id = u.id)
left outer join "groups" g on	(ugl.group_id = g.id)
limit 1;



------------- REPORT: ids sospitosos
select
	ucfv.string_value as mobil, u.id, u.username, u.user_activation_date 
--	date_trunc('week', u.user_activation_date)::date,
from
	users u 
	left outer join user_custom_field_values ucfv on (ucfv.owner_id=u.id)
where 
	u.network_id =2 -- Vilawatt live
	and ucfv.field_id=82 and ucfv.string_value in (
		select ucfv.string_value as mobil
	from
		users u 
		left outer join user_custom_field_values ucfv on (ucfv.owner_id=u.id)
	where 
		u.network_id =2 -- Vilawatt live
		and ucfv.field_id in (82)
	group by
		ucfv.string_value
	having
		count(*)>1)
order by mobil;

-- Detalls Cyclos d'un usuari
SELECT
	'========================================================' AS "--------------",	u.*,
	'========================================================' AS "--------------",	ugl.*,
	'========================================================' AS "--------------",	g.*,
	'********************************************************' AS "--------------",	u."name" AS nom, g.name AS tipus_usuari
FROM
	users u
	LEFT OUTER JOIN user_group_logs ugl ON	(ugl.user_id = u.id	)
	LEFT OUTER JOIN "groups" g 			ON	(ugl.group_id = g.id)
WHERE
	u.id = 2255	
LIMIT 1;



select
 cfv02.string_value as nom, cfv03.string_value as cognom, u.name as nom_complert,
 u.email, u.status, u.username, g.id as grup, g."name" as grup_desc, cfv06.string_value as NIF, cfv04.string_value as empresa, 
 cfv05.boolean_value as test,  cfv01.string_value as categoria
from
 users u
left join "groups" g on g.id = u.user_group_id
left join user_custom_field_values cfv01 on u.id = cfv01.owner_id and cfv01.field_id = 48  -- Categoria
left join user_custom_field_values cfv02 on u.id = cfv02.owner_id and cfv02.field_id = 18  -- Nom
left join user_custom_field_values cfv03 on u.id = cfv03.owner_id and cfv03.field_id = 19  -- Cognom
left join user_custom_field_values cfv04 on u.id = cfv04.owner_id and cfv04.field_id = 33    -- 23  -- Tipus entitat
left join user_custom_field_values cfv05 on u.id = cfv05.owner_id and cfv05.field_id = 70  -- Test?
left join user_custom_field_values cfv06 on u.id = cfv06.owner_id and cfv06.field_id = 23  -- Test?
--left join user_custom_field_values cfv07 on u.id = cfv07.owner_id and cfv07.field_id = 49  -- Test?
--left join user_custom_field_possible_values ucfpv on ucfpv.
where
 u.network_id = 2 -- n.internal_name = 'vwlive';
--status, cognom;
order by g.name 
;
