# Tissue Manufacturing Management System - Backend

Enterprise RESTful API backend for Tissue Manufacturing Management System built with Node.js, Express, and PostgreSQL stored functions.

## Features
- **Strict PostgreSQL Stored Function Layer:** 100% of business logic and queries execute via database functions (`fn_*`).
- **Standardized Response Architecture:** Returns standardized composite results matching enterprise database execution patterns.
- **Role-Based Access Control (RBAC):** Admin, Production Manager, Inventory Officer, and Operator privileges.
- **JWT Authentication:** Password hashing using bcrypt and token-based protected endpoints.
- **Comprehensive Industry Modules:**
  - Asset tracking, maintenance, and allocation
  - Vendor & supplier management
  - Customer order management
  - Production planning & batch execution with line tracking
  - Bill of materials (BOM), raw material consumption & wastage tracking
  - Inventory management with automated restock and movement logs
  - System settings and immutable activity audit logs

## Database Setup
1. Connect to PostgreSQL server (`local-dev`).
2. Run `database/00_master_setup.sql` in pgAdmin 4 or via psql CLI.

## Starting the Server
```bash
npm install
npm start
```
Default port: `5000`
Health check: `http://localhost:5000/health`
