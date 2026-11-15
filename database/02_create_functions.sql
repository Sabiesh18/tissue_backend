-- =============================================================================
-- TISSUE MANUFACTURING MANAGEMENT SYSTEM
-- Master PostgreSQL Functions (fn_* returning standardized composite result)
-- Pattern adheres to billora database architecture
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ACTIVITY LOGGING
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_log_activity(
    p_user_id VARCHAR,
    p_username VARCHAR,
    p_activity_type VARCHAR,
    p_module VARCHAR,
    p_description TEXT,
    p_record_id VARCHAR DEFAULT NULL,
    p_old_val JSONB DEFAULT NULL,
    p_new_val JSONB DEFAULT NULL,
    p_ip_address VARCHAR DEFAULT '127.0.0.1'
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
    v_act_id UUID := gen_random_uuid();
    v_user_uuid UUID := NULL;
BEGIN
    IF p_user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_user_uuid := p_user_id::uuid;
    END IF;

    INSERT INTO tbl_activity_logs (
        activity_id, user_id, username, activity_type, module,
        description, record_id, old_value, new_value, ip_address, created_at
    ) VALUES (
        v_act_id, v_user_uuid, p_username, p_activity_type, p_module,
        p_description, p_record_id, p_old_val, p_new_val, p_ip_address, CURRENT_TIMESTAMP
    );

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Activity logged'::VARCHAR, v_act_id::VARCHAR, 1, 1, jsonb_build_object('activityId', v_act_id::text);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'LOG_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. GET ACTIVITY HISTORY
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_get_activity_history(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 20,
    p_module VARCHAR DEFAULT NULL,
    p_activity_type VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_activity_logs a
    WHERE (p_module IS NULL OR p_module = '' OR a.module = p_module)
      AND (p_activity_type IS NULL OR p_activity_type = '' OR a.activity_type = p_activity_type);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'activityId', a.activity_id::text,
            'userId', a.user_id::text,
            'username', a.username,
            'activityType', a.activity_type,
            'module', a.module,
            'description', a.description,
            'recordId', a.record_id,
            'oldValue', a.old_value,
            'newValue', a.new_value,
            'ipAddress', a.ip_address,
            'createdAt', to_char(a.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT *
        FROM tbl_activity_logs a
        WHERE (p_module IS NULL OR p_module = '' OR a.module = p_module)
          AND (p_activity_type IS NULL OR p_activity_type = '' OR a.activity_type = p_activity_type)
        ORDER BY a.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) a;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Activity logs fetched'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_LOGS_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. USER AUTHENTICATION & CREDENTIAL CHECK
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_user_login(
    p_username VARCHAR,
    p_ip_address VARCHAR DEFAULT '127.0.0.1'
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
    v_user RECORD;
    v_auth RECORD;
BEGIN
    SELECT u.*, r.role_code
    INTO v_user
    FROM tbl_users u
    LEFT JOIN tbl_roles r ON u.role_id = r.role_id
    WHERE LOWER(u.username) = LOWER(p_username);

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'USER_NOT_FOUND'::VARCHAR, 'Invalid username or user does not exist'::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
        RETURN;
    END IF;

    IF NOT v_user.is_active THEN
        RETURN QUERY SELECT FALSE, 'USER_INACTIVE'::VARCHAR, 'User account is deactivated'::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
        RETURN;
    END IF;

    SELECT * INTO v_auth FROM tbl_user_auth WHERE user_id = v_user.user_id;

    IF FOUND AND v_auth.is_locked THEN
        RETURN QUERY SELECT FALSE, 'ACCOUNT_LOCKED'::VARCHAR, 'Account is locked due to too many failed attempts'::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
        RETURN;
    END IF;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'User authenticated details retrieved'::VARCHAR, v_user.user_id::VARCHAR, 1, 1,
        jsonb_build_object(
            'userId', v_user.user_id::text,
            'username', v_user.username,
            'fullName', v_user.full_name,
            'email', v_user.email,
            'phone', v_user.phone,
            'roleId', v_user.role_id::text,
            'roleName', v_user.role_name,
            'roleCode', COALESCE(v_user.role_code, v_user.role_name),
            'passwordHash', v_auth.password_hash
        );
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. UPDATE USER LOGIN SUCCESS / FAILURE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_update_login_status(
    p_user_id VARCHAR,
    p_is_successful BOOLEAN,
    p_ip_address VARCHAR DEFAULT '127.0.0.1'
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
    v_uid UUID := p_user_id::uuid;
BEGIN
    IF p_is_successful THEN
        UPDATE tbl_user_auth
        SET last_login = CURRENT_TIMESTAMP,
            failed_attempts = 0,
            is_locked = FALSE,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = v_uid;

        PERFORM fn_log_activity(p_user_id, 'SYSTEM', 'LOGIN_SUCCESS', 'AUTH', 'User login successful', p_user_id, NULL, NULL, p_ip_address);
    ELSE
        UPDATE tbl_user_auth
        SET failed_attempts = failed_attempts + 1,
            is_locked = CASE WHEN failed_attempts + 1 >= 5 THEN TRUE ELSE FALSE END,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = v_uid;

        PERFORM fn_log_activity(p_user_id, 'SYSTEM', 'LOGIN_FAILED', 'AUTH', 'User login failed attempt', p_user_id, NULL, NULL, p_ip_address);
    END IF;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Login status updated'::VARCHAR, p_user_id, 1, 1, NULL::JSONB;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'AUTH_STATUS_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. USERS: SAVE (CREATE / UPDATE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_user_save(
    p_user_id VARCHAR,
    p_username VARCHAR,
    p_full_name VARCHAR,
    p_email VARCHAR,
    p_phone VARCHAR,
    p_role_id VARCHAR,
    p_role_name VARCHAR,
    p_is_active BOOLEAN,
    p_password_hash VARCHAR DEFAULT NULL,
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
    v_id UUID;
    v_role_uuid UUID := NULL;
    v_result JSONB;
    v_exists BOOLEAN;
BEGIN
    IF p_role_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_role_uuid := p_role_id::uuid;
    END IF;

    IF p_user_id IS NOT NULL AND p_user_id <> '' AND p_user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_id := p_user_id::uuid;

        UPDATE tbl_users
        SET full_name = p_full_name,
            email = p_email,
            phone = p_phone,
            role_id = v_role_uuid,
            role_name = p_role_name,
            is_active = p_is_active,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = v_id;

        IF p_password_hash IS NOT NULL AND p_password_hash <> '' THEN
            UPDATE tbl_user_auth
            SET password_hash = p_password_hash,
                updated_at = CURRENT_TIMESTAMP
            WHERE user_id = v_id;
        END IF;

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'UPDATE', 'USERS', 'User updated: ' || p_username, v_id::text, NULL, NULL, '127.0.0.1');
    ELSE
        SELECT EXISTS(SELECT 1 FROM tbl_users WHERE LOWER(username) = LOWER(p_username)) INTO v_exists;
        IF v_exists THEN
            RETURN QUERY SELECT FALSE, 'USERNAME_TAKEN'::VARCHAR, 'Username already exists'::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
            RETURN;
        END IF;

        v_id := gen_random_uuid();

        INSERT INTO tbl_users (user_id, username, full_name, email, phone, role_id, role_name, is_active, created_at, updated_at)
        VALUES (v_id, p_username, p_full_name, p_email, p_phone, v_role_uuid, p_role_name, p_is_active, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

        INSERT INTO tbl_user_auth (auth_id, user_id, password_hash, last_login, failed_attempts, is_locked)
        VALUES (gen_random_uuid(), v_id, COALESCE(p_password_hash, ''), NULL, 0, FALSE);

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'CREATE', 'USERS', 'User created: ' || p_username, v_id::text, NULL, NULL, '127.0.0.1');
    END IF;

    SELECT jsonb_build_object(
        'userId', u.user_id::text,
        'username', u.username,
        'fullName', u.full_name,
        'email', u.email,
        'phone', u.phone,
        'roleId', u.role_id::text,
        'roleName', u.role_name,
        'isActive', u.is_active
    ) INTO v_result
    FROM tbl_users u WHERE u.user_id = v_id;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'User saved successfully'::VARCHAR, v_id::VARCHAR, 1, 1, v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'USER_SAVE_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. USERS: GET ALL (PAGINATED & SEARCHABLE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_user_get_all(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_search VARCHAR DEFAULT NULL,
    p_role_name VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_users u
    WHERE (p_search IS NULL OR p_search = '' OR u.username ILIKE '%' || p_search || '%' OR u.full_name ILIKE '%' || p_search || '%' OR u.email ILIKE '%' || p_search || '%')
      AND (p_role_name IS NULL OR p_role_name = '' OR u.role_name = p_role_name);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'userId', u.user_id::text,
            'username', u.username,
            'fullName', u.full_name,
            'email', u.email,
            'phone', u.phone,
            'roleId', u.role_id::text,
            'roleName', u.role_name,
            'isActive', u.is_active,
            'createdAt', to_char(u.created_at, 'YYYY-MM-DD"T"HH24:MI:SS'),
            'lastLogin', to_char(a.last_login, 'YYYY-MM-DD"T"HH24:MI:SS'),
            'isLocked', COALESCE(a.is_locked, FALSE)
        )
    ) INTO v_result
    FROM (
        SELECT u.*, a.last_login, a.is_locked
        FROM tbl_users u
        LEFT JOIN tbl_user_auth a ON u.user_id = a.user_id
        WHERE (p_search IS NULL OR p_search = '' OR u.username ILIKE '%' || p_search || '%' OR u.full_name ILIKE '%' || p_search || '%' OR u.email ILIKE '%' || p_search || '%')
          AND (p_role_name IS NULL OR p_role_name = '' OR u.role_name = p_role_name)
        ORDER BY u.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) u;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Users retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_USERS_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. ROLES & PERMISSIONS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_role_get_all()
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
    v_result JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'roleId', r.role_id::text,
            'roleName', r.role_name,
            'roleCode', r.role_code,
            'description', r.description,
            'isSystemRole', r.is_system_role,
            'createdAt', to_char(r.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM tbl_roles r ORDER BY r.role_name;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Roles retrieved'::VARCHAR, NULL::VARCHAR, jsonb_array_length(COALESCE(v_result, '[]'::jsonb)), 1, COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- -----------------------------------------------------------------------------
-- 8. VENDORS: SAVE (CREATE / UPDATE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_vendor_save(
    p_vendor_id VARCHAR,
    p_vendor_code VARCHAR,
    p_vendor_name VARCHAR,
    p_company_name VARCHAR,
    p_contact_person VARCHAR,
    p_email VARCHAR,
    p_phone VARCHAR,
    p_tax_number VARCHAR,
    p_address_line1 VARCHAR,
    p_city VARCHAR,
    p_state VARCHAR,
    p_postal_code VARCHAR,
    p_vendor_status VARCHAR DEFAULT 'ACTIVE',
    p_credit_period_days INT DEFAULT 30,
    p_notes TEXT DEFAULT NULL,
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
    v_id UUID;
    v_result JSONB;
BEGIN
    IF p_vendor_id IS NOT NULL AND p_vendor_id <> '' AND p_vendor_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_id := p_vendor_id::uuid;
        UPDATE tbl_vendors
        SET vendor_code = p_vendor_code,
            vendor_name = p_vendor_name,
            company_name = p_company_name,
            contact_person = p_contact_person,
            email = p_email,
            phone = p_phone,
            tax_number = p_tax_number,
            address_line1 = p_address_line1,
            city = p_city,
            state = p_state,
            postal_code = p_postal_code,
            vendor_status = p_vendor_status,
            credit_period_days = p_credit_period_days,
            notes = p_notes,
            updated_at = CURRENT_TIMESTAMP
        WHERE vendor_id = v_id;

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'UPDATE', 'VENDORS', 'Vendor updated: ' || p_vendor_name, v_id::text, NULL, NULL, '127.0.0.1');
    ELSE
        v_id := gen_random_uuid();
        INSERT INTO tbl_vendors (
            vendor_id, vendor_code, vendor_name, company_name, contact_person, email, phone,
            tax_number, address_line1, city, state, postal_code, vendor_status, credit_period_days, notes, created_at, updated_at
        ) VALUES (
            v_id, p_vendor_code, p_vendor_name, p_company_name, p_contact_person, p_email, p_phone,
            p_tax_number, p_address_line1, p_city, p_state, p_postal_code, p_vendor_status, p_credit_period_days, p_notes, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'CREATE', 'VENDORS', 'Vendor created: ' || p_vendor_name, v_id::text, NULL, NULL, '127.0.0.1');
    END IF;

    SELECT jsonb_build_object(
        'vendorId', v.vendor_id::text,
        'vendorCode', v.vendor_code,
        'vendorName', v.vendor_name,
        'companyName', v.company_name,
        'contactPerson', v.contact_person,
        'email', v.email,
        'phone', v.phone,
        'taxNumber', v.tax_number,
        'addressLine1', v.address_line1,
        'city', v.city,
        'state', v.state,
        'postalCode', v.postal_code,
        'vendorStatus', v.vendor_status,
        'creditPeriodDays', v.credit_period_days,
        'outstandingBalance', v.outstanding_balance
    ) INTO v_result
    FROM tbl_vendors v WHERE v.vendor_id = v_id;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Vendor saved successfully'::VARCHAR, v_id::VARCHAR, 1, 1, v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'VENDOR_SAVE_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 9. VENDORS: GET ALL (PAGINATED & SEARCHABLE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_vendor_get_all(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_search VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_vendors v
    WHERE (p_search IS NULL OR p_search = '' OR v.vendor_name ILIKE '%' || p_search || '%' OR v.company_name ILIKE '%' || p_search || '%' OR v.vendor_code ILIKE '%' || p_search || '%')
      AND (p_status IS NULL OR p_status = '' OR v.vendor_status = p_status);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'vendorId', v.vendor_id::text,
            'vendorCode', v.vendor_code,
            'vendorName', v.vendor_name,
            'companyName', v.company_name,
            'contactPerson', v.contact_person,
            'email', v.email,
            'phone', v.phone,
            'taxNumber', v.tax_number,
            'addressLine1', v.address_line1,
            'city', v.city,
            'state', v.state,
            'postalCode', v.postal_code,
            'vendorStatus', v.vendor_status,
            'creditPeriodDays', v.credit_period_days,
            'outstandingBalance', v.outstanding_balance,
            'rating', v.rating,
            'notes', v.notes,
            'createdAt', to_char(v.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT *
        FROM tbl_vendors v
        WHERE (p_search IS NULL OR p_search = '' OR v.vendor_name ILIKE '%' || p_search || '%' OR v.company_name ILIKE '%' || p_search || '%' OR v.vendor_code ILIKE '%' || p_search || '%')
          AND (p_status IS NULL OR p_status = '' OR v.vendor_status = p_status)
        ORDER BY v.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) v;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Vendors retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_VENDORS_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 10. VENDORS: DELETE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_vendor_delete(
    p_vendor_id VARCHAR,
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
    v_id UUID := p_vendor_id::uuid;
BEGIN
    DELETE FROM tbl_vendors WHERE vendor_id = v_id;
    PERFORM fn_log_activity(p_actor_id, p_actor_name, 'DELETE', 'VENDORS', 'Deleted vendor ID: ' || p_vendor_id, p_vendor_id, NULL, NULL, '127.0.0.1');
    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Vendor deleted successfully'::VARCHAR, p_vendor_id, 1, 1, NULL::JSONB;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'DEL_VENDOR_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 11. CUSTOMERS: SAVE (CREATE / UPDATE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_customer_save(
    p_customer_id VARCHAR,
    p_customer_code VARCHAR,
    p_customer_name VARCHAR,
    p_company_name VARCHAR,
    p_contact_person VARCHAR,
    p_email VARCHAR,
    p_phone VARCHAR,
    p_tax_number VARCHAR,
    p_billing_address TEXT,
    p_city VARCHAR,
    p_state VARCHAR,
    p_postal_code VARCHAR,
    p_customer_status VARCHAR DEFAULT 'ACTIVE',
    p_credit_limit NUMERIC DEFAULT 0.00,
    p_notes TEXT DEFAULT NULL,
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
    v_id UUID;
    v_result JSONB;
BEGIN
    IF p_customer_id IS NOT NULL AND p_customer_id <> '' AND p_customer_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_id := p_customer_id::uuid;
        UPDATE tbl_customers
        SET customer_code = p_customer_code,
            customer_name = p_customer_name,
            company_name = p_company_name,
            contact_person = p_contact_person,
            email = p_email,
            phone = p_phone,
            tax_number = p_tax_number,
            billing_address = p_billing_address,
            city = p_city,
            state = p_state,
            postal_code = p_postal_code,
            customer_status = p_customer_status,
            credit_limit = p_credit_limit,
            notes = p_notes,
            updated_at = CURRENT_TIMESTAMP
        WHERE customer_id = v_id;

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'UPDATE', 'CUSTOMERS', 'Customer updated: ' || p_customer_name, v_id::text, NULL, NULL, '127.0.0.1');
    ELSE
        v_id := gen_random_uuid();
        INSERT INTO tbl_customers (
            customer_id, customer_code, customer_name, company_name, contact_person, email, phone,
            tax_number, billing_address, city, state, postal_code, customer_status, credit_limit, notes, created_at, updated_at
        ) VALUES (
            v_id, p_customer_code, p_customer_name, p_company_name, p_contact_person, p_email, p_phone,
            p_tax_number, p_billing_address, p_city, p_state, p_postal_code, p_customer_status, p_credit_limit, p_notes, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'CREATE', 'CUSTOMERS', 'Customer created: ' || p_customer_name, v_id::text, NULL, NULL, '127.0.0.1');
    END IF;

    SELECT jsonb_build_object(
        'customerId', c.customer_id::text,
        'customerCode', c.customer_code,
        'customerName', c.customer_name,
        'companyName', c.company_name,
        'contactPerson', c.contact_person,
        'email', c.email,
        'phone', c.phone,
        'taxNumber', c.tax_number,
        'billingAddress', c.billing_address,
        'city', c.city,
        'state', c.state,
        'postalCode', c.postal_code,
        'customerStatus', c.customer_status,
        'creditLimit', c.credit_limit,
        'outstandingBalance', c.outstanding_balance
    ) INTO v_result
    FROM tbl_customers c WHERE c.customer_id = v_id;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Customer saved successfully'::VARCHAR, v_id::VARCHAR, 1, 1, v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'CUSTOMER_SAVE_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 12. CUSTOMERS: GET ALL (PAGINATED & SEARCHABLE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_customer_get_all(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_search VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_customers c
    WHERE (p_search IS NULL OR p_search = '' OR c.customer_name ILIKE '%' || p_search || '%' OR c.company_name ILIKE '%' || p_search || '%' OR c.customer_code ILIKE '%' || p_search || '%')
      AND (p_status IS NULL OR p_status = '' OR c.customer_status = p_status);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'customerId', c.customer_id::text,
            'customerCode', c.customer_code,
            'customerName', c.customer_name,
            'companyName', c.company_name,
            'contactPerson', c.contact_person,
            'email', c.email,
            'phone', c.phone,
            'taxNumber', c.tax_number,
            'billingAddress', c.billing_address,
            'city', c.city,
            'state', c.state,
            'postalCode', c.postal_code,
            'customerStatus', c.customer_status,
            'creditLimit', c.credit_limit,
            'outstandingBalance', c.outstanding_balance,
            'notes', c.notes,
            'createdAt', to_char(c.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT *
        FROM tbl_customers c
        WHERE (p_search IS NULL OR p_search = '' OR c.customer_name ILIKE '%' || p_search || '%' OR c.company_name ILIKE '%' || p_search || '%' OR c.customer_code ILIKE '%' || p_search || '%')
          AND (p_status IS NULL OR p_status = '' OR c.customer_status = p_status)
        ORDER BY c.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) c;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Customers retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_CUSTOMERS_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 13. ASSETS: SAVE (CREATE / UPDATE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_asset_save(
    p_asset_id VARCHAR,
    p_asset_code VARCHAR,
    p_asset_name VARCHAR,
    p_category VARCHAR,
    p_model_number VARCHAR,
    p_serial_number VARCHAR,
    p_vendor_id VARCHAR,
    p_vendor_name VARCHAR,
    p_purchase_date VARCHAR,
    p_purchase_cost NUMERIC,
    p_current_value NUMERIC,
    p_quantity INT,
    p_location_area VARCHAR,
    p_condition_status VARCHAR DEFAULT 'OPERATIONAL',
    p_warranty_expiry VARCHAR DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
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
    v_id UUID;
    v_vendor_uuid UUID := NULL;
    v_p_date DATE := NULL;
    v_w_date DATE := NULL;
    v_result JSONB;
BEGIN
    IF p_vendor_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_vendor_uuid := p_vendor_id::uuid;
    END IF;

    IF p_purchase_date IS NOT NULL AND p_purchase_date <> '' THEN
        v_p_date := p_purchase_date::DATE;
    END IF;

    IF p_warranty_expiry IS NOT NULL AND p_warranty_expiry <> '' THEN
        v_w_date := p_warranty_expiry::DATE;
    END IF;

    IF p_asset_id IS NOT NULL AND p_asset_id <> '' AND p_asset_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_id := p_asset_id::uuid;
        UPDATE tbl_assets
        SET asset_code = p_asset_code,
            asset_name = p_asset_name,
            category = p_category,
            model_number = p_model_number,
            serial_number = p_serial_number,
            vendor_id = v_vendor_uuid,
            vendor_name = p_vendor_name,
            purchase_date = v_p_date,
            purchase_cost = p_purchase_cost,
            current_value = p_current_value,
            quantity = p_quantity,
            location_area = p_location_area,
            condition_status = p_condition_status,
            warranty_expiry = v_w_date,
            notes = p_notes,
            updated_at = CURRENT_TIMESTAMP
        WHERE asset_id = v_id;

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'UPDATE', 'ASSETS', 'Asset updated: ' || p_asset_name, v_id::text, NULL, NULL, '127.0.0.1');
    ELSE
        v_id := gen_random_uuid();
        INSERT INTO tbl_assets (
            asset_id, asset_code, asset_name, category, model_number, serial_number, vendor_id, vendor_name,
            purchase_date, purchase_cost, current_value, quantity, location_area, condition_status, warranty_expiry, notes, created_at, updated_at
        ) VALUES (
            v_id, p_asset_code, p_asset_name, p_category, p_model_number, p_serial_number, v_vendor_uuid, p_vendor_name,
            v_p_date, p_purchase_cost, p_current_value, p_quantity, p_location_area, p_condition_status, v_w_date, p_notes, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'CREATE', 'ASSETS', 'Asset registered: ' || p_asset_name, v_id::text, NULL, NULL, '127.0.0.1');
    END IF;

    SELECT jsonb_build_object(
        'assetId', a.asset_id::text,
        'assetCode', a.asset_code,
        'assetName', a.asset_name,
        'category', a.category,
        'locationArea', a.location_area,
        'conditionStatus', a.condition_status,
        'purchaseCost', a.purchase_cost
    ) INTO v_result
    FROM tbl_assets a WHERE a.asset_id = v_id;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Asset saved successfully'::VARCHAR, v_id::VARCHAR, 1, 1, v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'ASSET_SAVE_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 14. ASSETS: GET ALL (PAGINATED & SEARCHABLE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_asset_get_all(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_search VARCHAR DEFAULT NULL,
    p_category VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_assets a
    WHERE (p_search IS NULL OR p_search = '' OR a.asset_name ILIKE '%' || p_search || '%' OR a.asset_code ILIKE '%' || p_search || '%' OR a.location_area ILIKE '%' || p_search || '%')
      AND (p_category IS NULL OR p_category = '' OR a.category = p_category)
      AND (p_status IS NULL OR p_status = '' OR a.condition_status = p_status);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'assetId', a.asset_id::text,
            'assetCode', a.asset_code,
            'assetName', a.asset_name,
            'category', a.category,
            'modelNumber', a.model_number,
            'serialNumber', a.serial_number,
            'vendorId', a.vendor_id::text,
            'vendorName', a.vendor_name,
            'purchaseDate', to_char(a.purchase_date, 'YYYY-MM-DD'),
            'purchaseCost', a.purchase_cost,
            'currentValue', a.current_value,
            'quantity', a.quantity,
            'locationArea', a.location_area,
            'assignedToName', a.assigned_to_name,
            'conditionStatus', a.condition_status,
            'warrantyExpiry', to_char(a.warranty_expiry, 'YYYY-MM-DD'),
            'notes', a.notes,
            'createdAt', to_char(a.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT *
        FROM tbl_assets a
        WHERE (p_search IS NULL OR p_search = '' OR a.asset_name ILIKE '%' || p_search || '%' OR a.asset_code ILIKE '%' || p_search || '%' OR a.location_area ILIKE '%' || p_search || '%')
          AND (p_category IS NULL OR p_category = '' OR a.category = p_category)
          AND (p_status IS NULL OR p_status = '' OR a.condition_status = p_status)
        ORDER BY a.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) a;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Assets retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_ASSETS_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 15. ASSETS: DELETE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_asset_delete(
    p_asset_id VARCHAR,
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
    v_id UUID := p_asset_id::uuid;
BEGIN
    DELETE FROM tbl_asset_maintenance WHERE asset_id = v_id;
    DELETE FROM tbl_assets WHERE asset_id = v_id;
    PERFORM fn_log_activity(p_actor_id, p_actor_name, 'DELETE', 'ASSETS', 'Deleted asset: ' || p_asset_id, p_asset_id, NULL, NULL, '127.0.0.1');
    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Asset deleted successfully'::VARCHAR, p_asset_id, 1, 1, NULL::JSONB;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'DEL_ASSET_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 16. PRODUCTS & RAW MATERIALS: SAVE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_product_save(
    p_product_id VARCHAR,
    p_product_code VARCHAR,
    p_product_name VARCHAR,
    p_product_type VARCHAR,
    p_category VARCHAR,
    p_gsm NUMERIC,
    p_ply INT,
    p_sheet_width_mm NUMERIC,
    p_roll_length_m NUMERIC,
    p_rolls_per_pack INT,
    p_uom VARCHAR,
    p_unit_cost NUMERIC,
    p_selling_price NUMERIC,
    p_tax_rate NUMERIC,
    p_reorder_level NUMERIC,
    p_description TEXT,
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
    v_id UUID;
    v_result JSONB;
BEGIN
    IF p_product_id IS NOT NULL AND p_product_id <> '' AND p_product_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_id := p_product_id::uuid;
        UPDATE tbl_products
        SET product_code = p_product_code,
            product_name = p_product_name,
            product_type = p_product_type,
            category = p_category,
            gsm = p_gsm,
            ply = p_ply,
            sheet_width_mm = p_sheet_width_mm,
            roll_length_m = p_roll_length_m,
            rolls_per_pack = p_rolls_per_pack,
            uom = p_uom,
            unit_cost = p_unit_cost,
            selling_price = p_selling_price,
            tax_rate = p_tax_rate,
            reorder_level = p_reorder_level,
            description = p_description,
            updated_at = CURRENT_TIMESTAMP
        WHERE product_id = v_id;

        -- update inventory item mirror
        UPDATE tbl_inventory
        SET product_name = p_product_name,
            product_code = p_product_code,
            product_type = p_product_type,
            uom = p_uom,
            minimum_stock_level = p_reorder_level,
            updated_at = CURRENT_TIMESTAMP
        WHERE product_id = v_id;

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'UPDATE', 'PRODUCTS', 'Product updated: ' || p_product_name, v_id::text, NULL, NULL, '127.0.0.1');
    ELSE
        v_id := gen_random_uuid();
        INSERT INTO tbl_products (
            product_id, product_code, product_name, product_type, category, gsm, ply, sheet_width_mm,
            roll_length_m, rolls_per_pack, uom, unit_cost, selling_price, tax_rate, reorder_level, description, is_active, created_at, updated_at
        ) VALUES (
            v_id, p_product_code, p_product_name, p_product_type, p_category, p_gsm, p_ply, p_sheet_width_mm,
            p_roll_length_m, p_rolls_per_pack, p_uom, p_unit_cost, p_selling_price, p_tax_rate, p_reorder_level, p_description, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );

        -- Initialize zero stock inventory record
        INSERT INTO tbl_inventory (
            inventory_id, product_id, product_code, product_name, product_type, warehouse_location, current_stock, reserved_stock, available_stock, uom, minimum_stock_level, maximum_stock_level, last_restocked_at, updated_at
        ) VALUES (
            gen_random_uuid(), v_id, p_product_code, p_product_name, p_product_type, 'MAIN_WAREHOUSE', 0.00, 0.00, 0.00, p_uom, p_reorder_level, 10000.00, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'CREATE', 'PRODUCTS', 'Product registered: ' || p_product_name, v_id::text, NULL, NULL, '127.0.0.1');
    END IF;

    SELECT jsonb_build_object(
        'productId', p.product_id::text,
        'productCode', p.product_code,
        'productName', p.product_name,
        'productType', p.product_type,
        'category', p.category,
        'gsm', p.gsm,
        'ply', p.ply,
        'uom', p.uom,
        'unitCost', p.unit_cost,
        'sellingPrice', p.selling_price
    ) INTO v_result
    FROM tbl_products p WHERE p.product_id = v_id;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Product saved successfully'::VARCHAR, v_id::VARCHAR, 1, 1, v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'PRODUCT_SAVE_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 17. PRODUCTS: GET ALL
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_product_get_all(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_search VARCHAR DEFAULT NULL,
    p_product_type VARCHAR DEFAULT NULL,
    p_category VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_products p
    WHERE (p_search IS NULL OR p_search = '' OR p.product_name ILIKE '%' || p_search || '%' OR p.product_code ILIKE '%' || p_search || '%')
      AND (p_product_type IS NULL OR p_product_type = '' OR p.product_type = p_product_type)
      AND (p_category IS NULL OR p_category = '' OR p.category = p_category);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'productId', p.product_id::text,
            'productCode', p.product_code,
            'productName', p.product_name,
            'productType', p.product_type,
            'category', p.category,
            'gsm', p.gsm,
            'ply', p.ply,
            'sheetWidthMm', p.sheet_width_mm,
            'rollLengthM', p.roll_length_m,
            'rollsPerPack', p.rolls_per_pack,
            'uom', p.uom,
            'unitCost', p.unit_cost,
            'sellingPrice', p.selling_price,
            'taxRate', p.tax_rate,
            'reorderLevel', p.reorder_level,
            'description', p.description,
            'currentStock', COALESCE(i.current_stock, 0.00),
            'availableStock', COALESCE(i.available_stock, 0.00),
            'createdAt', to_char(p.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT p.*
        FROM tbl_products p
        WHERE (p_search IS NULL OR p_search = '' OR p.product_name ILIKE '%' || p_search || '%' OR p.product_code ILIKE '%' || p_search || '%')
          AND (p_product_type IS NULL OR p_product_type = '' OR p.product_type = p_product_type)
          AND (p_category IS NULL OR p_category = '' OR p.category = p_category)
        ORDER BY p.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) p
    LEFT JOIN tbl_inventory i ON p.product_id = i.product_id;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Products retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_PRODUCTS_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 18. INVENTORY: GET ALL & ALERTS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_inventory_get_all(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_search VARCHAR DEFAULT NULL,
    p_product_type VARCHAR DEFAULT NULL,
    p_low_stock_only BOOLEAN DEFAULT FALSE
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_inventory i
    WHERE (p_search IS NULL OR p_search = '' OR i.product_name ILIKE '%' || p_search || '%' OR i.product_code ILIKE '%' || p_search || '%')
      AND (p_product_type IS NULL OR p_product_type = '' OR i.product_type = p_product_type)
      AND (NOT p_low_stock_only OR i.current_stock <= i.minimum_stock_level);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'inventoryId', i.inventory_id::text,
            'productId', i.product_id::text,
            'productCode', i.product_code,
            'productName', i.product_name,
            'productType', i.product_type,
            'warehouseLocation', i.warehouse_location,
            'currentStock', i.current_stock,
            'reservedStock', i.reserved_stock,
            'availableStock', i.available_stock,
            'uom', i.uom,
            'minimumStockLevel', i.minimum_stock_level,
            'maximumStockLevel', i.maximum_stock_level,
            'isLowStock', (i.current_stock <= i.minimum_stock_level),
            'lastRestockedAt', to_char(i.last_restocked_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT *
        FROM tbl_inventory i
        WHERE (p_search IS NULL OR p_search = '' OR i.product_name ILIKE '%' || p_search || '%' OR i.product_code ILIKE '%' || p_search || '%')
          AND (p_product_type IS NULL OR p_product_type = '' OR i.product_type = p_product_type)
          AND (NOT p_low_stock_only OR i.current_stock <= i.minimum_stock_level)
        ORDER BY i.current_stock ASC
        LIMIT p_page_size OFFSET v_offset
    ) i;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Inventory records retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_INV_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 19. INVENTORY: RECORD STOCK ADJUSTMENT / MOVEMENT
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_inventory_adjust_stock(
    p_product_id VARCHAR,
    p_movement_type VARCHAR, -- 'INWARD_PURCHASE', 'OUTWARD_SALE', 'PROD_CONSUMPTION', 'PROD_OUTPUT', 'ADJUSTMENT', 'WASTAGE'
    p_quantity NUMERIC,
    p_reference_type VARCHAR DEFAULT 'MANUAL_ADJUST',
    p_reference_id VARCHAR DEFAULT NULL,
    p_location VARCHAR DEFAULT 'MAIN_WAREHOUSE',
    p_notes TEXT DEFAULT NULL,
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
    v_pid UUID := p_product_id::uuid;
    v_inv RECORD;
    v_new_stock NUMERIC;
    v_mov_id UUID := gen_random_uuid();
BEGIN
    SELECT * INTO v_inv FROM tbl_inventory WHERE product_id = v_pid FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'INV_NOT_FOUND'::VARCHAR, 'Inventory record not found for product'::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
        RETURN;
    END IF;

    IF p_movement_type IN ('INWARD_PURCHASE', 'PROD_OUTPUT') THEN
        v_new_stock := v_inv.current_stock + p_quantity;
    ELSIF p_movement_type IN ('OUTWARD_SALE', 'PROD_CONSUMPTION', 'WASTAGE') THEN
        IF v_inv.current_stock < p_quantity THEN
            RETURN QUERY SELECT FALSE, 'INSUFFICIENT_STOCK'::VARCHAR, 'Insufficient stock available'::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
            RETURN;
        END IF;
        v_new_stock := v_inv.current_stock - p_quantity;
    ELSE -- ADJUSTMENT (override or signed)
        v_new_stock := GREATEST(0.00, p_quantity);
    END IF;

    UPDATE tbl_inventory
    SET current_stock = v_new_stock,
        available_stock = GREATEST(0.00, v_new_stock - reserved_stock),
        last_restocked_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE product_id = v_pid;

    INSERT INTO tbl_inventory_movements (
        movement_id, product_id, product_name, movement_type, quantity,
        previous_stock, new_stock, reference_type, reference_id, location, notes, created_by, created_at
    ) VALUES (
        v_mov_id, v_pid, v_inv.product_name, p_movement_type, p_quantity,
        v_inv.current_stock, v_new_stock, p_reference_type, p_reference_id, p_location, p_notes,
        CASE WHEN p_actor_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_actor_id::uuid ELSE NULL END,
        CURRENT_TIMESTAMP
    );

    PERFORM fn_log_activity(p_actor_id, p_actor_name, 'STOCK_ADJUST', 'INVENTORY',
        'Stock ' || p_movement_type || ' for ' || v_inv.product_name || ' qty: ' || p_quantity::text,
        v_mov_id::text, jsonb_build_object('oldStock', v_inv.current_stock), jsonb_build_object('newStock', v_new_stock), '127.0.0.1');

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Stock adjusted successfully'::VARCHAR, v_mov_id::VARCHAR, 1, 1,
        jsonb_build_object(
            'productId', v_pid::text,
            'previousStock', v_inv.current_stock,
            'newStock', v_new_stock,
            'movementId', v_mov_id::text
        );
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'STOCK_ADJ_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 20. INVENTORY MOVEMENTS: GET HISTORY
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_inventory_get_movements(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_product_id VARCHAR DEFAULT NULL,
    p_movement_type VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
    v_pid UUID := NULL;
BEGIN
    IF p_product_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_pid := p_product_id::uuid;
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM tbl_inventory_movements m
    WHERE (v_pid IS NULL OR m.product_id = v_pid)
      AND (p_movement_type IS NULL OR p_movement_type = '' OR m.movement_type = p_movement_type);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'movementId', m.movement_id::text,
            'productId', m.product_id::text,
            'productName', m.product_name,
            'movementType', m.movement_type,
            'quantity', m.quantity,
            'previousStock', m.previous_stock,
            'newStock', m.new_stock,
            'referenceType', m.reference_type,
            'referenceId', m.reference_id,
            'location', m.location,
            'notes', m.notes,
            'createdAt', to_char(m.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT *
        FROM tbl_inventory_movements m
        WHERE (v_pid IS NULL OR m.product_id = v_pid)
          AND (p_movement_type IS NULL OR p_movement_type = '' OR m.movement_type = p_movement_type)
        ORDER BY m.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) m;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Inventory movements retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_MOVEMENTS_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 21. PRODUCTION: SAVE PRODUCTION PLAN
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_production_plan_save(
    p_plan_id VARCHAR,
    p_plan_code VARCHAR,
    p_plan_name VARCHAR,
    p_start_date VARCHAR,
    p_end_date VARCHAR,
    p_target_quantity NUMERIC,
    p_status VARCHAR DEFAULT 'PLANNED',
    p_notes TEXT DEFAULT NULL,
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
    v_id UUID;
    v_s_date DATE := p_start_date::DATE;
    v_e_date DATE := p_end_date::DATE;
    v_result JSONB;
BEGIN
    IF p_plan_id IS NOT NULL AND p_plan_id <> '' AND p_plan_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_id := p_plan_id::uuid;
        UPDATE tbl_production_plans
        SET plan_code = p_plan_code,
            plan_name = p_plan_name,
            start_date = v_s_date,
            end_date = v_e_date,
            target_quantity = p_target_quantity,
            status = p_status,
            notes = p_notes,
            updated_at = CURRENT_TIMESTAMP
        WHERE plan_id = v_id;

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'UPDATE', 'PRODUCTION_PLAN', 'Plan updated: ' || p_plan_name, v_id::text, NULL, NULL, '127.0.0.1');
    ELSE
        v_id := gen_random_uuid();
        INSERT INTO tbl_production_plans (
            plan_id, plan_code, plan_name, start_date, end_date, target_quantity, status, notes,
            created_by, created_at, updated_at
        ) VALUES (
            v_id, p_plan_code, p_plan_name, v_s_date, v_e_date, p_target_quantity, p_status, p_notes,
            CASE WHEN p_actor_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_actor_id::uuid ELSE NULL END,
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'CREATE', 'PRODUCTION_PLAN', 'Plan created: ' || p_plan_name, v_id::text, NULL, NULL, '127.0.0.1');
    END IF;

    SELECT jsonb_build_object(
        'planId', p.plan_id::text,
        'planCode', p.plan_code,
        'planName', p.plan_name,
        'startDate', to_char(p.start_date, 'YYYY-MM-DD'),
        'endDate', to_char(p.end_date, 'YYYY-MM-DD'),
        'targetQuantity', p.target_quantity,
        'status', p.status
    ) INTO v_result
    FROM tbl_production_plans p WHERE p.plan_id = v_id;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Production plan saved'::VARCHAR, v_id::VARCHAR, 1, 1, v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'PLAN_SAVE_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 22. PRODUCTION: GET ALL PLANS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_production_plan_get_all(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_search VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_production_plans p
    WHERE (p_search IS NULL OR p_search = '' OR p.plan_name ILIKE '%' || p_search || '%' OR p.plan_code ILIKE '%' || p_search || '%')
      AND (p_status IS NULL OR p_status = '' OR p.status = p_status);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'planId', p.plan_id::text,
            'planCode', p.plan_code,
            'planName', p.plan_name,
            'startDate', to_char(p.start_date, 'YYYY-MM-DD'),
            'endDate', to_char(p.end_date, 'YYYY-MM-DD'),
            'targetQuantity', p.target_quantity,
            'status', p.status,
            'notes', p.notes,
            'createdAt', to_char(p.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT *
        FROM tbl_production_plans p
        WHERE (p_search IS NULL OR p_search = '' OR p.plan_name ILIKE '%' || p_search || '%' OR p.plan_code ILIKE '%' || p_search || '%')
          AND (p_status IS NULL OR p_status = '' OR p.status = p_status)
        ORDER BY p.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) p;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Production plans retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_PLANS_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 23. PRODUCTION BATCHES: SAVE (CREATE / UPDATE BATCH & MANAGE OUTPUT & WASTAGE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_production_batch_save(
    p_batch_id VARCHAR,
    p_batch_code VARCHAR,
    p_plan_id VARCHAR,
    p_product_id VARCHAR,
    p_product_name VARCHAR,
    p_machine_asset_id VARCHAR,
    p_machine_name VARCHAR,
    p_planned_quantity NUMERIC,
    p_produced_quantity NUMERIC DEFAULT 0.00,
    p_rejected_quantity NUMERIC DEFAULT 0.00,
    p_wastage_kg NUMERIC DEFAULT 0.00,
    p_batch_status VARCHAR DEFAULT 'PENDING',
    p_supervisor_name VARCHAR DEFAULT NULL,
    p_shift VARCHAR DEFAULT 'DAY',
    p_remarks TEXT DEFAULT NULL,
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
    v_id UUID;
    v_plan_uuid UUID := NULL;
    v_prod_uuid UUID := p_product_id::uuid;
    v_mach_uuid UUID := NULL;
    v_prev_produced NUMERIC := 0.00;
    v_diff_produced NUMERIC := 0.00;
    v_result JSONB;
BEGIN
    IF p_plan_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_plan_uuid := p_plan_id::uuid;
    END IF;

    IF p_machine_asset_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_mach_uuid := p_machine_asset_id::uuid;
    END IF;

    IF p_batch_id IS NOT NULL AND p_batch_id <> '' AND p_batch_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_id := p_batch_id::uuid;

        SELECT produced_quantity INTO v_prev_produced FROM tbl_production_batches WHERE batch_id = v_id;

        UPDATE tbl_production_batches
        SET batch_code = p_batch_code,
            plan_id = v_plan_uuid,
            product_id = v_prod_uuid,
            product_name = p_product_name,
            machine_asset_id = v_mach_uuid,
            machine_name = p_machine_name,
            planned_quantity = p_planned_quantity,
            produced_quantity = p_produced_quantity,
            rejected_quantity = p_rejected_quantity,
            wastage_kg = p_wastage_kg,
            batch_status = p_batch_status,
            supervisor_name = p_supervisor_name,
            shift = p_shift,
            remarks = p_remarks,
            end_time = CASE WHEN p_batch_status = 'COMPLETED' THEN CURRENT_TIMESTAMP ELSE end_time END,
            updated_at = CURRENT_TIMESTAMP
        WHERE batch_id = v_id;

        -- If batch completed and produced new quantities, automatically update finished goods inventory
        IF p_produced_quantity > v_prev_produced THEN
            v_diff_produced := p_produced_quantity - v_prev_produced;
            PERFORM fn_inventory_adjust_stock(
                p_product_id, 'PROD_OUTPUT', v_diff_produced, 'BATCH', p_batch_code, 'MAIN_WAREHOUSE', 'Produced from batch ' || p_batch_code, p_actor_id, p_actor_name
            );
        END IF;

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'UPDATE', 'PRODUCTION_BATCH', 'Batch updated: ' || p_batch_code, v_id::text, NULL, NULL, '127.0.0.1');
    ELSE
        v_id := gen_random_uuid();
        INSERT INTO tbl_production_batches (
            batch_id, batch_code, plan_id, product_id, product_name, machine_asset_id, machine_name,
            planned_quantity, produced_quantity, rejected_quantity, wastage_kg, start_time, batch_status,
            supervisor_name, shift, remarks, created_at, updated_at
        ) VALUES (
            v_id, p_batch_code, v_plan_uuid, v_prod_uuid, p_product_name, v_mach_uuid, p_machine_name,
            p_planned_quantity, p_produced_quantity, p_rejected_quantity, p_wastage_kg, CURRENT_TIMESTAMP, p_batch_status,
            p_supervisor_name, p_shift, p_remarks, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );

        IF p_produced_quantity > 0 THEN
            PERFORM fn_inventory_adjust_stock(
                p_product_id, 'PROD_OUTPUT', p_produced_quantity, 'BATCH', p_batch_code, 'MAIN_WAREHOUSE', 'Initial output batch ' || p_batch_code, p_actor_id, p_actor_name
            );
        END IF;

        PERFORM fn_log_activity(p_actor_id, p_actor_name, 'CREATE', 'PRODUCTION_BATCH', 'Batch created: ' || p_batch_code, v_id::text, NULL, NULL, '127.0.0.1');
    END IF;

    SELECT jsonb_build_object(
        'batchId', b.batch_id::text,
        'batchCode', b.batch_code,
        'productName', b.product_name,
        'machineName', b.machine_name,
        'plannedQuantity', b.planned_quantity,
        'producedQuantity', b.produced_quantity,
        'rejectedQuantity', b.rejected_quantity,
        'wastageKg', b.wastage_kg,
        'batchStatus', b.batch_status
    ) INTO v_result
    FROM tbl_production_batches b WHERE b.batch_id = v_id;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Production batch saved successfully'::VARCHAR, v_id::VARCHAR, 1, 1, v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'BATCH_SAVE_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 24. PRODUCTION BATCHES: GET ALL
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_production_batch_get_all(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_search VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_production_batches b
    WHERE (p_search IS NULL OR p_search = '' OR b.batch_code ILIKE '%' || p_search || '%' OR b.product_name ILIKE '%' || p_search || '%' OR b.machine_name ILIKE '%' || p_search || '%')
      AND (p_status IS NULL OR p_status = '' OR b.batch_status = p_status);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'batchId', b.batch_id::text,
            'batchCode', b.batch_code,
            'planId', b.plan_id::text,
            'productId', b.product_id::text,
            'productName', b.product_name,
            'machineAssetId', b.machine_asset_id::text,
            'machineName', b.machine_name,
            'plannedQuantity', b.planned_quantity,
            'producedQuantity', b.produced_quantity,
            'rejectedQuantity', b.rejected_quantity,
            'wastageKg', b.wastage_kg,
            'batchStatus', b.batch_status,
            'supervisorName', b.supervisor_name,
            'shift', b.shift,
            'remarks', b.remarks,
            'startTime', to_char(b.start_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
            'endTime', to_char(b.end_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
            'createdAt', to_char(b.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT *
        FROM tbl_production_batches b
        WHERE (p_search IS NULL OR p_search = '' OR b.batch_code ILIKE '%' || p_search || '%' OR b.product_name ILIKE '%' || p_search || '%' OR b.machine_name ILIKE '%' || p_search || '%')
          AND (p_status IS NULL OR p_status = '' OR b.batch_status = p_status)
        ORDER BY b.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) b;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Production batches retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_BATCHES_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 25. PURCHASE ORDERS: SAVE (HEADER & ITEMS)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_purchase_order_save(
    p_po_id VARCHAR,
    p_po_number VARCHAR,
    p_vendor_id VARCHAR,
    p_vendor_name VARCHAR,
    p_order_date VARCHAR,
    p_expected_delivery_date VARCHAR,
    p_subtotal NUMERIC,
    p_tax_amount NUMERIC,
    p_total_amount NUMERIC,
    p_paid_amount NUMERIC,
    p_payment_status VARCHAR,
    p_order_status VARCHAR,
    p_items JSONB,
    p_notes TEXT DEFAULT NULL,
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
    v_id UUID;
    v_vendor_uuid UUID := p_vendor_id::uuid;
    v_item RECORD;
BEGIN
    IF p_po_id IS NOT NULL AND p_po_id <> '' AND p_po_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_id := p_po_id::uuid;
        UPDATE tbl_purchase_orders
        SET po_number = p_po_number,
            vendor_id = v_vendor_uuid,
            vendor_name = p_vendor_name,
            order_date = p_order_date::DATE,
            expected_delivery_date = CASE WHEN p_expected_delivery_date IS NOT NULL AND p_expected_delivery_date <> '' THEN p_expected_delivery_date::DATE ELSE NULL END,
            subtotal = p_subtotal,
            tax_amount = p_tax_amount,
            total_amount = p_total_amount,
            paid_amount = p_paid_amount,
            payment_status = p_payment_status,
            order_status = p_order_status,
            notes = p_notes,
            updated_at = CURRENT_TIMESTAMP
        WHERE po_id = v_id;

        DELETE FROM tbl_purchase_order_items WHERE po_id = v_id;
    ELSE
        v_id := gen_random_uuid();
        INSERT INTO tbl_purchase_orders (
            po_id, po_number, vendor_id, vendor_name, order_date, expected_delivery_date,
            subtotal, tax_amount, total_amount, paid_amount, payment_status, order_status, notes,
            created_by, created_at, updated_at
        ) VALUES (
            v_id, p_po_number, v_vendor_uuid, p_vendor_name, p_order_date::DATE,
            CASE WHEN p_expected_delivery_date IS NOT NULL AND p_expected_delivery_date <> '' THEN p_expected_delivery_date::DATE ELSE NULL END,
            p_subtotal, p_tax_amount, p_total_amount, p_paid_amount, p_payment_status, p_order_status, p_notes,
            CASE WHEN p_actor_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_actor_id::uuid ELSE NULL END,
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );
    END IF;

    -- Insert items
    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
            "productId" TEXT, "productName" TEXT, "quantity" NUMERIC, "unitPrice" NUMERIC, "taxRate" NUMERIC, "taxAmount" NUMERIC, "totalAmount" NUMERIC
        )
        LOOP
            INSERT INTO tbl_purchase_order_items (
                po_item_id, po_id, product_id, product_name, quantity, unit_price, tax_rate, tax_amount, total_amount, created_at
            ) VALUES (
                gen_random_uuid(), v_id, v_item."productId"::uuid, v_item."productName", v_item."quantity", v_item."unitPrice",
                COALESCE(v_item."taxRate", 18.00), COALESCE(v_item."taxAmount", 0.00), v_item."totalAmount", CURRENT_TIMESTAMP
            );

            -- If PO status is marked RECEIVED, automatically increase inventory
            IF p_order_status = 'RECEIVED' THEN
                PERFORM fn_inventory_adjust_stock(
                    v_item."productId", 'INWARD_PURCHASE', v_item."quantity", 'PURCHASE_ORDER', p_po_number, 'MAIN_WAREHOUSE', 'Received from PO ' || p_po_number, p_actor_id, p_actor_name
                );
            END IF;
        END LOOP;
    END IF;

    PERFORM fn_log_activity(p_actor_id, p_actor_name, 'SAVE_PO', 'PROCUREMENT', 'Saved Purchase Order ' || p_po_number, v_id::text, NULL, NULL, '127.0.0.1');

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Purchase order saved successfully'::VARCHAR, v_id::VARCHAR, 1, 1, jsonb_build_object('poId', v_id::text, 'poNumber', p_po_number);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'PO_SAVE_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 26. PURCHASE ORDERS: GET ALL
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_purchase_order_get_all(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_search VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_purchase_orders po
    WHERE (p_search IS NULL OR p_search = '' OR po.po_number ILIKE '%' || p_search || '%' OR po.vendor_name ILIKE '%' || p_search || '%')
      AND (p_status IS NULL OR p_status = '' OR po.order_status = p_status);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'poId', po.po_id::text,
            'poNumber', po.po_number,
            'vendorId', po.vendor_id::text,
            'vendorName', po.vendor_name,
            'orderDate', to_char(po.order_date, 'YYYY-MM-DD'),
            'expectedDeliveryDate', to_char(po.expected_delivery_date, 'YYYY-MM-DD'),
            'subtotal', po.subtotal,
            'taxAmount', po.tax_amount,
            'totalAmount', po.total_amount,
            'paidAmount', po.paid_amount,
            'paymentStatus', po.payment_status,
            'orderStatus', po.order_status,
            'notes', po.notes,
            'createdAt', to_char(po.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT *
        FROM tbl_purchase_orders po
        WHERE (p_search IS NULL OR p_search = '' OR po.po_number ILIKE '%' || p_search || '%' OR po.vendor_name ILIKE '%' || p_search || '%')
          AND (p_status IS NULL OR p_status = '' OR po.order_status = p_status)
        ORDER BY po.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) po;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Purchase orders retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_PO_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 27. SALES ORDERS: SAVE (HEADER & ITEMS)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sales_order_save(
    p_so_id VARCHAR,
    p_so_number VARCHAR,
    p_customer_id VARCHAR,
    p_customer_name VARCHAR,
    p_order_date VARCHAR,
    p_delivery_date VARCHAR,
    p_subtotal NUMERIC,
    p_discount_amount NUMERIC,
    p_tax_amount NUMERIC,
    p_total_amount NUMERIC,
    p_paid_amount NUMERIC,
    p_payment_status VARCHAR,
    p_order_status VARCHAR,
    p_shipping_address TEXT,
    p_items JSONB,
    p_notes TEXT DEFAULT NULL,
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
    v_id UUID;
    v_cust_uuid UUID := p_customer_id::uuid;
    v_item RECORD;
BEGIN
    IF p_so_id IS NOT NULL AND p_so_id <> '' AND p_so_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_id := p_so_id::uuid;
        UPDATE tbl_sales_orders
        SET so_number = p_so_number,
            customer_id = v_cust_uuid,
            customer_name = p_customer_name,
            order_date = p_order_date::DATE,
            delivery_date = CASE WHEN p_delivery_date IS NOT NULL AND p_delivery_date <> '' THEN p_delivery_date::DATE ELSE NULL END,
            subtotal = p_subtotal,
            discount_amount = p_discount_amount,
            tax_amount = p_tax_amount,
            total_amount = p_total_amount,
            paid_amount = p_paid_amount,
            payment_status = p_payment_status,
            order_status = p_order_status,
            shipping_address = p_shipping_address,
            notes = p_notes,
            updated_at = CURRENT_TIMESTAMP
        WHERE so_id = v_id;

        DELETE FROM tbl_sales_order_items WHERE so_id = v_id;
    ELSE
        v_id := gen_random_uuid();
        INSERT INTO tbl_sales_orders (
            so_id, so_number, customer_id, customer_name, order_date, delivery_date,
            subtotal, discount_amount, tax_amount, total_amount, paid_amount, payment_status,
            order_status, shipping_address, notes, created_by, created_at, updated_at
        ) VALUES (
            v_id, p_so_number, v_cust_uuid, p_customer_name, p_order_date::DATE,
            CASE WHEN p_delivery_date IS NOT NULL AND p_delivery_date <> '' THEN p_delivery_date::DATE ELSE NULL END,
            p_subtotal, p_discount_amount, p_tax_amount, p_total_amount, p_paid_amount, p_payment_status,
            p_order_status, p_shipping_address, p_notes,
            CASE WHEN p_actor_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_actor_id::uuid ELSE NULL END,
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );
    END IF;

    -- Insert items
    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
            "productId" TEXT, "productName" TEXT, "quantity" NUMERIC, "unitPrice" NUMERIC, "taxRate" NUMERIC, "taxAmount" NUMERIC, "totalAmount" NUMERIC
        )
        LOOP
            INSERT INTO tbl_sales_order_items (
                so_item_id, so_id, product_id, product_name, quantity, unit_price, tax_rate, tax_amount, total_amount, created_at
            ) VALUES (
                gen_random_uuid(), v_id, v_item."productId"::uuid, v_item."productName", v_item."quantity", v_item."unitPrice",
                COALESCE(v_item."taxRate", 18.00), COALESCE(v_item."taxAmount", 0.00), v_item."totalAmount", CURRENT_TIMESTAMP
            );

            -- If Sales Order status is DISPATCHED or DELIVERED, automatically deduct from inventory
            IF p_order_status IN ('DISPATCHED', 'DELIVERED') THEN
                PERFORM fn_inventory_adjust_stock(
                    v_item."productId", 'OUTWARD_SALE', v_item."quantity", 'SALES_ORDER', p_so_number, 'MAIN_WAREHOUSE', 'Dispatched for SO ' || p_so_number, p_actor_id, p_actor_name
                );
            END IF;
        END LOOP;
    END IF;

    PERFORM fn_log_activity(p_actor_id, p_actor_name, 'SAVE_SO', 'SALES', 'Saved Sales Order ' || p_so_number, v_id::text, NULL, NULL, '127.0.0.1');

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Sales order saved successfully'::VARCHAR, v_id::VARCHAR, 1, 1, jsonb_build_object('soId', v_id::text, 'soNumber', p_so_number);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'SO_SAVE_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 28. SALES ORDERS: GET ALL
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sales_order_get_all(
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50,
    p_search VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
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
    v_offset INT := (GREATEST(p_page_number, 1) - 1) * GREATEST(p_page_size, 1);
    v_total INT := 0;
    v_pages INT := 0;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM tbl_sales_orders so
    WHERE (p_search IS NULL OR p_search = '' OR so.so_number ILIKE '%' || p_search || '%' OR so.customer_name ILIKE '%' || p_search || '%')
      AND (p_status IS NULL OR p_status = '' OR so.order_status = p_status);

    v_pages := CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))::INT;

    SELECT jsonb_agg(
        jsonb_build_object(
            'soId', so.so_id::text,
            'soNumber', so.so_number,
            'customerId', so.customer_id::text,
            'customerName', so.customer_name,
            'orderDate', to_char(so.order_date, 'YYYY-MM-DD'),
            'deliveryDate', to_char(so.delivery_date, 'YYYY-MM-DD'),
            'subtotal', so.subtotal,
            'discountAmount', so.discount_amount,
            'taxAmount', so.tax_amount,
            'totalAmount', so.total_amount,
            'paidAmount', so.paid_amount,
            'paymentStatus', so.payment_status,
            'orderStatus', so.order_status,
            'shippingAddress', so.shipping_address,
            'notes', so.notes,
            'createdAt', to_char(so.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT *
        FROM tbl_sales_orders so
        WHERE (p_search IS NULL OR p_search = '' OR so.so_number ILIKE '%' || p_search || '%' OR so.customer_name ILIKE '%' || p_search || '%')
          AND (p_status IS NULL OR p_status = '' OR so.order_status = p_status)
        ORDER BY so.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) so;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Sales orders retrieved'::VARCHAR, NULL::VARCHAR, v_total, v_pages, COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'GET_SO_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 29. SYSTEM SETTINGS: GET & SAVE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_system_settings_get_all()
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
    v_result JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'settingId', s.setting_id::text,
            'settingKey', s.setting_key,
            'settingValue', s.setting_value,
            'category', s.category,
            'description', s.description,
            'updatedAt', to_char(s.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_result
    FROM (
        SELECT * FROM tbl_system_settings ORDER BY category, setting_key
    ) s;

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Settings retrieved'::VARCHAR, NULL::VARCHAR, jsonb_array_length(COALESCE(v_result, '[]'::jsonb)), 1, COALESCE(v_result, '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION fn_system_setting_save(
    p_setting_key VARCHAR,
    p_setting_value TEXT,
    p_category VARCHAR DEFAULT 'GENERAL',
    p_description TEXT DEFAULT NULL,
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
    v_id UUID;
BEGIN
    SELECT setting_id INTO v_id FROM tbl_system_settings WHERE setting_key = p_setting_key;

    IF FOUND THEN
        UPDATE tbl_system_settings
        SET setting_value = p_setting_value,
            category = p_category,
            description = COALESCE(p_description, description),
            updated_at = CURRENT_TIMESTAMP
        WHERE setting_id = v_id;
    ELSE
        v_id := gen_random_uuid();
        INSERT INTO tbl_system_settings (setting_id, setting_key, setting_value, category, description, updated_at)
        VALUES (v_id, p_setting_key, p_setting_value, p_category, p_description, CURRENT_TIMESTAMP);
    END IF;

    PERFORM fn_log_activity(p_actor_id, p_actor_name, 'UPDATE_SETTING', 'SETTINGS', 'Updated setting: ' || p_setting_key, v_id::text, NULL, NULL, '127.0.0.1');

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Setting saved successfully'::VARCHAR, v_id::VARCHAR, 1, 1, jsonb_build_object('settingKey', p_setting_key, 'settingValue', p_setting_value);
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'SETTING_SAVE_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;

-- -----------------------------------------------------------------------------
-- 30. COMPREHENSIVE DASHBOARD METRICS: fn_get_dashboard_metrics
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_get_dashboard_metrics()
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
    v_total_prod NUMERIC := 0.00;
    v_today_prod NUMERIC := 0.00;
    v_monthly_prod NUMERIC := 0.00;
    v_total_wastage NUMERIC := 0.00;
    v_active_batches INT := 0;
    v_total_assets INT := 0;
    v_operational_assets INT := 0;
    v_total_vendors INT := 0;
    v_total_customers INT := 0;
    v_total_products INT := 0;
    v_low_stock_count INT := 0;
    v_sales_revenue NUMERIC := 0.00;
    v_pending_so INT := 0;
    v_pending_po INT := 0;
    v_recent_batches JSONB;
    v_recent_sales JSONB;
    v_production_trend JSONB;
    v_result JSONB;
BEGIN
    -- Production statistics
    SELECT COALESCE(SUM(produced_quantity), 0.00), COALESCE(SUM(wastage_kg), 0.00)
    INTO v_total_prod, v_total_wastage
    FROM tbl_production_batches;

    SELECT COALESCE(SUM(produced_quantity), 0.00) INTO v_today_prod
    FROM tbl_production_batches
    WHERE created_at::DATE = CURRENT_DATE;

    SELECT COALESCE(SUM(produced_quantity), 0.00) INTO v_monthly_prod
    FROM tbl_production_batches
    WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE);

    SELECT COUNT(*) INTO v_active_batches
    FROM tbl_production_batches WHERE batch_status IN ('RUNNING', 'PENDING');

    -- Assets
    SELECT COUNT(*), COUNT(*) FILTER (WHERE condition_status = 'OPERATIONAL')
    INTO v_total_assets, v_operational_assets
    FROM tbl_assets;

    -- Vendors & Customers
    SELECT COUNT(*) INTO v_total_vendors FROM tbl_vendors WHERE vendor_status = 'ACTIVE';
    SELECT COUNT(*) INTO v_total_customers FROM tbl_customers WHERE customer_status = 'ACTIVE';

    -- Inventory
    SELECT COUNT(*) INTO v_total_products FROM tbl_products WHERE is_active = TRUE;
    SELECT COUNT(*) INTO v_low_stock_count FROM tbl_inventory WHERE current_stock <= minimum_stock_level;

    -- Sales & Orders
    SELECT COALESCE(SUM(total_amount), 0.00), COUNT(*) FILTER (WHERE order_status = 'CONFIRMED')
    INTO v_sales_revenue, v_pending_so
    FROM tbl_sales_orders;

    SELECT COUNT(*) INTO v_pending_po
    FROM tbl_purchase_orders WHERE order_status = 'PENDING';

    -- Recent batches
    SELECT jsonb_agg(
        jsonb_build_object(
            'batchId', b.batch_id::text,
            'batchCode', b.batch_code,
            'productName', b.product_name,
            'machineName', b.machine_name,
            'producedQuantity', b.produced_quantity,
            'batchStatus', b.batch_status,
            'createdAt', to_char(b.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )
    ) INTO v_recent_batches
    FROM (
        SELECT * FROM tbl_production_batches ORDER BY created_at DESC LIMIT 5
    ) b;

    -- Recent sales orders
    SELECT jsonb_agg(
        jsonb_build_object(
            'soId', s.so_id::text,
            'soNumber', s.so_number,
            'customerName', s.customer_name,
            'totalAmount', s.total_amount,
            'orderStatus', s.order_status,
            'orderDate', to_char(s.order_date, 'YYYY-MM-DD')
        )
    ) INTO v_recent_sales
    FROM (
        SELECT * FROM tbl_sales_orders ORDER BY created_at DESC LIMIT 5
    ) s;

    -- Weekly Production Trend (Last 7 days)
    WITH daily_summary AS (
        SELECT 
            d::DATE as stat_date,
            to_char(d, 'Dy') as day_label,
            COALESCE(SUM(b.produced_quantity), 0.00) as prod_qty,
            COALESCE(SUM(b.wastage_kg), 0.00) as waste_qty
        FROM generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, '1 day'::interval) d
        LEFT JOIN tbl_production_batches b ON b.created_at::DATE = d::DATE
        GROUP BY d::DATE, to_char(d, 'Dy')
        ORDER BY d::DATE ASC
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'day', day_label,
            'date', to_char(stat_date, 'YYYY-MM-DD'),
            'produced', prod_qty,
            'wastage', waste_qty
        )
    ) INTO v_production_trend
    FROM daily_summary;

    v_result := jsonb_build_object(
        'totalProduction', v_total_prod,
        'todayProduction', v_today_prod,
        'monthlyProduction', v_monthly_prod,
        'totalWastageKg', v_total_wastage,
        'activeBatches', v_active_batches,
        'totalAssets', v_total_assets,
        'operationalAssets', v_operational_assets,
        'totalVendors', v_total_vendors,
        'totalCustomers', v_total_customers,
        'totalProducts', v_total_products,
        'lowStockCount', v_low_stock_count,
        'salesRevenue', v_sales_revenue,
        'pendingSalesOrders', v_pending_so,
        'pendingPurchaseOrders', v_pending_po,
        'recentBatches', COALESCE(v_recent_batches, '[]'::jsonb),
        'recentSalesOrders', COALESCE(v_recent_sales, '[]'::jsonb),
        'productionTrend', COALESCE(v_production_trend, '[]'::jsonb)
    );

    RETURN QUERY SELECT TRUE, 'SUCCESS'::VARCHAR, 'Dashboard metrics loaded'::VARCHAR, NULL::VARCHAR, 1, 1, v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'DASHBOARD_ERR'::VARCHAR, SQLERRM::VARCHAR, NULL::VARCHAR, 0, 0, NULL::JSONB;
END;
$$;
