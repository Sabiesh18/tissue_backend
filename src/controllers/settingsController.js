const bcrypt = require('bcryptjs');
const { executeFunction } = require('../config/db');

// Users
const getAllUsers = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const search = req.query.search || null;
    const roleName = req.query.roleName || null;

    const result = await executeFunction('fn_user_get_all', [page, limit, search, roleName]);
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

const saveUser = async (req, res) => {
  try {
    const { userId, username, fullName, email, phone, roleId, roleName, isActive, password } = req.body;
    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    let passwordHash = null;
    if (password) {
      passwordHash = await bcrypt.hash(password, 10);
    }

    const result = await executeFunction('fn_user_save', [
      userId || null,
      username,
      fullName,
      email || null,
      phone || null,
      roleId || null,
      roleName || 'OPERATOR',
      isActive !== undefined ? isActive : true,
      passwordHash,
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

// Roles
const getAllRoles = async (req, res) => {
  try {
    const result = await executeFunction('fn_role_get_all', []);
    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
      data: result.data || [],
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// Settings
const getSettings = async (req, res) => {
  try {
    const result = await executeFunction('fn_system_settings_get_all', []);
    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
      data: result.data || [],
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

const saveSetting = async (req, res) => {
  try {
    const { settingKey, settingValue, category, description } = req.body;
    const actorId = req.user ? req.user.userId : null;
    const actorName = req.user ? req.user.username : 'SYSTEM';

    const result = await executeFunction('fn_system_setting_save', [
      settingKey,
      settingValue,
      category || 'GENERAL',
      description || null,
      actorId,
      actorName,
    ]);

    return res.status(200).json({
      success: result.isSuccessful,
      message: result.resMsg,
      data: result.data,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// Activity Logs
const getActivityLogs = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '50', 10);
    const module = req.query.module || null;
    const activityType = req.query.activityType || null;

    const result = await executeFunction('fn_get_activity_history', [page, limit, module, activityType]);
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
  getAllUsers,
  saveUser,
  getAllRoles,
  getSettings,
  saveSetting,
  getActivityLogs,
};
