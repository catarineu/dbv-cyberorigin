
-- Aganea.account
CREATE FOREIGN TABLE aganea_account (
	id bigserial NOT NULL,
	optlock int4 NULL,
	created_at timestamp NOT NULL,
	downstream_id int8 NOT NULL,
	"owner" varchar(255) NOT NULL,
	upstream_id varchar(255) NULL,
	upstream_status varchar(255) NOT NULL,
	upstream_type varchar(255) NOT NULL,
	cashout_iban varchar(255) NULL,
	permanent_id varchar(255) NOT NULL,
	downstream_status varchar(255) NOT NULL,
	sca_validated_iban bool NULL DEFAULT false
) server vcity_aganea
OPTIONS (schema_name 'public', table_name 'account');

select * from aganea_account limit 1;
