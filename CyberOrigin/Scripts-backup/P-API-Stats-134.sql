-- INFORME #1 -- Control de bons per LOG
select
	a.d_inicial, 
	LEAST(a.d_inicial+6,CURRENT_DATE) as d_final,
	sell_limit as "Total",
	sell_limit-sum(assigned) over (order by d_inicial)+sum(refunded) over (order by d_inicial) as "Per vendre",
	assigned-refunded as "Venuts",
	assigned-lag(assigned) over (order by d_inicial) as "Dif Venuts",
	sum(assigned) over (order by d_inicial)-sum(refunded) over (order by d_inicial) as "Sum Venuts",
	num_bons as "NBons",
	sum(num_bons) over (order by d_inicial) as "Sum NBons",
	import_bons as "W Bons",
	import_bons-lag(import_bons) over (order by d_inicial) as "Dif W",
	100*round((import_bons-lag(import_bons) over (order by d_inicial))/lag(import_bons) over (order by d_inicial),2) as "% Dif W",
	c.num_ops as "Ops",
	c.num_ops-lag(c.num_ops) over (order by d_inicial) as "Dif Ops",
	sum(import_bons) over (order by d_inicial) as "WBons",
	50*sell_limit - sum(import_bons) over (order by d_inicial) as pendent,
	round(100*(50*sell_limit - sum(import_bons) over (order by d_inicial))/(50*sell_limit)) as pendent_pc
from
	(
	select
		date_trunc('week', "timestamp")::date as d_inicial,
		sum(case when event_type = 'ASSIGNED' then 1 else 0 end) as assigned,
		sum(case when event_type = 'REDEEMED' then 1 else 0 end) as redeemed,
		sum(case when event_type = 'REFUNDED' then 1 else 0 end) as refunded
	from
		voucher_event_log vel
	where timestamp >= '2021-12-25'
	group by
		date_trunc('week', "timestamp")::date
    ) a 
    left outer JOIN
    (select
		date_trunc('week', process_date)::date as d_inicial,
		count(composite_transaction_id) as num_bons,
		sum(redeem_amount) as import_bons
	from
		composite_transaction ct
	left outer join composite_transaction_vouchers ctv on ct.id = ctv.composite_transaction_id
	left outer join voucher v  on ctv.voucher_id = v.id 
	where
		ticket_status = 'PROCESSED'
		and ticket_type = 'QR_CODE'
		and v.status <> 'MERGED'     -- no s'han de comptar perquè s'han regenerat (proves bons)
	    and process_date >= '2021-12-25'
	group by
		date_trunc('week', process_date)::date
	having
		count(composite_transaction_id) > 0
    ) b using (d_inicial)
    left outer JOIN
    (select
		date_trunc('week', process_date)::date as d_inicial,
		count(*) as num_ops
	from
		composite_transaction ct
	where process_date >= '2021-12-25'
	group by
		date_trunc('week', process_date)::date
    ) c using (d_inicial),
    lateral (select case when d_inicial<'2021-12-25' then 7385 else 7385 end ) as s1 (sell_limit)
order by
	d_inicial

-- INFORME #3 -- Bons per comerç - Resum
select
	est_nom,
	num_bons,
	import_bons,
	round(100 * import_bons / sum(import_bons) over (), 1) as percent,
	round(mitja,1) as mitja
	(
from
	select
		--	payee_id as est_id
		trim(regexp_replace(payee_name, ' \(.*', '')) as est_nom,
		count(composite_transaction_id) as num_bons,
		sum(redeem_amount) as import_bons,
		avg(redeem_amount) as mitja
	from
		composite_transaction ct
	left outer join composite_transaction_vouchers ctv on ct.id = ctv.composite_transaction_id
	left outer join voucher v  on ctv.voucher_id = v.id 
	where
		ticket_status = 'PROCESSED'
		and ticket_type = 'QR_CODE'
		and v.status <> 'MERGED'     -- no s'han de comptar perquè s'han regenerat (proves bons)	
	    and process_date >= '2022-01-01'
	group by
		trim(regexp_replace(payee_name, ' \(.*', ''))
	having
		count(composite_transaction_id) > 0) a
order by
		import_bons desc;

-- INFORME #4 -- Bons per comerç - Detall
select
	trim(regexp_replace(payee_name, ' \(.*', '')) as establiment,
	ct.id as id_venta,
    left(md5(''||payer_id),6) as client_venta,
	process_date as data_venta2,
	ct.amount as import_venta,
	count(composite_transaction_id) as num_bons,
	string_agg(left(v.code,8)||' ('||redeem_amount||'₩)',', ') as bons_codes,
	sum(redeem_amount) as import_bons
from
	composite_transaction ct
	left outer join composite_transaction_vouchers ctv on ct.id = ctv.composite_transaction_id
	left outer join voucher v  on ctv.voucher_id = v.id 
where
	ticket_status = 'PROCESSED'
	and ticket_type = 'QR_CODE'
	and v.status <> 'MERGED'     -- no s'han de comptar perquè s'han regenerat (proves bons)
    and process_date >= '2022-01-01'
--	and payee_name ~ '^Electro'
group by  
	payee_name, left(md5(''||payer_id),6), process_date, ct.amount, ct.id
having
	count(composite_transaction_id) > 0
order by
	trim(regexp_replace(payee_name, ' \(.*', '')),
    process_date::date desc nulls last;

   
 
-- INFORME #FINAL -- Recirculació
select
	est_nom,
	import_bons,
	amount, 
	nom
from
	(
	select
		--	payee_id as est_id
		trim(regexp_replace(payee_name, ' \(.*', '')) as est_nom,
		count(composite_transaction_id) as num_bons,
		sum(redeem_amount) as import_bons,
		tr.nom, tr.amount
	from
		composite_transaction ct
	left outer join composite_transaction_vouchers ctv on ct.id = ctv.composite_transaction_id
	left outer join voucher v  on ctv.voucher_id = v.id
	full outer join tx_recirc tr on trim(both from tr.nom) = trim(both from payee_name)
	where
		ticket_status = 'PROCESSED'
		and ticket_type = 'QR_CODE'
		and v.status <> 'MERGED'     -- no s'han de comptar perquè s'han regenerat (proves bons)	
	group by
		trim(regexp_replace(payee_name, ' \(.*', '')), nom, tr.amount
	having
		count(composite_transaction_id) > 0) a
order by
		import_bons desc;

select ts.mobil, count(*)
from tx_susp ts  
group by mobil
having count(*)>1
order by count(*) desc;

select * from tmp_cyclos_users tcu  where tcu."name" ~ 'Inza'; 

select * from tx_uid tu 
where username in ('wilavatt');

--#########################################################################
-- INFORME #FINAL -- Compres fetes per diversos usuaris SOSPITOSOS
--#########################################################################
select
	ts.mobil, count(distinct tu2.username) as "numComptes", 
	count(distinct composite_transaction_id) as "numV",
	count(distinct process_date::date) as "numDiesV", 
	count(distinct tu1.idapi),tu1.username,
	sum(redeem_amount) as import_bons
from
	composite_transaction ct
left outer join composite_transaction_vouchers ctv on ct.id = ctv.composite_transaction_id
left outer join voucher v  on ctv.voucher_id = v.id 
left outer join tx_uid tu1 on tu1.idcyclos=payee_id 
left outer join tx_uid tu2 on tu2.idcyclos=payer_id
inner join tx_susp ts on ts.id = tu2.idapi 
where
	ticket_status = 'PROCESSED'
	and ticket_type = 'QR_CODE'
	and v.status <> 'MERGED'     -- no s'han de comptar perquè s'han regenerat (proves bons)
	and lower(tu2.username)=lower('wilavatt')
group by  
	ts.mobil, tu1.username ,tu1.username 
having
	count(composite_transaction_id) > 0 
order by
	count(distinct tu2.username) desc nulls last, sum(redeem_amount) desc;   

--#########################################################################
-- INFORME #FINAL -- Compres fetes per diversos usuaris SOSPITOSOS
--#########################################################################
select
	tu1.username as nomcom, --payee_id, 
	trim(regexp_replace(payee_name, ' \(.*', '')) as establiment,
    tu2.username as nomcli, --payer_id,
	ct.id as id_venta,
	ct.amount as i_venta,
	sum(redeem_amount) as i_bons,
	process_date as venta_data,
	count(composite_transaction_id) as n_bons,
	string_agg(left(v.code,8)||' ('||redeem_amount||'₩)',', ') as bons_codes
from
	composite_transaction ct
left outer join composite_transaction_vouchers ctv on ct.id = ctv.composite_transaction_id
left outer join voucher v  on ctv.voucher_id = v.id 
left outer join tx_uid tu1 on tu1.idcyclos=payee_id 
left outer join tx_uid tu2 on tu2.idcyclos=payer_id
where
	ticket_status = 'PROCESSED'
	and ticket_type = 'QR_CODE'
	and v.status <> 'MERGED'     -- no s'han de comptar perquè s'han regenerat (proves bons)
	and lower(tu2.username)=lower('farmacia.niubo')
--	and lower(tu2.username) in (select lower(username) from voucher_campaign_user_blacklist vcub)
group by  
	tu1.username, payee_id, payee_name, payer_id, 
	tu2.username, process_date, ct.amount, ct.id
having
	count(composite_transaction_id) > 0 
order by
	process_date, tu1.username;
   
--#########################################################################
-- INFORME #FINAL -- Compres fetes per diversos usuaris SOSPITOSOS
--#########################################################################
select
	v.status, tu1.username, sum(v.amount) --, sum(v.amount) over (order by tu1.username)
from
	 voucher v 
left outer join tx_uid tu1 on tu1.idcyclos=v.holder_id  
where
--	and ticket_type = 'QR_CODE'
	campaign_id =2
--	and v.status <> 'MERGED'     -- no s'han de comptar perquè s'han regenerat (proves bons)
	and v.status = 'ASSIGNED'     -- no s'han de comptar perquè s'han regenerat (proves bons)
	and lower(tu1.username)   in (select lower(username) from voucher_campaign_user_blacklist vcub)
	and assignment_date >='2022-01-01'
group by 
	v.status, tu1.username
order by
	tu1.username;
   

--#########################################################################
-- INFORME #FINAL -- Compres fetes per diversos usuaris SOSPITOSOS
--#########################################################################
select
--	count(*) OVER (PARTITION BY ts.mobil), 
	ts.mobil, tu1.idapi as idcom, tu1.username as nomcom, --payee_id, 
	trim(regexp_replace(payee_name, ' \(.*', '')) as establiment,
	sum(ct.amount) as i_venta,
	sum(redeem_amount) as i_bons,
	process_date::date as venta_data,
	tu2.idapi as idcli, tu2.username as nomcli, --payer_id,
	min(ct.id), string_agg(''||left(v.code,8) ,'/') as id_voucher,
	count(composite_transaction_id) as num_bons
from
	composite_transaction ct
left outer join composite_transaction_vouchers ctv on ct.id = ctv.composite_transaction_id
left outer join voucher v  on ctv.voucher_id = v.id 
left outer join tx_uid tu1 on tu1.idcyclos=payee_id 
left outer join tx_uid tu2 on tu2.idcyclos=payer_id
inner join tx_susp ts on ts.id = tu2.idapi 
where
	ticket_status = 'PROCESSED'
	and ticket_type = 'QR_CODE'
	and v.status <> 'MERGED'     -- no s'han de comptar perquè s'han regenerat (proves bons)
	and ts.mobil='636393446'
group by  
	ts.mobil, 
	tu1.idapi, tu1.username, payee_id, payee_name, payer_id, 
	tu2.idapi, tu2.username, process_date::date
having
	count(composite_transaction_id) > 0 
order by
	ts.mobil, sum(redeem_amount) desc, process_date::date, tu1.username;

-- INFORME #JUST01-BONS -- Bons per comerç - Detall
select
	ctv.voucher_id, 
	trim(regexp_replace(payee_name, ' \(.*', '')) as establiment,
	ct.id as id_venta,
	to_char(process_date, 'YYYY-MM-DD HH24:MI') as data_venta,
	ct.amount as import_venta,
	sum(redeem_amount) as import_bo,
	to_char(v.redemption_review_date, 'YYYY-MM-DD HH24:MI')  as data_liquidació
from
	composite_transaction ct
left outer join composite_transaction_vouchers ctv on ct.id = ctv.composite_transaction_id
left outer join voucher v on v.id = ctv.voucher_id 
where
	ticket_status = 'PROCESSED'
	and ticket_type = 'QR_CODE'
--	and process_date >= '2021-08-01'
--	and payee_name ~ '^Electro'
group by grouping sets 
((trim(regexp_replace(payee_name, ' \(.*', ''))),
 (trim(regexp_replace(payee_name, ' \(.*', '')), ct.id, voucher_id, process_date, ct.amount,v.redemption_review_date ),
 ())
having
	count(composite_transaction_id) > 0
order by
	trim(regexp_replace(payee_name, ' \(.*', '')),
    process_date::date nulls last;

-- #3 -- RESUM: Bons emesos/pendents
select 
	"name" as campanya,
	now()::date as "informe del dia...",
	total_issuable_number as bons_totals,
	vass.num-vref.num as bons_venuts,
	total_issuable_number-(vass.num-vref.num) as bons_restants,
	fixed_unit_amount as preu_bo,
	end_date as final_campanya
from 
	(select count(*) as num from voucher_event_log vel where event_type='ASSIGNED') vass,
	(select count(*) as num from voucher_event_log vel where event_type='REFUNDED') vref,
    (select "name", fixed_unit_amount, total_issuable_number, end_date  from voucher_campaign) vc;

----------------------------------------------------------------   
/*
 * 	a.d_inicial, 
	a.d_inicial+6 as d_final,
	assigned as bons_venuts,
	sum(assigned) over (order by d_inicial) as suma_bv,
	num_bons as bons_usats,
	sum(num_bons) over (order by d_inicial) as suma_bu,
	import_bons as bons_usats_eur,
	sum(import_bons) over (order by d_inicial) as suma_bue,
	redeemed as bons_redimits,
	sum(redeemed) over (order by d_inicial) as suma_br,
	c.num_ops as ops,
	sum(c.num_ops) over (order by d_inicial) as suma_ops
 */   



	--- COMPRADORS DE BONS de fora de VILADECANS
select
		process_date as d_inicial,
		count(composite_transaction_id) as num_bons,
		sum(redeem_amount) as import_bons
	from
		composite_transaction ct
	left outer join composite_transaction_vouchers ctv on ct.id = ctv.composite_transaction_id
	left outer join voucher v  on ctv.voucher_id = v.id 
	where
		ticket_status = 'PROCESSED'
		and ticket_type = 'QR_CODE'
		and v.status <> 'MERGED'     -- no s'han de comptar perquè s'han regenerat (proves bons)
	    and process_date >= '2022-01-01'
	group by
		process_date
	having
		count(composite_transaction_id) > 0
    
	
	
-- Control de bons per ESTAT
--    ASSIGNED   = En mans d'usuaris
--    REDEEMED   = Convertits a ₩
--    REDEMP_REQ = Pendents de validar per Xarxa
select
	status,	count(*), sum(amount)
from
	voucher v
group by
	status 
	
/*
 * ISSUED   = Bo creats
 * ASSIGNED = Bo venut
 * REFUNDED = Bo retornat
 **** Bons venut reals = ASSIGNED - REFUNDED
 * SPENT    = Bo usat en una venta
 * REDEEMED = Bo cobrat pel comerç
 */
  
 --------------------------------------------------------
	
	---------------------------------------------------
select
	'\lo_export ' || data || ' ''/mnt/dades/bons2021/' || 
	ct.id || ' -- ' || string_agg(left(v.code,8),'-') ||
	'.' || split_part(contenttype,'/',2) || ''''
from
	voucher v
    join composite_transaction_vouchers ctv   on	ctv.voucher_id = v.id
    join composite_transaction ct             on	ct.id = ctv.composite_transaction_id
    join composite_transaction_attachment cta on	cta.transaction_id = ct.id
    join stored_file sf                       on	cta.file_id = sf.id
where
	cta.type = 'TICKET'
	and v.status = 'REDEEMED'
group by 
	data, ct.id,contenttype;
	

select count(*) from tmp_cyclos_users tcu ;
delete from tmp_cyclos_users tcu ;

-- INSERT INTO tmp_cyclos_users (id,username,name,email,status) VALUES


