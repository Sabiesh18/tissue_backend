const { executeFunction } = require('../config/db');

// Purchase Orders
const getAllPurchaseOrders = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const search = req.query.search || null;
    const status = req.query.status || null;

    const result = await executeFunction('fn_purchase_order_get_all', [page, limit, search, status]);
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

const savePurchaseOrder = async (req, res) => {
  try {
    const {
      poId,
      poNumber,
      vendorId,
      vendorName,
      orderDate,
      expectedDeliveryDate,
      subtotal,
      taxAmount,
      totalAmount,
      paidAmount,
      paymentStatus,
      orderStatus,
      items,
      notes,
    } = req.body;

    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_purchase_order_save', [
      poId || null,
      poNumber,
      vendorId,
      vendorName,
      orderDate,
      expectedDeliveryDate || null,
      parseFloat(subtotal || 0),
      parseFloat(taxAmount || 0),
      parseFloat(totalAmount || 0),
      parseFloat(paidAmount || 0),
      paymentStatus || 'UNPAID',
      orderStatus || 'PENDING',
      JSON.stringify(items || []),
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

// Sales Orders
const getAllSalesOrders = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const search = req.query.search || null;
    const status = req.query.status || null;

    const result = await executeFunction('fn_sales_order_get_all', [page, limit, search, status]);
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

const saveSalesOrder = async (req, res) => {
  try {
    const {
      soId,
      soNumber,
      customerId,
      customerName,
      orderDate,
      deliveryDate,
      subtotal,
      discountAmount,
      taxAmount,
      totalAmount,
      paidAmount,
      paymentStatus,
      orderStatus,
      shippingAddress,
      items,
      notes,
    } = req.body;

    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_sales_order_save', [
      soId || null,
      soNumber,
      customerId,
      customerName,
      orderDate,
      deliveryDate || null,
      parseFloat(subtotal || 0),
      parseFloat(discountAmount || 0),
      parseFloat(taxAmount || 0),
      parseFloat(totalAmount || 0),
      parseFloat(paidAmount || 0),
      paymentStatus || 'UNPAID',
      orderStatus || 'CONFIRMED',
      shippingAddress || null,
      JSON.stringify(items || []),
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

module.exports = {
  getAllPurchaseOrders,
  savePurchaseOrder,
  getAllSalesOrders,
  saveSalesOrder,
};
