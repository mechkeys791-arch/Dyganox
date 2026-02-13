# Quick Deploy Guide - Admin Dashboard to EC2

## Fastest Method (Using Deployment Script)

### 1. Update Configuration

Edit `admin-dashboard/config.js` and ensure:
```javascript
baseUrl: 'http://34.228.113.212:8081', // Your EC2 IP
```

### 2. Run Deployment Script

```bash
cd admin-dashboard
./deploy.sh 34.228.113.212 /path/to/your-key.pem
```

That's it! The script will:
- ✅ Package the dashboard
- ✅ Upload to EC2
- ✅ Extract and deploy
- ✅ Set permissions
- ✅ Reload Nginx

## Manual Quick Deploy

### Step 1: Upload Files

```bash
# From your local machine
cd /home/pranam/Desktop/Dyganox-4
tar -czf admin-dashboard.tar.gz admin-dashboard/
scp -i /path/to/key.pem admin-dashboard.tar.gz ec2-user@34.228.113.212:/home/ec2-user/
```

### Step 2: SSH and Deploy

```bash
ssh -i /path/to/key.pem ec2-user@34.228.113.212
```

```bash
# Extract
cd /home/ec2-user
tar -xzf admin-dashboard.tar.gz

# Install Nginx (if not installed)
sudo yum install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx

# Deploy
sudo mkdir -p /var/www/admin-dashboard
sudo cp -r admin-dashboard/* /var/www/admin-dashboard/
sudo chown -R nginx:nginx /var/www/admin-dashboard

# Configure Nginx
sudo cp admin-dashboard/nginx.conf /etc/nginx/conf.d/admin-dashboard.conf
sudo nginx -t
sudo systemctl reload nginx
```

### Step 3: Open Security Group

In AWS Console:
- EC2 → Security Groups → Your instance's security group
- Add inbound rule: HTTP (port 80) from 0.0.0.0/0

### Step 4: Access

Open browser: `http://34.228.113.212`

## Verify Deployment

```bash
# On EC2, check Nginx
sudo systemctl status nginx

# Check files
ls -la /var/www/admin-dashboard/

# Test API (should return JSON)
curl http://localhost:8081/api/admin/analytics
```

## Troubleshooting

**Dashboard shows 404:**
```bash
sudo nginx -t  # Check config
sudo tail -f /var/log/nginx/error.log  # Check errors
```

**API calls fail:**
- Check backend is running: `curl http://localhost:8081/api/admin/analytics`
- Check CORS in backend
- Check browser console for errors

**Permission denied:**
```bash
sudo chown -R nginx:nginx /var/www/admin-dashboard
sudo chmod -R 755 /var/www/admin-dashboard
```

## Next Steps

1. ✅ Dashboard deployed
2. 🔒 Setup HTTPS (optional but recommended)
3. 🔑 Add authentication (optional)
4. 📊 Test all features
