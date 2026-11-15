const { executeFunction } = require('../config/db');

// Products
const getAllProducts = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const search = req.query.search || null;
    const productType = req.query.productType || null;
    const category = req.query.category || null;

    const result = await executeFunction('fn_product_get_all', [page, limit, search, productType, category]);
    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
      totalRecords: result.totalRecords,
      maxPages: result.maxPages,
      data: result.data || [],
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

const saveProduct = async (req, res) => {
  try {
    const {
      productId,
      productCode,
      productName,
      productType,
      category,
      gsm,
      ply,
      sheetWidthMm,
      rollLengthM,
      rollsPerPack,
      uom,
      unitCost,
      sellingPrice,
      taxRate,
      reorderLevel,
      description,
    } = req.body;

    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_product_save', [
      productId || null,
      productCode,
      productName,
      productType,
      category,
      parseFloat(gsm || 0),
      parseInt(ply || 1, 10),
      parseFloat(sheetWidthMm || 0),
      parseFloat(rollLengthM || 0),
      parseInt(rollsPerPack || 1, 10),
      uom || 'PCS',
      parseFloat(unitCost || 0),
      parseFloat(sellingPrice || 0),
      parseFloat(taxRate || 18),
      parseFloat(reorderLevel || 50),
      description || null,
      actorId,
      actorName,
    ]);

    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
      createdId: result.createdId,
      data: result.data,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// Inventory
const getInventory = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const search = req.query.search || null;
    const productType = req.query.productType || null;
    const lowStockOnly = req.query.lowStockOnly === 'true';

    const result = await executeFunction('fn_inventory_get_all', [page, limit, search, productType, lowStockOnly]);
    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
      totalRecords: result.totalRecords,
      maxPages: result.maxPages,
      data: result.data || [],
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

const adjustStock = async (req, res) => {
  try {
    const { productId, movementType, quantity, referenceType, referenceId, location, notes } = req.body;
    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_inventory_adjust_stock', [
      productId,
      movementType,
      parseFloat(quantity),
      referenceType || 'MANUAL_ADJUST',
      referenceId || null,
      location || 'MAIN_WAREHOUSE',
      notes || null,
      actorId,
      actorName,
    ]);

    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
      createdId: result.createdId,
      data: result.data,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

const getMovements = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const productId = req.query.productId || null;
    const movementType = req.query.movementType || null;

    const result = await executeFunction('fn_inventory_get_movements', [page, limit, productId, movementType]);
    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
      totalRecords: result.totalRecords,
      maxPages: result.maxPages,
      data: result.data || [],
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getAllProducts,
  saveProduct,
  getInventory,
  adjustStock,
  getMovements,
};
