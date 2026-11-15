const express = require('express');
const cors = require('cors');
require('dotenv').config();

const apiRoutes = require('./routes/api');
const { pool } = require('./config/db');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health Check
app.get('/health', async (req, res) => {
  try {
    const dbRes = await pool.query('SELECT current_database(), now();');
    res.status(200).json({
      status: 'UP',
      database: dbRes.rows[0].current_database,
      timestamp: dbRes.rows[0].now,
      service: 'Tissue Manufacturing Management System Backend',
    });
  } catch (error) {
    res.status(500).json({
      status: 'DOWN',
      error: error.message,
    });
  }
});

// API Routes
app.use('/api', apiRoutes);

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error',
  });
});

const server = app.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(`Tissue Manufacturing Backend running on port ${PORT}`);
  console.log(`Connected to PostgreSQL server [local-dev], Database [tissues]`);
  console.log(`API base endpoint: http://localhost:${PORT}/api`);
  console.log(`=======================================================`);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use by another running instance of node.`);
    console.error(`Please stop the existing process or use: Get-Process -Name node | Stop-Process -Force`);
    process.exit(1);
  } else {
    console.error('Server error:', err);
  }
});
