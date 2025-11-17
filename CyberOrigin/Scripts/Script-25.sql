
SELECT * FROM workflow_name wn
 ORDER BY code;

SELECT *
  FROM workflow_version wv 
 ORDER BY api, api_version;

SELECT id, api, api_version, is_group, steps, workflow_name_id AS wf_id
  FROM workflow_version wv 
 ORDER BY api, api_version;


SELECT cobchainad0_.id AS id2_53_, cobchainad0_.optlock AS optlock3_53_, cobchainad0_.actived AS actived4_53_, cobchainad0_.blocked AS blocked5_53_,
    cobchainad0_.created AS created6_53_, cobchainad0_.name AS name7_53_, cobchainad0_.name_to_show AS name_to_8_53_, cobchainad0_.removed AS
    removed9_53_, cobchainad0_.state AS state10_53_, cobchainad0_.type AS type1_53_, cobchainad0_.user_external_id AS user_ex11_53_,
    cobchainad0_.api_key AS api_key13_53_
FROM cob_chain_company cobchainad0_
WHERE cobchainad0_.type = 'ADMIN'
    AND cobchainad0_.api_key = ?
    
SELECT wtype AS wtype, wname AS wname, cyber_id AS cyberId, maxstep AS maxStep, step AS step, activity_name AS activityName, timestamp AS
	timestamp, api AS api, api_version AS apiVersion, success AS success, errorcode AS errorCode, message AS message, status AS status
    FROM v_register_log_detail rl
    WHERE rl.cyber_id = CAST(? AS varchar(255))
    ORDER BY timestamp ASC
    LIMIT ?

    SELECT count(1)
    FROM v_register_log_detail rl
    WHERE rl.cyber_id = CAST(? AS varchar(255))
