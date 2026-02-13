# Admin Dashboard Setup Guide

## Overview

The Dyganox Admin Dashboard is a comprehensive web-based management system that allows administrators to:

- **Monitor Mechanics**: View all registered mechanics and their approval status
- **Approve/Reject Mechanics**: Review and approve mechanic registrations
- **Track Service Requests**: Monitor all service requests from users to mechanics
- **Analyze Performance**: View analytics on mechanics, requests, revenue, and payments
- **Request Tracking**: See which mechanics are responding to requests and their response times

## Architecture

### Backend Components

1. **Mechanic Model** (`Mechanic.java`)
   - Added `approvalStatus` field (PENDING, APPROVED, REJECTED)
   - Defaults to PENDING for new registrations

2. **AdminController** (`AdminController.java`)
   - `/api/admin/mechanics` - Get all mechanics
   - `/api/admin/mechanics/pending` - Get pending mechanics
   - `/api/admin/mechanics/{id}/approve` - Approve mechanic
   - `/api/admin/mechanics/{id}/reject` - Reject mechanic
   - `/api/admin/requests` - Get all service requests
   - `/api/admin/analytics` - Get analytics data
   - `/api/admin/requests/tracking` - Get request tracking data
   - `/api/admin/mechanics/{id}/performance` - Get mechanic performance

3. **MechanicController** (Updated)
   - Added `?approved=true` query parameter to filter approved mechanics
   - Mobile app now only shows approved mechanics to users

### Frontend Components

The admin dashboard is located in `/admin-dashboard/` directory:

- `index.html` - Main dashboard HTML
- `styles.css` - Modern, responsive styling
- `app.js` - Dashboard functionality and API calls
- `config.js` - API configuration

## Setup Instructions

### 1. Backend Setup

#### Step 1: Rebuild Backend

The backend needs to be recompiled to include the new `approvalStatus` field:

```bash
cd backend
mvn clean package
```

#### Step 2: Update Database

The `approvalStatus` column will be automatically added to the `mechanics` table when you restart the Spring Boot application (Hibernate will handle the migration).

Alternatively, you can manually add it:

```sql
ALTER TABLE mechanics ADD COLUMN approval_status VARCHAR(20) DEFAULT 'PENDING';
```

#### Step 3: Set Existing Mechanics

For existing mechanics in your database, you may want to set their approval status:

```sql
-- Approve all existing mechanics (optional)
UPDATE mechanics SET approval_status = 'APPROVED' WHERE approval_status IS NULL;

-- Or keep them as pending for review
UPDATE mechanics SET approval_status = 'PENDING' WHERE approval_status IS NULL;
```

#### Step 4: Restart Backend

```bash
java -jar target/demo-0.0.1-SNAPSHOT.jar
```

Or if running with Maven:

```bash
mvn spring-boot:run
```

### 2. Admin Dashboard Setup

#### Step 1: Configure API Endpoint

Edit `admin-dashboard/config.js`:

```javascript
const API_CONFIG = {
    baseUrl: 'http://YOUR_SERVER_IP:8081', // Change to your EC2 IP or localhost:8081
    // ...
};
```

**For Local Development:**
```javascript
baseUrl: 'http://localhost:8081'
```

**For EC2/Production:**
```javascript
baseUrl: 'http://34.228.113.212:8081' // Your EC2 IP
```

#### Step 2: Start Dashboard

**Option 1: Python HTTP Server**
```bash
cd admin-dashboard
python3 -m http.server 8000
```
Open: `http://localhost:8000`

**Option 2: Node.js HTTP Server**
```bash
cd admin-dashboard
npx http-server -p 8000
```

**Option 3: VS Code Live Server**
- Install "Live Server" extension
- Right-click `index.html` → "Open with Live Server"

### 3. Mobile App Update

The mobile app has been updated to:
- Only show approved mechanics to users
- Filter mechanics by `approvalStatus = 'APPROVED'`

No additional configuration needed - the app will automatically filter approved mechanics.

## Workflow

### Mechanic Registration Flow

1. **Mechanic Registers** (Mobile App)
   - Mechanic fills registration form
   - Status: `approvalStatus = "PENDING"` (default)

2. **Admin Reviews** (Admin Dashboard)
   - Admin sees mechanic in "Pending Approvals" section
   - Admin reviews mechanic details

3. **Admin Approves/Rejects**
   - **Approve**: `approvalStatus = "APPROVED"`
     - Mechanic can now receive service requests
     - Appears in user's mechanic finder
   - **Reject**: `approvalStatus = "REJECTED"`
     - Mechanic cannot receive requests
     - Hidden from users

4. **User Experience**
   - Users only see approved mechanics
   - Can request services from approved mechanics
   - Requests tracked in admin dashboard

## Features

### Dashboard Overview
- Real-time statistics
- Visual charts (requests by status, service types)
- Quick metrics (mechanics, requests, revenue)

### Mechanic Management
- View all mechanics with approval status
- Filter by approval status
- Approve/reject actions
- View individual performance

### Service Request Monitoring
- View all service requests
- Filter by status (Pending, Accepted, Completed, Rejected)
- Track request/response times
- Monitor customer-mechanic interactions

### Request Tracking
- See which mechanics are responding
- Average response times
- Acceptance/completion rates
- Identify active vs inactive mechanics

### Analytics
- Mechanic statistics
- Request statistics
- Revenue tracking
- Payment statistics
- Service type distribution

## API Endpoints Reference

### Admin Endpoints

```
GET    /api/admin/mechanics                    - Get all mechanics
GET    /api/admin/mechanics/pending             - Get pending mechanics
PUT    /api/admin/mechanics/{id}/approve       - Approve mechanic
PUT    /api/admin/mechanics/{id}/reject        - Reject mechanic
GET    /api/admin/requests                      - Get all requests
GET    /api/admin/analytics                     - Get analytics
GET    /api/admin/requests/tracking             - Get tracking data
GET    /api/admin/mechanics/{id}/performance   - Get mechanic performance
```

### User-Facing Endpoints (Updated)

```
GET    /api/mechanic?approved=true             - Get only approved mechanics (for mobile app)
```

## Security Considerations

⚠️ **Important Security Notes:**

1. **Add Authentication**: The dashboard currently has no authentication. Add login before production use.

2. **CORS Configuration**: Backend has `@CrossOrigin(origins = "*")` for development. Restrict in production:
   ```java
   @CrossOrigin(origins = "https://your-admin-domain.com")
   ```

3. **API Security**: Consider adding:
   - API key authentication
   - JWT tokens
   - Role-based access control

4. **HTTPS**: Use HTTPS in production for secure communication.

## Troubleshooting

### Dashboard Not Loading Data

1. **Check API URL**: Verify `baseUrl` in `config.js` matches your backend
2. **Check CORS**: Ensure backend CORS is enabled
3. **Check Backend**: Verify backend is running and accessible
4. **Browser Console**: Check for JavaScript errors

### Mechanics Not Appearing

1. **Check Approval Status**: Verify mechanics have `approvalStatus = 'APPROVED'`
2. **Check Database**: Query database to see mechanic records
3. **Check Backend Logs**: Look for errors in Spring Boot logs

### Approval Not Working

1. **Check Backend Logs**: Look for errors when approving
2. **Verify Endpoint**: Test endpoint with Postman/curl
3. **Check Database**: Verify `approvalStatus` column exists

## Testing

### Test Admin Dashboard

1. Open dashboard in browser
2. Navigate to "Pending Approvals"
3. Approve a mechanic
4. Verify it appears in "All Mechanics" with "APPROVED" status
5. Check mobile app - mechanic should now be visible

### Test Mobile App

1. Register a new mechanic
2. Check admin dashboard - should appear in "Pending Approvals"
3. Approve the mechanic
4. Check mobile app - mechanic should now be visible to users

## Future Enhancements

- [ ] Add authentication/login system
- [ ] Real-time updates with WebSockets
- [ ] Email notifications for pending approvals
- [ ] Export data to CSV/PDF
- [ ] Advanced search and filtering
- [ ] Map view for mechanic locations
- [ ] User management section
- [ ] Payment transaction details
- [ ] Mechanic rating and review management

## Support

For issues:
1. Check backend logs: `tail -f app.log` (if logging to file)
2. Check browser console for frontend errors
3. Verify database connection
4. Test API endpoints with Postman/curl

## Files Modified/Created

### Backend
- `backend/src/main/java/com/example/demo/model/Mechanic.java` - Added approvalStatus
- `backend/src/main/java/com/example/demo/controller/AdminController.java` - New admin endpoints
- `backend/src/main/java/com/example/demo/controller/MechanicController.java` - Added approved filter

### Frontend
- `admin-dashboard/index.html` - Dashboard UI
- `admin-dashboard/styles.css` - Styling
- `admin-dashboard/app.js` - Dashboard logic
- `admin-dashboard/config.js` - API config
- `admin-dashboard/README.md` - Dashboard docs

### Mobile App
- `lib/screens/mechanic/mechanic_finder_page.dart` - Filter approved mechanics
