# 🚀 Quick Start: User-Mechanic Connection

## ✅ What's Been Updated

Your app now has a **fully connected** user-mechanic request system with:

1. ✅ **Backend API endpoint for completing requests** (`PUT /api/mechanic-requests/{id}/complete`)
2. ✅ **Auto-refresh mechanic dashboard** (every 30 seconds)
3. ✅ **Accept/Reject/Complete actions** persist to database
4. ✅ **Status case conversion** (PENDING → Pending for UI)
5. ✅ **Field mapping fix** (requestTime → createdAt in JSON)
6. ✅ **Comprehensive error handling** with user feedback

---

## 🎯 How to Start

### **Step 1: Start Backend**

```bash
cd backend
java -jar target/ev-charging-backend-0.0.1-SNAPSHOT.jar
```

**Expected Output:**
```
Started DemoApplication in X.XXX seconds
Tomcat started on port(s): 8081
```

**Verify Backend:**
```
Open browser: http://YOUR_IP:8081/api/mechanic-requests
Should see: [] or list of requests
```

---

### **Step 2: Run Flutter App**

```bash
flutter run
```

**Or use your batch file:**
```bash
run-app.bat
```

---

### **Step 3: Test the Flow**

#### **A. Register a Mechanic**

1. Open app → "Register as Mechanic"
2. Fill form:
   - Name: Test Mechanic
   - Email: test@mechanic.com
   - Phone: 9876543210
   - Specialty: Engine Specialist
   - Experience: 2-5 years
3. Tap "Get Current Location"
4. Submit
5. **Note the mechanic ID** from console

#### **B. Send Request as User**

1. Go to Home
2. Tap "Find Mechanic"
3. Find "Test Mechanic" in list
4. Tap mechanic card
5. Tap "Request" button
6. Confirm (₹50)
7. ✅ See success message

#### **C. Check Mechanic Dashboard**

1. Go back to mechanic registration flow or re-login as mechanic
2. Open dashboard
3. **Wait max 30 seconds** or pull down to refresh
4. You should see the new request!

**What You'll See:**
```
┌─────────────────────────────────────┐
│ Today's Schedule              (1)   │
├─────────────────────────────────────┤
│ 🔧 Customer                          │
│ General Service - 10:30              │
│ 📞 +91 9876543210                    │
│ 💵 ₹50                               │
│                                      │
│ [✅ Accept]  [❌ Decline]            │
└─────────────────────────────────────┘
```

#### **D. Accept Request**

1. Tap "Accept" button
2. Status changes to "Accepted" (green)
3. Check backend console:
   ```
   ✅ Accepting request ID: 1
   ✅ Request 1 accepted successfully
   ```

#### **E. Complete Request**

1. Tap on accepted request
2. Tap "Mark as Completed"
3. Status changes to "Completed" (blue)
4. Mechanic's completed jobs count increases

---

## 🔍 Verify Everything Works

### **Check 1: Database**
```sql
mysql -u root -p
USE dyganoxdb;
SELECT * FROM mechanic_requests ORDER BY request_time DESC LIMIT 5;
```

**You should see:**
```
+----+-------------+---------------+---------------+-----------+--------+
| id | mechanic_id | customer_name | service_type  | status    | amount |
+----+-------------+---------------+---------------+-----------+--------+
| 1  | 3           | Customer      | General Svc   | ACCEPTED  | 50.0   |
+----+-------------+---------------+---------------+-----------+--------+
```

### **Check 2: Backend Console**

**When user sends request:**
```
📥 Received Mechanic Request: MechanicRequest{id=null, mechanicId=3, ...}
✅ Request saved successfully with ID: 1
```

**When mechanic dashboard refreshes:**
```
📤 GET pending requests for mechanic: 3
📤 Found 1 pending requests
```

**When mechanic accepts:**
```
✅ Accepting request ID: 1
✅ Request 1 accepted successfully
```

### **Check 3: Flutter Console**

**When request sent:**
```
Sending mechanic request: {mechanicId: 3, customerName: Customer, ...}
Request sent successfully!
```

**When dashboard loads:**
```
Mechanic Dashboard: Fetching requests for mechanic ID: 3
API URL: http://98.93.125.193:8081/api/mechanic-requests/mechanic/3/pending
Mechanic Dashboard: Received 1 pending requests
Mechanic Dashboard: Loaded 1 bookings successfully
```

**Auto-refresh:**
```
🔄 Auto-refreshing mechanic dashboard...
Mechanic Dashboard: Fetching requests for mechanic ID: 3
```

**When accepting:**
```
Accepting booking ID: 1
✅ Booking 1 accepted successfully
```

---

## 🎯 Key Features to Test

### **1. Auto-Refresh**
- ⏱️ Dashboard auto-refreshes every 30 seconds
- 📱 Send request from user, wait 30s, should appear in mechanic dashboard
- 🔄 No manual refresh needed!

### **2. Pull-to-Refresh**
- 👆 Swipe down on dashboard
- 🔃 Loading indicator appears
- ✅ "Dashboard refreshed!" message

### **3. Status Filters**
- 📊 "All" - Shows all requests
- ⚠️ "Pending" - Shows only pending
- ✅ "Accepted" - Shows only accepted
- 🏁 "Completed" - Shows only completed

### **4. Real-time Status Updates**
- Accept → Status changes immediately
- Reject → Request disappears
- Complete → Moves to completed

### **5. Error Handling**
- ❌ Network error → "Network error. Please try again."
- ❌ Backend down → "Failed to fetch requests"
- ✅ All errors show user-friendly messages

---

## 📡 API Endpoints

All endpoints are now working:

```
POST   /api/mechanic-requests              ✅ Create request
GET    /api/mechanic-requests              ✅ Get all requests
GET    /api/mechanic-requests/mechanic/{id}/pending  ✅ Get pending
PUT    /api/mechanic-requests/{id}/accept  ✅ Accept request
PUT    /api/mechanic-requests/{id}/reject  ✅ Reject request
PUT    /api/mechanic-requests/{id}/complete ✅ Complete request (NEW!)
```

---

## 🐛 Troubleshooting

### **Problem: Requests not showing**
```bash
# 1. Check backend is running
curl http://YOUR_IP:8081/api/mechanic-requests

# 2. Check database
mysql -u root -p
USE dyganoxdb;
SELECT COUNT(*) FROM mechanic_requests;

# 3. Check Flutter API config
# File: lib/services/api_config.dart
# Verify baseUrl is correct
```

### **Problem: Auto-refresh not working**
```dart
// Check console for:
🔄 Auto-refreshing mechanic dashboard...

// If missing, restart app
// Timer should initialize on dashboard open
```

### **Problem: Accept/Reject fails**
```bash
# Test with curl:
curl -X PUT http://YOUR_IP:8081/api/mechanic-requests/1/accept

# Should return:
{"message": "Request accepted successfully", "status": "ACCEPTED"}

# If fails, check backend console for errors
```

### **Problem: Status not updating**
```
# Backend uses: PENDING, ACCEPTED, REJECTED, COMPLETED
# Flutter shows: Pending, Accepted, Rejected, Completed
# Conversion happens automatically in code
```

---

## 📊 Database Schema

**Table:** `mechanic_requests` (auto-created by JPA)

```sql
CREATE TABLE mechanic_requests (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
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
    response_time TIMESTAMP,
    
    INDEX idx_mechanic_status (mechanic_id, status)
);
```

**No manual creation needed!** Spring Boot creates it automatically.

---

## 🎉 What's Working Now

✅ User sends request → Saved to database  
✅ Mechanic dashboard → Fetches pending requests  
✅ Auto-refresh → Every 30 seconds  
✅ Pull-to-refresh → Manual refresh  
✅ Accept request → Updates database  
✅ Reject request → Updates database  
✅ Complete request → Updates database (NEW!)  
✅ Status filters → Working correctly  
✅ Error handling → User-friendly messages  
✅ Console logging → Detailed debugging info  

---

## 📚 Documentation Files

1. **USER_MECHANIC_CONNECTION_GUIDE.md** - Complete architecture guide
2. **REQUEST_FLOW_DIAGRAM.md** - Visual flow diagrams
3. **QUICK_START_USER_MECHANIC.md** - This file (quick start)
4. **REQUEST_FLOW_TEST_GUIDE.md** - Detailed testing steps

---

## 🔥 Next Steps (Optional)

1. **Add Push Notifications** - Notify mechanic of new requests
2. **User Request History** - Show user their past requests
3. **Real-time Chat** - Let user and mechanic communicate
4. **Location Tracking** - Track mechanic's arrival
5. **Payment Integration** - Handle real payments
6. **Rating System** - Let users rate mechanics

---

## 💡 Tips

1. **Always check backend console** for detailed logs
2. **Use auto-refresh** - no need to manually refresh
3. **Pull down** if you want instant refresh
4. **Check database** to verify data persistence
5. **Test with different mechanics** to see filtering

---

## ✅ Summary

Your user-mechanic connection is **100% functional**! 

- ✅ Database: Auto-created
- ✅ Backend: All endpoints working
- ✅ Frontend: User and Mechanic connected
- ✅ Real-time: Auto-refresh every 30s
- ✅ Status Management: Full lifecycle support

**Everything is connected and ready to use!** 🚀

Need help? Check the console logs - they're very detailed!

