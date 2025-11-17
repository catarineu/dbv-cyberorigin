select estat, tipus, count(*) 
  from membres m 
 group by estat, tipus 
 order by estat, tipus;

select estat, count(*)
  from membres m 
 where dbaixa is not null 
group by estat; 

select * from membres m 
 where ncol=346;

-- DROP TYPE rebut_st;
-- CREATE TYPE rebut_st AS ENUM ('Pendent', 'Pagat', 'Retornat');

/*
  1. EXCEL
     a. Mail secretaria → carpeta "REBUTS"
     b. Eliminar files de subtotals i exportar-lo a CSV (UTF-8,";")
     c. Editar-lo:
        - "Nom";"Cognom1";"Cognom2";"ncol";"iban";"quota"
        - Eliminar " €"
        - Eliminar BIC, \n, etc...
	
  2. IMPORTACIÓ
     aa. Marcatge de 'Retornat' de quatrimestre anterior
     ab. Creació taula receptora REBUTS (_SQL_)
     b. DBeaver → Import CSV
     c. Neteja de dades   (_SQL_)
     d. Revisió d'IBANS   (_SQL_)
     e. Anàlisi de canvis (_SQL_) → Enviar-li a Secretaria per revisió
     f. Actualització de dades de col·legiats (Altes, baixes, canvis)
     
  3. PREPARACIÓ REMESA
     a. Configuració del mandat
     b. Creació del mandat
     c. Comprobació de subtotals
     d. Comprobació de subtotals AMB DETALL (si cal)
     e. Actualització totals a remeses_rebuts
     
  4. GENERACIÓ REMESA
     a. Generació capçalera            → .XML
     b. TMP Generació cos+peu (taula)
     c. TMP Control de strings NULLS
     d. Generació cos+peu              → .XML
*/
@set rebuts_old = rebuts_22q1
@set rebuts     = rebuts_22q2
@set remesa     = remesa_22q2
@set r_any      = 2022
@set r_trim     = 2
-- -------------------------------------------
-- 2AA: Marcatge 'Retornat' anteriors
-- -------------------------------------------
update ${rebuts_old} set estat='Pagat';
update ${rebuts_old} set estat='Retornat' where ncol in ();

-- -------------------------------------------
-- 2AB: Nova taula REBUTS
-- -------------------------------------------
CREATE TABLE ${rebuts} (
	nom varchar NOT NULL,
	cognom1 varchar NOT NULL,
	cognom2 varchar NULL,
	ncol numeric NOT NULL,
	quota numeric(5, 2) NOT NULL,
	iban varchar NOT NULL,
	sepa varchar(16) NULL,
	estat public.rebut_st NOT NULL DEFAULT 'Pendent'::rebut_st,
	CONSTRAINT ${rebuts}_pk_1 PRIMARY KEY (ncol)
);

-- -------------------------------------------
-- 2B: DBeaver → Import CSV
-- -------------------------------------------

-- -------------------------------------------
-- 2C: Neteja de dades importades
-- -------------------------------------------
update ${rebuts} set iban=replace(iban,' ',''); 
update ${rebuts} set iban=replace(iban,'.',''); 
update ${rebuts} set iban=replace(iban,'-',''); 
update ${rebuts} set nom=btrim(nom), cognom1=btrim(cognom1), cognom2=btrim(cognom2) ; 

-------------------------------------------------------
-- 2D: Revisió d'IBANS de la nova remesa
-------------------------------------------------------
select * from ${rebuts} rq where ncol not in (select ncol from membres m);  -- Col·legiats NOUS

select m.ncol, m.iban, rq.iban as iban_rebut, rq.ncol as ncol_rebut                   -- Col·legiats and IBAN nou 
  from ${rebuts} rq    
  full outer join membres m on (m.ncol=rq.ncol)
 where m.iban<>rq.iban;

select * from membres                     -- Cerca de nous IBANs sense BINs (executar IBANS.sh)
 where iban is not null and iban <> ''
   and estat='A' and bic is null; 

-- -------------------------------------------
-- 2E: Anàlisi de canvis entre trimestres
-- -------------------------------------------
select case 
		when col1 is     null and col2 is not null then 'Alta'
		when col1 is not null and col2 is     null and st1='Retornat' then 'Retornat'
		when col1 is not null and col2 is     null then 'Baixa'
		when col1 is not null and col2 is not null then 'Canvi' 
	   end as tipus,
 	   iban1, nom1, col1, col2, nom2, iban2
  from (
		select mq.iban || ' (' || mq.quota || ')' as iban1,
			   mq.cognom1 || ' ' || mq.cognom2 || ', ' || mq.nom as nom1,
			   mq.ncol as col1, mq41.ncol as col2,
			   mq41.cognom1 || ' ' ||  mq41.cognom2 || ', ' ||  mq41.nom as nom2,
			   mq41.iban || ' (' || mq41.quota || ')' as iban2,
			   mq.estat as st1
		  from ${rebuts_old} mq 
		  	   full outer join ${rebuts} mq41 on (mq.ncol=mq41.ncol)
		 where (mq41.ncol is null or mq.ncol is null)
		    or mq.iban <> mq41.iban or mq.quota <> mq.quota) a
 order by tipus, col1;


-- -------------------------------------------
-- 2F: Revisió de dades de col·legiats
-- -------------------------------------------
-- Altes    >> De Excel.COEINF a 'membres'.A
-- Baixes   >> De Excel.baixes a 'membres'.B
-- Canvi    >> Canvis escrits  a 'membres'.A
-- Retornat >> Segueixen en    a 'membres'.A

-- -------------------------------------------
-- 3A: Programació del mandat
-- -------------------------------------------
INSERT INTO public.remeses_resum
  ("year",quarter,coeinf_iban,coeinf_bin,desc_l1,desc_l2,desc_l3) VALUES
  (${r_any},${r_trim},'ES9430250001131433543521','CDENESBBXXX',
   'COEINF Quota '||${r_trim}||'T-'||${r_any}||' (Col·legiat)',
   'COEINF Quota '||${r_trim}||'T-'||${r_any}||' (Adherit)',
   'COEINF Quota '||${r_trim}||'T-'||${r_any});

-- -------------------------------------------
-- 3B: Creació del mandat
-- -------------------------------------------

drop   table ${remesa};

create table ${remesa} as (
select distinct
--	m.estat,m.dalta,m.dbaixa, m.observacions, m.tarifa,m.dtarifa, 
	m.ncol,	left(concat_ws (' ', m.nom, m.cognom1, m.cognom2),50) as nom, m.tipus,
	left(concat_ws (' ', m.via, m.carrer, m.num, m.pis),50) as domicili,
	m.cpostal, m.poblacio, cp.provincia, m.pais,
	2 as deutor_type, m.dni as deutor_id, 'A' as compte_t, m.iban, m.bic, rq.quota as import, 
	((r.year%100 * 100 + r.quarter)*10000+m.ncol)::varchar || 'A' as carrecref,
	'RCUR' as carrectipus,
	now()::date+1 as carrecdata, 
	coalesce(to_char(m.dsepa, 'YYMMDD'),to_char(m.dalta, 'YYMMDD'))||to_char(m.ncol,'FM0000')  as mandatref,
	coalesce(m.dsepa,m.dalta)  as  mandatdate,
	case  
	when m.tipus='COL' then r.desc_l1 
	when m.tipus='ADH' then r.desc_l2
	end as desc, r.coeinf_iban, r.coeinf_bin 
  from membres m
       inner join ${rebuts} rq on (m.ncol=rq.ncol)
       left outer join cpostals cp on (m.cpostal=cp.cpostal),
       remeses_resum r
  where r.year=${r_any} and r.quarter=${r_trim}
   and  ((m.estat='A' and dalta<'2022-06-01')    -- Posa aquí data FINAL   del trimestre
        or (m.estat='B' and dbaixa>'2022-03-01')) -- Posa aquí data INICIAL del trimestre
   and (tarifa in ('NORMAL','COETIC')
        or (tarifa='PROMO' and dtarifa<now()))
   and rq.quota is not null                     -- descomentar pel csv !!
  order by m.tipus, m.ncol
 );

-- -------------------------------------------
-- 3C: Comprobació de subtotals
-- -------------------------------------------
select tipus, count(*), sum(import) as import
  from ${remesa}
 group by grouping sets ((tipus),())
 order by tipus;

-- -------------------------------------------
-- 3D: Comprobació de subtotals DETALLATS (si cal)
-- -------------------------------------------
select tipus, nom, ncol, sum(import) ,
       sum(import) OVER (PARTITION BY tipus ORDER BY ncol) AS impsum
  from ${remesa}
 group by grouping sets ((tipus, nom, ncol, import),())
 order by tipus desc nulls last, ncol nulls last;

-- -------------------------------------------
-- 3E: Actualització totals a remeses_resum
-- -------------------------------------------
update remeses_resum 
   set order_sum = rq.txsum,
       order_num = rq.txnum,
       exectime  = now()
   from (select count(ncol) as txnum, sum("import") as txsum from ${remesa}) as rq   -- TAULA REMESA
 where year=${r_any} and quarter=${r_trim};  
 

-- -------------------------------------------
-- 4A: Generació capçalera remesa XML
-- -------------------------------------------
select '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Document xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="urn:iso:std:iso:20022:tech:xsd:pain.008.001.02">
<CstmrDrctDbtInitn>
		<GrpHdr>
			<MsgId>'||msgid||'</MsgId>
			<CreDtTm>'||msgts||'</CreDtTm>
			<NbOfTxs>'||txnum||'</NbOfTxs>
			<CtrlSum>'||txsum||'</CtrlSum>
			<InitgPty>
				<Nm>'||initname||'</Nm>
				<Id>
					<PrvtId>
						<Othr>
							<Id>'||initid||'</Id>
						</Othr>
					</PrvtId>
				</Id>
			</InitgPty>
		</GrpHdr>
		<PmtInf>
			<PmtInfId>'||txid||'</PmtInfId>
			<PmtMtd>DD</PmtMtd>
			<BtchBookg>false</BtchBookg>
			<NbOfTxs>'||txnum||'</NbOfTxs>
			<CtrlSum>'||txsum||'</CtrlSum>
			<PmtTpInf>
				<SvcLvl>
					<Cd>SEPA</Cd>
				</SvcLvl>
				<LclInstrm>
					<Cd>CORE</Cd>
				</LclInstrm>
				<SeqTp>RCUR</SeqTp>
				<CtgyPurp>
					<Cd>CASH</Cd>
				</CtgyPurp>
			</PmtTpInf>
			<ReqdColltnDt>'||txday1||'</ReqdColltnDt>
			<Cdtr>
				<Nm>'||initname||'</Nm>
			</Cdtr>
			<CdtrAcct>
				<Id>
					<IBAN>'||initiban||'</IBAN>
				</Id>
			</CdtrAcct>
			<CdtrAgt>
				<FinInstnId>
					<BIC>'||initbic||'</BIC>
				</FinInstnId>
			</CdtrAgt>
			<CdtrSchmeId>
				<Id>
					<PrvtId>
						<Othr>
							<Id>'||initid||'</Id>
							<SchmeNm>
								<Prtry>SEPA</Prtry>
							</SchmeNm>
						</Othr>
					</PrvtId>
				</Id>
			</CdtrSchmeId>
'
from 
(select 'PRE' || to_char(now(),'YYYYMMDDHH24MISS') || '00800COEINF2022' as msgid,
       to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS') as msgts,
       rr.order_num as txnum,
       rr.order_sum as txsum,
       DATE 'tomorrow' as txday1,
       to_char(now(),'YYYYMMDDHH24MISS') || 'WA7' || i.nif || '200' as txid,
       'COL.LEGI OFICIAL D''ENGINYERIA INFORMATICA DE CATALUNYA' as initname,
       i.bankid as initid,
       rr.coeinf_iban as initiban,
       rr.coeinf_bin  as initbic
  from remeses_resum rr,
       info i 
 where rr."year" = ${r_any} and rr.quarter = ${r_trim}) a;                                           -- ANY i QUARTER


-- -------------------------------------------
-- 4B: TMP Generació cos+peu (taula)
-- -------------------------------------------
drop table tmprows;
select '			<DrctDbtTxInf>
				<PmtId>
					<EndToEndId>' || carrecref || '</EndToEndId>
				</PmtId>
				<InstdAmt Ccy="EUR">'||import||'</InstdAmt>
				<DrctDbtTx>
					<MndtRltdInf>
						<MndtId>'||mandatref||'</MndtId>
						<DtOfSgntr>2009-10-31</DtOfSgntr>
					</MndtRltdInf>
				</DrctDbtTx>
				<DbtrAgt>
					<FinInstnId>
						<BIC>'||bic||'</BIC>
					</FinInstnId>
				</DbtrAgt>
				<Dbtr>
					<Nm>'||ncol||' - '||upper(nom)||'</Nm>
					<PstlAdr>
						<Ctry>'||pais||'</Ctry>
						<AdrLine>'||upper(domicili) || ' ' || cpostal || ' ' || upper(poblacio) ||'</AdrLine>
						<AdrLine>('||coalesce(upper(provincia),'')||')</AdrLine>
					</PstlAdr>
					<Id>
						<PrvtId>
							<Othr>
								<Id>'||deutor_id||'</Id>
								<Issr>NIF</Issr>
							</Othr>
						</PrvtId>
					</Id>
				</Dbtr>
				<DbtrAcct>
					<Id>
						<IBAN>'||iban||'</IBAN>
					</Id>
				</DbtrAcct>
				<RmtInf>
					<Ustrd>'|| upper("desc")||'</Ustrd>
				</RmtInf>
			</DrctDbtTxInf>
' as outstr, tipus, ncol
into temp tmprows 
 from ${remesa} rq;                                                     -- TAULA REMESA
 
-- -------------------------------------------
-- 4C: TMP Control de strings NULLS
-- -------------------------------------------
 select t.ncol, rq2.*
  from tmprows t 
       full outer join ${remesa} rq2 on (t.ncol=rq2.ncol)
 where t.outstr is null;

-- -------------------------------------------
-- 4D: Generació cos+peu XML → TXT
-- -------------------------------------------
select string_agg(a.outstr,'') ||
'		</PmtInf>
	</CstmrDrctDbtInitn>
</Document>
'
  from (select outstr from tmprows order by tipus desc, ncol) a;
