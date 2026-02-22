#!/bin/bash
# Restart the Spring Boot backend on EC2 only (no deploy, no admin).
# Run from project root: ./restart-backend-ec2.sh [EC2_IP] [KEY_PATH]

EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-/home/pranam/Desktop/Dyganox-7/springbootEC2key .pem}"

echo "Restarting backend (app) on EC2 ($EC2_IP)..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ec2-user@$EC2_IP" << 'ENDSSH'
set -e
# Kill existing backend (jar or java process with ev-charging-backend)
pkill -f "ev-charging-backend.*\.jar" 2>/dev/null || true
sleep 2
# Start from backend-app if present, else from backend/target
if [ -f ~/backend-app/ev-charging-backend-0.0.1-SNAPSHOT.jar ]; then
  cd ~/backend-app
elif [ -f ~/backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar ]; then
  cd ~/backend/target
else
  echo "JAR not found in ~/backend-app or ~/backend/target"
  exit 1
fi
nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar --spring.profiles.active=ec2 > backend.log 2>&1 &
echo "Backend started. Wait a few seconds then check :8081"
ENDSSH
echo "Done."
