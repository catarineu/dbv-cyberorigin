UPDATE product_search_index SET nft_outdated =FALSE;


CREATE TABLE cob_chain_company_seg_backup AS (SELECT * FROM cob_chain_company ccc);



SELECT * FROM cob_chain_company ORDER BY TYPE, created desc;

SELECT * FROM product_search_index psi WHERE cyber_id ='CYR01-23-0672-292573';


SELECT cobchainst0_.id AS id2_53_, cobchainst0_.optlock AS optlock3_53_, cobchainst0_.actived AS actived4_53_, cobchainst0_.blocked AS blocked5_53_,
    cobchainst0_.created AS created6_53_, cobchainst0_.name AS name7_53_, cobchainst0_.name_to_show AS name_to_53_, cobchainst0_.removed AS
    removed9_53_, cobchainst0_.state AS state10_53_, cobchainst0_.type AS type1_53_, cobchainst0_.user_external_id AS user_ex11_53_,
    cobchainst0_.chain_member_id AS chain_m14_53_, cobchainst0_.level1client_company_id AS level15_53_
FROM cob_chain_company cobchainst0_
WHERE cobchainst0_.type = 'STAKEHOLDER_COMPANY'
    AND (cobchainst0_.chain_member_id IN (8, 7, 19, 4));


SELECT cobchainle0_.id AS id2_53_0_, cobchainle0_.optlock AS optlock3_53_0_, cobchainle0_.actived AS actived4_53_0_, cobchainle0_.blocked AS
    blocked5_53_0_, cobchainle0_.created AS created6_53_0_, cobchainle0_.name AS name7_53_0_, cobchainle0_.name_to_show AS name_to_8_53_0_,
    cobchainle0_.removed AS removed9_53_0_, cobchainle0_.state AS state10_53_0_, cobchainle0_.type AS type1_53_0_, cobchainle0_.user_external_id AS
    user_ex11_53_0_, cobchainle0_.email AS email13_53_0_
FROM cob_chain_company cobchainle0_
WHERE cobchainle0_.id = 'e02e33ea-2f13-4146-8423-016b8cfc77fc'
    AND cobchainle0_.type = 'LEVEL_1_CLIENT_COMPANY'
 


SELECT cobchainle0_.id AS id2_53_0_, cobchainle0_.optlock AS optlock3_53_0_, cobchainle0_.actived AS actived4_53_0_, cobchainle0_.blocked AS
    blocked5_53_0_, cobchainle0_.created AS created6_53_0_, cobchainle0_.name AS name7_53_0_, cobchainle0_.name_to_show AS name_to_8_53_0_,
    cobchainle0_.removed AS removed9_53_0_, cobchainle0_.state AS state10_53_0_, cobchainle0_.type AS type1_53_0_, cobchainle0_.user_external_id AS
    user_ex11_53_0_, cobchainle0_.email AS email13_53_0_
FROM cob_chain_company cobchainle0_
WHERE cobchainle0_.id = '78a75353-a8c7-47c8-b6ba-7102f79f07b3'
    AND cobchainle0_.type = 'LEVEL_1_CLIENT_COMPANY'

SELECT chain_member_id, "name", level_1_client_company, level1client_company_id FROM cob_chain_company ccc WHERE chain_member_id IN (8,7,19,4);

Finding user cobchain stakeholder company by chain members in :[[8 Responsable Cyberorigin, 7 Responsable Gil Gemma BV, 19 Responsable Prime Gems, 4 Responsable Gil]] ...

SELECT cobchainst0_.id AS id2_53_,...
  FROM cob_chain_company cobchainst0_
 WHERE cobchainst0_.type = 'STAKEHOLDER_COMPANY'
   AND (cobchainst0_.chain_member_id IN (?, ?, ?, ?))


SELECT chainmembe0_.id AS id1_51_0_, ...
  FROM chain_member chainmembe0_
       LEFT OUTER JOIN rjc rjc1_ ON chainmembe0_.rjc_id = rjc1_.id
       LEFT OUTER JOIN chain_member chainmembe2_ ON rjc1_.chain_member_id = chainmembe2_.id
 WHERE chainmembe0_.id = ?

SELECT cobchainle0_.id AS id2_53_0_,...
  FROM cob_chain_company cobchainle0_
 WHERE cobchainle0_.id = ?
   AND cobchainle0_.type = 'LEVEL_1_CLIENT_COMPANY'


SELECT chainmembe0_.id...
 FROM chain_member chainmembe0_
      LEFT OUTER JOIN rjc rjc1_ ON chainmembe0_.rjc_id = rjc1_.id
      LEFT OUTER JOIN chain_member chainmembe2_ ON rjc1_.chain_member_id = chainmembe2_.id
WHERE chainmembe0_.id = ?


SELECT chainmembe0_.id...
FROM chain_member chainmembe0_
    LEFT OUTER JOIN rjc rjc1_ ON chainmembe0_.rjc_id = rjc1_.id
    LEFT OUTER JOIN chain_member chainmembe2_ ON rjc1_.chain_member_id = chainmembe2_.id
WHERE chainmembe0_.id = ?


SELECT chainmembe0_.id...
FROM chain_member chainmembe0_
    LEFT OUTER JOIN rjc rjc1_ ON chainmembe0_.rjc_id = rjc1_.id
    LEFT OUTER JOIN chain_member chainmembe2_ ON rjc1_.chain_member_id = chainmembe2_.id
WHERE chainmembe0_.id = ?
