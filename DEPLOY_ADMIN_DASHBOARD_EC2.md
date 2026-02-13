# Deploy Admin Dashboard to EC2

Complete guide to deploy the Dyganox Admin Dashboard web application on EC2.

## Prerequisites

- EC2 instance running (your backend is already on `34.228.113.212`)
- SSH access to EC2 instance
- Backend API running on port 8081
- Domain name (optional, for HTTPS)

## Step 1: Prepare Dashboard Files

### Option A: Upload from Local Machine

1. **Create a deployment package** (from your local machine):
```bash
cd /home/pranam/Desktop/Dyganox-4
tar -czf admin-dashboard.tar.gz admin-dashboard/
```

2. **Upload to EC2**:
```bash
scp -i /path/to/your-key.pem admin-dashboard.tar.gz ec2-user@34.228.113.212:/home/ec2-user/
```

### Option B: Clone/Upload via Git

If your code is in a Git repository:
```bash
ssh -i /path/to/your-key.pem ec2-user@34.228.113.212
git clone <your-repo-url>
cd Dyganox-4
```

## Step 2: SSH into EC2 Instance

```bash
ssh -i /path/to/your-key.pem ec2-user@34.228.113.212
```

## Step 3: Install Nginx Web Server

```bash
# Update system packages
sudo yum update -y

# Install Nginx
sudo yum install nginx -y

# Start Nginx
sudo systemctl start nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx

# Check status
sudo systemctl status nginx
```

## Step 4: Extract and Setup Dashboard Files

```bash
# Extract dashboard files (if uploaded as tar.gz)
cd /home/ec2-user
tar -xzf admin-dashboard.tar.gz

# Create web directory
sudo mkdir -p /var/www/admin-dashboard

# Copy dashboard files
sudo cp -r admin-dashboard/* /var/www/admin-dashboard/

# Set proper permissions
sudo chown -R nginx:nginx /var/www/admin-dashboard
sudo chmod -R 755 /var/www/admin-dashboard
```

## Step 5: Configure Nginx

Create Nginx configuration file:

```bash
sudo nano /etc/nginx/conf.d/admin-dashboard.conf
```

Add the following configuration:

```nginx
server {
    listen 80;
    server_name 34.228.113.212;  # Replace with your domain if you have one
    
    root /var/www/admin-dashboard;
    index index.html;

    # Admin Dashboard
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API Proxy (optional - if you want to serve API through same domain)
    location /api/ {
        proxy_pass http://localhost:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

Save and exit (Ctrl+X, then Y, then Enter).

## Step 6: Update Dashboard Configuration

Update the dashboard config to use the correct backend URL:

```bash
sudo nano /var/www/admin-dashboard/config.js
```

Make sure it's configured correctly:
```javascript
const API_CONFIG = {
    baseUrl: 'http://34.228.113.212:8081', // Your EC2 IP and backend port
    // ... rest of config
};
```

**Important**: If you're using HTTPS later, change this to `https://your-domain.com:8081` or use the proxy path `/api`.

## Step 7: Test and Reload Nginx

```bash
# Test Nginx configuration
sudo nginx -t

# If test passes, reload Nginx
sudo systemctl reload nginx

# Check status
sudo systemctl status nginx
```

## Step 8: Configure EC2 Security Group

1. Go to AWS Console → EC2 → Security Groups
2. Select your EC2 instance's security group
3. Add inbound rule:
   - **Type**: HTTP
   - **Port**: 80
   - **Source**: 0.0.0.0/0 (or restrict to your IP for security)
4. Save rules

## Step 9: Access the Dashboard

Open your browser and navigate to:
```
http://34.228.113.212
```

You should see the admin dashboard!

## Optional: Setup HTTPS with Let's Encrypt (Recommended)

### Prerequisites for HTTPS:
- Domain name pointing to your EC2 IP
- Port 443 open in security group

### Install Certbot:

```bash
# Install certbot
sudo yum install certbot python3-certbot-nginx -y

# Get SSL certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Follow the prompts:
# - Enter your email
# - Agree to terms
# - Choose whether to redirect HTTP to HTTPS (recommended: Yes)

# Test auto-renewal
sudo certbot renew --dry-run
```

### Update Dashboard Config for HTTPS:

```bash
sudo nano /var/www/admin-dashboard/config.js
```

Change baseUrl to:
```javascript
baseUrl: 'https://your-domain.com:8081'  // or use proxy: '/api'
```

## Optional: Setup as Systemd Service (Auto-restart)

Create a systemd service for easier management:

```bash
sudo nano /etc/systemd/system/admin-dashboard.service
```

Add:
```ini
[Unit]
Description=Admin Dashboard Nginx
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable service:
```bash
sudo systemctl enable admin-dashboard
```

## Troubleshooting

### Dashboard not loading

1. **Check Nginx status**:
```bash
sudo systemctl status nginx
sudo nginx -t
```

2. **Check Nginx error logs**:
```bash
sudo tail -f /var/log/nginx/error.log
```

3. **Check file permissions**:
```bash
ls -la /var/www/admin-dashboard
sudo chown -R nginx:nginx /var/www/admin-dashboard
```

4. **Check if port 80 is open**:
```bash
sudo netstat -tuln | grep 80
```

### API calls failing

1. **Check backend is running**:
```bash
curl http://localhost:8081/api/admin/analytics
```

2. **Check CORS settings** in backend (should allow all origins for admin dashboard)

3. **Check browser console** for CORS errors

4. **Test API directly**:
```bash
curl http://34.228.113.212:8081/api/admin/analytics
```

### Google Maps not loading

1. **Get Google Maps API Key**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/google/maps-apis)
   - Create API key
   - Enable "Maps JavaScript API"

2. **Update dashboard**:
```bash
sudo nano /var/www/admin-dashboard/index.html
```

Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual key.

3. **Restart Nginx**:
```bash
sudo systemctl reload nginx
```

## Quick Deployment Script

Save this as `deploy-dashboard.sh`:

```bash
#!/bin/bash

# Configuration
EC2_IP="34.228.113.212"
KEY_PATH="/path/to/your-key.pem"
DASHBOARD_DIR="admin-dashboard"

echo "📦 Creating deployment package..."
tar -czf admin-dashboard.tar.gz $DASHBOARD_DIR/

echo "📤 Uploading to EC2..."
scp -i $KEY_PATH admin-dashboard.tar.gz ec2-user@$EC2_IP:/home/ec2-user/

echo "🚀 Deploying on EC2..."
ssh -i $KEY_PATH ec2-user@$EC2_IP << 'ENDSSH'
    cd /home/ec2-user
    tar -xzf admin-dashboard.tar.gz
    sudo rm -rf /var/www/admin-dashboard/*
    sudo cp -r admin-dashboard/* /var/www/admin-dashboard/
    sudo chown -R nginx:nginx /var/www/admin-dashboard
    sudo chmod -R 755 /var/www/admin-dashboard
    sudo nginx -t && sudo systemctl reload nginx
    echo "✅ Dashboard deployed successfully!"
ENDSSH

echo "✅ Deployment complete!"
echo "🌐 Access dashboard at: http://$EC2_IP"
```

Make it executable and run:
```bash
chmod +x deploy-dashboard.sh
./deploy-dashboard.sh
```

## Maintenance

### Update Dashboard

1. Make changes locally
2. Upload new files:
```bash
scp -i /path/to/key.pem -r admin-dashboard/* ec2-user@34.228.113.212:/home/ec2-user/admin-dashboard/
```

3. On EC2:
```bash
sudo cp -r /home/ec2-user/admin-dashboard/* /var/www/admin-dashboard/
sudo systemctl reload nginx
```

### View Logs

```bash
# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

### Backup Dashboard

```bash
# Create backup
sudo tar -czf /home/ec2-user/admin-dashboard-backup-$(date +%Y%m%d).tar.gz /var/www/admin-dashboard/
```

## Security Recommendations

1. **Restrict Security Group**: Only allow port 80/443 from your IP or office IP
2. **Use HTTPS**: Always use HTTPS in production
3. **Add Authentication**: Implement login system for admin dashboard
4. **Regular Updates**: Keep Nginx and system packages updated
5. **Firewall**: Use AWS Security Groups + EC2 firewall (iptables/firewalld)

## Access URLs

- **Dashboard**: `http://34.228.113.212` (or your domain)
- **Backend API**: `http://34.228.113.212:8081`
- **Admin Endpoints**: `http://34.228.113.212:8081/api/admin/*`

## Next Steps

1. ✅ Dashboard is now accessible at `http://34.228.113.212`
2. 🔒 Setup HTTPS with Let's Encrypt (recommended)
3. 🔐 Add authentication/login system
4. 📊 Test all dashboard features
5. 📱 Verify mobile app can still connect to backend

## Support

If you encounter issues:
1. Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`
2. Check backend logs: `tail -f backend.log` (or systemd journal)
3. Test API endpoints: `curl http://localhost:8081/api/admin/analytics`
4. Check browser console for JavaScript errors
