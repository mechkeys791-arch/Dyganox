# Deploy Backend to EC2

## Steps to Update Backend on EC2

### 1. Build the JAR file locally

```bash
cd backend
mvn clean package -DskipTests
```

This will create: `backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar`

### 2. Upload JAR to EC2

**Option A: Using SCP (from your local machine)**
```bash
scp -i /path/to/your-key.pem backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar ec2-user@54.175.33.37:/home/ec2-user/
```

**Option B: Using AWS Console**
- Upload the JAR file through AWS Systems Manager Session Manager or EC2 Instance Connect

### 3. SSH into EC2 Instance

```bash
ssh -i /path/to/your-key.pem ec2-user@54.175.33.37
```

### 4. Stop the Running Backend (if running as a service)

**If running as a systemd service:**
```bash
sudo systemctl stop dyganox-backend
# or
sudo systemctl stop spring-boot-app
```

**If running directly with java -jar:**
```bash
# Find the process
ps aux | grep java
# Kill it (replace PID with actual process ID)
kill -9 <PID>
```

**If running in screen/tmux:**
```bash
screen -r
# or
tmux attach
# Then Ctrl+C to stop
```

### 5. Replace the Old JAR

```bash
# Backup old JAR (optional but recommended)
mv ev-charging-backend-0.0.1-SNAPSHOT.jar ev-charging-backend-0.0.1-SNAPSHOT.jar.backup

# Move new JAR to the correct location
# (Adjust path based on where your backend runs from)
mv ~/ev-charging-backend-0.0.1-SNAPSHOT.jar /path/to/backend/
```

### 6. Start the Backend

**If using systemd:**
```bash
sudo systemctl start dyganox-backend
sudo systemctl status dyganox-backend
```

**If running directly:**
```bash
nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar > backend.log 2>&1 &
```

**If using screen:**
```bash
screen -S backend
java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar
# Press Ctrl+A then D to detach
```

**If using tmux:**
```bash
tmux new -s backend
java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar
# Press Ctrl+B then D to detach
```

### 7. Verify the Backend is Running

```bash
# Check if port 8081 is listening
netstat -tuln | grep 8081
# or
ss -tuln | grep 8081

# Check logs
tail -f backend.log
# or if using systemd
sudo journalctl -u dyganox-backend -f
```

### 8. Test the Endpoint

```bash
curl -X POST http://localhost:8081/api/person/profile \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","name":"Test","phone":"1234567890"}'
```

## Quick One-Liner (if you have direct access)

```bash
cd backend && mvn clean package -DskipTests && \
scp -i ~/.ssh/your-key.pem target/ev-charging-backend-0.0.1-SNAPSHOT.jar ec2-user@54.175.33.37:/home/ec2-user/ && \
ssh -i ~/.ssh/your-key.pem ec2-user@54.175.33.37 "sudo systemctl restart dyganox-backend"
```

## Notes

- Make sure port 8081 is open in your EC2 security group
- The backend should bind to `0.0.0.0` (already configured in application.properties)
- After deployment, the `/api/person/profile` endpoint should work correctly
- The Flutter app has a fallback to `/api/person` if the profile endpoint isn't available yet
