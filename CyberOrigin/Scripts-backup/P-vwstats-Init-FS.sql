/*********SUPERUSUARI***********************************************************
-- Setup extensió

CREATE EXTENSION postgres_fdw ;                              -- As superuser
GRANT USAGE ON FOREIGN DATA WRAPPER postgres_fdw TO vwstats; -- As superuser

--*********USUARI***********************************************************
-- BD.AGANEA

CREATE SERVER vcity_aganea
FOREIGN DATA WRAPPER postgres_fdw 
OPTIONS (host 'vcity-rds-postgres.c11ppfvvsfrq.eu-west-1.rds.amazonaws.com', dbname 'aganea', port '5432', use_remote_estimate 'true');

CREATE USER MAPPING FOR vwstats
SERVER vcity_aganea
OPTIONS (user 'aganea', password '...');*/

-- BD.CYCLOS4
CREATE SERVER vcity_cyclos
FOREIGN DATA WRAPPER postgres_fdw 
OPTIONS (host 'vcity-rds-postgres.c11ppfvvsfrq.eu-west-1.rds.amazonaws.com', dbname 'vilawatt_cyclos4', port '5432', use_remote_estimate 'true');

DROP USER MAPPING FOR vwstats SERVER vcity_cyclos;

CREATE USER MAPPING FOR vwstats
SERVER vcity_cyclos
OPTIONS (user 'vilawatt_cyclos_ro', password 'c.87BWFdPKBq-aTV');

-- BD.API
CREATE SERVER vcity_api
FOREIGN DATA WRAPPER postgres_fdw 
OPTIONS (host 'vcity-rds-postgres.c11ppfvvsfrq.eu-west-1.rds.amazonaws.com', dbname 'vwapi', port '5432', use_remote_estimate 'true');

CREATE USER MAPPING FOR vwstats
SERVER vcity_api
OPTIONS (user 'vwapi', password 'a5n8YbYAMpoEXw4lXQfXYxRc');*/

-- Permisos a l'usuari no privilegiat ??
-- GRANT USAGE ON FOREIGN SERVER vcity_test_aganea TO test_vwstats;

-- Llistat de "foreign tables"
SELECT * FROM information_schema.foreign_tables;


SELECT postgres_fdw_disconnect_all();

********************************************************************/
