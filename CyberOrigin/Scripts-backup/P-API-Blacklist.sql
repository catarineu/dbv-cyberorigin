select * from voucher_campaign_user_blacklist vcub order by id desc limit 2; 
select * from voucher_campaign_user_blacklist vcub where username~*'raquel'; 
delete   from voucher_campaign_user_blacklist	  where username='E3Raquel';

-- Cerca per nom 
select v.username, tcu.name from voucher_campaign_user_blacklist v
	left outer join tmp_cyclos_users tcu on (v.username=tcu.username) 
where tcu.name~*'beatriz';

-- Cerca per email
select username, name, email from tmp_cyclos_users tcu 
where email~*'beth';

-- Compra feta per un usuari
SELECT
	tu1.username as nomcom, --payee_id, 
	trim(regexp_replace(payee_name, ' \(.*', '')) as establiment,
    tu2.username as nomcli, --payer_id,
	ct.id as id_venta,
	ct.amount as i_venta,
	sum(redeem_amount) as i_bons,
	process_date as venta_data,
	count(composite_transaction_id) as n_bons,
	string_agg(left(v.code,8)||' ('||redeem_amount||'₩)',', ') as bons_codes
FROM
	composite_transaction ct
	LEFT OUTER JOIN composite_transaction_vouchers ctv on ct.id = ctv.composite_transaction_id
	LEFT OUTER JOIN voucher v  on ctv.voucher_id = v.id 
	LEFT OUTER JOIN tx_uid tu1 on tu1.idcyclos=payee_id 
	LEFT OUTER JOIN tx_uid tu2 on tu2.idcyclos=payer_id
WHERE
	ticket_status = 'PROCESSED'
	AND ticket_type = 'QR_CODE'
	AND v.status <> 'MERGED'     -- no s'han de comptar perquè s'han regenerat (proves bons)
	AND lower(tu2.username)=lower('Alexandradesalinas')
--	and lower(tu2.username) in (select lower(username) from voucher_campaign_user_blacklist vcub)
GROUP BY  
	tu1.username, payee_id, payee_name, payer_id, 
	tu2.username, process_date, ct.amount, ct.id
HAVING
	count(composite_transaction_id) > 0 
ORDER BY
	process_date, tu1.username;

-- delete from voucher_campaign_user_blacklist_
--where username in (select username from tmp_whitelist)

select count(*) from tmp_whitelist;
select count(*) from tmp_blacklist_orig;
select count(*) from tmp_blamed_innocents;
select count(*) from voucher_campaign_user_blacklist;

--insert into tmp_blamed_innocents (username) (
	select username from tmp_blacklist_orig
	where username in (select username from tmp_whitelist)
);

create table tmp_blamed_innocents (username varchar);
--create table tmp_blacklist_orig (username varchar);

select * from tmp_blacklist_orig
where username ~* 'angels';
