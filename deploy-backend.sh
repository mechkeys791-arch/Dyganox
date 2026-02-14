#!/bin/bash

# Backend Deployment Script for EC2
# This script builds and deploys the backend to EC2
# Usage: ./deploy-backend.sh [EC2_IP] [KEY_PATH] [EC2_USER]

set -e

# Configuration
EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-~/.ssh/your-key.pem}"
EC2_USER="${3:-ec2-user}"
BACKEND_DIR="backend"
JAR_NAME="ev-charging-backend-0.0.1-SNAPSHOT.jar"

echo "🚀 Deploying Backend to EC2..."
echo "📍 EC2 IP: $EC2_IP"
echo "🔑 Key: $KEY_PATH"
echo "👤 User: $EC2_USER"
echo ""

# Check if backend directory exists
if [ ! -d "$BACKEND_DIR" ]; then
    echo "❌ Error: $BACKEND_DIR directory not found!"
    exit 1
fi

# Check if Maven is installed locally
if ! command -v mvn &> /dev/null; then
    echo "⚠️  Maven not found locally. Building on EC2 instead..."
    BUILD_ON_EC2=true
else
    echo "✅ Maven found. Building locally..."
    BUILD_ON_EC2=false
fi

if [ "$BUILD_ON_EC2" = false ]; then
    # Build locally
    echo "📦 Building backend JAR locally..."
    cd "$BACKEND_DIR"
    mvn clean package -DskipTests
    cd ..
    
    if [ ! -f "$BACKEND_DIR/target/$JAR_NAME" ]; then
        echo "❌ Error: JAR file not found after build!"
        exit 1
    fi
    
    echo "✅ Build successful!"
    echo "📤 Uploading JAR to EC2..."
    scp -i "$KEY_PATH" "$BACKEND_DIR/target/$JAR_NAME" "$EC2_USER@$EC2_IP:/home/$EC2_USER/"
else
    # Upload source code and build on EC2
    echo "📤 Uploading backend source code to EC2..."
    tar -czf backend-src.tar.gz "$BACKEND_DIR/" --exclude="$BACKEND_DIR/target" --exclude="$BACKEND_DIR/.idea"
    scp -i "$KEY_PATH" backend-src.tar.gz "$EC2_USER@$EC2_IP:/home/$EC2_USER/"
    rm -f backend-src.tar.gz
fi

# Deploy on EC2
echo "🔧 Deploying on EC2..."
ssh -i "$KEY_PATH" "$EC2_USER@$EC2_IP" << ENDSSH
    set -e
    
    echo "🛑 Stopping existing backend..."
    # Try to stop systemd service
    sudo systemctl stop dyganox-backend 2>/dev/null || true
    sudo systemctl stop spring-boot-app 2>/dev/null || true
    
    # Kill any running Java processes on port 8081
    BACKEND_PID=\$(sudo lsof -t -i:8081 2>/dev/null || true)
    if [ ! -z "\$BACKEND_PID" ]; then
        echo "   Killing process \$BACKEND_PID on port 8081..."
        sudo kill -9 \$BACKEND_PID 2>/dev/null || true
    fi
    
    # Wait a moment for port to be free
    sleep 2
    
    if [ "$BUILD_ON_EC2" = true ]; then
        echo "📦 Extracting source code..."
        cd /home/$EC2_USER
        tar -xzf backend-src.tar.gz
        
        echo "🔨 Building backend on EC2..."
        cd backend
        
        # Install Maven if not installed
        if ! command -v mvn &> /dev/null; then
            echo "   Installing Maven..."
            sudo yum install -y maven
        fi
        
        # Build
        mvn clean package -DskipTests
        
        if [ ! -f "target/$JAR_NAME" ]; then
            echo "❌ Error: Build failed on EC2!"
            exit 1
        fi
        
        # Copy JAR to home directory
        cp target/$JAR_NAME /home/$EC2_USER/
        cd /home/$EC2_USER
        rm -rf backend backend-src.tar.gz
    fi
    
    echo "💾 Backing up old JAR..."
    if [ -f "$JAR_NAME" ]; then
        mv "$JAR_NAME" "${JAR_NAME}.backup.\$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    
    if [ "$BUILD_ON_EC2" = false ]; then
        echo "📋 JAR already in place from upload"
    else
        echo "📋 Moving new JAR to final location..."
    fi
    
    # Create backend directory if it doesn't exist
    mkdir -p ~/backend-app
    mv "$JAR_NAME" ~/backend-app/ 2>/dev/null || cp "$JAR_NAME" ~/backend-app/
    
    echo "🚀 Starting backend..."
    cd ~/backend-app
    
    # Start backend in background
    nohup java -jar "$JAR_NAME" > backend.log 2>&1 &
    
    # Wait a moment for startup
    sleep 5
    
    # Check if backend started successfully
    if sudo lsof -t -i:8081 > /dev/null 2>&1; then
        echo "✅ Backend started successfully on port 8081"
    else
        echo "⚠️  Backend may not have started. Check logs:"
        tail -20 backend.log
        exit 1
    fi
    
    echo "📊 Backend status:"
    ps aux | grep java | grep "$JAR_NAME" | grep -v grep || echo "   Process not found"
    
    echo ""
    echo "✅ Deployment complete!"
    echo "🌐 Backend should be accessible at: http://$EC2_IP:8081"
    echo "📝 Logs: tail -f ~/backend-app/backend.log"
ENDSSH

echo ""
echo "✅ Deployment successful!"
echo "🌐 Backend API: http://$EC2_IP:8081"
echo "🧪 Test endpoint: curl http://$EC2_IP:8081/api/user-addresses"
echo ""
