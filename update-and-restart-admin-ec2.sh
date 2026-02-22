#!/bin/bash
# Update admin dashboard (frontend) on EC2 and restart Nginx.
# Run from project root: ./update-and-restart-admin-ec2.sh [EC2_IP] [KEY_PATH]

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

EC2_IP="${1:-34.228.113.212}"
KEY_PATH="${2:-/home/pranam/Desktop/Dyganox-7/springbootEC2key .pem}"

echo "Updating admin dashboard (frontend) on EC2 and restarting Nginx..."
"$SCRIPT_DIR/admin-dashboard/deploy.sh" "$EC2_IP" "$KEY_PATH"
echo "Done. Dashboard: http://$EC2_IP"
