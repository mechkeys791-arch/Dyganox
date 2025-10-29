# Mechanic Registration & Dashboard Flow

## 🔄 Complete Data Flow

This document explains how mechanic data flows from registration to the dashboard using real database data.

---

## 📋 Step-by-Step Flow

### **Step 1: User Type Selection**
```
User selects "I'm a Mechanic"
    ↓
Navigates to Registration Form
```

### **Step 2: Registration Form**
Mechanic fills out:
- ✅ Full Name
- ✅ Email
- ✅ Phone Number
- ✅ Specialty (dropdown)
- ✅ Experience (dropdown)
- ✅ Location (GPS coordinates)
- ✅ Night Service Availability (checkbox)

### **Step 3: Form Submission**
```dart
POST http://10.73.102.113:8081/api/mechanic
Headers: { "Content-Type": "application/json" }
Body: {
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "+91 9876543210",
  "specialty": "General Repair",
  "experience": "5-10 years",
  "nightTimeAvailable": true,
  "latitude": "12.9716",
  "longitude": "77.5946"
}
```

### **Step 4: Backend Processing**
```java
// MechanicController.java
@PostMapping
public ResponseEntity<Mechanic> createMechanic(@RequestBody Mechanic mechanic) {
    Mechanic savedMechanic = mechanicRepo.save(mechanic);
    return ResponseEntity.status(HttpStatus.CREATED).body(savedMechanic);
}
```

**Database Table:** `mechanics`
- Inserts new row
- Auto-generates ID
- Returns complete mechanic object

### **Step 5: Response Received**
```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "+91 9876543210",
  "specialty": "General Repair",
  "experience": "5-10 years",
  "nightTimeAvailable": true,
  "latitude": "12.9716",
  "longitude": "77.5946"
}
```

### **Step 6: Parse Response**
```dart
Map<String, dynamic> savedMechanicData = jsonDecode(response.body);

// Add default values for new mechanics
savedMechanicData['rating'] = 0.0;           // New mechanics start with 0 rating
savedMechanicData['completedJobs'] = 0;      // No jobs completed yet
```

### **Step 7: Navigate to Dashboard**
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => MechanicServiceDashboard(
      mechanicData: savedMechanicData,  // Real data from database!
    ),
  ),
);
```

### **Step 8: Dashboard Loads with Real Data**
```dart
// Dashboard displays:
- Name: "John Doe" (from database)
- Specialty: "General Repair" (from database)
- Experience: "5-10 years" (from database)
- Phone: "+91 9876543210" (from database)
- Email: "john@example.com" (from database)
- Rating: 0.0 (new mechanic)
- Completed Jobs: 0 (new mechanic)
- Night Service: Available (from database)
```

---

## 🎯 Two Scenarios

### **Scenario 1: Backend Available** ✅

```
Registration Form
    ↓
Submit to Backend
    ↓
Backend saves to PostgreSQL
    ↓
Returns mechanic object with ID
    ↓
Parse response
    ↓
Navigate to Dashboard with DATABASE DATA
    ↓
Dashboard shows real name, email, specialty, etc.
```

### **Scenario 2: Backend Unavailable** 🟠

```
Registration Form
    ↓
Try to submit (timeout after 5 seconds)
    ↓
Catch error
    ↓
Show warning: "Backend not available"
    ↓
Navigate to Dashboard with FORM DATA
    ↓
Dashboard shows submitted data (not saved to DB)
    ↓
Rating: 0.0, Jobs: 0 (defaults)
```

---

## 📊 Data Mapping

### From Form → Database → Dashboard

| Form Field | Database Column | Dashboard Field |
|------------|-----------------|-----------------|
| Full Name | `name` | Profile Name |
| Email | `email` | Profile Email |
| Phone | `phone` | Profile Phone |
| Specialty | `specialty` | Profile Specialty |
| Experience | `experience` | Profile Experience |
| Latitude | `latitude` | Location Data |
| Longitude | `longitude` | Location Data |
| Night Service | `nightTimeAvailable` | Night Service Badge |
| - | `id` (auto) | Mechanic ID |

### Default Values (New Mechanics)

| Field | Default Value | Reason |
|-------|---------------|--------|
| `rating` | 0.0 | No reviews yet |
| `completedJobs` | 0 | No jobs done yet |

---

## 🔧 Backend API Details

### Endpoint
```
POST /api/mechanic
```

### Request Headers
```json
{
  "Content-Type": "application/json"
}
```

### Request Body Schema
```json
{
  "name": String (required),
  "email": String (required),
  "phone": String (required),
  "specialty": String (required),
  "experience": String (required),
  "nightTimeAvailable": Boolean (required),
  "latitude": String (required),
  "longitude": String (required)
}
```

### Success Response (201 Created)
```json
{
  "id": Long (auto-generated),
  "name": String,
  "email": String,
  "phone": String,
  "specialty": String,
  "experience": String,
  "nightTimeAvailable": Boolean,
  "latitude": String,
  "longitude": String
}
```

### Error Response (500)
```json
{
  "error": "Error message"
}
```

---

## 🎨 Dashboard Updates

The dashboard now receives and displays:

### **Profile Card**
- ✅ Real name from database
- ✅ Real specialty from database
- ✅ Real experience from database
- ✅ Rating (0.0 for new mechanics)
- ✅ Status badge (Available/Busy/Offline)

### **Profile Edit Page**
When clicking profile:
- ✅ Pre-filled with database data
- ✅ Can edit all fields
- ✅ Can update location
- ✅ Can toggle night service
- ✅ Saves changes back to state

### **Statistics**
- ✅ Total Jobs: 0 (new mechanic)
- ✅ Pending: Based on bookings
- ✅ Today: Based on bookings

---

## 💾 Data Persistence

### What's Saved to Database:
✅ All registration form fields
✅ Auto-generated ID
✅ Timestamp (automatic in PostgreSQL)

### What's NOT Saved (Yet):
❌ Profile picture (base64 can be added)
❌ Rating (calculated from reviews)
❌ Completed jobs count (incremented on job completion)
❌ Services list (separate table needed)
❌ Bookings (separate table with foreign key)

---

## 🔐 Data Integrity

### Validation Layers

**1. Frontend (Flutter)**
- Form validation (required fields)
- Email format validation
- Phone number length check
- Coordinate format check

**2. Backend (Spring Boot)**
- JPA entity validation
- Database constraints
- Exception handling

**3. Database (PostgreSQL)**
- NOT NULL constraints
- Data type enforcement
- Primary key uniqueness

---

## 🧪 Testing Guide

### Test Registration Flow:

1. **Start Backend:**
   ```bash
   cd backend
   mvn spring-boot:run
   ```

2. **Run Flutter App:**
   ```bash
   flutter run
   ```

3. **Navigate:**
   - Splash → Login → User Type Selection
   - Click "I'm a Mechanic"
   - Fill registration form
   - Submit

4. **Verify Backend:**
   ```bash
   # Check backend console logs
   📥 Received Mechanic data: Mechanic{name='John Doe'...}
   ✅ Mechanic saved successfully with ID: 1
   ```

5. **Verify Database:**
   ```sql
   SELECT * FROM mechanics;
   -- Should show new row with all data
   ```

6. **Verify Dashboard:**
   - Should open automatically
   - Should show submitted name, specialty, etc.
   - Should show rating: 0.0
   - Should show jobs: 0

---

## 🔍 Debugging

### If Dashboard Shows Wrong Data:

**Check 1: Backend Response**
```dart
print("Response: ${response.body}");
// Should print complete mechanic object with ID
```

**Check 2: Parsed Data**
```dart
print("Saved Mechanic Data: $savedMechanicData");
// Should have all fields including ID
```

**Check 3: Dashboard Receives Data**
```dart
// In MechanicServiceDashboard initState:
print("Received mechanic data: ${widget.mechanicData}");
```

### Common Issues:

**Issue: Dashboard shows "John Mechanic" instead of submitted name**
- ✅ Fixed: Dashboard now loads from `widget.mechanicData`
- Backend response is parsed and passed correctly

**Issue: Rating shows 4.8 instead of 0.0**
- ✅ Fixed: Default rating is set to 0.0 for new mechanics

**Issue: Jobs shows 127 instead of 0**
- ✅ Fixed: Default completedJobs is set to 0 for new mechanics

---

## 📈 Future Enhancements

### Phase 2: Full Backend Integration

1. **Update Profile:**
   ```
   PUT /api/mechanic/{id}
   Body: Updated fields
   ```

2. **Get Bookings:**
   ```
   GET /api/mechanic/{id}/bookings
   Response: List of customer bookings
   ```

3. **Update Services:**
   ```
   PUT /api/mechanic/{id}/services
   Body: ["General Repair", "Engine Service"]
   ```

4. **Update Rating:**
   ```
   Calculated from customer reviews
   Average of all review ratings
   ```

5. **Update Job Count:**
   ```
   Incremented when job marked as completed
   Updated in real-time
   ```

---

## ✅ Summary

**Registration Flow:**
1. Fill form → Submit → Backend saves → Returns data → Parse response → Navigate with DB data

**Dashboard:**
- Displays real mechanic data from database
- Shows ID, name, email, phone, specialty, experience
- Sets rating to 0.0 for new mechanics
- Sets completed jobs to 0 for new mechanics
- Updates when profile is edited

**Data Flow:**
- Form → Backend → PostgreSQL → Backend → Flutter → Dashboard ✅

**Status:** Complete & Working! 🚀

