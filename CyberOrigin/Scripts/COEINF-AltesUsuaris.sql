 
-- Inserció d'ADHERITS
insert into membres 
   (nom, cognom1, cognom2,	ncol, sexe,	carnet,
	acei, titol, titol_desc, universitat, any_titol, 
	email, email_coeinf, email_2, dni, tf, tf2,
	via, carrer, num, pis, cpostal, poblacio, iban, cessio_3rs,
	tarifa, observacions, dnaix, dalta, pais, tipus
	) 
	(select a.nom, a.cognom1, a.cognom2 , a."Num. Adh.", trim(a.sexe), trim(a.carnet), 
	lower(a."adreça correu-e"), a."títol", a."Desc Títol", a.universitat,
	"Any", "Correu-e", "correu-e domini", "Correu-e 2",
	dni, tf, tf2, via, carrer, num, "Pis ", "CP ", ciutat, "dades bancaries 1",
	 divulgació, 'Normal', comentaris, to_date("data neix.",'DD/MM/YYYY') as dneix,
	 to_date(alta,'DD/MM/YY') as dalta, 'ES', 'ADH' 
	from adherits a);
rollback;

begin;

-- Inserció de BAIXES
insert into membres 
   (nom, cognom1, cognom2,	ncol, sexe,	carnet,
	acei, titol, titol_desc, universitat, any_titol, 
	email, email_coeinf, email_2, dni, tf, tf2,
	via, carrer, num, pis, cpostal, poblacio, iban, cessio_3rs, tarifa,
	dnaix, dalta, dbaixa, baixa_motiu, 
	pais, tipus, observacions, estat
	) 
	(select a.nom, a.cognom1, a.cognom2 , a."Num. Col."::int, trim("H/D"), trim(a.carnet), 
	lower(a."adreça correu-e"), a."títol", a."Desc Títol", a.universitat,
	"Any", "Correu-e", "correu-e domini", "Correu-e 2",
	dni, tf, tf2, via, carrer, num, "Pis ", "CP ", ciutat, "dades bancaries", divulgació, 'Normal', 
     case when "data neix."~'\d\d/\d\d/\d\d\d\d' then to_date("data neix.",'DD/MM/YYYY') 
          when "data neix."~'\d\d/\d\d/\d\d' then to_date("data neix.",'DD/MM/YY') end as dneix,
     case when "data alta"~'\d\d/\d\d/\d\d\d\d' then to_date("data alta",'DD/MM/YYYY') 
          when "data alta"~'\d\d/\d\d/\d\d' then to_date("data alta",'DD/MM/YY') end as dalta,
     case when "baixa"    ~'\d\d/\d\d/\d\d\d\d' then to_date("baixa"    ,'DD/MM/YYYY') 
          when "baixa"    ~'\d\d/\d\d/\d\d' then to_date("baixa"    ,'DD/MM/YY') end as baixa,
          	 observacions, 'ES', 'ADH', '', 'B'
	from baixes a where "Num. Col." not in (13,839));
rollback;
