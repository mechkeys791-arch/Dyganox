# 🚀 Backend JAR File Guide

Your Spring Boot backend has been successfully built as a JAR file!

---

## 📦 JAR File Location:

```
backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar
```

---

## 🎯 Three Ways to Run Your Backend:

### **Option 1: Use the Helper Script (Easiest)**
```bash
start-backend.bat
```

This will:
- Check if JAR exists (build if needed)
- Start the backend server on port 8081
- Display connection URLs

### **Option 2: Use Maven**
```bash
cd backend
mvn spring-boot:run
```

### **Option 3: Run JAR Directly**
```bash
cd backend
java -jar target/ev-charging-backend-0.0.1-SNAPSHOT.jar
```

---

## 🔄 Rebuild JAR File:

If you make changes to backend code, rebuild the JAR:

### **Quick Rebuild:**
```bash
build-backend.bat
```

### **Manual Rebuild:**
```bash
cd backend
mvn clean package -DskipTests
```

### **With Tests:**
```bash
cd backend
mvn clean package
```

---

## 🚀 Complete Workflow (Backend + Flutter):

### **Option A: All-in-One Script**
```bash
run-everything.bat
```
This will:
1. Build backend JAR
2. Start backend server
3. Launch Flutter app on your phone

### **Option B: Manual Steps**
```bash
# Terminal 1 - Start Backend
start-backend.bat

# Terminal 2 - Run Flutter App
flutter run
```

---

## ✅ Verify Backend is Running:

### **Test from Computer:**
```
http://localhost:8081/api/mechanic
```

### **Test from Phone Browser:**
```
http://192.168.11.73:8081/api/mechanic
```

You should see JSON data (list of mechanics).

---

## 📊 Backend Endpoints:

Your backend exposes these APIs:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/mechanic` | GET | Get all mechanics |
| `/api/mechanic` | POST | Register new mechanic |
| `/api/mechanic-requests` | POST | Create mechanic request |
| `/api/mechanic-requests/mechanic/{id}/pending` | GET | Get pending requests |
| `/api/mechanic-requests/{id}/accept` | PUT | Accept request |
| `/api/mechanic-requests/{id}/reject` | PUT | Reject request |
| `/api/evprovider` | GET | Get all EV providers |
| `/api/evprovider` | POST | Register new provider |
| `/api/person` | GET | Test endpoint |
| `/api/person` | POST | Test endpoint |

---

## 🔧 Backend Configuration:

The JAR file uses settings from `backend/src/main/resources/application.properties`:

```properties
server.port=8081
spring.datasource.url=jdbc:postgresql://localhost:5432/your_database
spring.datasource.username=your_username
spring.datasource.password=your_password
```

---

## 🐛 Troubleshooting:

### **Problem: "Port 8081 already in use"**

**Solution:**
```bash
# Windows - Find process using port 8081
netstat -ano | findstr :8081

# Kill the process (replace PID with actual process ID)
taskkill /F /PID <PID>
```

### **Problem: JAR file not found**

**Solution:**
```bash
build-backend.bat
```

### **Problem: Database connection error**

**Solution:**
1. Make sure PostgreSQL/MySQL is running
2. Check database credentials in `application.properties`
3. Verify database exists

### **Problem: "Java not found"**

**Solution:**
- Install Java 17 or later
- Verify: `java -version`

---

## 📱 Running Backend for Mobile Testing:

1. **Start Backend:**
   ```bash
   start-backend.bat
   ```

2. **Verify Backend:**
   - Test from computer: `http://localhost:8081/api/mechanic`
   - Test from phone browser: `http://192.168.11.73:8081/api/mechanic`

3. **Run Flutter App:**
   ```bash
   flutter run
   ```

4. **Test in App:**
   - Open "Find Mechanic" page
   - Should see mechanics from database

---

## 🔐 Production Deployment:

For production, you can deploy the JAR file to:

### **Cloud Platforms:**
- **Heroku:** `git push heroku main`
- **AWS Elastic Beanstalk:** Upload JAR
- **Google Cloud Run:** Containerize and deploy
- **Azure App Service:** Deploy JAR

### **Traditional Server:**
```bash
# Copy JAR to server
scp backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar user@server:/app/

# Run on server
ssh user@server
cd /app
nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar &
```

### **Using Docker:**
```dockerfile
FROM openjdk:17-jdk-slim
COPY backend/target/ev-charging-backend-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## 📋 Quick Command Reference:

```bash
# Build JAR
build-backend.bat

# Start backend
start-backend.bat

# Run backend + Flutter
run-everything.bat

# Check if backend is running
curl http://localhost:8081/api/mechanic

# Find your IP
find-my-ip.bat

# Run Flutter app
flutter run
```

---

## ✨ Build Information:

- **Artifact:** ev-charging-backend
- **Version:** 0.0.1-SNAPSHOT
- **Java Version:** 17
- **Spring Boot:** 3.2.0
- **Build Tool:** Maven
- **Package Type:** JAR (executable)
- **Port:** 8081

---

## 📦 JAR File Size:

The JAR file includes:
- Your application code
- All dependencies
- Embedded Tomcat server
- Spring Boot framework

Typical size: 40-80 MB

---

## 🎯 Next Steps:

1. ✅ JAR file built successfully
2. 🚀 Start backend: `start-backend.bat`
3. 📱 Connect phone via USB
4. 🏃 Run Flutter: `flutter run`
5. ✨ Test app on mobile device

---

**Your backend is ready for mobile testing! 🎉**


