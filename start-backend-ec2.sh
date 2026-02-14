#!/bin/bash

# Start Backend on EC2
# Usage: ./start-backend-ec2.sh [EC2_IP] [KEY_PATH]

set -e

EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-~/.ssh/your-key.pem}"
EC2_USER="${3:-ec2-user}"

echo "🚀 Starting Backend on EC2..."
echo "📍 EC2 IP: $EC2_IP"
echo ""

ssh -i "$KEY_PATH" "$EC2_USER@$EC2_IP" << 'ENDSSH'
    echo "1️⃣ Checking if backend is already running..."
    BACKEND_PID=$(sudo lsof -t -i:8081 2>/dev/null || true)
    
    if [ ! -z "$BACKEND_PID" ]; then
        echo "   ✅ Backend is already running (PID: $BACKEND_PID)"
        echo "   To restart, run: sudo kill -9 $BACKEND_PID && ./start-backend-ec2.sh"
        exit 0
    fi
    
    echo "   ❌ Backend is NOT running"
    echo ""
    
    echo "2️⃣ Checking for JAR file..."
    JAR_PATH=""
    
    # Check common locations
    if [ -f ~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar ]; then
        JAR_PATH=~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar
        echo "   ✅ Found JAR at: $JAR_PATH"
    elif [ -f ~/ev-charging-backend-0.0.1-SNAPSHOT.jar ]; then
        JAR_PATH=~/ev-charging-backend-0.0.1-SNAPSHOT.jar
        echo "   ✅ Found JAR at: $JAR_PATH"
    elif [ -f ~/backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar ]; then
        JAR_PATH=~/backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar
        echo "   ✅ Found JAR at: $JAR_PATH"
    else
        echo "   ❌ JAR file not found!"
        echo ""
        echo "   Available options:"
        echo "   1. Build from source (if backend source exists)"
        echo "   2. Upload JAR from local machine"
        echo ""
        echo "   To build from source:"
        echo "   cd ~/backend && mvn clean package -DskipTests"
        echo ""
        echo "   To upload from local:"
        echo "   scp backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar ec2-user@$EC2_IP:~/backend-app/"
        exit 1
    fi
    
    echo ""
    echo "3️⃣ Starting backend..."
    
    # Create backend-app directory if it doesn't exist
    mkdir -p ~/backend-app
    
    # If JAR is not in backend-app, copy it there
    if [ "$JAR_PATH" != "~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar" ]; then
        cp "$JAR_PATH" ~/backend-app/
        JAR_PATH=~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar
    fi
    
    cd ~/backend-app
    
    # Check Java version
    echo "   Checking Java version..."
    java -version 2>&1 | head -1
    
    # Start backend
    echo "   Starting backend in background..."
    nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar > backend.log 2>&1 &
    
    echo "   ⏳ Waiting for backend to start (this may take 30-60 seconds)..."
    
    # Wait up to 60 seconds for backend to start
    for i in {1..60}; do
        sleep 1
        if sudo lsof -t -i:8081 > /dev/null 2>&1; then
            echo "   ✅ Backend started successfully!"
            break
        fi
        if [ $i -eq 60 ]; then
            echo "   ❌ Backend failed to start after 60 seconds"
            echo ""
            echo "   📝 Last 50 lines of log:"
            tail -50 backend.log
            exit 1
        fi
        if [ $((i % 10)) -eq 0 ]; then
            echo "   ⏳ Still starting... ($i seconds)"
        fi
    done
    
    echo ""
    echo "4️⃣ Verifying backend is responding..."
    sleep 3
    
    # Test a simple endpoint
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/person || echo "000")
    
    if [ "$HTTP_CODE" != "000" ]; then
        echo "   ✅ Backend is responding (HTTP $HTTP_CODE)"
    else
        echo "   ⚠️  Backend may not be fully ready yet"
    fi
    
    echo ""
    echo "5️⃣ Backend Status:"
    echo "=================="
    ps aux | grep java | grep ev-charging-backend | grep -v grep || echo "   Process not found"
    echo ""
    sudo lsof -i:8081 || echo "   Port 8081 not listening"
    
    echo ""
    echo "✅ Backend should now be running!"
    echo "📝 View logs: tail -f ~/backend-app/backend.log"
    echo "🌐 Test: curl http://localhost:8081/api/person"
ENDSSH

echo ""
echo "✅ Start process complete!"
echo "🧪 Test from your app now - it should connect!"
