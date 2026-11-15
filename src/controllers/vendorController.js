const { executeFunction } = require('../config/db');

const getAllVendors = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const search = req.query.search || null;
    const status = req.query.status || null;

    const result = await executeFunction('fn_vendor_get_all', [page, limit, search, status]);
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

const saveVendor = async (req, res) => {
  try {
    const {
      vendorId,
      vendorCode,
      vendorName,
      companyName,
      contactPerson,
      email,
      phone,
      taxNumber,
      addressLine1,
      city,
      state,
      postalCode,
      vendorStatus,
      creditPeriodDays,
      notes,
    } = req.body;

    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_vendor_save', [
      vendorId || null,
      vendorCode,
      vendorName,
      companyName || null,
      contactPerson || null,
      email || null,
      phone || null,
      taxNumber || null,
      addressLine1 || null,
      city || null,
      state || null,
      postalCode || null,
      vendorStatus || 'ACTIVE',
      parseInt(creditPeriodDays || 30, 10),
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

const deleteVendor = async (req, res) => {
  try {
    const { id } = req.params;
    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_vendor_delete', [id, actorId, actorName]);
    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getAllVendors,
  saveVendor,
  deleteVendor,
};
