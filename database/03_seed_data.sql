-- =============================================================================
-- TISSUE MANUFACTURING MANAGEMENT SYSTEM
-- Seed Data: Roles, Admin User, Raw Materials, Finished Goods, Assets,
-- Vendors, Customers, Production Batches, Inventory, System Settings
-- =============================================================================

-- 1. Roles
INSERT INTO tbl_roles (role_id, role_name, role_code, description, is_system_role)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'System Administrator', 'ADMIN', 'Full system access and configurations', TRUE),
    ('22222222-2222-2222-2222-222222222222', 'Plant Production Manager', 'PROD_MGR', 'Manages manufacturing lines, batches, and planning', TRUE),
    ('33333333-3333-3333-3333-333333333333', 'Inventory & Warehouse Officer', 'INV_OFFICER', 'Stock inwards, outwards, raw materials and dispatch', TRUE),
    ('44444444-4444-4444-4444-444444444444', 'Machine Operator', 'OPERATOR', 'Logs batch progress, runs lines and reports output', TRUE)
ON CONFLICT (role_id) DO NOTHING;

-- 2. Default Administrator (password: admin123 -> bcrypt hash or sha256)
-- We will store bcrypt compatible hash for 'admin123': $2a$10$xK7v0Z5E5k8F5j5qG/2A.eGq77QWqL0oBvy4W4J2i9A2mF8aL4Zqy (or standard bcrypt)
-- Also a known bcrypt hash for 'admin123': $2b$10$wT3jYVjDk9.1fKxU8jIqOeO5B5vF07I0vV6bX1Wl8a3G2gR0w.xvy
INSERT INTO tbl_users (user_id, username, full_name, email, phone, role_id, role_name, is_active)
VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'admin',
    'Production Administrator',
    'admin@tissuemanufacturing.com',
    '+91 98765 43210',
    '11111111-1111-1111-1111-111111111111',
    'System Administrator',
    TRUE
) ON CONFLICT (user_id) DO NOTHING;

INSERT INTO tbl_user_auth (auth_id, user_id, password_hash, last_login, failed_attempts, is_locked)
VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '$2a$10$wK1VfN6K1w7lDq0Z4J9WNu3R1o9T4Z7I1A6A0V3W5Q8Y4U7S2P0Qe', -- updated at backend startup if needed
    CURRENT_TIMESTAMP,
    0,
    FALSE
) ON CONFLICT (auth_id) DO NOTHING;

-- 3. Vendors
INSERT INTO tbl_vendors (vendor_id, vendor_code, vendor_name, company_name, contact_person, email, phone, tax_number, address_line1, city, state, postal_code, vendor_status, credit_period_days, rating)
VALUES 
    ('c1111111-1111-1111-1111-111111111111', 'VND-001', 'Tamilnadu Newsprint and Papers Ltd', 'TNPL Supplies', 'Sundararajan M', 'orders@tnplsupplies.com', '+91 94440 12345', '33AAACT0001A1Z1', '124 Mount Road', 'Chennai', 'Tamil Nadu', '600002', 'ACTIVE', 30, 4.8),
    ('c2222222-2222-2222-2222-222222222222', 'VND-002', 'ITC Paperboards & Specialty Papers', 'ITC PSPD', 'Rajesh Sharma', 'tissuepulp@itc.in', '+91 98840 23456', '33AAACI1234F1Z8', 'Bollaram Industrial Area', 'Hyderabad', 'Telangana', '500032', 'ACTIVE', 45, 4.9),
    ('c3333333-3333-3333-3333-333333333333', 'VND-003', 'Apex Packaging & Films Pvt Ltd', 'Apex Pack', 'Venkatesh K', 'sales@apexpack.co.in', '+91 98410 34567', '33AAACA9876C1Z3', 'SIDCO Industrial Estate, Ambattur', 'Chennai', 'Tamil Nadu', '600058', 'ACTIVE', 15, 4.6),
    ('c4444444-4444-4444-4444-444444444444', 'VND-004', 'Zenith Machinery & Spares', 'Zenith Engg', 'Maheshwari P', 'service@zenitheng.com', '+91 94220 56789', '27AAACZ4567D1Z9', 'MIDC Industrial Estate', 'Pune', 'Maharashtra', '411018', 'ACTIVE', 30, 4.7)
ON CONFLICT (vendor_id) DO NOTHING;

-- 4. Customers
INSERT INTO tbl_customers (customer_id, customer_code, customer_name, company_name, contact_person, email, phone, tax_number, billing_address, city, state, postal_code, customer_status, credit_limit)
VALUES 
    ('d1111111-1111-1111-1111-111111111111', 'CUST-001', 'Grand Chola Hospitality Supplies', 'ITC Grand Chola', 'Arun Kumar', 'procurement@grandchola.com', '+91 98401 11223', '33AAACG1111B1Z2', '63 Mount Road, Guindy', 'Chennai', 'Tamil Nadu', '600032', 'ACTIVE', 500000.00),
    ('d2222222-2222-2222-2222-222222222222', 'CUST-002', 'Apollo Hospitals Enterprise Ltd', 'Apollo Hospitals Group', 'Dr. Radhakrishnan', 'stores@apollohospitals.com', '+91 98402 33445', '33AAACA2222C1Z5', 'Greams Road, Thousand Lights', 'Chennai', 'Tamil Nadu', '600006', 'ACTIVE', 1000000.00),
    ('d3333333-3333-3333-3333-333333333333', 'CUST-003', 'Nilgiris Supermarket Retail Distribution', 'Nilgiris Dairy Farm', 'Senthil Nathan', 'purchase@nilgiris1905.com', '+91 98403 55667', '33AAACN3333D1Z8', 'Radhakrishnan Salai', 'Coimbatore', 'Tamil Nadu', '641018', 'ACTIVE', 350000.00),
    ('d4444444-4444-4444-4444-444444444444', 'CUST-004', 'Air India In-Flight Catering Logistics', 'TajSATS Air Catering', 'Pooja Verma', 'supply@tajsats.com', '+91 98404 77889', '33AAACT4444E1Z1', 'Airport Cargo Complex, Meenambakkam', 'Chennai', 'Tamil Nadu', '600027', 'ACTIVE', 800000.00)
ON CONFLICT (customer_id) DO NOTHING;

-- 5. Plant Assets (Tissue Manufacturing Lines & Utilities)
INSERT INTO tbl_assets (asset_id, asset_code, asset_name, category, model_number, serial_number, vendor_name, purchase_date, purchase_cost, current_value, location_area, condition_status)
VALUES 
    ('e1111111-1111-1111-1111-111111111111', 'AST-REW-01', 'High-Speed Automatic Toilet Roll Rewinder', 'MACHINERY', 'T-REW-2800', 'SR-2023-0891', 'Zenith Machinery & Spares', '2023-04-15', 3850000.00, 3400000.00, 'Plant Floor Line 1', 'OPERATIONAL'),
    ('e2222222-2222-2222-2222-222222222222', 'AST-EMB-01', 'Double Steel-to-Rubber Embossing Unit', 'MACHINERY', 'EMB-PRO-1800', 'EB-2023-0412', 'Zenith Machinery & Spares', '2023-06-20', 1450000.00, 1300000.00, 'Plant Floor Line 1', 'OPERATIONAL'),
    ('e3333333-3333-3333-3333-333333333333', 'AST-FAC-01', 'Facial Tissue Interfolding & Box Filling Line', 'MACHINERY', 'FTL-400-AUTO', 'FT-2024-0105', 'Zenith Machinery & Spares', '2024-01-10', 4200000.00, 4000000.00, 'Plant Floor Line 2', 'OPERATIONAL'),
    ('e4444444-4444-4444-4444-444444444444', 'AST-PCK-01', 'Automatic Shrink Wrap & Poly Bagging Machine', 'MACHINERY', 'SWP-80-BPM', 'PK-2024-0322', 'Apex Packaging & Films Pvt Ltd', '2024-03-01', 980000.00, 920000.00, 'Packaging Bay', 'OPERATIONAL'),
    ('e5555555-5555-5555-5555-555555555555', 'AST-CMP-01', 'Ingersoll Rand Industrial Screw Air Compressor', 'MACHINERY', 'UP6-30-125', 'IR-2022-7711', 'Zenith Machinery & Spares', '2022-11-18', 650000.00, 520000.00, 'Utility Room', 'OPERATIONAL'),
    ('e6666666-6666-6666-6666-666666666666', 'AST-FORK-01', 'Godrej 2.5 Ton Electric Forklift', 'VEHICLE', 'GX-250E', 'GD-2023-5590', 'Godrej Material Handling', '2023-08-12', 1250000.00, 1100000.00, 'Raw Material Yard', 'OPERATIONAL')
ON CONFLICT (asset_id) DO NOTHING;

-- 6. Products: Raw Materials and Finished Tissue Products
INSERT INTO tbl_products (product_id, product_code, product_name, product_type, category, gsm, ply, uom, unit_cost, selling_price, tax_rate, reorder_level, description)
VALUES 
    -- Raw materials
    ('f1111111-1111-1111-1111-111111111111', 'RM-PR-15', 'Virgin Pulp Parent Reel (15 GSM - Soft)', 'RAW_MATERIAL', 'Parent Reel', 15.00, 1, 'KG', 85.00, 0.00, 12.00, 1000.00, 'High tensile virgin wood pulp jumbo reel for toilet & facial tissue'),
    ('f2222222-2222-2222-2222-222222222222', 'RM-PR-18', 'Recycled Kraft Pulp Parent Reel (18 GSM)', 'RAW_MATERIAL', 'Parent Reel', 18.00, 1, 'KG', 62.00, 0.00, 12.00, 800.00, 'Cost-efficient reel for kitchen roll and commercial hand towels'),
    ('f3333333-3333-3333-3333-333333333333', 'RM-CORE-45', 'Spiral Cardboard Paper Core (45mm Inner Dia)', 'RAW_MATERIAL', 'Core Pipe', 0.00, 1, 'PCS', 1.80, 0.00, 18.00, 5000.00, 'Rigid paper core tubes for toilet roll winding'),
    ('f4444444-4444-4444-4444-444444444444', 'RM-FILM-LDPE', 'Printed Heat Seal LDPE Packaging Film', 'PACKING_MATERIAL', 'Packaging', 0.00, 1, 'KG', 140.00, 0.00, 18.00, 200.00, 'Outer wrapping shrink film for multipacks'),

    -- Finished Goods
    ('f5555555-5555-5555-5555-555555555555', 'FG-TR-2PLY-10', 'Soft Luxe 2-Ply Toilet Rolls (10 Roll Pack)', 'FINISHED_GOOD', 'Toilet Tissue', 30.00, 2, 'PACKS', 95.00, 160.00, 12.00, 250.00, 'Embossed ultra-soft perforated 2-ply bathroom tissue, 10 rolls per pack'),
    ('f6666666-6666-6666-6666-666666666666', 'FG-FB-200', 'Royal Care Facial Tissue Box (200 Pulls)', 'FINISHED_GOOD', 'Facial Box', 28.00, 2, 'BOXES', 42.00, 75.00, 12.00, 300.00, 'Premium 2-ply facial tissue pop-up box with aloe vera touch'),
    ('f7777777-7777-7777-7777-777777777777', 'FG-NP-100', 'Dine-In Table Napkins (100 Sheets Pack)', 'FINISHED_GOOD', 'Napkin', 17.00, 1, 'PACKS', 22.00, 45.00, 12.00, 400.00, '1/4 fold absorbent dining napkins for restaurant and banquet use'),
    ('f8888888-8888-8888-8888-888888888888', 'FG-KT-2RL', 'Ultra Absorb Kitchen Towel (2 Roll Pack)', 'FINISHED_GOOD', 'Paper Towel', 38.00, 2, 'PACKS', 55.00, 95.00, 12.00, 150.00, 'Honeycomb embossed 2-ply heavy duty kitchen cleaning paper roll')
ON CONFLICT (product_id) DO NOTHING;

-- 7. Initialize Inventory for all products
INSERT INTO tbl_inventory (inventory_id, product_id, product_code, product_name, product_type, warehouse_location, current_stock, reserved_stock, available_stock, uom, minimum_stock_level, maximum_stock_level)
VALUES 
    (gen_random_uuid(), 'f1111111-1111-1111-1111-111111111111', 'RM-PR-15', 'Virgin Pulp Parent Reel (15 GSM - Soft)', 'RAW_MATERIAL', 'RAW_STORE', 8450.00, 500.00, 7950.00, 'KG', 1000.00, 25000.00),
    (gen_random_uuid(), 'f2222222-2222-2222-2222-222222222222', 'RM-PR-18', 'Recycled Kraft Pulp Parent Reel (18 GSM)', 'RAW_MATERIAL', 'RAW_STORE', 4200.00, 200.00, 4000.00, 'KG', 800.00, 15000.00),
    (gen_random_uuid(), 'f3333333-3333-3333-3333-333333333333', 'RM-CORE-45', 'Spiral Cardboard Paper Core (45mm Inner Dia)', 'RAW_MATERIAL', 'RAW_STORE', 24500.00, 2000.00, 22500.00, 'PCS', 5000.00, 60000.00),
    (gen_random_uuid(), 'f4444444-4444-4444-4444-444444444444', 'RM-FILM-LDPE', 'Printed Heat Seal LDPE Packaging Film', 'PACKING_MATERIAL', 'RAW_STORE', 780.00, 50.00, 730.00, 'KG', 200.00, 3000.00),
    (gen_random_uuid(), 'f5555555-5555-5555-5555-555555555555', 'FG-TR-2PLY-10', 'Soft Luxe 2-Ply Toilet Rolls (10 Roll Pack)', 'FINISHED_GOOD', 'MAIN_WAREHOUSE', 1850.00, 300.00, 1550.00, 'PACKS', 250.00, 8000.00),
    (gen_random_uuid(), 'f6666666-6666-6666-6666-666666666666', 'FG-FB-200', 'Royal Care Facial Tissue Box (200 Pulls)', 'FINISHED_GOOD', 'MAIN_WAREHOUSE', 1240.00, 150.00, 1090.00, 'BOXES', 300.00, 6000.00),
    (gen_random_uuid(), 'f7777777-7777-7777-7777-777777777777', 'FG-NP-100', 'Dine-In Table Napkins (100 Sheets Pack)', 'FINISHED_GOOD', 'MAIN_WAREHOUSE', 2600.00, 400.00, 2200.00, 'PACKS', 400.00, 12000.00),
    (gen_random_uuid(), 'f8888888-8888-8888-8888-888888888888', 'FG-KT-2RL', 'Ultra Absorb Kitchen Towel (2 Roll Pack)', 'FINISHED_GOOD', 'MAIN_WAREHOUSE', 85.00, 10.00, 75.00, 'PACKS', 150.00, 5000.00) -- low stock example!
ON CONFLICT DO NOTHING;

-- 8. Production Plans
INSERT INTO tbl_production_plans (plan_id, plan_code, plan_name, start_date, end_date, target_quantity, status, notes)
VALUES 
    ('81111111-1111-1111-1111-111111111111', 'PLN-2026-WK46', 'Week 46 Hotel & Hospital Roll Supply Run', CURRENT_DATE - 3, CURRENT_DATE + 4, 15000.00, 'IN_PROGRESS', 'Targeting high-ply bath rolls and hospital bulk facial tissue'),
    ('82222222-2222-2222-2222-222222222222', 'PLN-2026-WK47', 'Week 47 Retail & Banquet Napkin Production Plan', CURRENT_DATE + 5, CURRENT_DATE + 12, 22000.00, 'PLANNED', 'Pre-festival dining napkin & kitchen towel batching')
ON CONFLICT (plan_id) DO NOTHING;

-- 9. Production Batches
INSERT INTO tbl_production_batches (batch_id, batch_code, plan_id, product_id, product_name, machine_asset_id, machine_name, planned_quantity, produced_quantity, rejected_quantity, wastage_kg, start_time, batch_status, supervisor_name, shift, remarks)
VALUES 
    ('91111111-1111-1111-1111-111111111111', 'BAT-2026-1101', '81111111-1111-1111-1111-111111111111', 'f5555555-5555-5555-5555-555555555555', 'Soft Luxe 2-Ply Toilet Rolls (10 Roll Pack)', 'e1111111-1111-1111-1111-111111111111', 'High-Speed Automatic Toilet Roll Rewinder', 1500.00, 1480.00, 20.00, 18.50, CURRENT_TIMESTAMP - INTERVAL '3 days', 'COMPLETED', 'Karthik Raja', 'DAY', 'Smooth run, core feed optimal'),
    ('92222222-2222-2222-2222-222222222222', 'BAT-2026-1102', '81111111-1111-1111-1111-111111111111', 'f6666666-6666-6666-6666-666666666666', 'Royal Care Facial Tissue Box (200 Pulls)', 'e3333333-3333-3333-3333-333333333333', 'Facial Tissue Interfolding & Box Filling Line', 1200.00, 1180.00, 12.00, 9.20, CURRENT_TIMESTAMP - INTERVAL '2 days', 'COMPLETED', 'Saravanan S', 'DAY', 'High precision interfolding'),
    ('93333333-3333-3333-3333-333333333333', 'BAT-2026-1103', '81111111-1111-1111-1111-111111111111', 'f7777777-7777-7777-7777-777777777777', 'Dine-In Table Napkins (100 Sheets Pack)', 'e1111111-1111-1111-1111-111111111111', 'High-Speed Automatic Toilet Roll Rewinder', 2500.00, 1950.00, 35.00, 14.00, CURRENT_TIMESTAMP - INTERVAL '1 day', 'RUNNING', 'Manikandan V', 'SHIFT_A', 'In progress on Line 1'),
    ('94444444-4444-4444-4444-444444444444', 'BAT-2026-1104', '81111111-1111-1111-1111-111111111111', 'f8888888-8888-8888-8888-888888888888', 'Ultra Absorb Kitchen Towel (2 Roll Pack)', 'e2222222-2222-2222-2222-222222222222', 'Double Steel-to-Rubber Embossing Unit', 800.00, 0.00, 0.00, 0.00, CURRENT_TIMESTAMP, 'PENDING', 'Saravanan S', 'DAY', 'Queued after Napkin batch')
ON CONFLICT (batch_id) DO NOTHING;

-- 10. System Settings
INSERT INTO tbl_system_settings (setting_id, setting_key, setting_value, category, description)
VALUES 
    (gen_random_uuid(), 'COMPANY_NAME', 'Sri Krishna Tissue Mills Pvt Ltd', 'COMPANY', 'Registered manufacturing company name'),
    (gen_random_uuid(), 'GSTIN_NUMBER', '33AAACS1818T1Z4', 'TAXATION', 'Goods and Services Tax Identification Number'),
    (gen_random_uuid(), 'CURRENCY_SYMBOL', '₹', 'REGIONAL', 'Default currency symbol (INR)'),
    (gen_random_uuid(), 'FACTORY_LOCATION', 'SIPCOT Industrial Park, Sriperumbudur, Tamil Nadu', 'FACILITY', 'Primary factory and manufacturing premises'),
    (gen_random_uuid(), 'DEFAULT_TAX_RATE', '12', 'TAXATION', 'Standard GST rate percentage on tissue paper products'),
    (gen_random_uuid(), 'MIN_REORDER_ALERT_DAYS', '7', 'INVENTORY', 'Threshold days of stock consumption to trigger purchase notification')
ON CONFLICT DO NOTHING;
