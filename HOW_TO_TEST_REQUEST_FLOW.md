# 🧪 How to Test Request Flow - Step by Step

## Quick Start Test Guide

Follow these exact steps to test the complete request flow from user to mechanic.

---

## 📱 **Step 1: Register as Mechanic**

1. **Open app on your vivo phone**
2. Tap **"Register as Mechanic"**
3. Fill the form:
   ```
   Name: John Test
   Email: john@test.com  
   Phone: 9876543210
   Specialty: Engine Specialist
   Experience: 2-5 years
   Tap "Get Current Location" button
   ```
4. Check "Night Time Available"
5. Accept terms
6. Tap **"Submit Registration"**
7. ✅ Should see "Success!" and navigate to dashboard
8. **IMPORTANT:** Check logs/console for mechanic ID (e.g., "id": 3)

---

## 📱 **Step 2: Go Back to Home (Act as User)**

1. Tap **Back button** or navigate to **Home**
2. You're now acting as a customer looking for a mechanic

---

## 📱 **Step 3: Find the Mechanic**

1. From home, tap **"Find Mechanic"**
2. Wait for mechanics to load from EC2
3. Scroll to find **"John Test"** in the list
4. ✅ You should see your newly registered mechanic!
5. Tap on the **"John Test"** card

---

## 📱 **Step 4: View Mechanic Details**

1. Detail popup should appear showing:
   - Name: John Test
   - Specialty: Engine Specialist
   - Experience: 2-5 years
   - Rating: 4.x ⭐
   - Phone number
   - Availability: Available 24/7

2. You'll see two buttons:
   - **"Show Direction"** - Shows route on map
   - **"Request"** - Sends service request

---

## 📱 **Step 5: Send Request**

1. Tap **"Request"** button
2. Confirmation dialog appears:
   ```
   Request Mechanic
   Request John Test for help

   Service Fee: ₹50
   This amount will be refunded when the mechanic completes the service.

   Contact: 9876543210
   ```

3. Tap **"Pay ₹50 & Request"**
4. Loading indicator shows "Sending request to John Test..."
5. ✅ Success dialog appears:
   ```
   Request Sent!
   Your request has been sent to John Test

   What happens next:
   • Mechanic will respond within 15 minutes
   • ₹50 will be refunded after service completion
   • You can call 9876543210 for urgent help
   ```

6. Tap **"Got it!"**

---

## 📱 **Step 6: Open Mechanic Dashboard**

1. Tap **Back** to home
2. Tap **"Mechanic Dashboard"** (or **"Service Provider Dashboard"**)
3. The dashboard should load with your mechanic profile

---

## 📱 **Step 7: Check for Request**

1. Scroll down to **"Service Requests"** or **"Pending Bookings"** section
2. ✅ **YOU SHOULD SEE THE REQUEST!**
   ```
   Customer: Customer
   Service: General Service
   Amount: ₹50
   Status: Pending
   Phone: +91 98765 43210
   ```

3. Tap on the request card to see full details:
   - Customer name
   - Phone number
   - Email
   - Service type
   - Description
   - Location coordinates
   - Amount

---

## 📱 **Step 8: Accept or Reject Request**

### **To Accept:**
1. In request details, tap **"Accept"** button
2. ✅ Success message: "Request accepted successfully!"
3. Request status changes to **"Accepted"**
4. Request disappears from pending list (moved to accepted)

### **To Reject:**
1. In request details, tap **"Reject"** button
2. ⚠️ Warning: "Request rejected"
3. Request status changes to **"Rejected"**
4. Request disappears from pending list

---

## ✅ **Success Indicators:**

You'll know it's working when:

### **User Side (Finder Page):**
- ✅ Can see list of mechanics
- ✅ Can find newly registered mechanic
- ✅ Request button works
- ✅ Success message appears
- ✅ "Request Sent!" confirmation

### **Mechanic Side (Dashboard):**
- ✅ Dashboard loads correctly
- ✅ Request appears in pending bookings
- ✅ Can see customer details
- ✅ Accept button works
- ✅ Reject button works
- ✅ Request count updates

### **Console Logs:**
```
Mechanic Finder: Successfully loaded X mechanics
Sending mechanic request: {mechanicId: 3, customerName: Customer, ...}
Request sent successfully!
Mechanic Dashboard: Fetching requests for mechanic ID: 3
Mechanic Dashboard: Received 1 pending requests
Mechanic Dashboard: Loaded 1 bookings successfully
```

---

## 🐛 **Troubleshooting:**

### **Issue: Request not showing in dashboard**

**Check:**
1. Are you looking at the correct mechanic's dashboard?
2. Is the mechanicId correct in the request?
3. Check console logs for errors
4. Refresh dashboard (pull down or reopen)

**Debug:**
```
Look for these logs:
- "Mechanic Dashboard: Fetching requests for mechanic ID: X"
- "Mechanic Dashboard: Received Y pending requests"
- "Mechanic Dashboard: Loaded Y bookings successfully"
```

**Verify in Database:**
```sql
-- Check if request was saved
SELECT * FROM mechanic_requests WHERE mechanic_id = 3;

-- Check all pending requests
SELECT * FROM mechanic_requests WHERE status = 'PENDING';
```

---

### **Issue: "No requests found"**

**Possible causes:**
1. **Wrong mechanic ID** - Dashboard looking for wrong ID
2. **Request failed** - Check network errors
3. **Backend issue** - EC2 server down or database error
4. **API endpoint wrong** - Check ApiConfig

**Fix:**
```dart
// Check these in logs:
print("Mechanic ID: ${widget.mechanicData?['id']}");
print("API URL: ${ApiConfig.mechanicRequestsEndpoint}/mechanic/X/pending");
```

---

### **Issue: "Can't send request"**

**Check:**
1. Internet connection
2. EC2 backend is running
3. mechanicId is valid
4. Backend API endpoint exists

**Test manually:**
```bash
curl -X POST http://98.93.125.193:8081/api/mechanic-requests \
  -H "Content-Type: application/json" \
  -d '{
    "mechanicId": 3,
    "customerName": "Test Customer",
    "customerPhone": "+91 9876543210",
    "serviceType": "Engine Service",
    "description": "Test request",
    "latitude": "12.9716",
    "longitude": "77.5946",
    "amount": 50.0
  }'
```

---

## 📊 **What Happens in Backend:**

### **When request is sent:**
```
1. POST /api/mechanic-requests
2. Request saved to database with:
   - mechanicId: 3
   - status: "PENDING"
   - customerName, phone, etc.
3. Returns 201 Created
```

### **When dashboard opens:**
```
1. GET /api/mechanic-requests/mechanic/3/pending
2. Backend filters: WHERE mechanic_id=3 AND status='PENDING'
3. Returns array of pending requests
4. Dashboard displays them
```

### **When accept/reject:**
```
1. PUT /api/mechanic-requests/123/accept
2. Backend updates: SET status='ACCEPTED' WHERE id=123
3. Returns 200 OK
4. Dashboard refreshes and request disappears
```

---

## 🎬 **Video Test Flow:**

```
[Start] → Register Mechanic → [Home] 
   ↓
Find Mechanic → Select Mechanic → Send Request
   ↓
[Home] → Mechanic Dashboard → View Request → Accept/Reject
   ↓
[Success] ✅
```

---

## 📝 **Expected Timeline:**

| Step | Expected Time |
|------|---------------|
| Register mechanic | 30 seconds |
| Find mechanic | 5 seconds |
| Send request | 3 seconds |
| Open dashboard | 2 seconds |
| See request | Instant |
| Accept/Reject | 2 seconds |
| **Total** | **~45 seconds** |

---

## 🎯 **Test Scenarios:**

### **Scenario 1: Single Request**
- Register mechanic ✅
- Send 1 request ✅
- Check dashboard → See 1 request ✅
- Accept → Request gone ✅

### **Scenario 2: Multiple Requests**
- Send 3 requests to same mechanic ✅
- Dashboard shows all 3 ✅
- Accept one → Shows 2 remaining ✅

### **Scenario 3: Multiple Mechanics**
- Register Mechanic A (ID: 3) ✅
- Register Mechanic B (ID: 4) ✅
- Send request to Mechanic A ✅
- Open Mechanic A dashboard → See request ✅
- Open Mechanic B dashboard → See nothing ✅

### **Scenario 4: Reject Flow**
- Send request ✅
- Reject instead of accept ✅
- Request disappears ✅
- Status = "REJECTED" in database ✅

---

## ✅ **Final Checklist:**

- [ ] Mechanic registered successfully (check ID in logs)
- [ ] Mechanic appears in finder list
- [ ] Can tap on mechanic card
- [ ] Can send request
- [ ] "Request Sent!" success message
- [ ] Dashboard opens correctly
- [ ] Request visible in dashboard
- [ ] Can view request details
- [ ] Can accept request
- [ ] Can reject request
- [ ] Status updates correctly
- [ ] No errors in console
- [ ] Backend logs show API calls

---

## 🚀 **You're Ready!**

Follow the steps above **in order** and you should see the complete flow working!

**Current Setup:**
- Backend: EC2 (98.93.125.193:8081)
- Device: vivo 1915
- Status: ✅ Ready to test

**Start with Step 1!** 📱

---

## 💡 **Pro Tips:**

1. **Keep console open** to see logs
2. **Take screenshots** at each step
3. **Note the mechanic ID** when registering
4. **Test with different mechanics** to verify isolation
5. **Check backend logs** on EC2 if something fails

**Happy Testing! 🎉**


