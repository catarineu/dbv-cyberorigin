SELECT
	stk.id,
	stk.name,
	cred.id credential_id,
	cred.cred_type,
	cred.period_end,
	cred.extended_period_end,
	CASE
		WHEN cred.id IS NULL THEN 'VOID'
		WHEN now() <= cred.period_end THEN 'VALID'
		WHEN now() >  cred.period_end   AND now() <= cred.extended_period_end THEN 'EXTENDED'
		WHEN now() >  cred.period_end   AND now() >  cred.extended_period_end THEN 'EXPIRED'
		ELSE 'UNKNOWN'
	END
FROM
	cob_chain_company stk
	LEFT JOIN (
		SELECT cr.*
		FROM   credential cr
		INNER  JOIN                                                                     
			(SELECT cred.id,                
				    COALESCE(cred.extended_period_end, cred.period_end),
					ROW_NUMBER() OVER (PARTITION BY stakeholder_id, cred_type 
					                       ORDER BY COALESCE(cred.extended_period_end, cred.period_end) DESC) AS rn
			   FROM credential cred                                                            
			) sub                                                                      
			ON  sub.rn = 1
			AND sub.id = cr.id
		INNER JOIN dynamic_enum_value cred_type_enum ON cr.cred_type = cred_type_enum.id                                              
	) AS cred 
	ON
	cred.stakeholder_id = stk.id
WHERE
	stk."type" = 'STAKEHOLDER_COMPANY';
