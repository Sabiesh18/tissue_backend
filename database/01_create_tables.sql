-- =============================================================================
-- TISSUE MANUFACTURING MANAGEMENT SYSTEM
-- Master Database Schema (tbl_* with UUID Primary Keys)
-- Target Database: tissues
-- Server: local-dev (PostgreSQL)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Drop existing tables in reverse order of dependencies (if needed)
DROP TABLE IF EXISTS tbl_activity_logs CASCADE;
DROP TABLE IF EXISTS tbl_system_settings CASCADE;
DROP TABLE IF EXISTS tbl_inventory_movements CASCADE;
DROP TABLE IF EXISTS tbl_inventory CASCADE;
DROP TABLE IF EXISTS tbl_production_batches CASCADE;
DROP TABLE IF EXISTS tbl_production_plans CASCADE;
DROP TABLE IF EXISTS tbl_bom_items CASCADE;
DROP TABLE IF EXISTS tbl_bom CASCADE;
DROP TABLE IF EXISTS tbl_products CASCADE;
DROP TABLE IF EXISTS tbl_sales_order_items CASCADE;
DROP TABLE IF EXISTS tbl_sales_orders CASCADE;
DROP TABLE IF EXISTS tbl_purchase_order_items CASCADE;
DROP TABLE IF EXISTS tbl_purchase_orders CASCADE;
DROP TABLE IF EXISTS tbl_asset_maintenance CASCADE;
DROP TABLE IF EXISTS tbl_assets CASCADE;
DROP TABLE IF EXISTS tbl_customers CASCADE;
DROP TABLE IF EXISTS tbl_vendors CASCADE;
DROP TABLE IF EXISTS tbl_role_permissions CASCADE;
DROP TABLE IF EXISTS tbl_permissions CASCADE;
DROP TABLE IF EXISTS tbl_roles CASCADE;
DROP TABLE IF EXISTS tbl_user_auth CASCADE;
DROP TABLE IF EXISTS tbl_users CASCADE;

-- 1. tbl_users: User profiles
CREATE TABLE tbl_users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150),
    phone VARCHAR(50),
    role_id UUID,
    role_name VARCHAR(50) DEFAULT 'OPERATOR',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. tbl_user_auth: User credentials and auth history
CREATE TABLE tbl_user_auth (
    auth_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    last_login TIMESTAMP WITHOUT TIME ZONE,
    failed_attempts INT DEFAULT 0,
    is_locked BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. tbl_roles: System roles
CREATE TABLE tbl_roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name VARCHAR(100) NOT NULL,
    role_code VARCHAR(50) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. tbl_permissions: Available system permissions
CREATE TABLE tbl_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    permission_code VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. tbl_role_permissions: Mapping of roles to permissions
CREATE TABLE tbl_role_permissions (
    role_permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL,
    permission_id UUID NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. tbl_vendors: Raw material, machinery, and service suppliers
CREATE TABLE tbl_vendors (
    vendor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_code VARCHAR(50) NOT NULL,
    vendor_name VARCHAR(200) NOT NULL,
    company_name VARCHAR(200),
    contact_person VARCHAR(150),
    email VARCHAR(150),
    phone VARCHAR(50),
    alternate_phone VARCHAR(50),
    tax_number VARCHAR(100),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'India',
    vendor_status VARCHAR(50) DEFAULT 'ACTIVE',
    credit_period_days INT DEFAULT 30,
    outstanding_balance NUMERIC(14, 2) DEFAULT 0.00,
    rating NUMERIC(3, 2) DEFAULT 5.00,
    notes TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. tbl_customers: Wholesale, distributors, and retail clients
CREATE TABLE tbl_customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_code VARCHAR(50) NOT NULL,
    customer_name VARCHAR(200) NOT NULL,
    company_name VARCHAR(200),
    contact_person VARCHAR(150),
    email VARCHAR(150),
    phone VARCHAR(50),
    alternate_phone VARCHAR(50),
    tax_number VARCHAR(100),
    billing_address TEXT,
    shipping_address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'India',
    customer_status VARCHAR(50) DEFAULT 'ACTIVE',
    credit_limit NUMERIC(14, 2) DEFAULT 0.00,
    outstanding_balance NUMERIC(14, 2) DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. tbl_assets: Plant machinery, vehicles, rewinding and embossing units, packing machines
CREATE TABLE tbl_assets (
    asset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_code VARCHAR(50) NOT NULL,
    asset_name VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL, -- 'MACHINERY', 'VEHICLE', 'TOOLS', 'ELECTRICAL', 'OFFICE'
    model_number VARCHAR(100),
    serial_number VARCHAR(100),
    vendor_id UUID,
    vendor_name VARCHAR(200),
    purchase_date DATE,
    purchase_cost NUMERIC(14, 2) DEFAULT 0.00,
    current_value NUMERIC(14, 2) DEFAULT 0.00,
    quantity INT DEFAULT 1,
    location_area VARCHAR(150), -- e.g., 'Plant Floor A', 'Embossing Line 1', 'Warehouse'
    assigned_to UUID,
    assigned_to_name VARCHAR(150),
    condition_status VARCHAR(50) DEFAULT 'OPERATIONAL', -- 'OPERATIONAL', 'MAINTENANCE', 'IDLE', 'SCRAPPED'
    warranty_expiry DATE,
    notes TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 9. tbl_asset_maintenance: Asset repair and preventive maintenance logs
CREATE TABLE tbl_asset_maintenance (
    maintenance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL,
    maintenance_type VARCHAR(100) DEFAULT 'PREVENTIVE', -- 'PREVENTIVE', 'BREAKDOWN', 'CALIBRATION'
    service_date DATE NOT NULL,
    service_provider VARCHAR(200),
    cost NUMERIC(12, 2) DEFAULT 0.00,
    performed_by VARCHAR(150),
    next_due_date DATE,
    issue_description TEXT,
    resolution_details TEXT,
    status VARCHAR(50) DEFAULT 'COMPLETED', -- 'SCHEDULED', 'IN_PROGRESS', 'COMPLETED'
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 10. tbl_products: Products & raw materials (Virgin Pulp, Parent Reels, Toilet Rolls, Facial Tissues, Napkins, Kitchen Towels, Packing Film, Cartons)
CREATE TABLE tbl_products (
    product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_code VARCHAR(50) NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    product_type VARCHAR(50) NOT NULL, -- 'RAW_MATERIAL', 'FINISHED_GOOD', 'PACKING_MATERIAL', 'SEMI_FINISHED'
    category VARCHAR(100) NOT NULL, -- 'Toilet Tissue', 'Facial Box', 'Napkin', 'Paper Towel', 'Parent Reel', 'Kraft Paper'
    gsm NUMERIC(6, 2) DEFAULT 0.00, -- Grams per square meter (e.g. 13.5 GSM, 17 GSM)
    ply INT DEFAULT 1, -- 1-ply, 2-ply, 3-ply, 4-ply
    sheet_width_mm NUMERIC(8, 2) DEFAULT 0.00,
    roll_length_m NUMERIC(8, 2) DEFAULT 0.00,
    rolls_per_pack INT DEFAULT 1,
    uom VARCHAR(30) DEFAULT 'PCS', -- 'KG', 'ROLLS', 'PACKS', 'BOXES', 'METERS'
    unit_cost NUMERIC(12, 2) DEFAULT 0.00,
    selling_price NUMERIC(12, 2) DEFAULT 0.00,
    tax_rate NUMERIC(5, 2) DEFAULT 18.00,
    reorder_level NUMERIC(12, 2) DEFAULT 50.00,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 11. tbl_bom: Bill of Materials header
CREATE TABLE tbl_bom (
    bom_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bom_code VARCHAR(50) NOT NULL,
    product_id UUID NOT NULL, -- Target finished good
    product_name VARCHAR(200) NOT NULL,
    batch_size NUMERIC(12, 2) DEFAULT 1.00,
    uom VARCHAR(30) DEFAULT 'PACKS',
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 12. tbl_bom_items: Bill of Materials items (e.g. 1 Pack Toilet Roll = 0.45kg Parent Reel 16GSM + 1 Cardboard Core + 0.01kg Poly Film)
CREATE TABLE tbl_bom_items (
    bom_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bom_id UUID NOT NULL,
    raw_material_id UUID NOT NULL,
    raw_material_name VARCHAR(200) NOT NULL,
    quantity_required NUMERIC(12, 4) NOT NULL,
    uom VARCHAR(30) NOT NULL,
    wastage_percentage NUMERIC(5, 2) DEFAULT 2.00,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 13. tbl_production_plans: Scheduled manufacturing plans
CREATE TABLE tbl_production_plans (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_code VARCHAR(50) NOT NULL,
    plan_name VARCHAR(200) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    target_quantity NUMERIC(12, 2) DEFAULT 0.00,
    status VARCHAR(50) DEFAULT 'PLANNED', -- 'PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 14. tbl_production_batches: Production batches on machines/lines
CREATE TABLE tbl_production_batches (
    batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_code VARCHAR(50) NOT NULL,
    plan_id UUID,
    product_id UUID NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    machine_asset_id UUID,
    machine_name VARCHAR(200),
    planned_quantity NUMERIC(12, 2) NOT NULL,
    produced_quantity NUMERIC(12, 2) DEFAULT 0.00,
    rejected_quantity NUMERIC(12, 2) DEFAULT 0.00,
    wastage_kg NUMERIC(12, 2) DEFAULT 0.00,
    start_time TIMESTAMP WITHOUT TIME ZONE,
    end_time TIMESTAMP WITHOUT TIME ZONE,
    batch_status VARCHAR(50) DEFAULT 'PENDING', -- 'PENDING', 'RUNNING', 'COMPLETED', 'HALTED'
    supervisor_id UUID,
    supervisor_name VARCHAR(150),
    shift VARCHAR(50) DEFAULT 'DAY', -- 'DAY', 'NIGHT', 'SHIFT_A', 'SHIFT_B'
    remarks TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 15. tbl_inventory: Current stock levels per product & warehouse location
CREATE TABLE tbl_inventory (
    inventory_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    product_code VARCHAR(50) NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    product_type VARCHAR(50) NOT NULL,
    warehouse_location VARCHAR(100) DEFAULT 'MAIN_WAREHOUSE', -- 'MAIN_WAREHOUSE', 'RAW_STORE', 'DISPATCH'
    current_stock NUMERIC(14, 2) DEFAULT 0.00,
    reserved_stock NUMERIC(14, 2) DEFAULT 0.00,
    available_stock NUMERIC(14, 2) DEFAULT 0.00,
    uom VARCHAR(30) DEFAULT 'PCS',
    minimum_stock_level NUMERIC(12, 2) DEFAULT 20.00,
    maximum_stock_level NUMERIC(12, 2) DEFAULT 10000.00,
    last_restocked_at TIMESTAMP WITHOUT TIME ZONE,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 16. tbl_inventory_movements: Inward, outward, adjustments, scrap, production usage
CREATE TABLE tbl_inventory_movements (
    movement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    movement_type VARCHAR(50) NOT NULL, -- 'INWARD_PURCHASE', 'OUTWARD_SALE', 'PROD_CONSUMPTION', 'PROD_OUTPUT', 'ADJUSTMENT', 'WASTAGE'
    quantity NUMERIC(12, 2) NOT NULL,
    previous_stock NUMERIC(14, 2) DEFAULT 0.00,
    new_stock NUMERIC(14, 2) DEFAULT 0.00,
    reference_type VARCHAR(50), -- 'PURCHASE_ORDER', 'SALES_ORDER', 'BATCH', 'MANUAL_ADJUST'
    reference_id VARCHAR(100),
    location VARCHAR(100) DEFAULT 'MAIN_WAREHOUSE',
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 17. tbl_purchase_orders: Raw material & supplies procurement from vendors
CREATE TABLE tbl_purchase_orders (
    po_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_number VARCHAR(50) NOT NULL,
    vendor_id UUID NOT NULL,
    vendor_name VARCHAR(200) NOT NULL,
    order_date DATE NOT NULL,
    expected_delivery_date DATE,
    subtotal NUMERIC(14, 2) DEFAULT 0.00,
    tax_amount NUMERIC(12, 2) DEFAULT 0.00,
    total_amount NUMERIC(14, 2) DEFAULT 0.00,
    paid_amount NUMERIC(14, 2) DEFAULT 0.00,
    payment_status VARCHAR(50) DEFAULT 'UNPAID', -- 'UNPAID', 'PARTIAL', 'PAID'
    order_status VARCHAR(50) DEFAULT 'PENDING', -- 'PENDING', 'APPROVED', 'RECEIVED', 'CANCELLED'
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 18. tbl_purchase_order_items: Line items for POs
CREATE TABLE tbl_purchase_order_items (
    po_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    quantity NUMERIC(12, 2) NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    tax_rate NUMERIC(5, 2) DEFAULT 18.00,
    tax_amount NUMERIC(12, 2) DEFAULT 0.00,
    total_amount NUMERIC(14, 2) NOT NULL,
    received_quantity NUMERIC(12, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 19. tbl_sales_orders: Customer wholesale and distribution sales orders
CREATE TABLE tbl_sales_orders (
    so_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    so_number VARCHAR(50) NOT NULL,
    customer_id UUID NOT NULL,
    customer_name VARCHAR(200) NOT NULL,
    order_date DATE NOT NULL,
    delivery_date DATE,
    subtotal NUMERIC(14, 2) DEFAULT 0.00,
    discount_amount NUMERIC(12, 2) DEFAULT 0.00,
    tax_amount NUMERIC(12, 2) DEFAULT 0.00,
    total_amount NUMERIC(14, 2) DEFAULT 0.00,
    paid_amount NUMERIC(14, 2) DEFAULT 0.00,
    payment_status VARCHAR(50) DEFAULT 'UNPAID', -- 'UNPAID', 'PARTIAL', 'PAID'
    order_status VARCHAR(50) DEFAULT 'CONFIRMED', -- 'CONFIRMED', 'DISPATCHED', 'DELIVERED', 'CANCELLED'
    shipping_address TEXT,
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 20. tbl_sales_order_items: Line items for sales orders
CREATE TABLE tbl_sales_order_items (
    so_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    so_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    quantity NUMERIC(12, 2) NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    tax_rate NUMERIC(5, 2) DEFAULT 18.00,
    tax_amount NUMERIC(12, 2) DEFAULT 0.00,
    total_amount NUMERIC(14, 2) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 21. tbl_system_settings: Application configuration key-values
CREATE TABLE tbl_system_settings (
    setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key VARCHAR(100) NOT NULL,
    setting_value TEXT NOT NULL,
    category VARCHAR(100) DEFAULT 'GENERAL',
    description TEXT,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 22. tbl_activity_logs: System activity and audit trail
CREATE TABLE tbl_activity_logs (
    activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    username VARCHAR(100),
    activity_type VARCHAR(100) NOT NULL,
    module VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    record_id VARCHAR(100),
    old_value JSONB,
    new_value JSONB,
    ip_address VARCHAR(50) DEFAULT '127.0.0.1',
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create performance indexes
CREATE INDEX idx_users_username ON tbl_users(username);
CREATE INDEX idx_products_type ON tbl_products(product_type);
CREATE INDEX idx_products_code ON tbl_products(product_code);
CREATE INDEX idx_inventory_prod ON tbl_inventory(product_id);
CREATE INDEX idx_movements_prod ON tbl_inventory_movements(product_id);
CREATE INDEX idx_batches_status ON tbl_production_batches(batch_status);
CREATE INDEX idx_batches_date ON tbl_production_batches(created_at);
CREATE INDEX idx_so_customer ON tbl_sales_orders(customer_id);
CREATE INDEX idx_so_status ON tbl_sales_orders(order_status);
CREATE INDEX idx_po_vendor ON tbl_purchase_orders(vendor_id);
CREATE INDEX idx_assets_cat ON tbl_assets(category);
CREATE INDEX idx_logs_module ON tbl_activity_logs(module);
CREATE INDEX idx_logs_created ON tbl_activity_logs(created_at);
