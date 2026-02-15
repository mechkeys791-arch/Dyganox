#!/bin/bash
# Restart backend on EC2 (no upload, just restart the JAR)
# Usage: ./restart-backend-ec2.sh [EC2_IP] [KEY_PATH]
set -e
EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-~/.ssh/your-key.pem}"
EC2_USER="${3:-ec2-user}"

echo "🔄 Restarting backend on EC2 ($EC2_IP)..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$EC2_USER@$EC2_IP" << 'ENDSSH'
set -e
cd ~/backend-app
echo "🛑 Stopping backend..."
sudo kill -9 $(sudo lsof -t -i:8081) 2>/dev/null || true
sleep 2
echo "🚀 Starting backend..."
nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar > backend.log 2>&1 &
echo "⏳ Waiting 15s for startup..."
sleep 15
if sudo lsof -t -i:8081 > /dev/null 2>&1; then
    echo "✅ Backend running on port 8081"
    tail -5 backend.log
else
    echo "❌ Backend may have failed. Last 40 lines of backend.log:"
    tail -40 backend.log
fi
ENDSSH
echo ""
echo "🌐 API: http://$EC2_IP:8081"
echo "📝 Logs on EC2: ssh -i \"$KEY_PATH\" $EC2_USER@$EC2_IP 'tail -f ~/backend-app/backend.log'"
