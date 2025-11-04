# 🔄 Request Flow Test Guide

## Complete User → Mechanic Request Flow

This guide helps you test the end-to-end request flow in your app.

---

## 📊 **Current Flow:**

```
USER SIDE:
1. User opens "Find Mechanic"
2. User sees list of mechanics from database
3. User clicks on a mechanic
4. User clicks "Request" button
5. System sends POST to: /api/mechanic-requests
   Data: {mechanicId, customerName, customerPhone, serviceType, location, amount}

BACKEND:
6. Request saved to database with status="PENDING"
7. Request linked to specific mechanic by mechanicId

MECHANIC SIDE:
8. Mechanic opens their dashboard
9. Dashboard fetches: GET /api/mechanic-requests/mechanic/{mechanicId}/pending
10. Mechanic sees all pending requests
11. Mechanic can Accept or Reject
12. Status updated to "ACCEPTED" or "REJECTED"
```

---

## 🧪 **Testing Steps:**

### **PART 1: Register a Test Mechanic**

1. **Open your app on vivo phone**
2. Go to **"Register as Mechanic"**
3. Fill in the form:
   ```
   Name: Test Mechanic
   Email: test@mechanic.com
   Phone: 9876543210
   Specialty: Engine Specialist
   Experience: 2-5 years
   Location: Use "Get Current Location"
   ```
4. Check "Night Time Available" (optional)
5. Accept terms and submit
6. **Note the mechanic ID from the response** (check logs)
7. Dashboard should open

---

### **PART 2: Find the Mechanic (As User)**

1. **Go back to home** (or restart app as different user)
2. Go to **"Find Mechanic"**
3. **Search for "Test Mechanic"** in the list
4. You should see your newly registered mechanic!
5. Click on the mechanic card

---

### **PART 3: Send Request**

1. In mechanic details, click **"Request"** button
2. Confirm the service request dialog
3. Click **"Pay ₹50 & Request"**
4. You should see:
   ```
   ✅ "Request Sent!" success message
   ✅ "Your request has been sent to Test Mechanic"
   ✅ Details about next steps
   ```

5. **Check the console logs:**
   ```
   Sending mechanic request: {mechanicId: X, customerName: Customer, ...}
   Request sent successfully!
   ```

---

### **PART 4: Mechanic Receives Request**

1. **Open mechanic dashboard** (the registered mechanic)
2. **Method A:** From registration success → Already at dashboard
3. **Method B:** Home → "Mechanic Dashboard"

4. **Check "Service Requests" section:**
   - Should show your pending request
   - Customer name: "Customer"
   - Service type: "General Service"
   - Amount: ₹50
   - Status: PENDING

5. **Click on the request card** to see full details:
   - Customer info
   - Service description
   - Location
   - Amount

6. **Test Actions:**
   - Click **"Accept"** → Request accepted ✅
   - OR Click **"Reject"** → Request rejected ❌

---

## ⚠️ **Current Issue & Fix:**

### **Problem:**
The mechanic dashboard is hardcoded to fetch requests for `mechanic ID = 1`:

```dart
// Line 105 in mechanic_dashboard_page.dart
Uri.parse("${ApiConfig.mechanicRequestsEndpoint}/mechanic/1/pending")
```

This means:
- ❌ Only mechanic with ID 1 will see requests
- ❌ New mechanics (ID 2, 3, etc.) won't see their requests
- ❌ All requests show up for mechanic ID 1, even if sent to others

### **Solution Needed:**
Pass the actual mechanic ID from registration to dashboard, so each mechanic sees only THEIR requests.

---

## 🔧 **API Endpoints Used:**

| Endpoint | Method | Purpose | Used By |
|----------|--------|---------|---------|
| `/api/mechanic` | POST | Register new mechanic | Registration page |
| `/api/mechanic` | GET | Get all mechanics | Finder page |
| `/api/mechanic-requests` | POST | Send request to mechanic | Finder page |
| `/api/mechanic-requests/mechanic/{id}/pending` | GET | Get mechanic's pending requests | Mechanic dashboard |
| `/api/mechanic-requests/{id}/accept` | PUT | Accept a request | Mechanic dashboard |
| `/api/mechanic-requests/{id}/reject` | PUT | Reject a request | Mechanic dashboard |

---

## 📱 **Expected Behavior:**

### **User Side:**
✅ Can find mechanics
✅ Can view mechanic details
✅ Can send request
✅ Gets confirmation
✅ Request saved to database

### **Mechanic Side:**
✅ Receives notification (not implemented yet)
✅ Sees request in dashboard
✅ Can view request details
✅ Can accept request
✅ Can reject request
✅ Status updates in real-time

---

## 🐛 **Troubleshooting:**

### **Issue: Requests not showing in dashboard**

**Check:**
1. Mechanic ID - Is dashboard looking for correct mechanic?
2. Request status - Is it "PENDING"?
3. API endpoint - Is URL correct?
4. Backend logs - Check if request reached server
5. Console logs - Check for errors

**Debug:**
```dart
// Add this to dashboard initState:
print("Fetching requests for mechanic ID: $mechanicId");
print("API URL: ${ApiConfig.mechanicRequestsEndpoint}/mechanic/$mechanicId/pending");
```

### **Issue: Request sent but not saved**

**Check:**
1. mechanicId is correct in request
2. Backend endpoint is receiving data
3. Database connection is working
4. Check EC2 backend logs

**Test manually:**
```bash
# Send test request via curl
curl -X POST http://98.93.125.193:8081/api/mechanic-requests \
  -H "Content-Type: application/json" \
  -d '{
    "mechanicId": 1,
    "customerName": "Test User",
    "customerPhone": "+91 9876543210",
    "serviceType": "Engine Service",
    "description": "Need help",
    "latitude": "12.9716",
    "longitude": "77.5946",
    "amount": 50.0
  }'
```

### **Issue: Can't accept/reject request**

**Check:**
1. Request ID is correct
2. Backend PUT endpoints are working
3. CORS is configured
4. Status field exists in database

---

## 🎯 **Test Scenarios:**

### **Scenario 1: Happy Path**
1. User finds mechanic ✅
2. User sends request ✅
3. Mechanic receives request ✅
4. Mechanic accepts request ✅
5. Status updates to ACCEPTED ✅

### **Scenario 2: Rejection**
1. User sends request ✅
2. Mechanic rejects request ❌
3. Status updates to REJECTED ✅
4. User notified (not implemented)

### **Scenario 3: Multiple Requests**
1. User A sends request to Mechanic 1 ✅
2. User B sends request to Mechanic 1 ✅
3. Mechanic 1 sees both requests ✅
4. User C sends request to Mechanic 2 ✅
5. Mechanic 2 sees only their request ⚠️ (Needs fix)

### **Scenario 4: Different Service Types**
1. Request with "Engine Service" ✅
2. Request with "Brake Service" ✅
3. Request with "General Service" ✅
4. All show in dashboard ✅

---

## 📊 **Database Schema:**

### **mechanic_requests table:**
```sql
CREATE TABLE mechanic_requests (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    mechanic_id BIGINT,
    customer_name VARCHAR(255),
    customer_phone VARCHAR(20),
    customer_email VARCHAR(255),
    service_type VARCHAR(100),
    description TEXT,
    latitude VARCHAR(50),
    longitude VARCHAR(50),
    amount DECIMAL(10,2),
    status VARCHAR(20), -- PENDING, ACCEPTED, REJECTED
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

---

## 🔍 **Verify in Database:**

### **After sending request:**
```sql
-- Check if request was saved
SELECT * FROM mechanic_requests WHERE mechanic_id = 1;

-- Check pending requests
SELECT * FROM mechanic_requests WHERE status = 'PENDING';

-- Check requests for specific mechanic
SELECT * FROM mechanic_requests 
WHERE mechanic_id = 2 AND status = 'PENDING';
```

---

## ✅ **Success Checklist:**

- [ ] Mechanic registered successfully
- [ ] Mechanic appears in finder list
- [ ] Can click on mechanic card
- [ ] Request dialog shows correct mechanic name
- [ ] Request sends successfully
- [ ] Success message appears
- [ ] Request saved to database
- [ ] Mechanic dashboard shows the request
- [ ] Request details are correct
- [ ] Can accept request
- [ ] Can reject request
- [ ] Status updates correctly

---

## 🚀 **Next Steps:**

1. **Fix mechanic ID issue** ← Current priority
2. **Add user profile** (to get real customer info)
3. **Add real-time notifications**
4. **Add request history**
5. **Add payment integration**
6. **Add rating system after service**

---

## 📝 **Notes:**

### **Current Mock Data:**
```dart
'customerName': 'Customer'  // Should come from user profile
'customerPhone': '+91 98765 43210'  // Should come from user profile
'customerEmail': 'customer@example.com'  // Should come from user profile
```

### **To Make Production Ready:**
1. Implement user authentication
2. Store user profile data
3. Use actual user info in requests
4. Add push notifications
5. Add request tracking
6. Add service completion workflow

---

**EC2 Backend:** `http://98.93.125.193:8081`
**Device:** vivo 1915 (Android 12)
**Status:** Ready to test!

---

## 🎬 **Quick Test Command:**

Open app and follow this sequence:
1. Register → "Test Mechanic"
2. Home → "Find Mechanic"
3. Find "Test Mechanic" → Request
4. Home → "Mechanic Dashboard"
5. Check for request in dashboard

**Expected:** Request appears in dashboard! 🎉


