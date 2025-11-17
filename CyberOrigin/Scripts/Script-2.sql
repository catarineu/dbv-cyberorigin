SELECT cyberid0_.id AS id1_59_, cyberid0_.optlock AS optlock2_59_, cyberid0_.api_name AS api_name3_59_, cyberid0_.api_version AS api_vers4_59_,
    cyberid0_.cancelled AS cancelle5_59_, cyberid0_.cancelled_timestamp AS cancelle6_59_, cyberid0_.company_prefix AS company_7_59_,
    cyberid0_.cyber_id AS cyber_id8_59_, cyberid0_.cyber_id_group_id AS cyber_i16_59_, cyberid0_.cyber_id_type AS cyber_id9_59_, cyberid0_.deleted AS
    deleted10_59_, cyberid0_.exception AS excepti11_59_, cyberid0_.lot_id AS lot_id12_59_, cyberid0_.revision AS revisio13_59_, cyberid0_.timestamp
    AS timesta14_59_, cyberid0_.validatable AS validat15_59_
FROM cyber_id cyberid0_
WHERE (cyberid0_.cyber_id LIKE (cast('CYR01-TEST-BL01GR0102' AS varchar(255)) || '%'))
    AND cyberid0_.cancelled = FALSE
    AND (length(cyberid0_.cyber_id) BETWEEN cast(20 AS int4)
        AND cast(24 AS int4))
ORDER BY cyberid0_.cyber_id DESC
