 WITH unsolved_warnings AS (
    SELECT *
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY lot_cyber_id ORDER BY warning_timestamp DESC) AS rn
    FROM stalled_lot_warning w)
    WHERE rn = 1
)
SELECT rl.wtype AS wtype, rl.wname AS wname, rl.cyber_id AS cyberId, rl.maxstep AS maxStep, rl.step AS step, rl.activity_name AS activityName,
    rl.timestamp AS timestamp, rl.api AS api, rl.api_version AS apiVersion, rl.success AS success, rl.errorcode AS errorCode, rl.message AS message,
    rl.status AS status, rl.what_to_do AS whatToDo, rl.who AS who, w.id AS stalledLotWarningId
FROM v_register_log_with_actions rl
    INNER JOIN unsolved_warnings w ON w.lot_cyber_id = rl.cyber_id
ORDER BY timestamp ASC


SELECT * FROM stalled_lot_warning WHERE lot_cyber_id ~ 'CYR01-22-0556-204036';

SELECT id, api, is_group, steps, workflow_name_id 
  FROM workflow_version wv 
 ORDER BY api;

SELECT code, api, id FROM workflow_name wn ORDER BY code;

SELECT * FROM v_register_log vrl WHERE cyber_id ~ 'CYR01-22-0556-204036' ORDER BY "timestamp" DESC ;

SELECT * FROM register_log vrl WHERE cyber_id ~ 'CYR01-22-0556-204036' ORDER BY "timestamp" DESC ;

SELECT cyber_id, api, blockchain_id FROM register_log vrl WHERE api='baguette-rainbow' ORDER BY "timestamp" DESC ;