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
     b. Editar-lo:
        - "Nom";"Cognom1";"Cognom2";"ncol";"iban";"SEPA";"quota"
     c. Eliminar files de subtotals i exportar-lo a CSV (UTF-8,";")
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
@set rebuts_old = rebuts_23q3
@set rebuts     = rebuts_23q4
@set remesa     = remesa_23q4
@set r_any      = 2023
@set r_trim     = 4
@set d_ini_trim = '2023-10-01'
@set d_fin_trim = '2023-12-01'

-- -------------------------------------------
-- 2AA: Marcatge 'Retornat' anteriors
-- -------------------------------------------
SELECT estat, count(*) FROM  ${rebuts_old} GROUP BY estat ORDER BY estat;
update ${rebuts_old} set estat='Pagat';
update ${rebuts_old} set estat='Retornat' where ncol in (25);
--SELECT * FROM ${rebuts_old} WHERE ncol=25;
--SELECT * FROM ${rebuts_old} WHERE nom ~*'';

-- -------------------------------------------
-- 2AB: Nova taula REBUTS
-- -------------------------------------------
--DROP TABLE ${rebuts} 
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

INSERT INTO public.membres 
   (nom, cognom1, cognom2, ncol, docs_carta, sexe, 
    carnet, acei, titol, titol_desc, universitat, any_titol, email,
    email_coeinf, email_2, dni, tf, tf2, via, carrer, num, pis, cpostal, poblacio, 
    dnaix, iban, cessio_3rs, dalta, dsepa, pais, tipus,
    dbaixa, baixa_motiu, estat, dtarifa, bic, tarifa, observacions)
    VALUES ('Jordi', 'Ballús', 'Vila', 1127, 'Sí','H',
    '','X','EI','Enginyeria Informàtica','UAB','2005','hola@jordiballus.com',
    'jordi_ballus@enginyeriainformatica.cat','', '77628487Z', '661040999', '','C','Major','87','','08755','Castellbisbal',
    '1976-01-20', 'ES6121000386280200524852', 'No', '2023-09-29', '2023-09-29', 'ES', 'COL', 
    NULL, NULL, 'A', '2023-09-29', NULL, 'NORMAL', '') ON CONFLICT (ncol) DO UPDATE 
   SET 
    nom = EXCLUDED.nom,     cognom1 = EXCLUDED.cognom1,    cognom2 = EXCLUDED.cognom2,    docs_carta = EXCLUDED.docs_carta, 
    sexe = EXCLUDED.sexe,     carnet = EXCLUDED.carnet,    acei = EXCLUDED.acei,    titol = EXCLUDED.titol, 
    titol_desc = EXCLUDED.titol_desc,     universitat = EXCLUDED.universitat,    any_titol = EXCLUDED.any_titol, 
    email = EXCLUDED.email,     email_coeinf = EXCLUDED.email_coeinf,    email_2 = EXCLUDED.email_2, 
    dni = EXCLUDED.dni,     tf = EXCLUDED.tf,    tf2 = EXCLUDED.tf2,     via = EXCLUDED.via,     carrer = EXCLUDED.carrer,
    num = EXCLUDED.num,     pis = EXCLUDED.pis,    cpostal = EXCLUDED.cpostal,    poblacio = EXCLUDED.poblacio, 
    dnaix = EXCLUDED.dnaix,     iban = EXCLUDED.iban,    cessio_3rs = EXCLUDED.cessio_3rs,    dalta = EXCLUDED.dalta, 
    dsepa = EXCLUDED.dsepa,  	  pais = EXCLUDED.pais,    tipus = EXCLUDED.tipus,    dbaixa = EXCLUDED.dbaixa, 
    baixa_motiu = EXCLUDED.baixa_motiu,    estat = EXCLUDED.estat,    dtarifa = EXCLUDED.dtarifa, 
    bic = EXCLUDED.bic,     tarifa = EXCLUDED.tarifa,
    observacions = EXCLUDED.observacions
;

SELECT * FROM membres WHERE ncol=1127;


--Jordi	Ballús	Vila	1127	Si/si	H		x		EI	Enginyeria  Informàtica	UAB	2005	hola@jordiballus.com	jordi_ballus@enginyeriainformatica.cat		
--77628487Z	661040999		C	Major	87		08755	Castellbisbal	20/01/1976	ES6121000386280200524852	NO	29/09/2023	29/09/2023



select m.ncol AS ncol_membre, m.iban AS iban_membre, trim(rq.iban) as iban_rebut, rq.ncol as ncol_rebut                   -- Col·legiats and IBAN nou 
  from ${rebuts} rq    
  full outer join membres m on (m.ncol=rq.ncol)
 where REPLACE(trim(m.iban), ' ', '')<>REPLACE(rq.iban,' ', '');

-- Actualitzar IBAN/BIC
-- https://www.ibancalculator.com/iban_validieren.html
UPDATE membres 
   SET iban=REPLACE('ES8021003370372100643572',' ',''),
       bic ='CAIXESBBXXX'
 WHERE ncol=1043;

select ncol, iban, bic from membres                     -- Cerca de nous IBANs sense BINs (executar IBANS.sh)
 where iban is not null and iban <> ''
   and estat='A' and bic is null; 

--  SELECT iban FROM rebuts_23q4 rq WHERE ncol=1126

-- -------------------------------------------
-- 2E: Anàlisi de canvis entre trimestres
-- -------------------------------------------
select case 
		when col1 is     null and col2 is not null then 'Alta'
		when col1 is not null and col2 is     null and st1='Retornat' then 'Retornat'
		when col1 is not null and col2 is     null then 'Baixa'
		when col1 is not null and col2 is not null then 'Canvi' 
	   end as tipus,
 	   iban1, nom1, col1, col2, nom2, iban2,
 	   m.estat
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
		 LEFT OUTER JOIN membres m ON (m.ncol=COALESCE(col1,col2))
 order by tipus, col1;

-- UPDATE membres SET estat='B' WHERE ncol IN (17,109,170,440,871,994,1020,1050,1084)

SELECT ncol, estat
  FROM membres m 
 WHERE estat='A'
       AND ncol NOT IN (SELECT ncol FROM ${rebuts})
 ORDER BY ncol;

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
--SELECT * FROM remeses_resum rr ORDER BY YEAR, quarter;
--DELETE FROM remeses_resum WHERE YEAR=${r_any} AND quarter=${r_trim};

INSERT INTO public.remeses_resum
  ("year",quarter,rev,coeinf_iban,coeinf_bin,desc_l1,desc_l2,desc_l3) VALUES
  (${r_any},${r_trim},1,'ES9430250001131433543521','CDENESBBXXX',
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
  where r.year=${r_any} and r.quarter=${r_trim} AND rev=1
   and  ((m.estat='A' and m.dalta<${d_fin_trim})    -- Posa aquí data FINAL   del trimestre
        or (m.estat='B' and m.dbaixa>${d_ini_trim})) -- Posa aquí data INICIAL del trimestre
   and (m.tarifa in ('NORMAL','COETIC')
        or (m.tarifa='PROMO' and dtarifa<now()))
   and rq.quota is not null                     -- descomentar pel csv !!
  order by m.tipus, m.ncol
 );


-- Detecció de files absents en els REBUTS generats, comprant-los amb la REMESA rebuda
SELECT m.ncol AS m_ncol, m.nom || ' ' || m.cognom1 || ' ' || m.cognom2  AS m_nom,
	   'Not present in ''${remesa}'''
  FROM ${rebuts} m
 WHERE m.ncol NOT IN (SELECT ncol FROM ${remesa})
UNION
SELECT m.ncol AS m_ncol, m.nom m_nom,
	   'Not present in ''${rebuts}'''
  FROM ${remesa} m
 WHERE m.ncol NOT IN (SELECT ncol FROM ${rebuts}) 
 
-- -------------------------------------------
-- 3C: Comprobació de subtotals
-- -------------------------------------------
select tipus, count(*), sum(import) as import
  from ${remesa}
 group by grouping sets ((tipus),())
 order by tipus;

-- SELECT ncol, nom, iban, import, tipus FROM ${remesa} WHERE tipus='ADH'
UPDATE ${remesa} SET IMPORT=7.5 WHERE tipus='ADH';
update ${remesa} set iban=replace(iban,' ',''); 
  
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
   where year=${r_any} and quarter=${r_trim} AND rev=1;

  
SELECT * FROM remeses_resum rr ORDER BY YEAR, quarter ; 
SELECT * FROM info;

--CREATE TABLE remeses_backup AS (SELECT * FROM remeses_resum);

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
 where rr."year" = ${r_any} and rr.quarter = ${r_trim} AND rev=1) a;   -- ANY, QUARTER i REV=1 !!!
 
-- -------------------------------------------
-- 4B: TMP Generació cos+peu (taula)
-- -------------------------------------------
DROP TABLE tmprows;

SELECT '			<DrctDbtTxInf>
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

--UPDATE ${remesa} SET cpostal='-',poblacio='-', provincia='-',pais='ES', deutor_id='-' WHERE ncol IN (1119,1120,1121,1122); 

-- -------------------------------------------
-- 4D: Generació cos+peu XML → TXT
-- -------------------------------------------
select string_agg(a.outstr,'') ||
'		</PmtInf>
	</CstmrDrctDbtInitn>
</Document>
'
  from (select outstr from tmprows order by tipus desc, ncol) a;
