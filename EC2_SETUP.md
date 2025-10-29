# ☁️ AWS EC2 Configuration

Your app is now configured to use AWS EC2 instance!

---

## ✅ **Current Configuration:**

```yaml
Server Type:     AWS EC2 (Remote)
EC2 Public IP:   98.93.125.193
Backend Port:    8081
Base URL:        http://98.93.125.193:8081
```

---

## 🎯 **API Endpoints:**

All endpoints now point to your EC2 instance:

```
Base URL: http://98.93.125.193:8081

Mechanic:
  GET/POST    http://98.93.125.193:8081/api/mechanic
  
Mechanic Requests:
  GET/POST    http://98.93.125.193:8081/api/mechanic-requests
  PUT         http://98.93.125.193:8081/api/mechanic-requests/{id}/accept
  PUT         http://98.93.125.193:8081/api/mechanic-requests/{id}/reject

EV Provider:
  GET/POST    http://98.93.125.193:8081/api/evprovider

Test:
  GET/POST    http://98.93.125.193:8081/api/person
```

---

## 🚀 **Running the App:**

Since you're using EC2, you don't need to run the backend locally!

### **Just run the Flutter app:**
```bash
flutter run
```

Or use the helper script:
```bash
run-on-mobile.bat
```

---

## ✅ **Test EC2 Backend Connection:**

### **From Your Computer Browser:**
```
http://98.93.125.193:8081/api/mechanic
```

### **From Your Phone Browser:**
```
http://98.93.125.193:8081/api/mechanic
```

### **Expected Response:**
JSON array of mechanics from your database

---

## 🔧 **Configuration File:**

Updated: `lib/services/api_config.dart`

```dart
class ApiConfig {
  static const bool _useLocalServer = false;  // Using EC2
  static const String _ec2PublicIp = '98.93.125.193';
  static const String _port = '8081';
  
  // Computed URL: http://98.93.125.193:8081
}
```

---

## 🔄 **Switching Between Local and EC2:**

### **To use EC2 (current setup):**
```dart
static const bool _useLocalServer = false;  // ✅ Current
```

### **To use local server:**
```dart
static const bool _useLocalServer = true;
```

---

## ⚠️ **EC2 Security Group Requirements:**

Make sure your EC2 security group allows:

### **Inbound Rules:**
- **Port 8081** (HTTP) - From anywhere (0.0.0.0/0)
- **Port 22** (SSH) - For server management
- **Port 5432/3306** - Database (if using RDS)

### **Check Security Group:**
1. Go to AWS Console → EC2 → Security Groups
2. Find your instance's security group
3. Edit Inbound Rules
4. Add rule:
   - Type: Custom TCP
   - Port: 8081
   - Source: 0.0.0.0/0 (or your IP for security)

---

## 🧪 **Testing Checklist:**

- [ ] EC2 instance is running
- [ ] Backend is running on EC2 (port 8081)
- [ ] Security group allows port 8081
- [ ] Can access from browser: `http://98.93.125.193:8081/api/mechanic`
- [ ] Flutter app configured to use EC2 IP
- [ ] App runs without connection errors
- [ ] Data loads in Mechanic Finder
- [ ] Data loads in EV Charging pages

---

## 🐛 **Troubleshooting:**

### **Problem: Connection timeout**

**Check:**
1. EC2 instance is running
2. Backend service is running on EC2
3. Security group allows port 8081
4. EC2 public IP is correct (it changes if instance restarts!)

**Test:**
```bash
# From your computer
curl http://98.93.125.193:8081/api/mechanic

# If this fails, problem is with EC2, not Flutter app
```

### **Problem: Connection refused**

**Solution:**
```bash
# SSH into EC2
ssh -i your-key.pem ec2-user@98.93.125.193

# Check if backend is running
ps aux | grep java

# Start backend if not running
nohup java -jar your-backend.jar &

# Check logs
tail -f nohup.out
```

### **Problem: Data not loading**

**Steps:**
1. Test EC2 directly from browser
2. Check Flutter console for error messages
3. Verify API endpoints return data
4. Check EC2 backend logs

---

## 🔐 **Security Best Practices:**

### **For Development:**
✅ HTTP is fine  
✅ Port 8081 open to all  

### **For Production:**
⚠️ **You should:**
1. Use HTTPS (not HTTP)
2. Get SSL certificate (Let's Encrypt)
3. Use Elastic Load Balancer
4. Restrict security group to specific IPs
5. Use environment variables
6. Enable CloudWatch monitoring
7. Set up auto-scaling
8. Use RDS for database (not local DB)

---

## 📊 **EC2 Backend Management:**

### **Connect to EC2:**
```bash
ssh -i your-key.pem ec2-user@98.93.125.193
```

### **Check Backend Status:**
```bash
ps aux | grep java
```

### **View Backend Logs:**
```bash
tail -f nohup.out
# or
journalctl -u your-backend-service -f
```

### **Restart Backend:**
```bash
# Find process
ps aux | grep java

# Kill process
kill <PID>

# Restart
nohup java -jar backend.jar &
```

### **Check Port 8081:**
```bash
netstat -tulpn | grep 8081
```

---

## 🌐 **DNS Setup (Optional):**

Instead of using IP, you can use a domain name:

1. Register domain (e.g., api.dyganox.com)
2. Point to EC2 IP: 98.93.125.193
3. Update API config:
   ```dart
   static const String _ec2PublicIp = 'api.dyganox.com';
   ```

---

## 📱 **Running on Mobile:**

### **No Local Server Needed!**

Just run:
```bash
flutter run
```

Your app will connect to EC2 automatically.

### **Test Connection:**

1. Open app on phone
2. Go to "Find Mechanic" page
3. Should see mechanics from EC2 database
4. Go to "EV Charging" page
5. Should see charging stations from EC2 database

---

## ⚡ **Advantages of Using EC2:**

✅ No need to keep computer on  
✅ Backend accessible from anywhere  
✅ No WiFi/network restrictions  
✅ Better for testing with multiple devices  
✅ Closer to production setup  
✅ Can scale horizontally  
✅ Professional deployment  

---

## 🚨 **Important Notes:**

### **EC2 Public IP Changes:**
⚠️ If you stop/start your EC2 instance, the public IP may change!

**Solutions:**
1. Use **Elastic IP** (static IP that doesn't change)
2. Or update API config when IP changes

### **Costs:**
- EC2 instance (t2.micro = free tier)
- Data transfer (outbound)
- Elastic IP (free if attached to running instance)
- RDS (if using managed database)

---

## 📋 **Quick Commands:**

### **Test Backend:**
```bash
# From anywhere
curl http://98.93.125.193:8081/api/mechanic

# With details
curl -v http://98.93.125.193:8081/api/mechanic
```

### **Test from Phone Browser:**
```
http://98.93.125.193:8081/api/mechanic
```

### **Run Flutter App:**
```bash
flutter run
```

### **Check API Config:**
```bash
# The app will print on startup:
# Base URL: http://98.93.125.193:8081
```

---

## 🎯 **Current Setup Summary:**

```
Local Server:    ❌ Not used
AWS EC2:         ✅ Active
EC2 IP:          98.93.125.193
Port:            8081
Flutter Config:  ✅ Updated
Ready to Test:   ✅ Yes

Database:        On EC2 (PostgreSQL/MySQL)
Backend JAR:     Running on EC2
Flutter App:     Connects to EC2
```

---

## ✨ **You're All Set!**

Your app is now configured to use AWS EC2 backend!

Simply run:
```bash
flutter run
```

And your app will connect to the EC2 instance at `98.93.125.193:8081`

---

**No need to run local backend anymore! 🎉**

Just make sure:
1. ✅ EC2 instance is running
2. ✅ Backend service is running on EC2
3. ✅ Security group allows port 8081
4. ✅ Flutter app is configured with EC2 IP

**Happy testing! ☁️📱**

