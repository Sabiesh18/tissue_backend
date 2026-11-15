const { executeFunction } = require('../config/db');

const getAllAssets = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const search = req.query.search || null;
    const category = req.query.category || null;
    const status = req.query.status || null;

    const result = await executeFunction('fn_asset_get_all', [page, limit, search, category, status]);
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

const saveAsset = async (req, res) => {
  try {
    const {
      assetId,
      assetCode,
      assetName,
      category,
      modelNumber,
      serialNumber,
      vendorId,
      vendorName,
      purchaseDate,
      purchaseCost,
      currentValue,
      quantity,
      locationArea,
      conditionStatus,
      warrantyExpiry,
      notes,
    } = req.body;

    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_asset_save', [
      assetId || null,
      assetCode,
      assetName,
      category,
      modelNumber || null,
      serialNumber || null,
      vendorId || null,
      vendorName || null,
      purchaseDate || null,
      parseFloat(purchaseCost || 0),
      parseFloat(currentValue || 0),
      parseInt(quantity || 1, 10),
      locationArea || null,
      conditionStatus || 'OPERATIONAL',
      warrantyExpiry || null,
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

const deleteAsset = async (req, res) => {
  try {
    const { id } = req.params;
    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_asset_delete', [id, actorId, actorName]);
    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getAllAssets,
  saveAsset,
  deleteAsset,
};
