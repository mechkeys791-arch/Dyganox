# Admin Dashboard - Complete Features List

## ✅ All Features Implemented

### 1. **User Management** 👥
- ✅ View all users
- ✅ Search by phone/email
- ✅ View user bookings & history
- ✅ User profile details (name, email, phone, DOB, gender)

### 2. **Mechanic Management** 🔧
- ✅ View all mechanics
- ✅ Preview mechanic profile (full details)
- ✅ Upload/view documents (document URLs management)
- ✅ Approve/reject mechanic
- ✅ Block/unblock mechanic
- ✅ Suspend/unsuspend mechanic
- ✅ Manually add mechanic (admin creation)
- ✅ View mechanic performance metrics

### 3. **Live Tracking** 📍
- ✅ View mechanic locations on Google Maps
- ✅ Filter by online/offline status
- ✅ Track active jobs (requests with ACCEPTED status)
- ✅ Real-time location updates
- ✅ Last location update timestamp
- ✅ Map visualization with markers

### 4. **Service Request Monitoring** 📋
- ✅ View all service requests
- ✅ Filter by status (Pending, Accepted, Completed, Rejected)
- ✅ Track request and response times
- ✅ View customer and mechanic information

### 5. **Request Tracking** 🗺️
- ✅ Monitor which mechanics are responding to requests
- ✅ Average response times per mechanic
- ✅ Acceptance and completion rates
- ✅ Identify active vs inactive mechanics

### 6. **Analytics & Dashboard** 📊
- ✅ Real-time statistics and metrics
- ✅ Visual charts (requests by status, service types)
- ✅ Revenue tracking
- ✅ Payment statistics
- ✅ Mechanic statistics
- ✅ Request statistics

## Backend Endpoints Added

### User Management
- `GET /api/admin/users` - Get all users
- `GET /api/admin/users/search?query=...` - Search users
- `GET /api/admin/users/{email}/bookings` - Get user bookings

### Enhanced Mechanic Management
- `GET /api/admin/mechanics/{id}/profile` - Get mechanic profile
- `PUT /api/admin/mechanics/{id}/documents` - Update documents
- `PUT /api/admin/mechanics/{id}/block` - Block mechanic
- `PUT /api/admin/mechanics/{id}/unblock` - Unblock mechanic
- `PUT /api/admin/mechanics/{id}/suspend` - Suspend mechanic
- `PUT /api/admin/mechanics/{id}/unsuspend` - Unsuspend mechanic
- `POST /api/admin/mechanics/create` - Manually create mechanic

### Live Tracking
- `GET /api/admin/mechanics/locations?filter=online|offline` - Get mechanic locations
- `PUT /api/admin/mechanics/{id}/location` - Update mechanic location (for mobile app)
- `GET /api/admin/jobs/active` - Get active jobs

## Database Schema Updates

### Mechanics Table - New Fields
- `is_blocked` (boolean) - Whether mechanic is blocked
- `is_suspended` (boolean) - Whether mechanic is suspended
- `is_online` (boolean) - Online/offline status
- `current_latitude` (String) - Current live location latitude
- `current_longitude` (String) - Current live location longitude
- `last_location_update` (LocalDateTime) - Last location update time
- `document_urls` (String, 2000 chars) - JSON array of document URLs

## Setup Instructions

### 1. Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/google/maps-apis)
2. Create a new project or select existing
3. Enable "Maps JavaScript API"
4. Create credentials (API Key)
5. Replace `YOUR_GOOGLE_MAPS_API_KEY` in `index.html` with your actual key

**Note**: If you don't have a Google Maps API key, the maps will not load, but all other features will work.

### 2. Backend Setup

The new fields will be automatically added to the database when you restart the Spring Boot application (Hibernate auto-update).

### 3. Mobile App Integration

To enable live location tracking from mobile app, mechanics need to call:
```
PUT /api/admin/mechanics/{id}/location
Body: { "latitude": "...", "longitude": "..." }
```

This updates the mechanic's current location and sets `isOnline = true`.

## Feature Details

### User Management
- **View All Users**: Lists all registered users (filtered from `person` table where email exists)
- **Search**: Real-time search by name, email, or phone number
- **Bookings**: View complete booking history for any user

### Mechanic Management
- **Profile Preview**: Full mechanic details including statistics
- **Documents**: Upload/view mechanic documents (stored as JSON array of URLs)
- **Block/Suspend**: Temporarily disable mechanic access
- **Manual Creation**: Admins can create mechanics directly (auto-approved)

### Live Tracking
- **Google Maps**: Visual map showing all mechanic locations
- **Online/Offline Filter**: Filter mechanics by online status
- **Active Jobs Map**: Shows active service requests with mechanic and service locations
- **Location Updates**: Real-time location tracking (updated by mobile app)

### Privacy Note
⚠️ **Important**: User locations are NOT tracked continuously. Only mechanic locations are tracked for service delivery purposes.

## Usage Examples

### Block a Mechanic
1. Go to "Mechanics" section
2. Find the mechanic
3. Click "Block" button
4. Mechanic will be blocked and cannot receive requests

### View User Bookings
1. Go to "User Management" section
2. Search for user by email/phone
3. Click "View Bookings" button
4. See complete booking history

### Track Active Jobs
1. Go to "Active Jobs" section
2. View list of active service requests
3. See map showing mechanic and service locations
4. Monitor job progress in real-time

### Upload Mechanic Documents
1. Go to "Mechanics" section
2. Click "View Profile" for a mechanic
3. Click "Upload Documents"
4. Enter comma-separated document URLs
5. Documents are saved and can be viewed

## Files Modified

### Backend
- `Mechanic.java` - Added new fields
- `AdminController.java` - Added all new endpoints
- `MechanicRequestRepo.java` - Added search methods

### Frontend
- `index.html` - Added new sections and navigation
- `app.js` - Added all new functionality
- `config.js` - Added new endpoint configurations
- `styles.css` - (No changes needed, existing styles work)

## Testing Checklist

- [ ] User search functionality
- [ ] View user bookings
- [ ] Mechanic profile preview
- [ ] Block/unblock mechanic
- [ ] Suspend/unsuspend mechanic
- [ ] Upload mechanic documents
- [ ] Live tracking map loads
- [ ] Filter mechanics by online/offline
- [ ] Active jobs display correctly
- [ ] Active jobs map shows locations

## Future Enhancements

- [ ] Real-time WebSocket updates for live tracking
- [ ] Document file upload (currently URL-based)
- [ ] Email notifications for pending approvals
- [ ] Export data to CSV/PDF
- [ ] Advanced filtering and search
- [ ] User activity logs
- [ ] Mechanic rating management
