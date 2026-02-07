# Deploy Fixed JAR to EC2

## ✅ Issue Fixed

**Problem**: Square payment properties were commented out, causing Spring Boot to fail on startup.

**Solution**: Uncommented Square properties and rebuilt JAR.

## 🚀 Deploy Updated JAR

### Step 1: Copy New JAR to EC2

**On your local machine** (replace with your EC2 IP and key):

```bash
scp -i your-key.pem backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar ec2-user@YOUR_EC2_IP:/home/ec2-user/app/
```

### Step 2: Stop Old Spring Boot Process

**SSH into EC2**:

```bash
ssh -i your-key.pem ec2-user@YOUR_EC2_IP
cd /home/ec2-user/app

# Stop any running Spring Boot process
pkill -f ev-charging-backend

# Wait a moment
sleep 2

# Verify it's stopped
ps aux | grep java
```

### Step 3: Start Spring Boot with New JAR

**Option A: Run in Background (Recommended)**

```bash
cd /home/ec2-user/app
nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar > app.log 2>&1 &

# Check if it started
sleep 5
tail -20 app.log
```

**Option B: Run in Foreground (to see logs)**

```bash
cd /home/ec2-user/app
java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar
```

### Step 4: Verify It's Running

```bash
# Check if Java process is running
ps aux | grep java

# Check if port 8081 is listening
sudo netstat -tlnp | grep 8081
# OR
sudo ss -tlnp | grep 8081

# Check logs for success
tail -f app.log
```

### Step 5: Test API Endpoints

**From your local machine**:

```bash
# Test mechanic endpoint
curl http://YOUR_EC2_IP:8081/api/mechanic

# Test EV provider endpoint
curl http://YOUR_EC2_IP:8081/api/evprovider
```

## ✅ Expected Success Logs

You should see:
```
✅ HikariPool-1 - Start completed.
✅ Started DemoApplication
✅ Tomcat started on port(s): 8081 (http)
```

**No errors** about `square.application.id` or `square.access.token`!

## 🔍 If Using Systemd Service

If you set up a systemd service, restart it:

```bash
sudo systemctl restart promech-backend
sudo systemctl status promech-backend
```

## 📝 What Was Fixed

**Before** (commented out):
```properties
# # Square Payment Gateway Configuration (Sandbox)
# # 🔥 PUT YOUR SQUARE SANDBOX CREDENTIALS HERE 🔥
square.environment=sandbox
square.application.id=sandbox-sq0idb-0UJaOZfiilnERiwDLf9t_Q
square.access.token=EAAAlxcrAOyG7VOxzEvHoOPXD91DqpuYLhnh4TuRRr6u47bBn52r6lpP1L9oO0mt
```

**After** (properly configured):
```properties
# Square Payment Gateway Configuration (Sandbox)
square.environment=sandbox
square.application.id=sandbox-sq0idb-0UJaOZfiilnERiwDLf9t_Q
square.access.token=EAAAlxcrAOyG7VOxzEvHoOPXD91DqpuYLhnh4TuRRr6u47bBn52r6lpP1L9oO0mt
```

The properties are now properly uncommented and included in the JAR.
