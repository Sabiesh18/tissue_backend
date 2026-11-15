const { executeFunction } = require('../config/db');

// Plans
const getAllPlans = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const search = req.query.search || null;
    const status = req.query.status || null;

    const result = await executeFunction('fn_production_plan_get_all', [page, limit, search, status]);
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

const savePlan = async (req, res) => {
  try {
    const { planId, planCode, planName, startDate, endDate, targetQuantity, status, notes } = req.body;
    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_production_plan_save', [
      planId || null,
      planCode,
      planName,
      startDate,
      endDate,
      parseFloat(targetQuantity || 0),
      status || 'PLANNED',
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

// Batches
const getAllBatches = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const search = req.query.search || null;
    const status = req.query.status || null;

    const result = await executeFunction('fn_production_batch_get_all', [page, limit, search, status]);
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

const saveBatch = async (req, res) => {
  try {
    const {
      batchId,
      batchCode,
      planId,
      productId,
      productName,
      machineAssetId,
      machineName,
      plannedQuantity,
      producedQuantity,
      rejectedQuantity,
      wastageKg,
      batchStatus,
      supervisorName,
      shift,
      remarks,
    } = req.body;

    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_production_batch_save', [
      batchId || null,
      batchCode,
      planId || null,
      productId,
      productName,
      machineAssetId || null,
      machineName || null,
      parseFloat(plannedQuantity || 0),
      parseFloat(producedQuantity || 0),
      parseFloat(rejectedQuantity || 0),
      parseFloat(wastageKg || 0),
      batchStatus || 'PENDING',
      supervisorName || null,
      shift || 'DAY',
      remarks || null,
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

const deleteBatch = async (req, res) => {
  try {
    const { id } = req.params;
    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_production_batch_delete', [id, actorId, actorName]);
    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getAllPlans,
  savePlan,
  getAllBatches,
  saveBatch,
  deleteBatch,
};
