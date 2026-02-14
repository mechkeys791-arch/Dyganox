#!/bin/bash

# Check Backend Status on EC2
# Usage: ./check-backend-status.sh [EC2_IP] [KEY_PATH]

set -e

EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-~/.ssh/your-key.pem}"
EC2_USER="${3:-ec2-user}"

echo "🔍 Checking Backend Status on EC2..."
echo "📍 EC2 IP: $EC2_IP"
echo ""

ssh -i "$KEY_PATH" "$EC2_USER@$EC2_IP" << 'ENDSSH'
    echo "📊 Backend Process Status:"
    echo "=========================="
    ps aux | grep java | grep ev-charging-backend | grep -v grep || echo "   ❌ No backend process found"
    
    echo ""
    echo "🔌 Port 8081 Status:"
    echo "==================="
    sudo lsof -i:8081 || echo "   ❌ Nothing listening on port 8081"
    
    echo ""
    echo "📁 JAR File Location:"
    echo "===================="
    if [ -f ~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar ]; then
        ls -lh ~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar
        echo ""
        echo "📦 Checking if UserAddressController is in JAR:"
        jar -tf ~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar | grep UserAddressController || echo "   ❌ UserAddressController NOT found in JAR!"
    else
        echo "   ❌ JAR file not found at ~/backend-app/"
    fi
    
    echo ""
    echo "📝 Recent Backend Logs (last 30 lines):"
    echo "======================================"
    if [ -f ~/backend-app/backend.log ]; then
        tail -30 ~/backend-app/backend.log
    else
        echo "   ⚠️  No log file found"
    fi
    
    echo ""
    echo "🧪 Testing Endpoint Locally:"
    echo "==========================="
    curl -s -o /dev/null -w "   /api/user-addresses: HTTP %{http_code}\n" http://localhost:8081/api/user-addresses || echo "   ❌ Connection failed"
    
    echo ""
    echo "🌐 Testing from External:"
    echo "========================"
    curl -s -o /dev/null -w "   http://34.228.113.212:8081/api/user-addresses: HTTP %{http_code}\n" http://34.228.113.212:8081/api/user-addresses || echo "   ❌ Connection failed"
ENDSSH

echo ""
echo "✅ Status check complete!"
