#!/bin/bash
# Restart admin dashboard (Nginx) only on EC2. Does NOT update frontend files.
# To update frontend and restart, use: ./update-and-restart-admin-ec2.sh
# Run from project root: ./restart-admin-dashboard-ec2.sh [EC2_IP] [KEY_PATH]

EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-/home/pranam/Desktop/Dyganox-7/springbootEC2key .pem}"

echo "Restarting admin dashboard (Nginx) on EC2 ($EC2_IP)..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ec2-user@$EC2_IP" << 'ENDSSH'
set -e
echo "--- Web dashboard (Nginx) ---"
sudo systemctl restart nginx 2>/dev/null || sudo systemctl start nginx
echo "Nginx restarted. Dashboard :80"
ENDSSH
echo "Done."
