# 📱 Mobile Device Setup Guide for Dyganox

This guide will help you run your Flutter app and backend on a physical mobile device.

---

## 🔧 Prerequisites

- Flutter SDK installed on your computer
- Java backend running
- Physical Android/iOS device with USB cable
- Computer and mobile device on the **same WiFi network**

---

## 📝 Step 1: Find Your Computer's Local IP Address

### **Windows:**
1. Open **Command Prompt** (Press `Win + R`, type `cmd`, press Enter)
2. Type: `ipconfig` and press Enter
3. Look for **"IPv4 Address"** under your active WiFi adapter
4. Example: `192.168.1.100` or `10.0.0.50`

### **Mac:**
1. Open **Terminal** (Press `Cmd + Space`, type "terminal")
2. Type: `ifconfig | grep "inet "` or `ipconfig getifaddr en0`
3. Find the address that looks like `192.168.x.x` or `10.0.x.x`

### **Linux:**
1. Open **Terminal**
2. Type: `ip addr` or `hostname -I`
3. Find the address that looks like `192.168.x.x` or `10.0.x.x`

**📌 Important:** Make sure you get the **local IP** (not 127.0.0.1)

---

## 🔨 Step 2: Update API Configuration

1. Open `lib/services/api_config.dart` in your project
2. Update the following settings:

```dart
class ApiConfig {
  // Set to false when using physical device
  static const bool _useEmulator = false;
  
  // Replace with YOUR computer's IP address from Step 1
  static const String _localIpAddress = '192.168.1.100'; // CHANGE THIS!
  
  // Make sure this matches your backend port
  static const String _port = '8081';
}
```

**Example:**
If your computer's IP is `192.168.11.74`, change:
```dart
static const String _localIpAddress = '192.168.11.74';
```

---

## 🚀 Step 3: Start the Backend Server

### **If using Java Spring Boot backend:**

1. Open terminal/command prompt
2. Navigate to your backend directory:
   ```bash
   cd C:\Users\naikh\Dyganox\backend
   ```

3. Start the backend:
   ```bash
   # Using Maven
   mvn spring-boot:run
   
   # OR using the compiled JAR
   java -jar target/your-app-name.jar
   ```

4. Wait for the message: **"Started Application on port 8081"**

5. Verify backend is running by opening in browser:
   ```
   http://localhost:8081/api/mechanic
   ```

---

## 📱 Step 4: Prepare Your Mobile Device

### **Android Device:**

1. **Enable Developer Options:**
   - Go to **Settings → About Phone**
   - Tap **Build Number** 7 times
   - You'll see "You are now a developer!"

2. **Enable USB Debugging:**
   - Go to **Settings → Developer Options**
   - Turn on **USB Debugging**

3. **Connect to Computer:**
   - Connect phone via USB cable
   - When prompted on phone, tap **Allow USB Debugging**

4. **Verify Connection:**
   ```bash
   flutter devices
   ```
   You should see your device listed

### **iOS Device:**

1. Open Xcode on Mac
2. Add your Apple ID in Xcode → Preferences → Accounts
3. Connect iPhone via USB
4. Trust the computer on your iPhone when prompted

---

## 🏃 Step 5: Run the Flutter App

1. Open terminal in your project directory:
   ```bash
   cd C:\Users\naikh\Dyganox
   ```

2. Make sure your device is connected:
   ```bash
   flutter devices
   ```

3. Clean and get dependencies:
   ```bash
   flutter clean
   flutter pub get
   ```

4. Run the app on your device:
   ```bash
   flutter run
   ```

   Or if you have multiple devices:
   ```bash
   flutter run -d <device-id>
   ```

---

## ✅ Step 6: Test the Connection

1. Open the app on your mobile device
2. Navigate to **"Find Mechanic"** or **"EV Charging"** page
3. Check if data loads from the database
4. If you see data, **congratulations!** 🎉

---

## 🔍 Troubleshooting

### **Problem: App shows "Failed to connect" or no data loads**

**Solution 1: Check Network**
- Ensure computer and phone are on the **same WiFi network**
- Disable mobile data on phone (use WiFi only)
- Check if WiFi is not set to "AP Isolation" or "Guest Mode"

**Solution 2: Check Firewall**
- Windows: Allow Java through Windows Firewall
  - Go to **Windows Firewall → Allow an app**
  - Make sure **Java** and **javaw.exe** are allowed on Private network
  
**Solution 3: Verify Backend is Accessible**
- On your computer, open browser and go to:
  ```
  http://<YOUR-IP>:8081/api/mechanic
  ```
  Replace `<YOUR-IP>` with your actual IP address
  
- If this doesn't work, your firewall is blocking the connection

**Solution 4: Test from Phone Browser**
- Open Chrome/Safari on your phone
- Navigate to: `http://<YOUR-IP>:8081/api/mechanic`
- If this works, the issue is in the Flutter app configuration

**Solution 5: Check API Config**
- Verify `lib/services/api_config.dart`:
  ```dart
  static const bool _useEmulator = false;  // Should be false
  static const String _localIpAddress = '192.168.1.100'; // Your actual IP
  ```

**Solution 6: Check Backend Port**
- Make sure backend is running on port 8081
- Check `backend/src/main/resources/application.properties`:
  ```properties
  server.port=8081
  ```

---

## 📊 Verify Database Connection

1. Make sure MySQL/PostgreSQL is running
2. Check backend console for database connection logs
3. Test backend API manually:
   ```bash
   curl http://localhost:8081/api/mechanic
   ```

---

## 🔄 Quick Commands Reference

### **Find your IP (Windows):**
```bash
ipconfig
```

### **Start Backend:**
```bash
cd backend
mvn spring-boot:run
```

### **Run Flutter App:**
```bash
flutter clean
flutter pub get
flutter run
```

### **Check Connected Devices:**
```bash
flutter devices
```

### **Hot Reload (while app is running):**
Press `r` in terminal

### **Hot Restart:**
Press `R` in terminal

---

## 🌐 Network Configuration Tips

### **For Home WiFi:**
- Usually works without issues
- Make sure both devices are on same network

### **For Enterprise/School WiFi:**
- May have AP isolation enabled (blocks device-to-device communication)
- Try using mobile hotspot instead:
  1. Enable hotspot on your phone
  2. Connect computer to phone's hotspot
  3. Find computer's new IP address
  4. Update `api_config.dart` with new IP
  5. Run app

### **For Mobile Hotspot:**
1. Enable **Personal Hotspot** on your phone
2. Connect your computer to the hotspot
3. Find computer's IP (usually `192.168.43.x` or similar)
4. Update `api_config.dart`
5. Run backend on computer
6. Run Flutter app on phone

---

## 🎯 Testing Checklist

- [ ] Computer and phone on same WiFi
- [ ] Backend running on port 8081
- [ ] Firewall allows Java/backend
- [ ] `api_config.dart` has correct IP
- [ ] `_useEmulator` set to `false`
- [ ] Device connected and authorized
- [ ] Database is running and accessible
- [ ] Can access backend from computer browser
- [ ] Can access backend from phone browser
- [ ] Flutter app runs without errors

---

## 📞 API Endpoints Being Used

Your app uses these endpoints:
- **Mechanic:** `http://<YOUR-IP>:8081/api/mechanic`
- **Mechanic Requests:** `http://<YOUR-IP>:8081/api/mechanic-requests`
- **EV Provider:** `http://<YOUR-IP>:8081/api/evprovider`
- **Person (Test):** `http://<YOUR-IP>:8081/api/person`

---

## 💡 Pro Tips

1. **Use Hot Reload:** After making changes, press `r` instead of restarting the entire app
2. **Check Console:** Keep terminal open to see error messages
3. **Use Debug Mode:** Run with `flutter run --verbose` for detailed logs
4. **Test Backend First:** Always verify backend is accessible before running the app
5. **Print Current Config:** The app will print the API configuration on startup

---

## 🔒 Security Note

⚠️ This configuration is for **development only**. For production:
- Use HTTPS instead of HTTP
- Implement proper authentication
- Use environment variables for configuration
- Deploy backend to a proper hosting service

---

## 📱 Switching Between Emulator and Physical Device

### **To use Emulator:**
```dart
static const bool _useEmulator = true;
```

### **To use Physical Device:**
```dart
static const bool _useEmulator = false;
static const String _localIpAddress = '192.168.1.100'; // Your IP
```

---

## 🆘 Still Having Issues?

If you're still facing issues after following this guide:

1. **Check backend logs** for errors
2. **Check Flutter console** for error messages  
3. **Verify database** is running and has data
4. **Try using Postman** to test backend APIs directly
5. **Print debug info** in your code:
   ```dart
   ApiConfig.printConfig(); // Call this in your initState
   ```

---

## ✨ Success Indicators

You'll know everything is working when:
- ✅ Mechanic Finder page loads mechanics from database
- ✅ EV Charging page shows charging stations
- ✅ Registration forms successfully submit data
- ✅ No connection errors in the console
- ✅ Maps display correctly with markers

---

**Happy Coding! 🚀**

For more help, check the project's README.md or contact the development team.

