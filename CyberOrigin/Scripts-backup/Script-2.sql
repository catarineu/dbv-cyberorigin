-- Llistat d'entrades venudes per dia
select
	e.id , e.nom,
    c.created_at::date,
	p.id , replace(cast(p.nom as json)->>'es'::varchar, '"', ''),
	count(*)
from
	comandas c, 
    left outer join "comandaItems" ci on (c.id = ci.comanda_id)
    left outer join productes      p  on (p.id  = ci.producte_id)
    left outer join establiments e on (e.id=c.establiment_id)
where
	c.estat = 3
	-- Canvi de 1→3
	and c.tipus_cua = 3
	-- Cua entrades
	and ci.producte_id in (146, 147, 148)
	and c.created_at > '2022-01-01'
group by
	e.id, p.id, c.establiment_id, e.nom, producte_id, p.nom,	c.created_at::date
order by
	c.establiment_id, producte_id, p.nom,	c.created_at::date
limit 10;

DROP TRIGGER check_ticket_stock_trigger ON comandas;
DROP FUNCTION check_ticket_stock();

CREATE OR REPLACE FUNCTION check_ticket_stock()
  RETURNS TRIGGER 
  LANGUAGE PLPGSQL  
  AS
$$
declare 
	t1 int; 
	t2 int;
	t12lim int;
	t3 int;
	t3lim int;
BEGIN
	IF (NEW.estat = 3) and (OLD.estat=1) and (new.tipus_cua =3) then
		select count(*) into t1
	      from "comandaItems" ci 
	           left outer join comandas c2 on (c2.id = ci.comanda_id and c2.estat=3)
	     where c2.establiment_id = NEW.establiment_id
 	       and ci.producte_id = 146;

   		select count(*) into t2
	      from "comandaItems" ci 
	           left outer join comandas c2 on (c2.id = ci.comanda_id and c2.estat=3)
	     where c2.establiment_id = NEW.establiment_id
 	       and ci.producte_id = 147;

 	    select "limit" into t12lim 
 	      from entrades_limits el
 	     where el.establiment_id=new.establiment_id and el.producte_id = 146147;
 	      
	   if ((t1+t2) >= t12lim) then
	       raise warning '   T1 >= Limit  →  %+% >= %', t1, t2, t12lim;
 	       update "producteEstabliments" set estat=3 where producte_id in (146, 147) and establiment_id=NEW.establiment_id;
	   else
	       raise warning '   T1 << Limit  →  %+% <  %', t1, t2, t12lim;
	   end if;

	  select count(*) into t3
	      from "comandaItems" ci 
	           left outer join comandas c2 on (c2.id = ci.comanda_id and c2.estat=3)
	     where c2.establiment_id = NEW.establiment_id
 	       and ci.producte_id = 148;
 	      
	   select "limit" into t3lim from entrades_limits where establiment_id=new.establiment_id and producte_id = 148;
 	      
-- 	      any(array(select id_producte from entrades_limits cl where cl.id_establiment=new.establiment_id));
	   raise warning '146 - T1 = %', t1;
	   if (t3 >= t3lim) then
	       raise warning '   T1 >= Limit  →  % >= %', t3, t3lim;
 	       update "producteEstabliments" set estat=3 where producte_id=148 and establiment_id=NEW.establiment_id;
	   else
	       raise warning '   T1 << Limit  →  % < %', t3, t3lim;
	   end if;
	END IF;

	RETURN NEW;
END;
$$


CREATE TRIGGER check_ticket_stock_trigger
  AFTER UPDATE
  ON comandas
  FOR EACH ROW
  EXECUTE PROCEDURE check_ticket_stock();


select * from "comandaItems" ci  limit 3;

select * from productes p where id in (146,147,148);
select * from productes p where nom~*'entrada';
select replace(cast(nom as json)->>'es'::varchar,'"','') from productes p where nom~*'entrada';


DROP TABLE public.entrades_limits;

CREATE TABLE public.entrades_limits (
	id_producte int4 NOT NULL,
	id_establiment int4 NOT NULL,
	"limit" int4 NULL,
	CONSTRAINT entrades_limits_pk PRIMARY KEY (id_producte, id_establiment)
);

insert into  entrades_limits (id_producte, id_establiment, "limit") values (146147,18,15);
insert into  entrades_limits (id_producte, id_establiment, "limit") values (148,18,15);
select * from entrades_limits;

select id_producte::varchar, id_establiment, "limit"  from entrades_limits;
select id_producte[1] from entrades_limits;

select * from productes p where id = any(array(select id_producte from entrades_limits));

-- Consulta d'entrades comprades (TOTALS)
select producte_id, count(*)
  from "comandaItems" ci 
       left outer join comandas c2 on (c2.id = ci.comanda_id and c2.estat=3)
 where c2.establiment_id = 18
 group by producte_id;

select * from "producteEstabliments" where establiment_id=18;
update "producteEstabliments" set estat=3 where establiment_id=18;

select c.id , c.estat, c.appusuari_id, c.establiment_id, c.updated_at , ci.producte_id, ci.quantitat, ci.comanda_id
  from comandas c
       left outer join "comandaItems" ci on (c.id =ci.comanda_id)
order by c.id desc limit 5;

select * from "comandaItems" order by id desc;

select * from establiments e where id=16;
select * from establiment_zona_torns_cua eztc where id=16;
select * from users u where id=967;

CREATE OR REPLACE FUNCTION check_double_buy()
  RETURNS TRIGGER 
  LANGUAGE PLPGSQL  
  AS
$$
declare 
	v_est  int;
	v_usu  int;
	v_num  int;
	msg	   varchar;
begin
	select c.establiment_id, c.appusuari_id into v_est, v_usu
      from comandas c
     where c.id = new.comanda_id;

   	if v_est not in (15) then   -- Només apliquem al 15
   		return new; 
   	end if;

    select sum(ci.quantitat) into v_num
      from "comandaItems" ci 
           left outer join comandas c2 on (c2.id = ci.comanda_id )
     where c2.estat=3 
       and c2.establiment_id = v_est
       and c2.appusuari_id = v_usu;

     if (v_num>0) then
		msg = 'L''Usuari ' || v_usu || ' ha comprat ja ' || v_num || ' entrades a l''establiment ' || v_est;
		raise warning '%', msg;
		insert into incidencies (tipus, descr, usuari_id, establiment_id) values ('LIMIT_USU', msg, v_usu, v_est);
		return NULL;
	 end if;

	RETURN NEW;
END;
$$

CREATE TRIGGER check_double_buy_trigger
  BEFORE INSERT
  ON "comandaItems"
  FOR EACH ROW
  EXECUTE PROCEDURE check_double_buy();
  
DROP TRIGGER check_double_buy_trigger   ON "comandaItems";

select * from incidencies;

explain     select ci.*
      from "comandaItems" ci 
           left outer join comandas c2 on (c2.id = ci.comanda_id)
     where c2.estat=3 
       and c2.appusuari_id = 967
       and c2.establiment_id = 15;
 