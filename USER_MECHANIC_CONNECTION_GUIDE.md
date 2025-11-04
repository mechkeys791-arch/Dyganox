# 🔗 User-Mechanic Connection System Guide

## Overview

Your Dyganox app now has a **fully functional** connection between users and mechanics! When a user sends a service request, it immediately appears in the mechanic's dashboard.

---

## 🏗️ System Architecture

### Database Table: `mechanic_requests`

This table stores all service requests from users to mechanics.

**Table Structure:**
```sql
CREATE TABLE mechanic_requests (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    mechanic_id BIGINT NOT NULL,
    customer_name VARCHAR(255),
    customer_phone VARCHAR(50),
    customer_email VARCHAR(255),
    service_type VARCHAR(100),
    description TEXT,
    latitude VARCHAR(50),
    longitude VARCHAR(50),
    status VARCHAR(20),  -- PENDING, ACCEPTED, REJECTED, COMPLETED
    amount DOUBLE,
    request_time TIMESTAMP,
    response_time TIMESTAMP
);
```

**No manual table creation needed!** Spring Boot JPA automatically creates this table when you start the backend.

---

## 🔄 Complete Request Flow

### **Step 1: User Sends Request**

**Location:** `lib/screens/mechanic/mechanic_finder_page.dart`

```dart
// User clicks "Request" button on a mechanic
POST → /api/mechanic-requests

// Request Data:
{
  "mechanicId": 3,
  "customerName": "Customer",
  "customerPhone": "+91 98765 43210",
  "customerEmail": "customer@example.com",
  "serviceType": "General Service",
  "description": "Customer needs help",
  "latitude": "12.9141",
  "longitude": "74.8560",
  "amount": 50.0
}
```

### **Step 2: Backend Saves Request**

**Location:** `backend/src/main/java/com/example/demo/controller/MechanicRequestController.java`

```java
@PostMapping
public ResponseEntity<MechanicRequest> createRequest(@RequestBody MechanicRequest request) {
    request.setStatus("PENDING");  // Set initial status
    request.setRequestTime(LocalDateTime.now());  // Set timestamp
    MechanicRequest savedRequest = mechanicRequestRepo.save(request);
    return ResponseEntity.status(HttpStatus.CREATED).body(savedRequest);
}
```

### **Step 3: Mechanic Dashboard Fetches Requests**

**Location:** `lib/screens/mechanic/mechanic_service_dashboard.dart`

```dart
// Dashboard auto-refreshes every 30 seconds
GET → /api/mechanic-requests/mechanic/{mechanicId}/pending

// Returns all PENDING requests for this mechanic
[
  {
    "id": 1,
    "mechanicId": 3,
    "customerName": "Customer",
    "customerPhone": "+91 98765 43210",
    "serviceType": "General Service",
    "status": "PENDING",
    "amount": 50.0,
    "createdAt": "2024-01-15T10:30:00"
  }
]
```

### **Step 4: Mechanic Takes Action**

**Three possible actions:**

#### **Accept Request**
```dart
// Mechanic clicks "Accept"
PUT → /api/mechanic-requests/{requestId}/accept

// Backend updates status to "ACCEPTED"
// Mechanic can now see it in "Accepted" filter
```

#### **Reject Request**
```dart
// Mechanic clicks "Decline"
PUT → /api/mechanic-requests/{requestId}/reject

// Backend updates status to "REJECTED"
// Request is removed from mechanic's pending list
```

#### **Complete Request**
```dart
// After service is done, mechanic clicks "Mark as Completed"
PUT → /api/mechanic-requests/{requestId}/complete

// Backend updates status to "COMPLETED"
// Mechanic's completed job count increases
```

---

## 🚀 Key Features

### **1. Auto-Refresh Dashboard**
- ✅ Dashboard automatically refreshes every 30 seconds
- ✅ New requests appear without manual refresh
- ✅ Real-time updates when user sends request

### **2. Request Status Management**
- ✅ **PENDING** - New request from user
- ✅ **ACCEPTED** - Mechanic has accepted
- ✅ **REJECTED** - Mechanic declined
- ✅ **COMPLETED** - Service finished

### **3. Status Filters**
- ✅ Filter by: All, Pending, Accepted, Completed
- ✅ See count for each status category
- ✅ Quick navigation between statuses

### **4. Pull-to-Refresh**
- ✅ Swipe down to manually refresh
- ✅ Shows loading indicator
- ✅ Success message on refresh

---

## 🧪 How to Test

### **Test 1: Register a Mechanic**

1. Open app on your phone
2. Go to "Register as Mechanic"
3. Fill in details:
   - Name: Test Mechanic
   - Email: test@mechanic.com
   - Phone: 9876543210
   - Specialty: Engine Specialist
   - Experience: 2-5 years
4. Get current location
5. Submit registration
6. **Note the mechanic ID from logs**
7. Dashboard opens automatically

### **Test 2: Send Request as User**

1. Go back to home (act as user)
2. Tap "Find Mechanic"
3. Find "Test Mechanic" in list
4. Tap on mechanic card
5. Click "Request" button
6. Confirm request (Pay ₹50)
7. See success message

### **Test 3: Check Mechanic Dashboard**

1. Go back to mechanic dashboard (or wait 30 seconds for auto-refresh)
2. You should see the new request in "Pending Bookings"
3. Request shows:
   - Customer name
   - Phone number
   - Service type
   - Location
   - Date/Time
   - Amount

### **Test 4: Accept Request**

1. Click on the pending request
2. Click "Accept" button
3. Status changes to "Accepted" (green)
4. Request moves to "Accepted" filter
5. Backend database updated to "ACCEPTED"

### **Test 5: Complete Request**

1. In accepted requests, click request
2. Click "Mark as Completed"
3. Status changes to "Completed" (blue)
4. Mechanic's completed jobs count increases
5. Backend database updated to "COMPLETED"

---

## 📡 API Endpoints Reference

### **User Side:**
```
POST   /api/mechanic-requests              Create new request
```

### **Mechanic Side:**
```
GET    /api/mechanic-requests/mechanic/{id}/pending   Get pending requests
PUT    /api/mechanic-requests/{id}/accept             Accept request
PUT    /api/mechanic-requests/{id}/reject             Reject request  
PUT    /api/mechanic-requests/{id}/complete           Complete request
GET    /api/mechanic-requests                         Get all requests (admin)
```

---

## 🛠️ Technical Details

### **Backend (Spring Boot)**

**Model:** `MechanicRequest.java`
- JPA Entity with auto-generated ID
- Timestamps managed automatically
- JSON serialization with Jackson
- Field `requestTime` mapped to `createdAt` in JSON

**Repository:** `MechanicRequestRepo.java`
- `findByMechanicIdAndStatus()` - Get requests by mechanic and status
- `findByMechanicIdOrderByRequestTimeDesc()` - Get all mechanic requests

**Controller:** `MechanicRequestController.java`
- RESTful endpoints with proper HTTP status codes
- Exception handling with try-catch
- Console logging for debugging

### **Frontend (Flutter)**

**User Request:** `mechanic_finder_page.dart`
- Sends POST request with customer details
- Shows loading dialog during submission
- Success/error feedback to user

**Mechanic Dashboard:** `mechanic_service_dashboard.dart`
- Fetches pending requests on init
- Auto-refreshes every 30 seconds
- Pull-to-refresh support
- Status case conversion (PENDING → Pending)
- Network error handling

**Bookings Page:** `mechanic_bookings_page.dart`
- Displays all requests with filters
- Accept/Reject/Complete actions
- Real-time status updates

---

## 🔍 Troubleshooting

### **Problem: Requests not appearing in mechanic dashboard**

**Solutions:**
1. Check backend is running: `http://YOUR_IP:8081/api/mechanic-requests`
2. Verify mechanic ID matches in request and dashboard
3. Check API configuration in `api_config.dart`
4. Look for errors in backend console
5. Try manual refresh (pull down)

### **Problem: Accept/Reject not working**

**Solutions:**
1. Check network connection
2. Verify request ID is valid
3. Check backend logs for errors
3. Ensure backend endpoints are accessible
4. Test with Postman: `PUT http://YOUR_IP:8081/api/mechanic-requests/1/accept`

### **Problem: Status not updating**

**Solutions:**
1. Check status case matching (PENDING vs Pending)
2. Verify backend response status code (should be 200)
3. Check Flutter console for error messages
4. Ensure status conversion logic is working

### **Problem: Auto-refresh not working**

**Solutions:**
1. Timer should be initialized in `initState()`
2. Check timer is not null
3. Verify timer interval (30 seconds)
4. Check network connectivity
5. Look for errors in `_fetchBookings()` method

---

## 📊 Database Access

### **View All Requests (MySQL Command Line):**
```sql
-- Connect to database
mysql -u root -p

-- Select database
USE dyganoxdb;

-- View all requests
SELECT * FROM mechanic_requests;

-- View requests for specific mechanic
SELECT * FROM mechanic_requests WHERE mechanic_id = 3;

-- View pending requests
SELECT * FROM mechanic_requests WHERE status = 'PENDING';

-- View requests with customer details
SELECT id, mechanic_id, customer_name, customer_phone, service_type, status, amount, request_time 
FROM mechanic_requests 
ORDER BY request_time DESC;
```

### **No Manual Database Setup Needed!**

The `mechanic_requests` table is **automatically created** by Spring Boot JPA when you:
1. Start the backend server
2. Have proper database connection in `application.properties`

```properties
spring.jpa.hibernate.ddl-auto=update  # Auto-creates/updates tables
```

---

## ✅ What's Already Working

- ✅ User can send requests to mechanics
- ✅ Requests are saved to database
- ✅ Mechanic dashboard fetches requests
- ✅ Accept/Reject/Complete functionality
- ✅ Auto-refresh every 30 seconds
- ✅ Pull-to-refresh support
- ✅ Status filtering and counting
- ✅ Backend API endpoints
- ✅ Database persistence
- ✅ Error handling
- ✅ Status case conversion
- ✅ Real-time updates

---

## 🎯 Next Steps (Optional Enhancements)

### **1. Push Notifications**
- Notify mechanic when new request arrives
- Notify user when request is accepted/completed

### **2. User Request History**
- Add page for users to see their request history
- Show current request status to user

### **3. Real-time Updates**
- Use WebSockets for instant updates
- No need to wait for 30-second refresh

### **4. Chat Feature**
- Allow user and mechanic to chat
- Share photos of vehicle issues

### **5. Rating System**
- Let users rate mechanics after service
- Update mechanic rating in database

### **6. Payment Integration**
- Integrate payment gateway
- Handle refunds for completed services

### **7. Location Tracking**
- Show mechanic's live location to user
- Estimate arrival time

---

## 📝 Important Notes

1. **Database Table:** Auto-created by Spring Boot JPA - no manual SQL needed
2. **Status Format:** Backend uses UPPERCASE, Flutter converts to Title Case
3. **Auto-Refresh:** Dashboard refreshes every 30 seconds automatically
4. **Error Handling:** Network errors are caught and shown to user
5. **Debugging:** Check console logs for detailed request/response info

---

## 🎉 Congratulations!

Your user-mechanic connection system is **fully functional**! Users can now:
- Find nearby mechanics
- Send service requests
- Get real-time responses

And mechanics can:
- View all incoming requests
- Accept or reject requests
- Complete jobs and track earnings

**Everything is connected and working!** 🚀

