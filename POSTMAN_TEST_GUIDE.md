# Postman Testing Guide for EV Provider API

## Important Setup Notes

Since you're running your Flutter app in Chrome browser on college WiFi, use **`localhost`** or **`127.0.0.1`** for Postman testing when both your backend and Postman are on the same machine.

---

## API Base URL
```
http://localhost:8081/api/evprovider
```

---

## 1. POST - Create New EV Provider

**URL:** `http://localhost:8081/api/evprovider`  
**Method:** `POST`  
**Headers:**
```
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "name": "John Doe",
  "phone": "9876543210",
  "address": "123 Main Street, Bangalore, Karnataka 560001",
  "chargerType": "Type 2",
  "rate": "15.50",
  "availableHours": "6PM-10PM"
}
```

**Expected Response (201 Created):**
```json
{
  "id": 1,
  "name": "John Doe",
  "phone": "9876543210",
  "address": "123 Main Street, Bangalore, Karnataka 560001",
  "chargerType": "Type 2",
  "rate": "15.50",
  "availableHours": "6PM-10PM"
}
```

---

## 2. GET - Fetch All EV Providers

**URL:** `http://localhost:8081/api/evprovider`  
**Method:** `GET`  
**Headers:** None required

**Expected Response (200 OK):**
```json
[
  {
    "id": 1,
    "name": "John Doe",
    "phone": "9876543210",
    "address": "123 Main Street, Bangalore, Karnataka 560001",
    "chargerType": "Type 2",
    "rate": "15.50",
    "availableHours": "6PM-10PM"
  },
  {
    "id": 2,
    "name": "Jane Smith",
    "phone": "8765432109",
    "address": "456 Park Avenue, Mumbai, Maharashtra 400001",
    "chargerType": "CCS",
    "rate": "18.00",
    "availableHours": "24/7"
  }
]
```

---

## 3. GET - Fetch Single EV Provider by ID

**URL:** `http://localhost:8081/api/evprovider/1`  
**Method:** `GET`  
**Headers:** None required

**Expected Response (200 OK):**
```json
{
  "id": 1,
  "name": "John Doe",
  "phone": "9876543210",
  "address": "123 Main Street, Bangalore, Karnataka 560001",
  "chargerType": "Type 2",
  "rate": "15.50",
  "availableHours": "6PM-10PM"
}
```

---

## 4. PUT - Update Existing EV Provider

**URL:** `http://localhost:8081/api/evprovider/1`  
**Method:** `PUT`  
**Headers:**
```
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "name": "John Doe Updated",
  "phone": "9876543210",
  "address": "123 Main Street, Bangalore, Karnataka 560001",
  "chargerType": "CCS",
  "rate": "20.00",
  "availableHours": "24/7"
}
```

**Expected Response (200 OK):**
```json
{
  "id": 1,
  "name": "John Doe Updated",
  "phone": "9876543210",
  "address": "123 Main Street, Bangalore, Karnataka 560001",
  "chargerType": "CCS",
  "rate": "20.00",
  "availableHours": "24/7"
}
```

---

## 5. DELETE - Delete EV Provider

**URL:** `http://localhost:8081/api/evprovider/1`  
**Method:** `DELETE`  
**Headers:** None required

**Expected Response (204 No Content)**

---

## Testing Workflow

### Step 1: Start Your Backend
```bash
cd backend
mvn spring-boot:run
```

Wait until you see: `Started DemoApplication in X seconds`

### Step 2: Test with Postman

1. **Create a provider** (POST) - Copy the returned `id`
2. **Get all providers** (GET) - Verify your data is there
3. **Get by ID** (GET) - Use the `id` from step 1
4. **Update provider** (PUT) - Use the `id` from step 1
5. **Delete provider** (DELETE) - Use the `id` from step 1

---

## Additional Test Bodies for POST/PUT

### Example 1: CCS Charger
```json
{
  "name": "Rajesh Kumar",
  "phone": "9123456789",
  "address": "78 Green Park, Delhi 110016",
  "chargerType": "CCS",
  "rate": "22.00",
  "availableHours": "9AM-10AM"
}
```

### Example 2: Tesla Charger
```json
{
  "name": "Priya Sharma",
  "phone": "8234567890",
  "address": "42 Lake Road, Pune, Maharashtra 411001",
  "chargerType": "Tesla",
  "rate": "25.00",
  "availableHours": "4PM-8PM"
}
```

### Example 3: CHAdeMO Charger
```json
{
  "name": "Amit Patel",
  "phone": "7345678901",
  "address": "15 Beach Road, Chennai, Tamil Nadu 600001",
  "chargerType": "CHAdeMO",
  "rate": "19.50",
  "availableHours": "24/7"
}
```

---

## Troubleshooting

### Issue 1: Connection Refused
**Problem:** `Connection refused` error in Postman  
**Solution:** 
- Make sure backend is running (`mvn spring-boot:run`)
- Check backend console for "Started DemoApplication"
- Verify port 8081 is not blocked

### Issue 2: Empty Response
**Problem:** GET returns `[]` empty array  
**Solution:** 
- First create data using POST
- Check backend console for database connection logs
- Verify database credentials in `application.properties`

### Issue 3: 404 Not Found
**Problem:** `404` error  
**Solution:** 
- Check the URL is exactly: `http://localhost:8081/api/evprovider`
- Make sure controller is running (check backend logs)

### Issue 4: 500 Internal Server Error
**Problem:** `500` error  
**Solution:**
- Check backend console for detailed error logs
- Verify database connection
- Check if all required fields are provided in request body

---

## Database Table Info

**Table Name:** `ev_providers`

**Columns:**
- `id` (BIGINT, Primary Key, Auto-increment)
- `name` (VARCHAR)
- `phone` (VARCHAR)
- `address` (VARCHAR)
- `charger_type` (VARCHAR)
- `rate` (VARCHAR)
- `available_hours` (VARCHAR)

The table will be created automatically when you start the backend (thanks to `spring.jpa.hibernate.ddl-auto=update`).

---

## Notes for College WiFi

Since you're on college WiFi:
- **For Postman testing:** Use `localhost` or `127.0.0.1`
- **For Flutter app in Chrome:** Use `localhost` or `127.0.0.1`
- Both your Flutter app and backend must be running on the **same machine**
- If you need to test from a different device, you'll need to find your machine's local IP address and update the Flutter app accordingly

