SELECT DISTINCT cobchainle2_.id AS col_0_0_, coalesce(cobchainle2_.name_to_show, cobchainle2_.name) AS col_1_0_, cobchainle2_.id AS id2_53_,
    cobchainle2_.optlock AS optlock3_53_, cobchainle2_.actived AS actived4_53_, cobchainle2_.blocked AS blocked5_53_, cobchainle2_.created AS
    created6_53_, cobchainle2_.name AS name7_53_, cobchainle2_.name_to_show AS name_to_8_53_, cobchainle2_.removed AS removed9_53_,
    cobchainle2_.state AS state10_53_, cobchainle2_.type AS type1_53_, cobchainle2_.user_external_id AS user_ex11_53_,
    cobchainle2_.level_1_client_company AS level_16_53_
FROM product_search_index productsea0_
    INNER JOIN cob_chain_company cobchainst1_ ON (cobchainst1_.chain_member_id = productsea0_.owner)
    INNER JOIN cob_chain_company cobchainle2_ ON (cobchainle2_.level_1_client_company = cobchainst1_.level1client_company_id
            AND cobchainle2_.user_external_id = productsea0_.customer_id)
WHERE cobchainst1_.level1client_company_id = ?
    AND (? IS NULL
        OR productsea0_.brand_id2 = ?)
ORDER BY col_1_0_


SELECT cobchainle0_.id AS id2_53_0_, cobchainle0_.optlock AS optlock3_53_0_, cobchainle0_.actived AS actived4_53_0_, cobchainle0_.blocked AS
    blocked5_53_0_, cobchainle0_.created AS created6_53_0_, cobchainle0_.name AS name7_53_0_, cobchainle0_.name_to_show AS name_to_8_53_0_,
    cobchainle0_.removed AS removed9_53_0_, cobchainle0_.state AS state10_53_0_, cobchainle0_.type AS type1_53_0_, cobchainle0_.user_external_id AS
    user_ex11_53_0_, cobchainle0_.email AS email12_53_0_
FROM cob_chain_company cobchainle0_
WHERE cobchainle0_.id = ?
    AND cobchainle0_.type = 'LEVEL_1_CLIENT_COMPANY'
