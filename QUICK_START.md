# 🚀 Quick Start Guide - Running on Your Mobile Device

## ✅ All Set! Your Configuration:

- **Your Computer's IP:** `192.168.11.73`
- **Backend Port:** `8081`
- **Configuration File:** Updated ✓

---

## 📋 Now Follow These Simple Steps:

### **1️⃣ Start the Backend (Java Spring Boot)**

Open a terminal and run:

```bash
cd backend
mvn spring-boot:run
```

**Wait for:** "Started Application on port 8081"

### **2️⃣ Verify Backend is Running**

Open your browser and go to:
```
http://localhost:8081/api/mechanic
```

You should see JSON data (mechanic list).

### **3️⃣ Connect Your Phone**

1. Connect phone to computer via USB
2. Enable USB Debugging on phone:
   - Settings → About Phone
   - Tap "Build Number" 7 times
   - Go back → Developer Options → Enable USB Debugging
3. Accept USB debugging prompt on phone

### **4️⃣ Run the Flutter App**

**Option A: Use the batch file (Easiest)**
```bash
run-on-mobile.bat
```

**Option B: Manual command**
```bash
flutter clean
flutter pub get
flutter run
```

---

## ✨ What's Been Fixed:

✅ Created centralized API configuration (`lib/services/api_config.dart`)  
✅ Updated all mechanic pages to use API config  
✅ Updated all EV charging pages to use API config  
✅ Updated all test pages to use API config  
✅ Configured with your computer's IP: `192.168.11.73`  
✅ Set to physical device mode (`_useEmulator = false`)  

---

## 🔍 Testing the Connection:

Once the app is running on your phone:

1. Navigate to **"Find Mechanic"** page
2. You should see mechanics from your database
3. Navigate to **"EV Charging"** page
4. You should see charging stations from your database

---

## ⚠️ Important Notes:

1. **Same WiFi Network:** Make sure your computer AND phone are on the same WiFi network
2. **Firewall:** Windows Firewall might block connections. If data doesn't load:
   - Go to Windows Firewall settings
   - Allow Java through the firewall
   
3. **Backend Must Be Running:** Always start the backend BEFORE running the Flutter app

---

## 🐛 Troubleshooting:

### Problem: No data loads on phone

**Quick Fix:**
```bash
# On your computer, open browser and test:
http://192.168.11.73:8081/api/mechanic

# If this doesn't work, check:
1. Backend is running
2. Firewall allows port 8081
3. Both devices on same WiFi
```

### Problem: Connection refused

1. Check if backend is running: Look for "Started Application on port 8081" in backend console
2. Test from computer browser first: `http://localhost:8081/api/mechanic`
3. Check firewall settings

### Problem: App can't find device

```bash
# Check connected devices:
flutter devices

# If no devices shown:
1. Reconnect USB cable
2. Accept USB debugging on phone
3. Try different USB port
```

---

## 📞 Quick Test Commands:

```bash
# 1. Check if backend is accessible from phone
# Open phone browser and go to:
http://192.168.11.73:8081/api/mechanic

# 2. Check connected devices
flutter devices

# 3. See detailed logs
flutter run --verbose
```

---

## 🎯 Your API Endpoints:

All configured to use `http://192.168.11.73:8081`

- Mechanics: `/api/mechanic`
- Mechanic Requests: `/api/mechanic-requests`  
- EV Providers: `/api/evprovider`
- Test Endpoint: `/api/person`

---

## 💡 Pro Tips:

1. **Keep terminal open** to see logs while app runs
2. **Use Hot Reload** (press `r`) after making code changes
3. **Check backend console** for incoming API requests
4. **Use the test pages** in your app to verify connection

---

## 📁 Key Files Updated:

- `lib/services/api_config.dart` - API configuration (with your IP)
- `lib/screens/mechanic/mechanic_finder_page.dart` - Now uses ApiConfig
- `lib/screens/mechanic/mechanic_registration_page.dart` - Now uses ApiConfig
- `lib/screens/mechanic/mechanic_dashboard_page.dart` - Now uses ApiConfig
- `lib/screens/ev_charging/ev_charging_page.dart` - Now uses ApiConfig
- `lib/screens/ev_charging/ev_charging_user_page.dart` - Now uses ApiConfig
- All test pages - Now use ApiConfig

---

## 🔄 Switching Back to Emulator:

If you want to test on emulator again:

1. Open `lib/services/api_config.dart`
2. Change: `static const bool _useEmulator = true;`
3. Run: `flutter run`

---

**🎉 You're all set! Run the backend, connect your phone, and launch the app!**

For detailed troubleshooting, see `MOBILE_SETUP_GUIDE.md`

