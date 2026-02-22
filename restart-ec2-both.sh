#!/bin/bash
# Restart both backend (Spring Boot) and web dashboard (Nginx) on EC2.
# Does NOT deploy/update code. To update: use update-backend-ec2.sh and update-and-restart-admin-ec2.sh.
# Run from project root: ./restart-ec2-both.sh [EC2_IP] [KEY_PATH]

EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-/home/pranam/Desktop/Dyganox-7/springbootEC2key .pem}"

echo "Restarting backend + web dashboard on EC2 ($EC2_IP)..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ec2-user@$EC2_IP" << 'ENDSSH'
set -e

# 1) Restart Backend
echo "--- Backend ---"
pkill -f "ev-charging-backend.*\.jar" 2>/dev/null || true
sleep 2
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

# 2) Restart Web Dashboard (Nginx)
echo "--- Web dashboard (Nginx) ---"
sudo systemctl restart nginx 2>/dev/null || sudo systemctl start nginx
echo "Nginx restarted."

echo "Done. Backend :8081, Dashboard :80"
ENDSSH
echo "Done."
