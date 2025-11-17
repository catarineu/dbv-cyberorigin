SELECT code, api FROM workflow_name wn ORDER BY code ;

SELECT * 
  FROM step_assigned_member sam 
 WHERE api='diamonds-semi-full' 
 ORDER BY  api_version DESC, step, sam.id

SELECT sam.id, sam.optlock, sam.step, sam.chain_member_id AS id, cm.company_name , sam.api, sam.api_version  
  FROM step_assigned_member sam 
       LEFT OUTER JOIN chain_member cm ON cm.id=sam.chain_member_id 
 WHERE api='diamonds-semi-full' 
 ORDER BY  api_version DESC, step, sam.id;

SELECT id, company_name, * FROM chain_member cm ORDER BY id; 

-- round-coloured-stones
-- coloured-stones

-- PEL TON
SELECT api, sam.step, sam.chain_member_id AS id, cm.company_name , cm.api_key  
  FROM step_assigned_member sam 
       LEFT OUTER JOIN chain_member cm ON cm.id=sam.chain_member_id 
 WHERE api='diamonds-semi-full' 
 ORDER BY  api_version DESC, step, sam.id;
