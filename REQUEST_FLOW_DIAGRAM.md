# 🔄 Request Flow Diagram

## Visual Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         USER SENDS REQUEST                                │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  📱 User App (mechanic_finder_page.dart)                                 │
│                                                                           │
│  User Action:                                                             │
│  1. Opens "Find Mechanic"                                                 │
│  2. Sees list of mechanics from database                                  │
│  3. Clicks on a mechanic                                                  │
│  4. Clicks "Request" button                                               │
│  5. Confirms request (₹50 payment)                                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTP POST
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  🌐 API Endpoint: POST /api/mechanic-requests                            │
│                                                                           │
│  Request Body:                                                            │
│  {                                                                        │
│    "mechanicId": 3,                                                       │
│    "customerName": "Customer Name",                                       │
│    "customerPhone": "+91 9876543210",                                     │
│    "customerEmail": "customer@example.com",                               │
│    "serviceType": "General Service",                                      │
│    "description": "Customer needs help",                                  │
│    "latitude": "12.9141",                                                 │
│    "longitude": "74.8560",                                                │
│    "amount": 50.0                                                         │
│  }                                                                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  💾 Backend Controller (MechanicRequestController.java)                  │
│                                                                           │
│  Processing:                                                              │
│  1. Receives request data                                                 │
│  2. Sets status = "PENDING"                                               │
│  3. Sets requestTime = now()                                              │
│  4. Saves to database                                                     │
│  5. Returns saved request with ID                                         │
│                                                                           │
│  Console Output:                                                          │
│  📥 Received Mechanic Request: {id=null, mechanicId=3, ...}              │
│  ✅ Request saved successfully with ID: 1                                │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  🗃️ Database Table: mechanic_requests                                    │
│                                                                           │
│  id  mechanic_id  customer_name  service_type   status   amount  time   │
│  ──  ───────────  ─────────────  ────────────   ──────   ──────  ────   │
│  1   3            Customer       General Svc    PENDING  50.0    10:30  │
│  2   5            John Doe       Engine Svc     ACCEPTED 150.0   09:15  │
│  3   3            Jane Smith     Brake Svc      PENDING  80.0    11:45  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │
        ┌───────────────────────────┴───────────────────────────┐
        │                                                         │
        │  🔄 AUTO-REFRESH (Every 30 seconds)                    │
        │                                                         │
        ▼                                                         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  📱 Mechanic Dashboard (mechanic_service_dashboard.dart)                 │
│                                                                           │
│  Automatic Actions:                                                       │
│  1. Timer.periodic(30 seconds) triggers                                   │
│  2. Calls _fetchBookings()                                                │
│  3. Sends GET request to backend                                          │
│  4. Updates UI with new requests                                          │
│                                                                           │
│  Manual Actions:                                                          │
│  • Pull down to refresh                                                   │
│  • Tap "Bookings" to see all                                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTP GET
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  🌐 API Endpoint: GET /api/mechanic-requests/mechanic/{id}/pending      │
│                                                                           │
│  Query: mechanic_id = 3 AND status = "PENDING"                           │
│                                                                           │
│  Response:                                                                │
│  [                                                                        │
│    {                                                                      │
│      "id": 1,                                                             │
│      "mechanicId": 3,                                                     │
│      "customerName": "Customer",                                          │
│      "customerPhone": "+91 9876543210",                                   │
│      "serviceType": "General Service",                                    │
│      "status": "PENDING",                                                 │
│      "amount": 50.0,                                                      │
│      "createdAt": "2024-01-15T10:30:00"                                   │
│    },                                                                     │
│    {                                                                      │
│      "id": 3,                                                             │
│      "mechanicId": 3,                                                     │
│      ...                                                                  │
│    }                                                                      │
│  ]                                                                        │
│                                                                           │
│  Console Output:                                                          │
│  📤 GET pending requests for mechanic: 3                                 │
│  📤 Found 2 pending requests                                             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  📊 Dashboard UI Display                                                  │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ Today's Schedule                                            (2) │    │
│  ├─────────────────────────────────────────────────────────────────┤    │
│  │                                                                 │    │
│  │  🔧 Customer                               ⚠️ PENDING         │    │
│  │  General Service - 10:30                                       │    │
│  │  📞 +91 9876543210                                             │    │
│  │  💵 ₹50                                                        │    │
│  │                                                                 │    │
│  │  [✅ Accept]  [❌ Decline]                                     │    │
│  │                                                                 │    │
│  ├─────────────────────────────────────────────────────────────────┤    │
│  │                                                                 │    │
│  │  🔧 Jane Smith                             ⚠️ PENDING         │    │
│  │  Brake Service - 11:45                                         │    │
│  │  📞 +91 8765432109                                             │    │
│  │  💵 ₹80                                                        │    │
│  │                                                                 │    │
│  │  [✅ Accept]  [❌ Decline]                                     │    │
│  │                                                                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ MECHANIC CLICKS ACTION
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  🎯 Mechanic Actions                                                      │
│                                                                           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │
│  │   Accept     │    │   Reject     │    │   Complete   │              │
│  │   Request    │    │   Request    │    │   Request    │              │
│  └──────────────┘    └──────────────┘    └──────────────┘              │
│         │                    │                    │                      │
│         ▼                    ▼                    ▼                      │
│  PUT /accept         PUT /reject        PUT /complete                    │
│  Status→ACCEPTED     Status→REJECTED    Status→COMPLETED                │
│                                                                           │
│  Backend Updates Database ✅                                             │
│  Dashboard Refreshes UI ✅                                               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Status State Transitions

```
NEW REQUEST
    ↓
PENDING ────┐
    │       │
    ▼       ▼
ACCEPTED  REJECTED
    │       
    ▼       
COMPLETED   
```

**Allowed Transitions:**
- PENDING → ACCEPTED ✅
- PENDING → REJECTED ✅
- ACCEPTED → COMPLETED ✅
- REJECTED → (end state) ❌
- COMPLETED → (end state) ❌

---

## Data Flow Timeline

```
Time    User Side                Backend                  Mechanic Side
────    ─────────                ───────                  ─────────────
10:30   User finds mechanic      →                        
10:30   Clicks "Request"         →                        
10:30   Confirms ₹50             → POST /requests         
10:30                            → Saves to DB            
10:30                            ← Returns ID: 1          
10:30   ✅ Success message       ←                        
10:31                                                     ← Dashboard refreshes
10:31                                                     ← Shows new request
10:32                                                     Mechanic clicks Accept
10:32                            ← PUT /accept            
10:32                            → Updates DB             
10:32                            → Status = ACCEPTED      
10:32                                                     ← ✅ Request accepted
```

---

## Component Interaction Map

```
┌─────────────────────────────────────────────────────────────────┐
│                     FLUTTER APP (Frontend)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  User Components                    Mechanic Components          │
│  ────────────────                   ───────────────────         │
│  • homepage.dart                    • mechanic_service_          │
│  • mechanic_finder_page.dart          dashboard.dart            │
│  • emergency_assistance_page.dart   • mechanic_bookings_        │
│                                        page.dart                 │
│                    │                                 │           │
│                    └────────────┬────────────────────┘           │
│                                 │                                │
└─────────────────────────────────┼────────────────────────────────┘
                                  │
                        ┌─────────▼──────────┐
                        │   ApiConfig.dart   │
                        │  baseUrl: EC2 IP   │
                        └─────────┬──────────┘
                                  │
                                  │ HTTP/REST API
                                  │
┌─────────────────────────────────▼────────────────────────────────┐
│                SPRING BOOT BACKEND (Java)                         │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Controllers              Repository              Models          │
│  ───────────             ──────────              ──────          │
│  • MechanicRequest       • MechanicRequest       • MechanicRequest│
│    Controller              Repo                    .java          │
│  • MechanicController    • MechanicRepo          • Mechanic.java │
│                                                                   │
│                           │                                       │
└───────────────────────────┼───────────────────────────────────────┘
                            │
                            │ JPA/Hibernate
                            │
┌───────────────────────────▼───────────────────────────────────────┐
│                    MySQL DATABASE                                  │
├───────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Tables:                                                           │
│  • mechanic_requests (auto-created by JPA)                        │
│  • mechanics (mechanic profiles)                                  │
│  • ev_providers (charging stations)                               │
│  • persons (users)                                                │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## Key Integration Points

### **1. User → Backend**
```
mechanic_finder_page.dart
    ↓ (HTTP POST)
ApiConfig.mechanicRequestsEndpoint
    ↓
http://YOUR_IP:8081/api/mechanic-requests
    ↓
MechanicRequestController.createRequest()
    ↓
mechanicRequestRepo.save()
    ↓
Database: mechanic_requests table
```

### **2. Backend → Mechanic**
```
mechanic_service_dashboard.dart
    ↓ (HTTP GET every 30s)
http://YOUR_IP:8081/api/mechanic-requests/mechanic/3/pending
    ↓
MechanicRequestController.getPendingRequests()
    ↓
mechanicRequestRepo.findByMechanicIdAndStatus()
    ↓
Returns List<MechanicRequest>
    ↓
Dashboard displays in UI
```

### **3. Mechanic Actions → Backend**
```
mechanic_service_dashboard.dart (Accept button)
    ↓ (HTTP PUT)
http://YOUR_IP:8081/api/mechanic-requests/1/accept
    ↓
MechanicRequestController.acceptRequest()
    ↓
request.setStatus("ACCEPTED")
    ↓
mechanicRequestRepo.save()
    ↓
Database updated
    ↓
Response sent back to Flutter
    ↓
UI updates locally
```

---

## Summary

✅ **3 Components** (User App, Backend, Mechanic App)  
✅ **1 Database Table** (mechanic_requests)  
✅ **6 API Endpoints** (Create, Get Pending, Accept, Reject, Complete, Get All)  
✅ **4 Status States** (PENDING, ACCEPTED, REJECTED, COMPLETED)  
✅ **Auto-refresh** (Every 30 seconds)  
✅ **Real-time updates** (Via HTTP polling)

**Everything is connected and working!** 🎉

