# New EC2 Instance Setup Guide

## 🎯 Fresh Start - New EC2 Instance Setup

This guide will help you set up a new EC2 instance from scratch for your ProMech app.

## ✅ What's Already Configured

1. **RDS Database**: ✅ Configured and ready
   - Endpoint: `postgresforpro.cw52wo446izi.us-east-1.rds.amazonaws.com:5432`
   - Username: `postgres_ForPro`
   - Password: `Promech0980`
   - Database: `postgres`

2. **Backend Code**: ✅ Ready
   - `application.properties` has correct RDS credentials
   - JAR can be built with: `mvn clean package -DskipTests`

3. **Flutter App**: ✅ Ready
   - `api_config.dart` needs EC2 IP update (will be done after EC2 creation)

## 📋 Step-by-Step Setup

### Step 1: Create New EC2 Instance

1. **Go to AWS Console** → **EC2** → **Launch Instance**

2. **Configure Instance**:
   - **Name**: `promech-backend` (or your preferred name)
   - **AMI**: Amazon Linux 2023 or Ubuntu 22.04 LTS
   - **Instance Type**: `t2.micro` (free tier) or `t3.small` (recommended)
   - **Key Pair**: Create new key pair or use existing
     - Download the `.pem` file
     - Save it securely (you'll need it for SSH)

3. **Network Settings**:
   - **VPC**: Use default or same VPC as RDS
   - **Subnet**: Public subnet
   - **Auto-assign Public IP**: Enable
   - **Security Group**: Create new security group
     - **Inbound Rules**:
       - SSH (22) from your IP
       - Custom TCP (8081) from `0.0.0.0/0` (for Spring Boot API)
     - **Outbound Rules**: Allow all (default)

4. **Storage**: 8 GB (free tier) or 20 GB (recommended)

5. **Launch Instance**

### Step 2: Configure Security Groups

#### EC2 Security Group:
- ✅ SSH (22) from your IP
- ✅ Custom TCP (8081) from `0.0.0.0/0`

#### RDS Security Group:
- ✅ PostgreSQL (5432) from EC2 Security Group ID
- ✅ PostgreSQL (5432) from your IP (for testing)

**How to add EC2 Security Group to RDS**:
1. Go to RDS → `postgresforpro` → Connectivity & security
2. Click Security Group → Inbound Rules → Edit
3. Add rule: PostgreSQL (5432) from EC2 Security Group ID

### Step 3: Connect to EC2 and Install Java

```bash
# Connect to EC2 (replace with your key and IP)
ssh -i your-key.pem ec2-user@YOUR_EC2_IP

# Update system
sudo yum update -y  # For Amazon Linux
# OR
sudo apt update && sudo apt upgrade -y  # For Ubuntu

# Install Java 17
sudo yum install java-17-amazon-corretto -y  # Amazon Linux
# OR
sudo apt install openjdk-17-jdk -y  # Ubuntu

# Verify Java installation
java -version
```

### Step 4: Build and Deploy JAR

**On Your Local Machine**:

```bash
# Build JAR
cd backend
mvn clean package -DskipTests

# Copy JAR to EC2
scp -i your-key.pem target/ev-charging-backend-0.0.1-SNAPSHOT.jar ec2-user@YOUR_EC2_IP:/home/ec2-user/
```

**On EC2**:

```bash
# Create app directory
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

# Move JAR file
mv /home/ec2-user/ev-charging-backend-0.0.1-SNAPSHOT.jar .

# Test run (to verify connection)
java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar
```

### Step 5: Create Systemd Service (Optional but Recommended)

**On EC2**, create a service file:

```bash
sudo nano /etc/systemd/system/promech-backend.service
```

**Add this content**:
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

**Enable and start service**:
```bash
sudo systemctl daemon-reload
sudo systemctl enable promech-backend
sudo systemctl start promech-backend
sudo systemctl status promech-backend
```

### Step 6: Update Flutter App Configuration

**Update `lib/services/api_config.dart`**:

```dart
// AWS EC2 Instance Public IP
static const String _ec2PublicIp = 'YOUR_NEW_EC2_IP';
```

### Step 7: Test Connection

**Test Spring Boot API**:
```bash
curl http://YOUR_EC2_IP:8081/api/mechanic
curl http://YOUR_EC2_IP:8081/api/evprovider
```

**Check Logs** (if using systemd):
```bash
sudo journalctl -u promech-backend -f
```

**Or check app.log**:
```bash
tail -f /home/ec2-user/app/app.log
```

## ✅ Verification Checklist

- [ ] EC2 instance is running
- [ ] Java 17 is installed on EC2
- [ ] JAR file is deployed to EC2
- [ ] Spring Boot is running (check with `ps aux | grep java`)
- [ ] Port 8081 is accessible (test with curl)
- [ ] RDS Security Group allows EC2 Security Group
- [ ] EC2 Security Group allows port 8081
- [ ] Flutter app has correct EC2 IP in `api_config.dart`
- [ ] Database connection works (check logs for no errors)

## 🔍 Troubleshooting

### Spring Boot Not Starting:
- Check Java version: `java -version` (should be 17+)
- Check logs: `tail -f app.log`
- Verify RDS connection in logs

### Connection Timeout:
- Verify security groups are configured correctly
- Check EC2 is in same VPC as RDS (or has VPC peering)
- Verify RDS Security Group allows EC2 Security Group

### Database Connection Failed:
- Check RDS Security Group inbound rules
- Verify RDS endpoint in `application.properties`
- Check RDS status is "Available"

## 📝 Quick Reference

**RDS Endpoint**: `postgresforpro.cw52wo446izi.us-east-1.rds.amazonaws.com:5432`
**RDS Username**: `postgres_ForPro`
**RDS Password**: `Promech0980`
**Spring Boot Port**: `8081`
**Database Port**: `5432`

## 🎉 Next Steps

After setup is complete:
1. Test all API endpoints
2. Test from Flutter app
3. Monitor logs for any issues
4. Set up CloudWatch for monitoring (optional)
