@set lot_id = '22-0543-202496'
@set cyber_id = 'CYR01-' || ${lot_id}
select ${cyber_id}

-- API per l'script
select api_key from cob_chain_company ccc where name ='ubiquat-admin'

-- Pels UUID
SELECT uuid, company_name  FROM chain_member cm ORDER BY name

-- Vista stakeholders
select	blockchain,	api, api_version, step, stakeholder_uuid, company_name,
	next_user_uuid, next_ompany_name from v_bl20_v1_all_steps;
	
	
-- #################
-- #### STEP 01 ####
-- #################
INSERT INTO bl20_v1_st01_purchase
(
	optlock, lot_id, amendment,	
 	ref_plan, fluorescence, 
 	"type",	quality,
 	colour,	pieces,
	refcde, ref_client, ref_fab_order, ref_model, 
	brand_id, customer_id,
	"date", 
	stakeholder_uuid,
 	next_user_uuid
)
VALUES(
	0, ${lot_id}, false,
	'FER131 V01',    -- ref_plan,
 	'N_A',           -- fluo
 	'BAGUETTES_SAPHIR_BLEU', --type
 	'EC',	         -- quality
 	'MASTERCARD',    -- color
 	120,             -- pieces
	'28295',         -- refCDE
	'1235276',       -- refCLIENT
	'Police 22U0293',-- refFabORDER
 	'10697 SB109',   -- refMODEL
	'00314',         -- brandID
	'00132',         -- customerID
	'2022-02-25T00:00:00', -- date
	'03a8b163-eee2-470e-85c2-b0776d398d37',--GIL  -- stake
	'2cbae77e-2c8a-40af-804e-76ea0db590fc' --P&B  -- next
 	) RETURNING id;
/*------------------------------
  -- registerDB ================= bl20_v1_st01_purchase
  ------------------------------
    <v1:apiKey>   ... </v1:apiKey>
    <register>
      <blockchain> 20 </blockchain>
      <version>    v1 </version>
      <step>        1 </step>
      <rowId>       2 </rowId>
   </register>
   <registerNextItemIfError> False </registerNextItemIfError>
*/
-- CONTROL --
SELECT id, registered, registered_response, registered_success
  FROM bl20_v1_st01_purchase WHERE id=7;

 
-- #################
-- #### STEP 02 ####
-- #################
INSERT INTO bl20_v1_st02_provider
(
	optlock, cyber_id,
	amendment, 
	amendment_original_buyer, buyer,
	stakeholder_uuid, next_user_uuid
)
VALUES(
	0, ${cyber_id}, 
	false,
	null, 'PETER_AND_BROOKS',
	'2cbae77e-2c8a-40af-804e-76ea0db590fc',--P&B  -- stake
	'2cbae77e-2c8a-40af-804e-76ea0db590fc' --P&B  -- next
) RETURNING id;
-- CONTROL --
SELECT id, registered, registered_response, registered_success, stakeholder_uuid, next_user_uuid
  FROM bl20_v1_st02_provider WHERE id=7;

 
-- #################
-- #### STEP 03 ####
-- #################
INSERT INTO bl20_v1_st03_rough_purchase_pre
(
	optlock, cyber_id,	amendment, 
	rough_invoice_id,	amendment_original_rough_invoice_id,
	supplier, 			amendment_original_supplier, 	
	invoice_doc, invoice_doc_filen_name,
	stone_type,	buyer, carats, "date",
	stakeholder_uuid, next_user_uuid,
	cert_rjc_member_certificate_file_name, cert_rjc_member_id, 
	cert_rjc_period_end, cert_rjc_period_start, cert_rjc_standard_id,
	cert_rjc_member_certificate, rs_reg_country
	)
values
(
	0, ${cyber_id}, false,
	'2022/003',              		-- RoughInvoiceID
	NULL, 							-- ammendOriginalInvoice
	'JAYAMINI_GEMS_AND_LAPIDARY',	-- Supplier
	NULL, 							-- ammendOriginalRoughSupplier
	'...(doc)...',					-- invoice_doc
	'22-0543-202496-ST03.pdf',      -- filename
	'SAPHIR_BLEU',	                -- stoneType
	'PETER_AND_BROOKS',				-- buyer
	59.48,							-- carats
	'2022-02-25T00:00:00',			-- date
	'2cbae77e-2c8a-40af-804e-76ea0db590fc',--P&B  -- stake
	'2cbae77e-2c8a-40af-804e-76ea0db590fc',--P&B  -- next
	'CERT_PETER_AND_BROOKS.pdf',    -- cert_rjc_member_certificate_file_name
	0105560193975, 					-- cert_rjc_member_id
	'2099-04-21', 					-- cert_rjc_period_end
	'2021-04-21',					-- cert_rjc_period_start
	'COMPANY_REG',					-- cert_rjc_standard_id   COMPANY_REG / RJC_COP_2013/9 / NON_APPLICABLE
	'...(doc)...',					-- cert_rjc_member_certificate
	'TH'							-- Country https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes
) RETURNING id;
-- invoice_doc --
WITH prev AS   (SELECT invoice_doc FROM bl20_v1_st03_rough_purchase_pre WHERE id=7)
UPDATE bl20_v1_st03_rough_purchase_pre SET invoice_doc=(SELECT invoice_doc FROM prev) WHERE id=8;
-- invoice_doc --
UPDATE bl20_v1_st03_rough_purchase_pre SET invoice_doc=''
WHERE id=7 RETURNING md5(invoice_doc);

-- cert_rjc_member_certificate --
WITH prev AS   (SELECT cert_rjc_member_certificate FROM bl20_v1_st03_rough_purchase_pre WHERE id=1)
UPDATE bl20_v1_st03_rough_purchase_pre SET cert_rjc_member_certificate=(SELECT cert_rjc_member_certificate FROM prev) WHERE id=8;	

-- CONTROL --
SELECT id, registered, registered_response, registered_success
  FROM bl20_v1_st03_rough_purchase_pre WHERE id=8;


-- #################
-- #### STEP 04 ####
-- #################
INSERT INTO bl20_v1_st04_parcel_assessment
(	
	optlock, cyber_id,	amendment,
	fourc_initial_id, fourc_initial_doc_file_name, fourc_initial_doc,	
	"type", city, origin, carats_sent, "date",		
	stakeholder_uuid, next_user_uuid,	
	cert_rjc_member_certificate_file_name, cert_rjc_member_id, 
	cert_rjc_period_end, cert_rjc_period_start, cert_rjc_standard_id,
	cert_rjc_member_certificate, rs_reg_country
 )
VALUES(
	0, ${cyber_id}, false,
	'22-006/1',						-- 4C_initial_id
	'22-0543-202502-ST04.pdf',      -- 4C_initial_doc_file_name
	'...(doc)...',					-- fourc_initial_doc
	'BAGUETTES_SAPHIR_BLEU',	    -- type
	'BANGKOK_THA',					-- city
	'SRI_LANKA_LKA',				-- origin
	59.48,							-- carats_sent
	'2022-03-04T00:00:00',			-- date
	'2cbae77e-2c8a-40af-804e-76ea0db590fc',--P&B  	-- stake
	'6f027c90-e7ab-45ea-bbec-ac40e1a231a5',--C4CUT  -- next
	'CERT_PETER_AND_BROOKS.pdf',    -- cert_rjc_member_certificate_file_name
	0105560193975, 					-- cert_rjc_member_id
	'2099-04-21', 					-- cert_rjc_period_end
	'2021-04-21',					-- cert_rjc_period_start
	'COMPANY_REG',					-- cert_rjc_standard_id   COMPANY_REG / RJC_COP_2013/9 / NON_APPLICABLE
	'...(doc)...',					-- cert_rjc_member_certificate
	'TH'							-- Country https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes
) RETURNING id;

-- Cal executar això perque Step 4 estigui connectat a Step 3
INSERT INTO bl20_v1_st04_parcel_assessment_rough_supplier_invoice_id (
	bl20v1st04parcel_assessment_data_id, rough_invoiceid, supplier
) select
		(select max(st02.id) from bl20_v1_st04_parcel_assessment st02 where cyber_id = st03.cyber_id),
		st03.rough_invoice_id ,
		st03.supplier 
	from bl20_v1_st03_rough_purchase_pre st03
	where  st03.cyber_id = ${cyber_id}

-- invoice_doc --
UPDATE bl20_v1_st04_parcel_assessment SET fourc_initial_doc=''
WHERE id=7 RETURNING md5(fourc_initial_doc);

-- cert_rjc_member_certificate --
WITH prev AS   (SELECT cert_rjc_member_certificate FROM bl20_v1_st04_parcel_assessment WHERE id=1)
UPDATE bl20_v1_st04_parcel_assessment SET cert_rjc_member_certificate=(SELECT cert_rjc_member_certificate FROM prev) WHERE id=7;	

-- CONTROL --
SELECT id, registered, registered_response, registered_success, next_user_uuid
  FROM bl20_v1_st04_parcel_assessment WHERE id=7;

 
-- #################
-- #### STEP 05 ####
-- #################	
INSERT into bl20_v1_st05_cut 
(
	optlock, cyber_id, amendment,	
	polisher_invoiceid, amendment_original_polisher_invoiceid,
	carats_polished,  pieces, cut_invoice_doc, cut_invoice_doc_file_name,
	city, ref_plan_gil,	"date", stakeholder_uuid, next_user_uuid, 	
	cert_rjc_member_certificate_file_name, cert_rjc_member_id, 
	cert_rjc_period_end, cert_rjc_period_start, cert_rjc_standard_id,  
	cert_rjc_member_certificate, rs_reg_country)
values
(
	0, ${cyber_id}, false,
	'2022/161', 				-- polisher_invoiceid
	NULL,						-- amendment_original_polisher_invoiceid
	6.32, 						-- carats_polished
	120,						-- pieces
	'...(doc)...',				-- cut_invoice_doc
	'22-0543-202502-ST05.pdf',  -- cut_invoice_doc_file_name
	'GODAGAMA_LKA',				-- city
	'FER131 V01',				-- ref_plan_gil
	'2022-08-15T00:00:00Z',		-- date
	'6f027c90-e7ab-45ea-bbec-ac40e1a231a5',--C4CUT  -- Stake
	'2cbae77e-2c8a-40af-804e-76ea0db590fc',--P&B    -- NEXT
	'CERT_C4CUT.pdf',   			-- cert_rjc_member_certificate_file_name
	68637, 							-- cert_rjc_member_id
	'2099-12-31', 					-- cert_rjc_period_end
	'2018-05-14',					-- cert_rjc_period_start
	'COMPANY_REG',					-- cert_rjc_standard_id   COMPANY_REG / RJC_COP_2013/9 / NON_APPLICABLE
	'...(doc)...',					-- cert_rjc_member_certificate
	'LK'							-- Country https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes
) RETURNING id;
-- invoice_doc --
UPDATE bl20_v1_st05_cut SET cut_invoice_doc=''
WHERE id=7 RETURNING md5(cut_invoice_doc);

-- cert_rjc_member_certificate --
WITH prev AS   (SELECT cert_rjc_member_certificate FROM bl20_v1_st05_cut WHERE id=1)
UPDATE bl20_v1_st05_cut SET cert_rjc_member_certificate=(SELECT cert_rjc_member_certificate FROM prev) WHERE id=7;	

-- CONTROL --
SELECT id, registered, registered_response, registered_success
  FROM bl20_v1_st05_cut WHERE id=7;


-- #################
-- #### STEP 06 ####
-- #################	
INSERT INTO bl20_v1_st06_quality_control
(
	optlock, cyber_id , amendment,
	fourc_final_id,	fourc_final_doc, fourc_final_doc_file_name,
	"type",	quality, colour, pieces_final, carats_final,
 	city, "date", stakeholder_uuid, next_user_uuid, 	
	cert_rjc_member_certificate_file_name, cert_rjc_member_id, cert_rjc_period_end, cert_rjc_period_start, cert_rjc_standard_id,  
	cert_rjc_member_certificate, 
	rs_reg_country
)
VALUES(
	0, ${cyber_id}, false,
	'22-006/2',						-- fourc_final_id
	'...(doc)...',					-- fourc_final_doc
	'22-0543-202502-ST06.pdf',      -- fourc_final_doc_file_name
 	'BAGUETTES_SAPHIR_BLEU',        -- type
 	'EC',							-- quality
 	'MASTERCARD',					-- colour
 	120, 							-- pieces_final
 	6.32,							-- carats_final
 	'BANGKOK_THA',					-- city
	'2022-08-18T00:00:00Z',			-- date
	'2cbae77e-2c8a-40af-804e-76ea0db590fc',--P&B -- Stake
	'03a8b163-eee2-470e-85c2-b0776d398d37',--GIL -- NEXT
	'CERT_PETER_AND_BROOKS.pdf',    -- cert_rjc_member_certificate_file_name
	0105560193975, 					-- cert_rjc_member_id
	'2099-04-21', 					-- cert_rjc_period_end
	'2021-04-21',					-- cert_rjc_period_start
	'COMPANY_REG',					-- cert_rjc_standard_id   COMPANY_REG / RJC_COP_2013/9 / NON_APPLICABLE
	'...(doc)...',					-- cert_rjc_member_certificate
	'TH'							-- Country https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes
 	) RETURNING id;

insert into  bl20_v1_st06_quality_control_polisher_invoice_id(
	bl20v1st06quality_control4cdata_id,	polisher_invoiceids
) select
		(select max(st06.id) from bl20_v1_st06_quality_control st06 where cyber_id = st06.cyber_id),
		st05.polisher_invoiceid 
	from bl20_v1_st05_cut st05
	where  st05.cyber_id = ${cyber_id}

-- fourc_final_doc --
UPDATE bl20_v1_st06_quality_control SET fourc_final_doc=''
WHERE id=8 RETURNING md5(fourc_final_doc);

-- cert_rjc_member_certificate --
WITH prev AS   (SELECT cert_rjc_member_certificate FROM bl20_v1_st06_quality_control WHERE id=2)
UPDATE bl20_v1_st06_quality_control SET cert_rjc_member_certificate=(SELECT cert_rjc_member_certificate FROM prev) WHERE id=8;		
	
 -- CONTROL --
SELECT id, registered, registered_response, registered_success
  FROM bl20_v1_st06_quality_control WHERE id=8;
 
 
 
-- #################
-- #### STEP 07 ####
-- #################	
insert into  bl20_v1_st07_choose_lab 
(
	optlock, amendment,cyber_id,
	stakeholder_uuid, next_user_uuid
) values (
	0,false,  ${cyber_id},
	'03a8b163-eee2-470e-85c2-b0776d398d37',--GIL	-- Stake
	'03a8b163-eee2-470e-85c2-b0776d398d37' --GIL	-- Next
) RETURNING id;
 -- CONTROL --
SELECT id, registered, registered_response, registered_success
  FROM bl20_v1_st07_choose_lab WHERE id=7;

 

-- #################
-- #### STEP 08 ####
-- #################	
insert into  bl20_v1_st08_lab_data
(
	optlock, cyber_id, amendment,
	lab_report_id, lab_report, lab_report_filename,
	lab_report_provider, lab_report_type, city,
	pieces_final, carats_final,	"date",
	stakeholder_uuid, next_user_uuid
)values 
(
	0, ${cyber_id}, false,
	'22-G-8473',							-- lab_report_id
	'...(doc)...',					        -- lab_report
	'22-0543-202502-ST08.pdf',              -- lab_report_filename
	'GGTL',									-- lab_report_provider
	'BAGUETTES_SAPHIR_BLEU',	   		    -- lab_report_type
	'BALZERS_LI',							-- city
	120, 									-- pieces_final
	6.32,									-- carats_final
	'2022-09-01T00:00:00',					-- date
	'03a8b163-eee2-470e-85c2-b0776d398d37',	--GIL	-- Stake
	'03a8b163-eee2-470e-85c2-b0776d398d37'	--GIL	-- Next
) RETURNING id;

-- fourc_final_doc --
UPDATE bl20_v1_st08_lab_data SET lab_report=''
WHERE id=8 RETURNING md5(lab_report);
 
-- CONTROL --
SELECT id, registered, registered_response, registered_success
  FROM bl20_v1_st08_lab_data WHERE id=8;
 
 
-- #################
-- #### STEP 09 ####
-- #################	
insert into  bl20_v1_st09_quality_control_and_order_approval 
(
	optlock, cyber_id, amendment, final_certificate_id, invalidate,
	pieces_final, carats_final, "date",
	stakeholder_uuid,	
	cert_rjc_member_certificate_file_name, cert_rjc_member_id, cert_rjc_period_end, cert_rjc_period_start, cert_rjc_standard_id,  
	cert_rjc_member_certificate, rs_reg_country
)
VALUES 
(
	0, ${cyber_id}, false, '', false, -- optlock, cyber_id, amendment, final_certificate_id, invalidate,
	120,						-- pieces_final
	6.32,						-- carats_final
	'2022-10-14T00:00:00',		-- date
	'03a8b163-eee2-470e-85c2-b0776d398d37',--GIL
	'CERT_GIL.pdf',  				-- cert_rjc_member_certificate_file_name
	1646, 					-- cert_rjc_member_id
	'2022-01-01', 					-- cert_rjc_period_end
	'2019-01-01',					-- cert_rjc_period_start
	'RJC_COP_2013',					-- cert_rjc_standard_id   COMPANY_REG / RJC_COP_2013/9 / NON_APPLICABLE
	'...(doc)...',					-- cert_rjc_member_certificate
	'GB'	
) RETURNING id;
 -- cert_rjc_member_certificate --
WITH prev AS   (SELECT cert_rjc_member_certificate FROM bl20_v1_st09_quality_control_and_order_approval WHERE id=1)
UPDATE bl20_v1_st09_quality_control_and_order_approval SET cert_rjc_member_certificate=(SELECT cert_rjc_member_certificate FROM prev) WHERE id=7;		
	
-- CONTROL --
SELECT id, registered, registered_response, registered_success
  FROM bl20_v1_st09_quality_control_and_order_approval WHERE id=7;

-- =======================================================================================
-- FINAL: Verificació de l'informe generat
-- =======================================================================================
SELECT cyber_id, final_certificate_url FROM product_search_index psi WHERE cyber_id=${cyber_id};

 
--per extreure les linies del xmp que s'ha d'enviar al soap
@set cyber_id = 'CYR01-TEST.01.DB.0017'
select 
blockchain,
api,
api_version,
step,
id,
cyber_id, registered_success, v.registered 
from v_bl20_v1_all_steps v
where cyber_id =${cyber_id} 
or  registered_success = false

select id,step,xml_request_registerDB from v_bl01_v4_all_steps  where cyber_id =${cyber_id} and registered_success is null or  registered_success = false

--per veure l'estat dels registres
select cyber_id,registered, registered_success, registered_response, out_batch_id  from v_bl01_v4_all_steps  where cyber_id =${cyber_id};

select * from dynamic_enum_value dev where api = 'diamonds-full' and api_version ='4'
