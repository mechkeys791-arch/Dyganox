#!/bin/bash

# Admin Dashboard Deployment Script for EC2
# Usage: ./deploy.sh [EC2_IP] [KEY_PATH]

set -e

# Configuration
EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-~/.ssh/your-key.pem}"
DASHBOARD_DIR="admin-dashboard"

echo "🚀 Deploying Admin Dashboard to EC2..."
echo "📍 EC2 IP: $EC2_IP"
echo "🔑 Key: $KEY_PATH"
echo ""

# Check if dashboard directory exists
if [ ! -d "$DASHBOARD_DIR" ]; then
    echo "❌ Error: $DASHBOARD_DIR directory not found!"
    exit 1
fi

# Create deployment package
echo "📦 Creating deployment package..."
tar -czf admin-dashboard.tar.gz $DASHBOARD_DIR/ 2>/dev/null || {
    echo "❌ Error: Failed to create tar.gz"
    exit 1
}

# Upload to EC2
echo "📤 Uploading to EC2..."
scp -i "$KEY_PATH" admin-dashboard.tar.gz ec2-user@$EC2_IP:/home/ec2-user/ || {
    echo "❌ Error: Failed to upload files"
    exit 1
}

# Deploy on EC2
echo "🔧 Deploying on EC2..."
ssh -i "$KEY_PATH" ec2-user@$EC2_IP << 'ENDSSH'
    set -e
    
    echo "📂 Extracting files..."
    cd /home/ec2-user
    tar -xzf admin-dashboard.tar.gz
    
    echo "📋 Copying files to web directory..."
    sudo mkdir -p /var/www/admin-dashboard
    sudo rm -rf /var/www/admin-dashboard/*
    sudo cp -r admin-dashboard/* /var/www/admin-dashboard/
    
    echo "🔐 Setting permissions..."
    sudo chown -R nginx:nginx /var/www/admin-dashboard
    sudo chmod -R 755 /var/www/admin-dashboard
    
    echo "🔄 Reloading Nginx..."
    sudo nginx -t && sudo systemctl reload nginx || {
        echo "⚠️  Nginx reload failed, but files are deployed"
    }
    
    echo "✅ Deployment complete!"
    echo "🌐 Dashboard should be accessible at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
ENDSSH

# Cleanup
echo "🧹 Cleaning up..."
rm -f admin-dashboard.tar.gz

echo ""
echo "✅ Deployment successful!"
echo "🌐 Access dashboard at: http://$EC2_IP"
echo ""
