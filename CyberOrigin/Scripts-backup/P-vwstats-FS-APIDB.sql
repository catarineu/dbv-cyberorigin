-- API.voucher_campaign_custom_assignment
-----------------------------------------
CREATE FOREIGN TABLE api_voucher_campaign_custom_assignment (
	id bigserial NOT NULL,
	"comment" varchar(255) NULL,
	quantity int4 NOT NULL,
	spent int4 NULL,
	"timestamp" timestamp NULL DEFAULT CURRENT_TIMESTAMP,
	user_id int8 NOT NULL,
	campaign_id int8 NOT NULL,
	quota_id int8 NOT NULL
) SERVER vcity_api
OPTIONS (schema_name 'public', table_name 'voucher_campaign_custom_assignment');
-- TEST
SELECT * FROM api_voucher_campaign_custom_assignment LIMIT 1;


-- API.voucher_campaign_custom_assignment_delta
-----------------------------------------
CREATE FOREIGN TABLE api_voucher_campaign_custom_assignment_delta (
	id bigserial NOT NULL,
	"comment" varchar(255) NULL,
	quantity int4 NOT NULL,
	reason varchar(255) NULL,
	"timestamp" timestamp NULL DEFAULT CURRENT_TIMESTAMP,
	user_id int8 NOT NULL,
	campaign_id int8 NOT NULL,
	quota_id int8 NOT NULL
) SERVER vcity_api
OPTIONS (schema_name 'public', table_name 'voucher_campaign_custom_assignment_delta');
-- TEST
SELECT * FROM api_voucher_campaign_custom_assignment_delta LIMIT 1;


-- API.voucher_campaign_quota
-----------------------------------------
CREATE FOREIGN TABLE api_voucher_campaign_quota (
	id bigserial NOT NULL,
	"general" bool NULL,
	"name" varchar(255) NOT NULL,
	quantity int4 NOT NULL,
	campaign_id int8 NOT NULL
) SERVER vcity_api
OPTIONS (schema_name 'public', table_name 'voucher_campaign_quota');
-- TEST
SELECT * FROM api_voucher_campaign_quota LIMIT 1;


-- API.voucher_campaign_user_blacklist
-----------------------------------------
CREATE FOREIGN TABLE api_voucher_campaign_user_blacklist (
	id bigserial NOT NULL,
	username varchar(255) NOT NULL,
	campaign_id int8 NOT NULL
) SERVER vcity_api
OPTIONS (schema_name 'public', table_name 'voucher_campaign_user_blacklist');
-- TEST
SELECT * FROM api_voucher_campaign_user_blacklist LIMIT 1;

