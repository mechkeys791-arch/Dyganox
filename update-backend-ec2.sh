#!/bin/bash

# Quick Backend Update Script for EC2
# This updates and restarts the backend on your running EC2 instance
# Usage: ./update-backend-ec2.sh [EC2_IP] [KEY_PATH]

set -e

EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-~/.ssh/your-key.pem}"
EC2_USER="${3:-ec2-user}"

echo "🔄 Updating Backend on EC2..."
echo "📍 EC2 IP: $EC2_IP"
echo ""

# Upload source code
if [ ! -d "backend" ]; then
    echo "❌ Error: ./backend folder not found. Run this script from the project root (e.g. ~/Desktop/Dyganox)."
    exit 1
fi
echo "📤 Uploading backend source code..."
tar --exclude="backend/target" --exclude="backend/.idea" -czf backend-src.tar.gz backend/ || {
    echo "❌ Failed to create backend-src.tar.gz"
    exit 1
}
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null backend-src.tar.gz "$EC2_USER@$EC2_IP:/home/$EC2_USER/" || {
    echo "❌ Failed to upload. Check: 1) Key path 2) EC2 IP 3) Security group allows SSH (port 22)."
    exit 1
}
rm -f backend-src.tar.gz

# Build and restart on EC2
echo "🔧 Building and restarting backend on EC2..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$EC2_USER@$EC2_IP" << 'ENDSSH'
    set -e
    
    echo "📦 Extracting source code..."
    cd /home/ec2-user
    rm -rf backend-old
    if [ -d "backend" ]; then
        mv backend backend-old
    fi
    tar -xzf backend-src.tar.gz
    rm -f backend-src.tar.gz
    
    echo "🔨 Building backend..."
    cd backend
    
    # Install Maven if not installed
    if ! command -v mvn &> /dev/null; then
        echo "   Installing Maven..."
        sudo yum install -y maven
    fi
    
    # Build
    echo "   Compiling..."
    mvn clean package -DskipTests
    
    if [ ! -f "target/ev-charging-backend-0.0.1-SNAPSHOT.jar" ]; then
        echo "❌ Build failed!"
        exit 1
    fi
    
    echo "🛑 Stopping old backend..."
    # Kill process on port 8081
    BACKEND_PID=$(sudo lsof -t -i:8081 2>/dev/null || true)
    if [ ! -z "$BACKEND_PID" ]; then
        echo "   Stopping process $BACKEND_PID..."
        sudo kill -9 $BACKEND_PID 2>/dev/null || true
        sleep 2
    fi
    
    # Try systemd services
    sudo systemctl stop dyganox-backend 2>/dev/null || true
    sudo systemctl stop spring-boot-app 2>/dev/null || true
    
    echo "💾 Backing up old JAR..."
    mkdir -p ~/backend-app
    if [ -f ~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar ]; then
        mv ~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar ~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    echo "📋 Copying new JAR..."
    cp target/ev-charging-backend-0.0.1-SNAPSHOT.jar ~/backend-app/
    
    echo "🚀 Starting backend..."
    cd ~/backend-app
    nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar > backend.log 2>&1 &
    
    echo "⏳ Waiting for backend to start..."
    sleep 8
    
    # Check if started
    if sudo lsof -t -i:8081 > /dev/null 2>&1; then
        echo "✅ Backend started successfully!"
        echo ""
        echo "📊 Status:"
        ps aux | grep java | grep ev-charging-backend | grep -v grep | head -1
        echo ""
        echo "🧪 Testing endpoint..."
        sleep 2
        curl -s -o /dev/null -w "   /api/user-addresses: HTTP %{http_code}\n" http://localhost:8081/api/user-addresses || echo "   Endpoint test failed"
    else
        echo "⚠️  Backend may not have started. Check logs:"
        tail -30 backend.log
        exit 1
    fi
    
    echo ""
    echo "✅ Update complete!"
    echo "📝 View logs: tail -f ~/backend-app/backend.log"
ENDSSH

echo ""
echo "✅ Backend updated and restarted!"
echo "🌐 API: http://$EC2_IP:8081"
echo "🧪 Test: curl http://$EC2_IP:8081/api/user-addresses"
echo ""
