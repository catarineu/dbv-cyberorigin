/*********SUPERUSUARI***********************************************************
-- Setup extensió
CREATE EXTENSION postgres_fdw ;                                   -- As superuser
GRANT USAGE ON FOREIGN DATA WRAPPER postgres_fdw TO test_vwstats; -- As superuser

--*********USUARI***********************************************************
-- BD.AGANEA
CREATE SERVER vcity_test_aganea
FOREIGN DATA WRAPPER postgres_fdw 
OPTIONS (host 'vcity-rds-postgres.c11ppfvvsfrq.eu-west-1.rds.amazonaws.com', dbname 'test_aganea', port '5432', use_remote_estimate 'true');

CREATE USER MAPPING FOR test_vwstats
SERVER vcity_test_aganea
OPTIONS (user 'test_aganea', password 'test_aganea');

-- BD.CYCLOS4
CREATE SERVER vcity_test_cyclos
FOREIGN DATA WRAPPER postgres_fdw 
OPTIONS (host 'vcity-rds-postgres.c11ppfvvsfrq.eu-west-1.rds.amazonaws.com', dbname 'vilawatt_test_cyclos4', port '5432', use_remote_estimate 'true');

CREATE USER MAPPING FOR test_vwstats
SERVER vcity_test_cyclos
OPTIONS (user 'vilawatt_test_cyclos', password 'vilawatt_test_cyclos');

-- BD.API
CREATE SERVER vcity_test_api
FOREIGN DATA WRAPPER postgres_fdw 
OPTIONS (host 'vcity-rds-postgres.c11ppfvvsfrq.eu-west-1.rds.amazonaws.com', dbname 'test_vwapi', port '5432', use_remote_estimate 'true');

CREATE USER MAPPING FOR test_vwstats
SERVER vcity_test_api
OPTIONS (user 'test_vwapi', password 'test_vwapi');

-- Permisos a l'usuari no privilegiat ??
-- GRANT USAGE ON FOREIGN SERVER vcity_test_aganea TO test_vwstats;

-- Llistat de "foreign tables"
SELECT * FROM information_schema.foreign_tables;


SELECT postgres_fdw_disconnect_all();

********************************************************************/

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
) server vcity_test_aganea
OPTIONS (schema_name 'public', table_name 'account');
