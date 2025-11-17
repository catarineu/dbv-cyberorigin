select iban,bic from membres where iban is not null and iban<>'' order by estat,iban;
select ncol, estat, tarifa, iban,bic from membres where iban is not null and iban<>'' order by estat,iban;

select tipus,estat,count(*) 
from membres 
group by tipus,estat
order by tipus,estat;

select estat, tarifa, ncol, nom, cognom1, iban, bic 
  from membres
 where estat='B' and iban<>'';

-- -------------------------------------------
-- Canvis entre quatrimestres
-- -------------------------------------------
select case 
		when col1 is     null and col2 is not null then 'Alta'
		when col1 is not null and col2 is     null then 'Baixa'
		when col1 is not null and col2 is not null then 'Canvi' 
	   end as tipus,
 	   iban1, nom1, col1, col2, nom2, iban2
  from (
		select mq.iban || ' (' || mq.quota || ')' as iban1,
			   mq.cognom1 || ' ' || mq.cognom2 || ', ' || mq.nom as nom1,
			   mq.ncol as col1, mq41.ncol as col2,
			   mq41.cognom1 || ' ' ||  mq41.cognom2 || ', ' ||  mq41.nom as nom2,
			   mq41.iban || ' (' || mq41.quota || ')' as iban2
		  from "rebuts_21Q3" mq 
		  	   full outer join "rebuts_21Q4" mq41 on (mq.ncol=mq41.ncol)
		 where (mq41.ncol is null or mq.ncol is null)
		    or mq.iban <> mq41.iban or mq.quota <> mq.quota) a
 order by tipus, col1;

---------------------------------------------------
--(1) Cerca de nous IBANs sense BINs (executar BINS.sh)
select * from membres_4q where bic is null; 

--(2) Neteja despais
update membres_4q set iban=replace(iban,' ',''); 
update membres_4q set nom=btrim(nom), cognom1=btrim(cognom1), cognom2=btrim(cognom2) ; 

--(3) Definició del mandat
INSERT INTO_ public.mandates 
  ("year",quarter,mandate_seed,coeinf_iban,coeinf_bin,desc_l1,desc_l2,desc_l3,exectime) VALUES
  (2021,3,70000000000,'ES1500810115910001225926','BSABESBBXXX',
   'COEINF Quota 4T-2021','COEINF Quota 4T-2021','COEINF Quota 4T-2021',NULL);

select * from remesa_21Q4;
 
-------------------------------------------------------
-- REVISAR si hi ha rebuts sense dades del col·legiat
-------------------------------------------------------
select * from "rebuts_21Q4" rq where ncol not in (select ncol from membres m);
select rq.iban,m.iban,rq.bic,m.bin
  from "rebuts_21Q4" rq
       full outer join membres m on (m.ncol=rq.ncol)
 order by ncol;

-- Rebuts_21Q4
drop table remesa_21Q4;
create table remesa_21Q4 as (
select distinct
--	m.estat,m.dalta,m.dbaixa, m.observacions, m.tarifa,m.dtarifa, 
	m.ncol,	left(concat_ws (' ', m.nom, m.cognom1, m.cognom2),50) as nom, m.tipus,
	left(concat_ws (' ', m.via, m.carrer, m.num, m.pis),50) as domicili,
	m.cpostal, m.poblacio, cp.provincia, m.pais,
	2 as deutor_type, m.dni as deutor_id, 'A' as compte_t, m.iban, m.bic, rq.quota as import, 
	((r.year%100 * 100 + r.quarter)*10000+m.ncol)::varchar || 'A' as carrecref,
	'RCUR' as carrectipus,
	now()::date+1 as carrecdata, 
	to_char(m.dalta, 'YYMMDD')||to_char(m.ncol,'FM0000')  as mandatref,
	case 
	when m.tipus='COL' then r.desc_l1 
	when m.tipus='ADH' then r.desc_l2
	end as desc, r.coeinf_iban, r.coeinf_bin 
  from membres m
       full outer join "rebuts_21Q4" rq on (m.ncol=rq.ncol)
       left outer join cpostals cp on (m.cpostal=cp.cpostal),
       remeses_resum r
  where r.year=2021 and r.quarter=4 
   and  ((estat='A' and dalta<='2021-12-31')    -- Posa aquí data FINAL   del trimestre
        or (estat='B' and dbaixa>'2021-10-01')) -- Posa aquí data INICIAL del trimestre
   and (tarifa in ('NORMAL','COETIC')
        or (tarifa='PROMO' and dtarifa<now()))
   and rq.quota is not null                     -- descomentar pel csv !!
  order by m.tipus, m.ncol
 );
;


-- REPORT de cobraments segons tipus d'usuari
select tipus, count(*), sum(import) as import
  from remesa_21Q4
 group by grouping sets ((tipus),())
 order by tipus;

-- REPORT de cobraments segons tipus d'usuari (només efectius)
select "desc", tipus, estat, tarifa, dtarifa, tmp.import, count(*), sum(import) as import, 
		string_agg('## ' || coalesce(ncol,0)||','||nom
				   ||', alta='||coalesce(dalta,'2999-01-01')||coalesce(', baixa='||dbaixa,'')
		 		   ||', '||coalesce(observacions,''),',  ')  
  from remesa_21Q4 
 where ((estat='A' and dalta<='2021-12-31')
        or (estat='B' and dbaixa>'2021-10-01')) -- Posa aquí data oficial del rebut
   and (tarifa in ('NORMAL','COETIC')
        or (tarifa='PROMO' and dtarifa<now()))
 group by grouping sets (("desc",tipus,estat,tarifa,dtarifa, import),("desc",tipus),()) 
 order by "desc", tipus, estat, tmp.import nulls first, "desc" nulls last, tarifa, tmp.import;

