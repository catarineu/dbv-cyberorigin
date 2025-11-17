CREATE OR REPLACE FUNCTION trigger_psi_customer_and_brand()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the provided customer_id is NULL
    IF NEW.customer_id IS NULL THEN
        -- Set customer_id2 to the fallback value '99999'
        NEW.customer_id2 := '99999';
    ELSE
        -- Copy customer_id to customer_id2
        NEW.customer_id2 := NEW.customer_id;
    END IF;

    -- Copy customer_id to customer_id2
    NEW.brand_id2 := NEW.brand_id;
   
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_trigger_psi_customer_and_brand
AFTER INSERT OR UPDATE ON product_search_index
FOR EACH ROW
EXECUTE FUNCTION trigger_psi_customer_and_brand();