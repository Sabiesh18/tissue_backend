const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'tissues',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('connect', () => {
  // console.log('Connected to PostgreSQL local-dev [tissues]');
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle PostgreSQL client', err);
});

/**
 * Execute a PostgreSQL stored function exclusively.
 * As per architecture requirements, no raw table queries are run directly.
 * 
 * @param {string} functionName - e.g. 'fn_get_dashboard_metrics'
 * @param {Array} params - parameters to pass into the function
 * @returns {Promise<Object>} standardized DbExecutionResult
 */
const executeFunction = async (functionName, params = []) => {
  const client = await pool.connect();
  try {
    const placeholders = params.map((_, i) => `$${i + 1}`).join(', ');
    const query = `SELECT * FROM ${functionName}(${placeholders});`;
    const res = await client.query(query, params);
    
    if (res.rows && res.rows.length > 0) {
      const row = res.rows[0];
      return {
        isSuccessful: row.is_successful,
        resCode: row.res_code,
        resMsg: row.res_msg,
        createdId: row.created_id,
        totalRecords: row.total_records,
        maxPages: row.max_pages,
        data: row.result_data,
      };
    }
    return {
      isSuccessful: true,
      resCode: 'EMPTY',
      resMsg: 'No records returned',
      data: null,
    };
  } catch (error) {
    console.error(`Error executing database function ${functionName}:`, error.message);
    throw error;
  } finally {
    client.release();
  }
};

module.exports = {
  pool,
  executeFunction,
};
