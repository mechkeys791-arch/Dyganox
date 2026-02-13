# Dyganox Admin Dashboard

A comprehensive web-based admin dashboard for monitoring and managing the Dyganox platform, including mechanics, service requests, and analytics.

## Features

### 📊 Dashboard Overview
- Real-time statistics and metrics
- Visual charts for requests by status and service type
- Quick overview of mechanics, requests, and revenue

### 👥 Mechanic Management
- View all registered mechanics
- Filter mechanics by approval status
- Approve or reject mechanic registrations
- View individual mechanic performance metrics

### ⏳ Pending Approvals
- View all mechanics awaiting approval
- Quick approve/reject actions
- Review mechanic details before approval

### 📋 Service Requests
- Monitor all service requests from users
- Filter requests by status (Pending, Accepted, Completed, Rejected)
- Track request and response times
- View customer and mechanic information

### 🗺️ Request Tracking
- Monitor which mechanics are responding to requests
- Track average response times
- View acceptance and completion rates per mechanic
- Identify active vs inactive mechanics

### 📈 Analytics
- Detailed statistics for mechanics, requests, and revenue
- Payment statistics
- Service type breakdown
- Performance metrics

## Setup Instructions

### 1. Configure API Endpoint

Edit `config.js` and update the `baseUrl` with your backend server URL:

```javascript
const API_CONFIG = {
    baseUrl: 'http://YOUR_SERVER_IP:8081', // Change to your EC2 IP or localhost:8081
    // ...
};
```

### 2. Backend Requirements

Ensure your Spring Boot backend includes:
- `AdminController` with all admin endpoints
- `Mechanic` model with `approvalStatus` field
- CORS enabled for the admin dashboard domain

### 3. Running the Dashboard

#### Option 1: Simple HTTP Server (Python)
```bash
cd admin-dashboard
python3 -m http.server 8000
```
Then open `http://localhost:8000` in your browser.

#### Option 2: Node.js HTTP Server
```bash
cd admin-dashboard
npx http-server -p 8000
```

#### Option 3: VS Code Live Server
- Install "Live Server" extension in VS Code
- Right-click on `index.html` and select "Open with Live Server"

## API Endpoints Used

The dashboard uses the following backend endpoints:

- `GET /api/admin/mechanics` - Get all mechanics
- `GET /api/admin/mechanics/pending` - Get pending mechanics
- `PUT /api/admin/mechanics/{id}/approve` - Approve mechanic
- `PUT /api/admin/mechanics/{id}/reject` - Reject mechanic
- `GET /api/admin/requests` - Get all service requests
- `GET /api/admin/analytics` - Get analytics data
- `GET /api/admin/requests/tracking` - Get request tracking data
- `GET /api/admin/mechanics/{id}/performance` - Get mechanic performance

## Features in Detail

### Mechanic Approval Workflow
1. New mechanics register through the mobile app
2. They appear in "Pending Approvals" with status "PENDING"
3. Admin reviews their details
4. Admin can approve (status → "APPROVED") or reject (status → "REJECTED")
5. Only approved mechanics can receive service requests

### Request Monitoring
- Track which mechanics are actively responding to requests
- Monitor average response times
- Identify mechanics with high completion rates
- View detailed request history

### Analytics Dashboard
- Real-time statistics
- Revenue tracking from completed services
- Payment statistics
- Service type distribution
- Recent activity (last 7 days)

## Browser Compatibility

- Chrome/Edge (recommended)
- Firefox
- Safari
- Opera

## Security Notes

⚠️ **Important**: This is an admin dashboard with full access to your system. Consider:

1. **Authentication**: Add login/authentication before deploying
2. **HTTPS**: Use HTTPS in production
3. **Access Control**: Restrict access to authorized admins only
4. **API Security**: Implement API authentication/authorization on backend

## Troubleshooting

### CORS Errors
If you see CORS errors, ensure your backend has CORS enabled:
```java
@CrossOrigin(origins = "*")
```

### API Connection Issues
1. Check that `baseUrl` in `config.js` matches your backend URL
2. Verify backend is running and accessible
3. Check browser console for detailed error messages

### Data Not Loading
1. Check browser console for errors
2. Verify backend endpoints are working (test with Postman/curl)
3. Ensure database is connected and has data

## Future Enhancements

- [ ] Add authentication/login system
- [ ] Real-time updates using WebSockets
- [ ] Export data to CSV/PDF
- [ ] Advanced filtering and search
- [ ] Email notifications for pending approvals
- [ ] User management section
- [ ] Payment transaction details
- [ ] Map view for mechanic locations

## Support

For issues or questions, check:
- Backend logs for API errors
- Browser console for frontend errors
- Network tab for failed API calls
