const { executeFunction } = require('../config/db');

const getAllCustomers = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const search = req.query.search || null;
    const status = req.query.status || null;

    const result = await executeFunction('fn_customer_get_all', [page, limit, search, status]);
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

const saveCustomer = async (req, res) => {
  try {
    const {
      customerId,
      customerCode,
      customerName,
      companyName,
      contactPerson,
      email,
      phone,
      taxNumber,
      billingAddress,
      city,
      state,
      postalCode,
      customerStatus,
      creditLimit,
      notes,
    } = req.body;

    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_customer_save', [
      customerId || null,
      customerCode,
      customerName,
      companyName || null,
      contactPerson || null,
      email || null,
      phone || null,
      taxNumber || null,
      billingAddress || null,
      city || null,
      state || null,
      postalCode || null,
      customerStatus || 'ACTIVE',
      parseFloat(creditLimit || 0),
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

const deleteCustomer = async (req, res) => {
  try {
    const { id } = req.params;
    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_customer_delete', [id, actorId, actorName]);
    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getAllCustomers,
  saveCustomer,
  deleteCustomer,
};
