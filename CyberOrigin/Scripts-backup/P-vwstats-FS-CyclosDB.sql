-- CREATION: cyclos.id_cipher_rounds
-----------------------------------------
--DROP FOREIGN TABLE cyclos_id_cipher_rounds;
CREATE FOREIGN TABLE cyclos_id_cipher_rounds (
	id bigserial NOT NULL,
	mask int8 NOT NULL,
	order_index int4 NOT NULL,
	rotate_bits int4 NOT NULL
) server vcity_cyclos
OPTIONS (schema_name 'public', table_name 'id_cipher_rounds');
-- TEST
select * from cyclos_id_cipher_rounds limit 1;

-- CREATION: cyclos.users
-----------------------------------------
--DROP FOREIGN TABLE cyclos_users;
CREATE FOREIGN TABLE cyclos_users (
	id bigserial NOT NULL,
	subclass varchar(31) NULL,
	creation_date timestamp NOT NULL,
	display varchar(255) NULL,
	email varchar(255) NULL,
	"name" varchar(200) NULL,
	new_email varchar(255) NULL,
	password_statuses text NULL,
	registration_confirmation_date timestamp NULL,
	registration_type varchar(255) NULL,
	security_answer text NULL,
	security_question varchar(255) NULL,
	send_activation_email bool NULL,
	short_display varchar(255) NULL,
	status varchar(255) NULL,
	username varchar(255) NOT NULL,
	validation_key varchar(255) NULL,
	validation_key_date timestamp NULL,
	validation_key_type varchar(255) NULL,
	"version" int4 NOT NULL,
	network_id int8 NULL,
	registered_by_id int8 NULL,
	operator_group_id int8 NULL,
	operator_user_id int8 NULL,
	accepted_agreement_ids text NULL,
	user_activation_date timestamp NULL,
	user_hide_email bool NULL,
	individual_product_ids text NULL,
	user_group_id int8 NULL,
	image_id int8 NULL,
	name_tsvector tsvector NULL,
	username_tsvector tsvector null
) server vcity_cyclos
OPTIONS (schema_name 'public', table_name 'users');
-- TEST
select * from cyclos_users limit 1;

-- CREATION: cyclos.user_custom_fields
-----------------------------------------
-- DROP FOREIGN TABLE cyclos_user_custom_fields;
CREATE FOREIGN TABLE cyclos_user_custom_fields (
	id bigserial NOT NULL,
	all_selected_label varchar(255) NULL,
	allowed_mime_types text NULL,
	"control" varchar(255) NOT NULL,
	decimal_digits int4 NULL,
	default_boolean_value bool NULL,
	default_date_today bool NULL,
	default_date_value timestamp NULL,
	default_decimal_value numeric NULL,
	default_integer_value int4 NULL,
	default_rich_text_value text NULL,
	default_string_value varchar(4000) NULL,
	default_text_value text NULL,
	description text NULL,
	exact_match bool NOT NULL,
	expanded_categories bool NOT NULL,
	hidden_by_default bool NULL,
	ignore_sanitizer bool NOT NULL,
	include_in_csv bool NULL,
	information_text text NULL,
	internal_name varchar(50) NULL,
	linked_entity_type varchar(255) NULL,
	load_values_script_parameters text NULL,
	max_files int4 NULL,
	max_word_size int4 NULL,
	"name" varchar(100) NOT NULL,
	order_index int4 NOT NULL,
	other_mime_types text NULL,
	pattern varchar(255) NULL,
	val_required bool NOT NULL,
	"size" varchar(255) NULL,
	"type" varchar(255) NOT NULL,
	val_unique bool NOT NULL,
	validation_script_parameters text NULL,
	"version" int4 NOT NULL,
	max_decimal_value numeric NULL,
	min_decimal_value numeric NULL,
	max_integer_value int4 NULL,
	min_integer_value int4 NULL,
	val_max_length int4 NULL,
	val_min_length int4 NULL,
	load_values_script_id int8 NULL,
	network_id int8 NOT NULL,
	validation_script_id int8 NULL,
	purge_values bool NULL,
	storage_directory varchar(255) NULL
	) SERVER vcity_cyclos
OPTIONS (schema_name 'public', table_name 'user_custom_fields');
-- TEST
SELECT * FROM cyclos_user_custom_fields LIMIT 1;

-- CREATION: cyclos.user_custom_field_values
-----------------------------------------
-- DROP FOREIGN TABLE cyclos_user_custom_field_values;
CREATE FOREIGN TABLE cyclos_user_custom_field_values (
	id bigserial NOT NULL,
	boolean_value bool NULL,
	date_value timestamp NULL,
	decimal_value numeric NULL,
	hidden bool NOT NULL,
	integer_value int4 NULL,
	linked_entity_id int8 NULL,
	rich_text_value text NULL,
	string_value varchar(4000) NULL,
	text_value text NULL,
	"version" int4 NOT NULL,
	field_id int8 NOT NULL,
	owner_id int8 NOT NULL,
	value_tsvector tsvector NULL
) SERVER vcity_cyclos
OPTIONS (schema_name 'public', table_name 'user_custom_field_values');
-- TEST
SELECT * FROM cyclos_user_custom_field_values LIMIT 1;
