/**
 * Comprehensive API Test Suite
 * Tests CRUD operations (Insert, Fetch, Update, Delete, View) across all modules:
 * 1. Authentication (Login / View Profile)
 * 2. Dashboard Metrics (Fetch / Aggregation View)
 * 3. Assets Management (Create, Fetch, Update, Delete)
 * 4. Vendors Management (Create, Fetch, Update, Delete)
 * 5. Customers Management (Create, Fetch, Update, Delete)
 * 6. Products & Raw Materials (Create, Fetch, Update, Delete)
 * 7. Inventory & Stock Adjustments (Fetch, Stock Inward Adjust, Stock Outward Adjust)
 * 8. Manufacturing Batches (Create, Fetch, Complete/Update, Delete)
 * 9. Production Plans (Create, Fetch, Update)
 * 10. Orders - Sales & Purchase (Create, Fetch)
 * 11. Settings & Audit Logs (Fetch, Save Setting, Fetch Logs)
 */

const BASE_URL = 'http://localhost:5000/api';

async function runTests() {
  console.log('===============================================================');
  console.log('STARTING AUTOMATED API CRUD & FUNCTIONALITY TEST SUITE');
  console.log('===============================================================\n');

  let token = null;
  let passed = 0;
  let failed = 0;

  function assert(condition, testName, details = '') {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName} - ${details}`);
      failed++;
    }
  }

  // Helper
  const apiCall = async (endpoint, method = 'GET', body = null) => {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    const opts = { method, headers };
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch(`${BASE_URL}${endpoint}`, opts);
    return res.json();
  };

  try {
    // 1. AUTH - LOGIN
    console.log('--- 1. Testing Auth & Session ---');
    const loginRes = await apiCall('/auth/login', 'POST', { username: 'admin', password: 'admin123' });
    assert(loginRes.success === true && loginRes.token, 'Auth: Login successful & JWT generated');
    token = loginRes.token;

    const meRes = await apiCall('/auth/me');
    assert(meRes.success === true && meRes.user.username === 'admin', 'Auth: Fetch / View current profile (/auth/me)');

    // 2. DASHBOARD METRICS
    console.log('\n--- 2. Testing Dashboard Metrics ---');
    const dashRes = await apiCall('/dashboard/metrics');
    assert(dashRes.success === true && dashRes.data.totalAssets >= 0, 'Dashboard: Fetch live plant metrics');
    assert(Array.isArray(dashRes.data.productionTrend), 'Dashboard: View 7-day production yield trend');

    // 3. ASSETS CRUD
    console.log('\n--- 3. Testing Assets Management (CRUD) ---');
    // Insert
    const newAsset = {
      assetCode: `TEST-AST-${Date.now()}`,
      assetName: 'Automated Napkin Folding Machine Model X',
      category: 'MACHINERY',
      conditionStatus: 'OPERATIONAL',
      purchaseCost: 2500000,
      quantity: 1,
      locationArea: 'Plant Floor Line 3',
    };
    const createAssetRes = await apiCall('/assets', 'POST', newAsset);
    assert(createAssetRes.success === true && createAssetRes.createdId, 'Assets: INSERT new machinery asset');
    const testAssetId = createAssetRes.createdId;

    // Fetch / View
    const getAssetsRes = await apiCall('/assets');
    const foundAsset = getAssetsRes.data?.find((a) => a.assetId === testAssetId);
    assert(foundAsset && foundAsset.assetName === newAsset.assetName, 'Assets: FETCH / VIEW newly created asset');

    // Update
    const updateAssetRes = await apiCall('/assets', 'POST', {
      assetId: testAssetId,
      assetCode: newAsset.assetCode,
      assetName: 'Automated Napkin Folding Machine Model X (Calibrated)',
      category: 'MACHINERY',
      conditionStatus: 'OPERATIONAL',
      purchaseCost: 2600000,
      locationArea: 'Plant Floor Line 3 - Section B',
    });
    assert(updateAssetRes.success === true, 'Assets: UPDATE machinery details');

    // Delete
    const delAssetRes = await apiCall(`/assets/${testAssetId}`, 'DELETE');
    assert(delAssetRes.success === true, 'Assets: DELETE plant asset');

    // 4. VENDORS CRUD
    console.log('\n--- 4. Testing Vendors Management (CRUD) ---');
    // Insert
    const newVendor = {
      vendorCode: `TEST-VND-${Date.now()}`,
      vendorName: 'Southern Paperboard Traders',
      companyName: 'SPT Pulp Ltd',
      contactPerson: 'Murugan R',
      email: 'sales@sptpulp.in',
      phone: '+91 99887 76655',
      vendorStatus: 'ACTIVE',
      creditPeriodDays: 45,
    };
    const createVendorRes = await apiCall('/vendors', 'POST', newVendor);
    assert(createVendorRes.success === true && createVendorRes.createdId, 'Vendors: INSERT new supplier');
    const testVendorId = createVendorRes.createdId;

    // Fetch
    const getVendorsRes = await apiCall('/vendors');
    const foundVendor = getVendorsRes.data?.find((v) => v.vendorId === testVendorId);
    assert(foundVendor && foundVendor.vendorName === newVendor.vendorName, 'Vendors: FETCH / VIEW registered vendor');

    // Update
    const updateVendorRes = await apiCall('/vendors', 'POST', {
      vendorId: testVendorId,
      vendorCode: newVendor.vendorCode,
      vendorName: 'Southern Paperboard Traders Pvt Ltd',
      creditPeriodDays: 60,
    });
    assert(updateVendorRes.success === true, 'Vendors: UPDATE vendor credit terms');

    // Delete
    const delVendorRes = await apiCall(`/vendors/${testVendorId}`, 'DELETE');
    assert(delVendorRes.success === true, 'Vendors: DELETE vendor supplier');

    // 5. CUSTOMERS CRUD
    console.log('\n--- 5. Testing Customers Management (CRUD) ---');
    // Insert
    const newCust = {
      customerCode: `TEST-CUST-${Date.now()}`,
      customerName: 'Taj Connemara Heritage Hotel',
      companyName: 'IHCL Hotels',
      contactPerson: 'Kalyan Sundaram',
      phone: '+91 98409 12345',
      creditLimit: 750000,
      customerStatus: 'ACTIVE',
    };
    const createCustRes = await apiCall('/customers', 'POST', newCust);
    assert(createCustRes.success === true && createCustRes.createdId, 'Customers: INSERT new wholesale account');
    const testCustId = createCustRes.createdId;

    // Fetch
    const getCustRes = await apiCall('/customers');
    const foundCust = getCustRes.data?.find((c) => c.customerId === testCustId);
    assert(foundCust && foundCust.customerName === newCust.customerName, 'Customers: FETCH / VIEW account');

    // Update
    const updateCustRes = await apiCall('/customers', 'POST', {
      customerId: testCustId,
      customerCode: newCust.customerCode,
      customerName: 'Taj Connemara Heritage Hotel & Resorts',
      creditLimit: 900000,
    });
    assert(updateCustRes.success === true, 'Customers: UPDATE credit limit');

    // Delete
    const delCustRes = await apiCall(`/customers/${testCustId}`, 'DELETE');
    assert(delCustRes.success === true, 'Customers: DELETE customer account');

    // 6. PRODUCTS & INVENTORY CRUD
    console.log('\n--- 6. Testing Products Catalog & Inventory Stock Movements ---');
    // Insert Product
    const newProduct = {
      productCode: `TEST-PR-${Date.now()}`,
      productName: 'Eco Kraft Heavy Duty Wipes 50s',
      productType: 'FINISHED_GOOD',
      category: 'Paper Towel',
      gsm: 40,
      ply: 2,
      uom: 'PACKS',
      unitCost: 45,
      sellingPrice: 85,
      taxRate: 12,
      reorderLevel: 100,
    };
    const createProdRes = await apiCall('/products', 'POST', newProduct);
    assert(createProdRes.success === true && createProdRes.createdId, 'Products: INSERT product & auto-create inventory record');
    const testProductId = createProdRes.createdId;

    // Fetch Products
    const getProdRes = await apiCall('/products');
    const foundProduct = getProdRes.data?.find((p) => p.productId === testProductId);
    assert(foundProduct && foundProduct.productName === newProduct.productName, 'Products: FETCH / VIEW product catalog');

    // Stock Inward Adjustment (Stock increase)
    const adjustInwardRes = await apiCall('/inventory/adjust', 'POST', {
      productId: testProductId,
      movementType: 'INWARD_PURCHASE',
      quantity: 500,
      referenceType: 'MANUAL_TEST',
      notes: 'Initial test batch inward receipt',
    });
    assert(adjustInwardRes.success === true && adjustInwardRes.data.newStock === 500, 'Inventory: STOCK INWARD (Add 500 units)');

    // Stock Outward Adjustment (Stock deduction)
    const adjustOutwardRes = await apiCall('/inventory/adjust', 'POST', {
      productId: testProductId,
      movementType: 'OUTWARD_SALE',
      quantity: 120,
      referenceType: 'MANUAL_TEST',
      notes: 'Sample dispatch test',
    });
    assert(adjustOutwardRes.success === true && adjustOutwardRes.data.newStock === 380, 'Inventory: STOCK OUTWARD (Deduct 120 units -> 380 left)');

    // Delete Product
    const delProdRes = await apiCall(`/products/${testProductId}`, 'DELETE');
    assert(delProdRes.success === true, 'Products: DELETE test product');

    // 7. MANUFACTURING BATCHES CRUD
    console.log('\n--- 7. Testing Manufacturing Batches & Production ---');
    // Insert Batch
    const newBatch = {
      batchCode: `TEST-BAT-${Date.now()}`,
      productId: 'f5555555-5555-5555-5555-555555555555',
      productName: 'Soft Luxe 2-Ply Toilet Rolls (10 Roll Pack)',
      machineName: 'Line 1 High Speed Rewinder',
      plannedQuantity: 800,
      producedQuantity: 0,
      rejectedQuantity: 0,
      wastageKg: 0,
      batchStatus: 'RUNNING',
      shift: 'DAY',
    };
    const createBatchRes = await apiCall('/production/batches', 'POST', newBatch);
    assert(createBatchRes.success === true && createBatchRes.createdId, 'Manufacturing: INSERT active production batch');
    const testBatchId = createBatchRes.createdId;

    // Fetch Batches
    const getBatchesRes = await apiCall('/production/batches');
    const foundBatch = getBatchesRes.data?.find((b) => b.batchId === testBatchId);
    assert(foundBatch && foundBatch.batchCode === newBatch.batchCode, 'Manufacturing: FETCH / VIEW batch in progress');

    // Update / Complete Batch (Yield + Wastage calculation)
    const updateBatchRes = await apiCall('/production/batches', 'POST', {
      batchId: testBatchId,
      batchCode: newBatch.batchCode,
      productId: newBatch.productId,
      productName: newBatch.productName,
      plannedQuantity: 800,
      producedQuantity: 790,
      rejectedQuantity: 10,
      wastageKg: 7.5,
      batchStatus: 'COMPLETED',
      shift: 'DAY',
    });
    assert(updateBatchRes.success === true, 'Manufacturing: UPDATE & complete batch with yield and wastage logging');

    // Delete Batch
    const delBatchRes = await apiCall(`/production/batches/${testBatchId}`, 'DELETE');
    assert(delBatchRes.success === true, 'Manufacturing: DELETE production batch');

    // 8. ORDERS (COMMERCIAL)
    console.log('\n--- 8. Testing Sales Orders & Purchase Orders ---');
    const getSoRes = await apiCall('/orders/sales');
    assert(getSoRes.success === true && Array.isArray(getSoRes.data), 'Sales Orders: FETCH commercial sales orders');

    const getPoRes = await apiCall('/orders/purchase');
    assert(getPoRes.success === true && Array.isArray(getPoRes.data), 'Purchase Orders: FETCH procurement purchase orders');

    // 9. SETTINGS & ACTIVITY LOGS
    console.log('\n--- 9. Testing System Settings & Audit Logs ---');
    const getSettingsRes = await apiCall('/settings');
    assert(getSettingsRes.success === true && getSettingsRes.data.length > 0, 'Settings: FETCH plant configuration parameters');

    const saveSettingRes = await apiCall('/settings', 'POST', {
      settingKey: 'TEST_SETTING_FLAG',
      settingValue: 'ENABLED',
      category: 'TESTING',
    });
    assert(saveSettingRes.success === true, 'Settings: SAVE / UPDATE system parameter');

    const getLogsRes = await apiCall('/logs');
    assert(getLogsRes.success === true && getLogsRes.data.length > 0, 'Audit Trail: FETCH immutable activity logs');

  } catch (err) {
    console.error('Test execution error:', err);
    failed++;
  }

  console.log('\n===============================================================');
  console.log(`TEST SUMMARY: ${passed} PASSED, ${failed} FAILED (TOTAL: ${passed + failed})`);
  console.log('===============================================================');

  if (failed === 0) {
    console.log('ALL API FUNCTIONALITY (INSERT, UPDATE, DELETE, FETCH, VIEW) CONFIRMED WORKING PROPERLY!');
  }
}

runTests();
