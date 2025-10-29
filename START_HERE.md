# 🎯 START HERE - Complete Setup Guide

## ✅ **Everything is Ready!**

Your Dyganox app is fully configured to run on your mobile device!

---

## 🚀 **Fastest Way to Get Running:**

### **Single Command (Recommended):**
```bash
run-everything.bat
```
This starts backend + Flutter app automatically!

### **Or Step by Step:**

**Terminal 1 - Backend:**
```bash
start-backend.bat
```

**Terminal 2 - Flutter App:**
```bash
flutter run
```

---

## 📱 **What You Need:**

✅ Phone connected via USB  
✅ USB Debugging enabled  
✅ Computer and phone on same WiFi  
✅ Database running (PostgreSQL/MySQL)  

---

## 🎯 **Quick Setup Checklist:**

- [x] ✅ IP configuration updated (`192.168.11.73`)
- [x] ✅ API config file created
- [x] ✅ All pages updated to use API config
- [x] ✅ Backend JAR built successfully
- [x] ✅ Helper scripts created

---

## 📂 **Helper Scripts Created:**

| Script | Purpose |
|--------|---------|
| **`run-everything.bat`** | 🚀 Start backend + Flutter (one click!) |
| **`start-backend.bat`** | ▶️ Start backend server |
| **`build-backend.bat`** | 🔨 Build JAR file |
| **`run-on-mobile.bat`** | 📱 Launch Flutter app only |
| **`find-my-ip.bat`** | 🔍 Find your IP address |

---

## 📚 **Documentation Files:**

| File | What It Contains |
|------|------------------|
| **`QUICK_START.md`** | ⚡ Fast start guide (read this first!) |
| **`MOBILE_SETUP_GUIDE.md`** | 📱 Complete mobile setup instructions |
| **`BACKEND_JAR_GUIDE.md`** | 🔧 Backend JAR file guide |
| **`SETUP_COMPLETE.md`** | ✅ Summary of all changes |

---

## 🎬 **Step-by-Step Instructions:**

### **Step 1: Start Backend**
```bash
start-backend.bat
```
Wait for: **"Started DemoApplication in X seconds"**

### **Step 2: Test Backend**
Open browser: `http://localhost:8081/api/mechanic`  
You should see: JSON data (list of mechanics)

### **Step 3: Test from Phone**
Open phone browser: `http://192.168.11.73:8081/api/mechanic`  
You should see: Same JSON data

### **Step 4: Connect Phone**
1. Enable **Developer Options** (tap Build Number 7 times)
2. Enable **USB Debugging**
3. Connect via USB cable
4. Accept debugging prompt on phone

### **Step 5: Run Flutter App**
```bash
flutter run
```
Or use: `run-on-mobile.bat`

### **Step 6: Test in App**
- Open **"Find Mechanic"** → Should show mechanics ✅
- Open **"EV Charging"** → Should show stations ✅

---

## 🎯 **Your Configuration:**

```
Computer IP:     192.168.11.73
Backend Port:    8081
Backend URL:     http://192.168.11.73:8081
Device Mode:     Physical Device
JAR File:        backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar
```

---

## 🔥 **Common Issues & Quick Fixes:**

### **Issue: No data loading in app**
```bash
# 1. Check backend is running
# Look for "Started DemoApplication" in backend terminal

# 2. Test from phone browser
http://192.168.11.73:8081/api/mechanic

# 3. Check Windows Firewall
# Allow Java through firewall on Private network
```

### **Issue: Can't connect to backend from phone**
```bash
# 1. Verify same WiFi
# Both computer and phone must be on same WiFi

# 2. Check IP is correct
find-my-ip.bat

# 3. Test firewall
# Temporarily disable to test (don't forget to re-enable!)
```

### **Issue: Backend won't start**
```bash
# 1. Check if port 8081 is in use
netstat -ano | findstr :8081

# 2. Kill process if needed
taskkill /F /PID <process_id>

# 3. Check database is running
# PostgreSQL/MySQL must be running
```

---

## 🎯 **Testing Workflow:**

1. **Backend Test:**
   ```
   Browser: http://localhost:8081/api/mechanic
   Expected: JSON array of mechanics
   ```

2. **Network Test:**
   ```
   Phone Browser: http://192.168.11.73:8081/api/mechanic
   Expected: Same JSON data
   ```

3. **Flutter Test:**
   ```
   App: Find Mechanic page
   Expected: List of mechanics with details
   ```

---

## 📊 **Project Structure:**

```
Dyganox/
├── backend/
│   ├── src/                    # Source code
│   ├── target/                 # Built JAR
│   └── pom.xml                 # Maven config
├── lib/
│   ├── services/
│   │   └── api_config.dart     # ⭐ API configuration
│   └── screens/                # App pages
├── start-backend.bat           # ⭐ Start backend
├── run-everything.bat          # ⭐ Start everything
├── run-on-mobile.bat           # ⭐ Run Flutter
└── Documentation files...
```

---

## 🔧 **Key Files Modified:**

### **API Configuration:**
`lib/services/api_config.dart` - Centralized API URLs

### **Mechanic Pages:**
- `mechanic_finder_page.dart`
- `mechanic_registration_page.dart`
- `mechanic_dashboard_page.dart`

### **EV Charging Pages:**
- `ev_charging_page.dart`
- `ev_charging_user_page.dart`

### **Test Pages:**
- `backend_test_page.dart`
- `test_connection_page.dart`

---

## 🎬 **Demo Workflow:**

```bash
# 1. Start everything
run-everything.bat

# 2. App opens on phone

# 3. Test features:
   - Register as mechanic
   - Find mechanics
   - Request mechanic service
   - Register as EV provider
   - Find charging stations

# 4. Check backend logs
   # Watch terminal for API requests
```

---

## 💻 **Backend API Endpoints:**

```
GET    /api/mechanic              - List all mechanics
POST   /api/mechanic              - Register mechanic
GET    /api/mechanic-requests/... - Get requests
POST   /api/mechanic-requests     - Create request
PUT    /api/mechanic-requests/... - Accept/Reject
GET    /api/evprovider            - List EV providers
POST   /api/evprovider            - Register provider
```

---

## 📱 **Flutter App Features:**

✅ **Mechanic Finder** - Find nearby mechanics  
✅ **Mechanic Registration** - Register as mechanic  
✅ **Mechanic Dashboard** - Manage service requests  
✅ **EV Charging** - Find charging stations  
✅ **EV Provider** - Register as charging provider  
✅ **Test Pages** - Connection testing  

---

## 🔐 **Security Notes:**

⚠️ **Current setup is for DEVELOPMENT only!**

For production:
- Use HTTPS instead of HTTP
- Implement authentication (JWT/OAuth)
- Use environment variables
- Deploy to cloud (AWS/Google Cloud/Azure)
- Enable proper CORS settings
- Use API gateway

---

## 🎯 **Success Indicators:**

You'll know everything works when:

✅ Backend starts without errors  
✅ Can access APIs in browser  
✅ Can access APIs from phone browser  
✅ Mechanic data loads in app  
✅ EV charging data loads in app  
✅ Can register new mechanics  
✅ Can register new EV providers  
✅ Maps show correctly  
✅ No connection errors in console  

---

## 📞 **Need Help?**

### **Read These Guides:**
1. `QUICK_START.md` - Fast setup
2. `MOBILE_SETUP_GUIDE.md` - Detailed setup
3. `BACKEND_JAR_GUIDE.md` - Backend help
4. `SETUP_COMPLETE.md` - Technical details

### **Check Logs:**
```bash
# Backend logs
# Check terminal where backend is running

# Flutter logs
flutter logs

# Verbose logs
flutter run --verbose
```

### **Test Commands:**
```bash
# Check devices
flutter devices

# Check IP
find-my-ip.bat

# Test backend
curl http://localhost:8081/api/mechanic
```

---

## 🏆 **You're All Set!**

Everything is configured and ready to run. Just execute:

```bash
run-everything.bat
```

And start testing your app on your mobile device!

---

## 📋 **Final Checklist:**

- [ ] Backend JAR built ✅ (Done!)
- [ ] IP configured ✅ (Done!)
- [ ] API config updated ✅ (Done!)
- [ ] Phone connected via USB
- [ ] USB debugging enabled
- [ ] Same WiFi network
- [ ] Database running
- [ ] Run `start-backend.bat`
- [ ] Run `flutter run`
- [ ] Test app features

---

**🎉 Happy Testing!**

Your Dyganox app is ready to run on your mobile device!

---

**Created:** 2025-10-29  
**IP Address:** 192.168.11.73  
**Backend Port:** 8081  
**JAR File:** ev-charging-backend-0.0.1-SNAPSHOT.jar  
**Status:** ✅ Ready for Mobile Testing

