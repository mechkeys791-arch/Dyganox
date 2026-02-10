# Database Schema - ProMech App

## 📊 Database Information

**Database Type**: PostgreSQL  
**Database Name**: `postgres`  
**Host**: `postgresforpro.cw52wo446izi.us-east-1.rds.amazonaws.com:5432`  
**Total Tables**: **5 tables**

---

## 📋 Tables Overview

### 1. **`mechanics`** Table
**Purpose**: Stores mechanic/service provider information

**Columns**:
- `id` (Long, Primary Key, Auto-generated)
- `name` (String) - Mechanic name
- `email` (String) - Email address
- `phone` (String) - Phone number
- `specialty` (String) - Service specialty
- `experience` (String) - Years of experience
- `nightTimeAvailable` (Boolean) - Available for night service
- `latitude` (String) - Location latitude
- `longitude` (String) - Location longitude

**API Endpoint**: `/api/mechanic`

---

### 2. **`mechanic_requests`** Table
**Purpose**: Stores service requests from customers to mechanics

**Columns**:
- `id` (Long, Primary Key, Auto-generated)
- `mechanicId` (Long) - Reference to mechanic
- `customerName` (String) - Customer name
- `customerPhone` (String) - Customer phone
- `customerEmail` (String) - Customer email
- `serviceType` (String) - Type of service needed
- `description` (String) - Service description
- `latitude` (String) - Service location latitude
- `longitude` (String) - Service location longitude
- `status` (String) - PENDING, ACCEPTED, REJECTED, COMPLETED
- `amount` (Double) - Service amount
- `requestTime` (LocalDateTime) - When request was created
- `responseTime` (LocalDateTime) - When mechanic responded

**API Endpoint**: `/api/mechanic-requests`

---

### 3. **`ev_providers`** Table
**Purpose**: Stores EV charging station providers

**Columns**:
- `id` (Long, Primary Key, Auto-generated)
- `name` (String) - Provider/Station name
- `phone` (String) - Contact phone
- `address` (String) - Station address
- `chargerType` (String) - Type of charger
- `rate` (String) - Charging rate
- `availableHours` (String) - Operating hours
- `latitude` (String) - Location latitude
- `longitude` (String) - Location longitude

**API Endpoint**: `/api/evprovider`

---

### 4. **`payments`** Table
**Purpose**: Stores payment transactions (Square payment gateway)

**Columns**:
- `id` (Long, Primary Key, Auto-generated)
- `paymentIntentId` (String) - Square payment intent ID
- `paymentId` (String) - Square payment ID (after success)
- `mechanicId` (Long) - Reference to mechanic
- `requestId` (Long) - Reference to mechanic request
- `amount` (Double) - Payment amount
- `currency` (String) - USD, INR, etc.
- `status` (String) - PENDING, SUCCESS, FAILED, CANCELLED
- `paymentMethod` (String) - CARD, UPI, etc.
- `customerEmail` (String) - Customer email
- `customerPhone` (String) - Customer phone
- `createdAt` (LocalDateTime) - Payment creation time
- `completedAt` (LocalDateTime) - Payment completion time
- `orderId` (String) - App's order ID

**API Endpoint**: `/api/payment/square`

---

### 5. **`person`** Table
**Purpose**: Legacy table for EV charging providers (may be deprecated in favor of `ev_providers`)

**Columns**:
- `id` (Long, Primary Key, Auto-generated)
- `name` (String) - Provider name
- `phone` (String) - Contact phone
- `address` (String) - Service address
- `chargerType` (String) - Type of charger
- `rate` (String) - Charging rate
- `availableHours` (String) - Available hours

**API Endpoint**: `/api/person`

**Note**: This appears to be an older version of EV provider data. Consider migrating to `ev_providers` table.

---

## 🔗 Table Relationships

```
mechanics (1) ──< (many) mechanic_requests
mechanic_requests (1) ──< (many) payments
```

**Relationships**:
- One mechanic can have many requests
- One request can have one payment
- Payments are linked to mechanics and requests

---

## 📈 Summary

| Table Name | Purpose | Records Type |
|------------|---------|--------------|
| `mechanics` | Mechanic profiles | Service providers |
| `mechanic_requests` | Service requests | Customer requests |
| `ev_providers` | EV charging stations | Charging providers |
| `payments` | Payment transactions | Payment records |
| `person` | Legacy EV providers | (May be deprecated) |

**Total**: **5 tables** in **1 database** (`postgres`)

---

## 🔍 How to Check Tables in Database

**Via SSH on EC2**:
```bash
# Connect to PostgreSQL
psql -h postgresforpro.cw52wo446izi.us-east-1.rds.amazonaws.com -U postgres_ForPro -d postgres

# List all tables
\dt

# Count records in each table
SELECT 'mechanics' as table_name, COUNT(*) FROM mechanics
UNION ALL
SELECT 'mechanic_requests', COUNT(*) FROM mechanic_requests
UNION ALL
SELECT 'ev_providers', COUNT(*) FROM ev_providers
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'person', COUNT(*) FROM person;
```

**Via Spring Boot Logs**:
- Check `app.log` on EC2 for Hibernate table creation logs
- Look for: `create table mechanics`, `create table mechanic_requests`, etc.

---

## ✅ Database Status

- **Database**: PostgreSQL (RDS)
- **Connection**: ✅ Connected and working
- **Tables**: 5 tables created automatically by Hibernate
- **Auto-Update**: Enabled (`spring.jpa.hibernate.ddl-auto=update`)
