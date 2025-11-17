-- AUTOTABLE#1 = Documents/Steps for all WF
SELECT wf,step,wfs.name, fname,ftype 
 FROM wf_fields
 	  LEFT OUTER JOIN wf_steps wfs USING (VERSION,wf,step)
WHERE ftype='Document' ORDER BY wf, step;

WITH matrix AS (
	SELECT wfs.phase, wfs.name AS sname, fname AS field,
		CASE WHEN wf='01' THEN TRUE ELSE FALSE END AS wf01,
		CASE WHEN wf='02' THEN TRUE ELSE FALSE END AS wf02,
		CASE WHEN wf='10' THEN TRUE ELSE FALSE END AS wf10,
		CASE WHEN wf='20' THEN TRUE ELSE FALSE END AS wf20,
		CASE WHEN wf='21' THEN TRUE ELSE FALSE END AS wf21,
		CASE WHEN wf='30' THEN TRUE ELSE FALSE END AS wf30
	 FROM wf_fields
	 	  LEFT OUTER JOIN wf_steps wfs USING (VERSION,wf,step)
	WHERE ftype='Document')
SELECT phase AS phase, sname, field, 
	   bool_or(wf01) AS wf01,
	   bool_or(wf02) AS wf02,
	   bool_or(wf10) AS wf10,
	   bool_or(wf20) AS wf20,
	   bool_or(wf21) AS wf21,
	   bool_or(wf30) AS wf30
 FROM matrix
GROUP BY phase, sname, field 
ORDER BY phase, sname, field;


