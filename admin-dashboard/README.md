# Dyganox Admin Dashboard

Web dashboard for admins. No login required; opens directly at the home page.

### Features
- Real-time statistics and metrics
- Visual charts for requests by status and service type
- Mechanics, requests, revenue overview
- User management, mechanics, banners, user support

---

## Setup

Edit **`config.js`**:
- **`baseUrl`** – backend URL (e.g. `http://34.228.113.212:8081`).

## Deploy

- Set `baseUrl` in `config.js`.
- Deploy the `admin-dashboard` folder to your web server or EC2 (e.g. `./deploy.sh`).

Access the dashboard at your server URL.
