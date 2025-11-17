-- TRUE = 'quantity' s'ignora fins límit de campanya
INSERT INTO voucher_campaign_quota (campaign_id, general, name, quantity) 
     VALUES (2, true, 'BW22 Quota general', 0);

-- Fixa un límit per la campanya, però no són bons reservats
-- (poden ser gastats per els 2 bons inicials de regal)
INSERT INTO voucher_campaign_quota (campaign_id, general, name, quantity) 
     VALUES (2, true, 'BW22 Tercer bo', 1000);
@set quota_id = 4
    
-- Assignació de BONS per WHITELIST
@set user_id = 2424207780375288570
@set quant   = now() + '3 days'::interval
INSERT INTO	voucher_campaign_custom_assignment_delta
   (reason, quantity, "comment", "timestamp", user_id, campaign_id, quota_id)
VALUES
   ('3R BO: TOTHOM', 1, '3r bo pels que viuen/treballen a VLD', ${quant}, ${user_id}, 2, ${quota_id}) 
RETURNING id;
SELECT id FROM voucher_campaign_custom_assignment_delta ORDER BY ID DESC LIMIT 1;
@set delta_id = 000

-- CREATE EXTENSION pgcrypto;
-------- SELECT lo_import('/path/to/file/lorem.txt');           -- Per pujar un loid
-------- SELECT loid FROM pg_largeobject;                       -- Per veure darrer loid
-------- SELECT encode(digest(lo_get(174766), 'sha256'),'hex'); -- Per obtenir sha256 del fitxer pujat
-------- SELECT pg_column_size(lo_get(174766)) - 4;             -- column_size = int4 + <blob>
-------- SELECT lo_export(16386, '/path/to/file/lorem2.txt');   -- Per baixar un loid

SELECT lo_import('/path/to/file/lorem.txt');           -- Per pujar un loid
@set blob = 174766

INSERT INTO public.stored_file
	(optlock, contenttype, "data", "name", sha256checksum, sizebytes)
VALUES(0, 'application/pdf', ${blob}, 'Prova-IBAN.pdf', encode(digest(lo_get(${blob}), 'sha256'),'hex'), pg_column_size(lo_get(${blob})) - 4)
RETURNING id;
SELECT id FROM stored_file ORDER BY id DESC LIMIT 1;
@set file_id = 000

INSERT INTO public.voucher_campaign_custom_assignment_delta_files
	(voucher_campaign_custom_assignment_delta_id, stored_file_id)
VALUES(${delta_id}, ${file_id});

@set  user_id = 2424207780375288570
-- Relació de bons ASSIGNATS/USATS per l'usuari
select vcca.user_id, vcca.quantity, vcca.spent, vcca.timestamp as last_update, vcq."name" as campaign
  from voucher_campaign_custom_assignment vcca
       left outer join voucher_campaign_quota vcq on (vcca.quota_id=vcq.id)
 where vcca.campaign_id = 2
   and vcca.user_id=${user_id}

-- Llistat de les ASSIGNACIONS de bons fetes a un usuari
SELECT vccad.timestamp, vccad.quantity, vccad.reason, vccad.comment,  vcq."name" as campaign
  FROM voucher_campaign_custom_assignment_delta vccad
       left outer join voucher_campaign_quota vcq on (vccad.quota_id=vcq.id)
 WHERE vccad.user_id=${user_id}
   and vccad.campaign_id=2
 ORDER BY vccad.timestamp; 
  