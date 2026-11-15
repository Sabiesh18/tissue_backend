const { executeFunction } = require('../config/db');

const getDashboardMetrics = async (req, res) => {
  try {
    const result = await executeFunction('fn_get_dashboard_metrics', []);
    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
      data: result.data || {},
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getDashboardMetrics,
};
