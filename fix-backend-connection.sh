#!/bin/bash

# Fix Backend Connection Issues
# This script checks and fixes common backend connection problems
# Usage: ./fix-backend-connection.sh [EC2_IP] [KEY_PATH]

set -e

EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-~/.ssh/your-key.pem}"
EC2_USER="${3:-ec2-user}"

echo "🔧 Fixing Backend Connection Issues..."
echo "📍 EC2 IP: $EC2_IP"
echo ""

ssh -i "$KEY_PATH" "$EC2_USER@$EC2_IP" << 'ENDSSH'
    echo "1️⃣ Checking if backend is running..."
    BACKEND_PID=$(sudo lsof -t -i:8081 2>/dev/null || true)
    
    if [ -z "$BACKEND_PID" ]; then
        echo "   ❌ Backend is NOT running!"
        echo ""
        echo "2️⃣ Starting backend..."
        
        # Check if JAR exists
        if [ ! -f ~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar ]; then
            echo "   ❌ JAR file not found! Need to build first."
            echo "   Run: ./update-backend-ec2.sh"
            exit 1
        fi
        
        # Start backend
        cd ~/backend-app
        nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar > backend.log 2>&1 &
        
        echo "   ⏳ Waiting for backend to start..."
        sleep 10
        
        # Check again
        if sudo lsof -t -i:8081 > /dev/null 2>&1; then
            echo "   ✅ Backend started successfully!"
        else
            echo "   ❌ Backend failed to start. Check logs:"
            tail -50 backend.log
            exit 1
        fi
    else
        echo "   ✅ Backend is running (PID: $BACKEND_PID)"
    fi
    
    echo ""
    echo "3️⃣ Verifying endpoint..."
    sleep 2
    
    # Test endpoint
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/user-addresses || echo "000")
    
    if [ "$HTTP_CODE" = "405" ] || [ "$HTTP_CODE" = "400" ]; then
        echo "   ✅ Endpoint exists! (HTTP $HTTP_CODE - Method not allowed is OK for GET on POST endpoint)"
    elif [ "$HTTP_CODE" = "404" ]; then
        echo "   ❌ Endpoint NOT found (404)"
        echo ""
        echo "4️⃣ Checking if UserAddressController is in JAR..."
        if jar -tf ~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar | grep -q UserAddressController; then
            echo "   ✅ UserAddressController found in JAR"
            echo "   ⚠️  But endpoint returns 404. Backend may need restart."
            echo ""
            echo "5️⃣ Restarting backend..."
            sudo lsof -t -i:8081 | xargs sudo kill -9 2>/dev/null || true
            sleep 2
            cd ~/backend-app
            nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar > backend.log 2>&1 &
            sleep 10
            echo "   ✅ Backend restarted"
        else
            echo "   ❌ UserAddressController NOT in JAR!"
            echo "   Need to rebuild with: ./update-backend-ec2.sh"
        fi
    elif [ "$HTTP_CODE" = "000" ]; then
        echo "   ❌ Connection failed - backend may not be running"
    else
        echo "   ✅ Endpoint responding (HTTP $HTTP_CODE)"
    fi
    
    echo ""
    echo "6️⃣ Checking security group (port 8081)..."
    echo "   Make sure EC2 security group allows inbound on port 8081"
    echo "   From: 0.0.0.0/0 (or your IP)"
    
    echo ""
    echo "7️⃣ Testing from external IP..."
    EXTERNAL_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://34.228.113.212:8081/api/user-addresses || echo "000")
    if [ "$EXTERNAL_CODE" != "000" ]; then
        echo "   ✅ External access working (HTTP $EXTERNAL_CODE)"
    else
        echo "   ⚠️  External access failed - check security group"
    fi
    
    echo ""
    echo "📝 Recent logs:"
    tail -20 ~/backend-app/backend.log 2>/dev/null || echo "   No logs found"
ENDSSH

echo ""
echo "✅ Diagnostic complete!"
