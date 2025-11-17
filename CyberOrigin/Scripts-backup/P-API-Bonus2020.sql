# ENLLAÇ ENTRE BDs
#
# 1. Cyclos→Exportació usuaris → tx_uid
# 2. Cyclos→Users(export)      → tmp_cyclos_users


# 2. Cyclos→Users(export)
select u.id, u."name", u.username, u.email, creation_date, user_activation_date , status 
from   users u
where  network_id =2; 

---------------------------------------------------------------
-- Llistat d'usuaris amb dret a RESSUCITAMENT de BONS 2020
------
select tcu.status, tcu.name, tcu.email, txu.username, preu, num, import, "inc %" || ' %' as "inc %"
  from 
  (
	select
		assignee_id,
		sum(price) as preu,
		ceiling(sum(price)/ 25) as num,
		ceiling(sum(price)/ 25)*25 as import,
		floor(((ceiling(sum(price)/ 25)*25 / sum(price))-1)*100)  as "inc %"
	from
		(
		select v.id, v.assignee_id, v.status, v.price, v.amount,v.campaign_id
		  from voucher v
		  left join voucher_campaign c on v.campaign_id = c.id
		where
		      v.campaign_id = 1
		  and v.status = 'REFUNDED'
		  and v.refund_date >= c.end_date
		order by
			assignee_id) my_vouchers
	group by
		assignee_id) bons2020,
	tx_uid txu,
	tmp_cyclos_users tcu
where 
      assignee_id=txu.idcyclos
  and tcu.username = txu.username
  and status='ACTIVE'
--  and name~*'leon'
order by "inc %", preu, username;
