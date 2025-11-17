INSERT INTO public.field_mapping_value 
(api, api_version, field, hidden, step_name, visible_in_summary, send_field, order_field) 
VALUES
('leather-goods-components', '1', 'product_material', false, 'ORDER', true, true, 
 (SELECT COALESCE(MAX(order_field), 0) + 1 FROM field_mapping_value 
  WHERE api = 'leather-goods-components' AND api_version = '1' AND step_name = 'ORDER')),
('leather-goods-components', '1', 'product_stones', false, 'ORDER', true, true,
 (SELECT COALESCE(MAX(order_field), 0) + 2 FROM field_mapping_value 
  WHERE api = 'leather-goods-components' AND api_version = '1' AND step_name = 'ORDER'))
ON CONFLICT (api, api_version, step_name, field) DO NOTHING;


-- Consulta de noms de workflows
SELECT code, api FROM workflow_name wn ORDER BY name;


-- Llistat dels camps visibles per un workflow
SELECT api, api_version AS v, step_name, field, order_field, order_in_summary, send_field, hidden, visible_in_summary, replace_field 
  FROM field_mapping_value fmv 
 WHERE api='diamonds-full' AND api_version ='5' ORDER BY step_name, field;




-- code|api                         |
-------+----------------------------+
-- 01  |diamonds-full               |
-- 02  |diamonds-semi-full          |
-- 03  |lab-grown-diamonds-semi-full|
-- 10  |round-coloured-stones       |
-- 20  |coloured-stones             |
-- 21  |baguette-rainbow            |
-- 30  |diamonds-baguettes          |
-- 80  |gold-full                   |
-- 99  |leather-goods-components    |
SELECT id,   field, send_field, hidden, api_version AS v, api, order_field, 
       step_name, visible_in_summary 
  FROM field_mapping_value fmv 
 WHERE api IN ('leather-goods-components') AND step_name ='ORDER'
 ORDER BY api, api_version DESC, step_name, send_field DESC, order_field ;

SELECT * FROM field_mapping_value fmv WHERE field~'doc' AND send_field =FALSE ORDER BY step_name, field ;


SELECT * FROM chain_member cm WHERE api_key ~*'2337';
SELECT * FROM chain_member cm WHERE name ~*'gil';


SELECT id, api_version, cob_value, enum_type, obsolete, vottun_value, api 
  FROM dynamic_enum_value dev
 WHERE api='gold-full'
 ORDER BY enum_type ;

SELECT * FROM app_config ac WHERE api~*'gold'; 


SELECT code, api FROM workflow_name wn ORDER BY code;

SELECT wn.code, s1.* 
  FROM step s1
       LEFT OUTER JOIN workflow_name wn ON wn.api=s1.api
 WHERE api_version = (SELECT max(api_version) FROM step s2 WHERE s2.api=s1.api)
   AND public_step IS NOT NULL 
 ORDER BY  wn.code, public_step, step;

-- ----------------------------------------------------------------------
-- Detecta passos a 'field_mapping_value' que no estan a 'step'
SELECT DISTINCT 
    COALESCE(s1.api, fmv.api) as api,
    s1.code_step, s1.public_step AS ps,
    fmv.api as fmv_api, 
    fmv.step_name
FROM 
    (SELECT s1.*
       FROM step s1
      WHERE s1.api_version = (SELECT max(s2.api_version) 
                                FROM step s2 
                               WHERE s2.api = s1.api)) s1
	FULL OUTER JOIN 
    	field_mapping_value fmv ON fmv.api = s1.api AND fmv.step_name = s1.code_step
ORDER BY 
    COALESCE(s1.api, fmv.api), 
    s1.public_step,
    s1.code_step, 
    fmv.step_name;

-- -- INSERT dels valors que faltin
INSERT INTO public.step
      (api,             api_version, role_name,  activity_name, step, public_step, code_step)
VALUES
('diamonds-full', '1',        'RoleCut', 'Cut',          1,           1, 'LAB_CONTROL'),
('diamonds-full', '1',        'RoleCut', 'Cut',          1,           2, 'VALIDATION_OF_PRODUCTION')
;

SELECT * 
  FROM step 
--  WHERE api='diamonds-full' ORDER BY api_version DESC, public_step 
  WHERE api='diamonds-full' ORDER BY api_version DESC, public_step 


  SELECT s1.api, api_version, public_step, code_step AS step_name
   FROM step s1
        LEFT OUTER JOIN workflow_name wn ON wn.api=s1.api
  WHERE s1.api_version = (SELECT max(s2.api_version) 
                            FROM step s2 
                           WHERE s2.api = s1.api)
    AND public_step IS NOT NULL                            
   ORDER BY wn.code, s1.public_step ;
  
  
SELECT DISTINCT api, max(api_version) FROM field_mapping_value GROUP BY api ORDER BY api;

SELECT api, api_version, step_name, field FROM field_mapping_value ORDER BY api, api_version DESC, step_name, order_field ;


--date
--certificate_id
--lab_name
--city
--carats
--pieces
--diameter_min
--diameter_max
--clarity
--colour
--naturalness
--naturalness_control
--out_batch_0
--order
--cyber_id_group
--certificate_url
--lot_id

SELECT generate_FMV_insert_statements_v2();

CREATE OR REPLACE FUNCTION generate_FMV_insert_statements_v2()
RETURNS TEXT AS $func$
DECLARE
    result TEXT := '';
    group_counter INTEGER := 0;
    r RECORD;
    current_api TEXT := '';
    current_api_version TEXT := '';
    current_step_name TEXT := '';
    is_first_in_group BOOLEAN;
    pad_length INTEGER := 24; -- Adjust based on your maximum field name length
    api_description TEXT;
    api_code TEXT;
    
    -- Cursor for ordered batch generation
    batch_order CURSOR FOR
        SELECT wn.code, s1.api, api_version, public_step, code_step as step_name, wn.name
        FROM step s1
        LEFT OUTER JOIN workflow_name wn ON wn.api=s1.api
        WHERE s1.api_version = (
            SELECT max(s2.api_version)
            FROM step s2
            WHERE s2.api = s1.api
        )
        AND public_step IS NOT NULL
		UNION ALL		
		SELECT '*', '*', '*', 0, '*', '*'
        ORDER BY 1, 4;
        
    batch_rec RECORD;
    previous_api TEXT := '';
BEGIN
    -- First, generate a result using the specified order
    result := '';
    
    -- Loop through the batch order
    FOR batch_rec IN batch_order LOOP
        -- Check if this is a new API and add header comment only for new APIs
        IF batch_rec.api != previous_api THEN
            -- Get API description and code for the header comment
            api_description := COALESCE(batch_rec.name, batch_rec.api, 'UNKNOWN');
            api_code := COALESCE(batch_rec.code, 'XX');
            
            -- Add a descriptive header comment for the new API
            result := result || E'\n/****************************************************************************************************\n';
            result := result || ' *                               ' || 
                        UPPER(api_description) || ' (' || 
                        LPAD(api_code, 2, '0') || ')' || E'\n';
            result := result || E' ****************************************************************************************************/\n\n';
            
            -- Update previous_api to current
            previous_api := batch_rec.api;
        END IF;
        
        -- For each batch, get its records
        FOR r IN 
            SELECT 
                api, 
                api_version, 
                step_name, 
                field, 
                order_field, 
                order_in_summary, 
                send_field, 
                hidden, 
                visible_in_summary, 
                replace_field
            FROM field_mapping_value 
            WHERE api = batch_rec.api 
            AND api_version = batch_rec.api_version
            AND step_name = batch_rec.step_name
            ORDER BY field
        LOOP
            -- Check if we're starting a new group
            IF current_api != r.api OR current_api_version != r.api_version OR current_step_name != r.step_name THEN               
                -- Start a new transaction and delete statement for this group
                result := result || 'BEGIN;' || E'\n';
                result := result || 'DELETE FROM field_mapping_value WHERE api = ''' || r.api || ''' AND api_version = ''' || r.api_version || ''' AND step_name = ''' || r.step_name || ''';' || E'\n';
                
                -- Start a new INSERT statement for this group
                result := result || 'INSERT INTO field_mapping_value (api, api_version, step_name, field, order_field, order_in_summary, send_field, hidden, visible_in_summary, replace_field) VALUES';
                
                -- Update current group identifiers
                current_api := r.api;
                current_api_version := r.api_version;
                current_step_name := r.step_name;
                is_first_in_group := TRUE;
                group_counter := group_counter + 1;
            ELSE
                -- Add a comma before the next value in the same group
                result := result || ',';
                is_first_in_group := FALSE;
            END IF;
            
            -- Format the values with padding for better alignment
            result := result || E'\n    (';
            result := result || '''' || r.api || ''', ';
            result := result || '''' || r.api_version || ''', ';
            result := result || '''' || r.step_name || ''', ';
            
            -- Add field with padding to align order_field
            result := result || '''' || r.field || '''' || 
                      repeat(' ', greatest(1, pad_length - length(r.field))) || ', ';
            
            -- Add order_field with left padding for right alignment (2 spaces)
            result := result || CASE 
                        WHEN length(r.order_field::TEXT) = 1 THEN '  ' || r.order_field::TEXT
                        WHEN length(r.order_field::TEXT) = 2 THEN ' ' || r.order_field::TEXT
                        ELSE r.order_field::TEXT
                      END || ', ';
            
            -- Handle NULL values with proper formatting for order_in_summary 
            -- Right-aligned with 2 spaces left padding
            IF r.order_in_summary IS NULL THEN
                result := result || ' null, ';
            ELSE
                -- Assume max value is 2 digits, so pad to make it look right-aligned
                result := result || CASE 
                          WHEN length(r.order_in_summary::TEXT) = 1 THEN '    ' || r.order_in_summary::TEXT
                          WHEN length(r.order_in_summary::TEXT) = 2 THEN '   ' || r.order_in_summary::TEXT
                          ELSE r.order_in_summary::TEXT
                        END || ', ';
            END IF;
            
            -- Boolean values are formatted as "false" or " true" (with one space on the left for true)
            result := result || CASE WHEN r.send_field THEN ' true' ELSE 'false' END || ', ';
            result := result || CASE WHEN r.hidden THEN ' true' ELSE 'false' END || ', ';
            result := result || CASE WHEN r.visible_in_summary THEN ' true' ELSE 'false' END || ', ';
            
            -- Handle NULL values for replace_field (no padding needed for last field)
            IF r.replace_field IS NULL THEN
                result := result || 'NULL';
            ELSE
                result := result || '''' || r.replace_field || '''';
            END IF;
            
            result := result || ')';
        END LOOP;
        
        -- Add COMMIT for the last group if records were found
        IF current_api = batch_rec.api AND current_api_version = batch_rec.api_version AND current_step_name = batch_rec.step_name THEN
            result := result || ';' || E'\nCOMMIT;' || E'\n\n';
        END IF;
    END LOOP;
      
    RETURN result;
END;
$func$ LANGUAGE plpgsql;

