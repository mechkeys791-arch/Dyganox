# Setup EC2 Auto-Start Service (One-Time Setup)

## 🎯 Why Setup a Service?

**Current**: You need to manually restart Spring Boot after EC2 reboots  
**With Service**: Spring Boot auto-starts on EC2 reboot and can be managed easily

## ✅ Benefits

- ✅ Auto-starts on EC2 reboot
- ✅ Easy to restart: `sudo systemctl restart promech-backend`
- ✅ Easy to check status: `sudo systemctl status promech-backend`
- ✅ Auto-restarts if it crashes
- ✅ Better logging management

---

## 📋 One-Time Setup (Do This Once)

### Step 1: SSH into EC2

```bash
ssh -i your-key.pem ec2-user@YOUR_EC2_IP
```

### Step 2: Create Service File

```bash
sudo nano /etc/systemd/system/promech-backend.service
```

### Step 3: Add This Content

```ini
[Unit]
Description=ProMech Backend Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/app
ExecStart=/usr/bin/java -jar /home/ec2-user/app/ev-charging-backend-0.0.1-SNAPSHOT.jar
Restart=always
RestartSec=10
StandardOutput=append:/home/ec2-user/app/app.log
StandardError=append:/home/ec2-user/app/app.log

[Install]
WantedBy=multi-user.target
```

**Save**: Press `Ctrl+X`, then `Y`, then `Enter`

### Step 4: Enable and Start Service

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service (auto-start on boot)
sudo systemctl enable promech-backend

# Start service
sudo systemctl start promech-backend

# Check status
sudo systemctl status promech-backend
```

---

## 🚀 After Setup - Deployment Process

### Option A: Using Deployment Script (Easier)

**On your local machine**:
```bash
# Just run the script
deploy-to-ec2.bat
```

The script will:
1. Build JAR (if needed)
2. Copy to EC2
3. Restart the service

### Option B: Manual Deployment

**On your local machine**:
```bash
# 1. Build JAR
cd backend
mvn clean package -DskipTests
cd ..

# 2. Copy to EC2
scp -i your-key.pem backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar ec2-user@YOUR_EC2_IP:/home/ec2-user/app/
```

**On EC2** (via SSH):
```bash
# Restart service (automatically stops old, starts new)
sudo systemctl restart promech-backend

# Check if it started successfully
sudo systemctl status promech-backend
tail -f /home/ec2-user/app/app.log
```

---

## 🔧 Service Management Commands

### Check Status
```bash
sudo systemctl status promech-backend
```

### Start Service
```bash
sudo systemctl start promech-backend
```

### Stop Service
```bash
sudo systemctl stop promech-backend
```

### Restart Service
```bash
sudo systemctl restart promech-backend
```

### View Logs
```bash
# Service logs
sudo journalctl -u promech-backend -f

# Or app.log file
tail -f /home/ec2-user/app/app.log
```

### Disable Auto-Start (if needed)
```bash
sudo systemctl disable promech-backend
```

---

## 📝 Deployment Workflow

### When You Make Code Changes:

1. **Build JAR locally**:
   ```bash
   cd backend
   mvn clean package -DskipTests
   ```

2. **Deploy to EC2**:
   - **Easy way**: Run `deploy-to-ec2.bat`
   - **Manual way**: Copy JAR, then SSH and restart service

3. **Verify**:
   ```bash
   # Check service status
   sudo systemctl status promech-backend
   
   # Check logs
   tail -f /home/ec2-user/app/app.log
   ```

---

## ⚠️ Important Notes

- **First Time**: You need to set up the service (one-time)
- **After Setup**: Just deploy JAR and restart service
- **Auto-Restart**: Service will auto-start on EC2 reboot
- **Crash Recovery**: Service will auto-restart if Spring Boot crashes

---

## 🎯 Summary

**Before Setup**: Manual `nohup` process, need to restart manually  
**After Setup**: Managed service, easy restart, auto-start on reboot

**Setup Time**: ~5 minutes (one-time)  
**Deployment Time**: ~30 seconds (after setup)
