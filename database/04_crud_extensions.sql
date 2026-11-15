-- Extra deletion helper functions
CREATE OR REPLACE FUNCTION fn_customer_delete(
    p_customer_id VARCHAR,
    p_actor_id VARCHAR DEFAULT NULL,
    p_actor_name VARCHAR DEFAULT 'SYSTEM'
)
RETURNS TABLE (
    is_successful BOOLEAN,
    res_code VARCHAR,
    res_msg VARCHAR,
    created_id VARCHAR,
    total_records INT,
    max_pages INT,
    result_data JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id UUID := p_customer_id::uuid;
BEGIN
    DELETE FROM tbl_customers WHERE customer_id = v_id;
    PERFORM fn_log_activity(p_actor_id, p_actor_name, 'DELETE', 'CUSTOMERS', 'Deleted customer ID: ' || p_customer_id, p_customer_id, NULL, NULL, '127.0.0.1');
    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Customer deleted successfully'::VARCHAR, p_customer_id, 1, 1, NULL::JSONB;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'DEL_CUST_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

CREATE OR REPLACE FUNCTION fn_product_delete(
    p_product_id VARCHAR,
    p_actor_id VARCHAR DEFAULT NULL,
    p_actor_name VARCHAR DEFAULT 'SYSTEM'
)
RETURNS TABLE (
    is_successful BOOLEAN,
    res_code VARCHAR,
    res_msg VARCHAR,
    created_id VARCHAR,
    total_records INT,
    max_pages INT,
    result_data JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id UUID := p_product_id::uuid;
BEGIN
    DELETE FROM tbl_inventory WHERE product_id = v_id;
    DELETE FROM tbl_products WHERE product_id = v_id;
    PERFORM fn_log_activity(p_actor_id, p_actor_name, 'DELETE', 'PRODUCTS', 'Deleted product ID: ' || p_product_id, p_product_id, NULL, NULL, '127.0.0.1');
    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Product deleted successfully'::VARCHAR, p_product_id, 1, 1, NULL::JSONB;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'DEL_PROD_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

CREATE OR REPLACE FUNCTION fn_production_batch_delete(
    p_batch_id VARCHAR,
    p_actor_id VARCHAR DEFAULT NULL,
    p_actor_name VARCHAR DEFAULT 'SYSTEM'
)
RETURNS TABLE (
    is_successful BOOLEAN,
    res_code VARCHAR,
    res_msg VARCHAR,
    created_id VARCHAR,
    total_records INT,
    max_pages INT,
    result_data JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id UUID := p_batch_id::uuid;
BEGIN
    DELETE FROM tbl_production_batches WHERE batch_id = v_id;
    PERFORM fn_log_activity(p_actor_id, p_actor_name, 'DELETE', 'PRODUCTION_BATCH', 'Deleted batch ID: ' || p_batch_id, p_batch_id, NULL, NULL, '127.0.0.1');
    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Batch deleted successfully'::VARCHAR, p_batch_id, 1, 1, NULL::JSONB;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'DEL_BATCH_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;
