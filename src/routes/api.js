const express = require('express');
const router = express.Router();
const { verifyToken, requireRole } = require('../middleware/auth');

const authController = require('../controllers/authController');
const dashboardController = require('../controllers/dashboardController');
const assetController = require('../controllers/assetController');
const vendorController = require('../controllers/vendorController');
const customerController = require('../controllers/customerController');
const productionController = require('../controllers/productionController');
const inventoryController = require('../controllers/inventoryController');
const orderController = require('../controllers/orderController');
const settingsController = require('../controllers/settingsController');

// 1. Auth routes (public login)
router.post('/auth/login', authController.login);
router.get('/auth/me', verifyToken, authController.getCurrentUser);
router.post('/auth/logout', verifyToken, authController.logout);

// 2. Dashboard
router.get('/dashboard/metrics', verifyToken, dashboardController.getDashboardMetrics);

// 3. Assets
router.get('/assets', verifyToken, assetController.getAllAssets);
router.post('/assets', verifyToken, assetController.saveAsset);
router.delete('/assets/:id', verifyToken, requireRole('ADMIN', 'PROD_MGR'), assetController.deleteAsset);

// 4. Vendors
router.get('/vendors', verifyToken, vendorController.getAllVendors);
router.post('/vendors', verifyToken, vendorController.saveVendor);
router.delete('/vendors/:id', verifyToken, requireRole('ADMIN'), vendorController.deleteVendor);

// 5. Customers
router.get('/customers', verifyToken, customerController.getAllCustomers);
router.post('/customers', verifyToken, customerController.saveCustomer);

// 6. Production & Manufacturing
router.get('/production/plans', verifyToken, productionController.getAllPlans);
router.post('/production/plans', verifyToken, productionController.savePlan);
router.get('/production/batches', verifyToken, productionController.getAllBatches);
router.post('/production/batches', verifyToken, productionController.saveBatch);

// 7. Inventory & Products
router.get('/products', verifyToken, inventoryController.getAllProducts);
router.post('/products', verifyToken, inventoryController.saveProduct);
router.get('/inventory', verifyToken, inventoryController.getInventory);
router.post('/inventory/adjust', verifyToken, inventoryController.adjustStock);
router.get('/inventory/movements', verifyToken, inventoryController.getMovements);

// 8. Orders (Purchase & Sales)
router.get('/orders/purchase', verifyToken, orderController.getAllPurchaseOrders);
router.post('/orders/purchase', verifyToken, orderController.savePurchaseOrder);
router.get('/orders/sales', verifyToken, orderController.getAllSalesOrders);
router.post('/orders/sales', verifyToken, orderController.saveSalesOrder);

// 9. Settings, Users & Audit Logs
router.get('/users', verifyToken, requireRole('ADMIN'), settingsController.getAllUsers);
router.post('/users', verifyToken, requireRole('ADMIN'), settingsController.saveUser);
router.get('/roles', verifyToken, settingsController.getAllRoles);
router.get('/settings', verifyToken, settingsController.getSettings);
router.post('/settings', verifyToken, requireRole('ADMIN'), settingsController.saveSetting);
router.get('/logs', verifyToken, requireRole('ADMIN'), settingsController.getActivityLogs);

module.exports = router;
