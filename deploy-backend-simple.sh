#!/bin/bash

# Simple Backend Deployment Script
# Builds on EC2 and deploys the backend with UserAddressController

set -e

EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2}"

if [ -z "$KEY_PATH" ]; then
    echo "❌ Error: SSH key path required!"
    echo ""
    echo "Usage: ./deploy-backend-simple.sh [EC2_IP] [SSH_KEY_PATH]"
    echo ""
    echo "Example:"
    echo "  ./deploy-backend-simple.sh 34.228.113.212 ~/.ssh/id_rsa"
    echo "  ./deploy-backend-simple.sh 34.228.113.212 ~/.ssh/id_ed25519"
    echo "  ./deploy-backend-simple.sh 34.228.113.212 ~/Downloads/my-key.pem"
    echo ""
    echo "Find your SSH key:"
    echo "  ls -la ~/.ssh/"
    exit 1
fi

EC2_USER="${3:-ec2-user}"

echo "🚀 Deploying Backend to EC2..."
echo "📍 EC2 IP: $EC2_IP"
echo "🔑 Key: $KEY_PATH"
echo "👤 User: $EC2_USER"
echo ""

# Check if key exists
if [ ! -f "$KEY_PATH" ]; then
    echo "❌ Error: SSH key not found at: $KEY_PATH"
    exit 1
fi

# Set key permissions
chmod 400 "$KEY_PATH" 2>/dev/null || true

# Check if backend directory exists
if [ ! -d "backend" ]; then
    echo "❌ Error: backend directory not found!"
    exit 1
fi

# Upload source code
echo "📤 Uploading backend source code to EC2..."
tar --exclude="backend/target" --exclude="backend/.idea" --exclude="backend/.git" -czf backend-src.tar.gz backend/ 2>/dev/null

scp -i "$KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null backend-src.tar.gz "$EC2_USER@$EC2_IP:/home/$EC2_USER/" || {
    echo "❌ Failed to upload. Check:"
    echo "   1. SSH key path is correct: $KEY_PATH"
    echo "   2. EC2 IP is correct: $EC2_IP"
    echo "   3. EC2 security group allows SSH (port 22)"
    exit 1
}

rm -f backend-src.tar.gz

# Build and deploy on EC2
echo "🔧 Building and deploying backend on EC2..."
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
    echo "   Compiling (this may take a few minutes)..."
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
    sleep 10
    
    # Check if started
    if sudo lsof -t -i:8081 > /dev/null 2>&1; then
        echo "✅ Backend started successfully!"
        echo ""
        echo "📊 Status:"
        ps aux | grep java | grep ev-charging-backend | grep -v grep | head -1
        echo ""
        echo "🧪 Testing endpoint..."
        sleep 2
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/user-addresses || echo "000")
        if [ "$HTTP_CODE" = "405" ] || [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "200" ]; then
            echo "   ✅ Endpoint /api/user-addresses is available (HTTP $HTTP_CODE)"
        else
            echo "   ⚠️  Endpoint returned HTTP $HTTP_CODE (check logs if not 405/400/200)"
        fi
    else
        echo "⚠️  Backend may not have started. Check logs:"
        tail -30 backend.log
        exit 1
    fi
    
    echo ""
    echo "✅ Deployment complete!"
    echo "📝 View logs: tail -f ~/backend-app/backend.log"
ENDSSH

echo ""
echo "✅ Backend deployed successfully!"
echo "🌐 API: http://$EC2_IP:8081"
echo "🧪 Test: curl http://$EC2_IP:8081/api/user-addresses"
echo ""
echo "Now try saving an address in your app - it should work! 🎉"
