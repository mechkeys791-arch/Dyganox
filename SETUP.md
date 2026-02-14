# Dyganox – Full Setup Guide

This guide covers running the backend (local or EC2), configuring the Flutter app, and verifying mechanic registration (data saved in the **`requests`** table).

---

## 1. Prerequisites

- **Java 17+** and **Maven** (for backend)
- **PostgreSQL** (you’re using AWS RDS; ensure the machine running the backend can reach it)
- **Flutter** (for the app)
- **EC2** (optional): if you want the app to use a remote server, you need an EC2 instance and an SSH key (`.pem` or `id_rsa`)

### 1.1 Mechanic Cognito (separate User Pool)

Mechanics use a **different Cognito User Pool** from app users. You need to create that pool in AWS and set its IDs in the app.

- **Full steps**: see **[MECHANIC_COGNITO_SETUP.md](MECHANIC_COGNITO_SETUP.md)**.
- **In the app**: edit `lib/services/cognito_service.dart` and set:
  - `_mechanicUserPoolId` – your mechanic User Pool ID (e.g. `us-east-1_XXXXXXXXX`)
  - `_mechanicClientId` – your mechanic app client ID

Until these are set, mechanic **Create account** and **Login** will use the placeholder pool and will not work until you complete the setup.

---

## 2. Backend – Run Locally (quick test)

Use this to confirm the backend and database work before using EC2.

### 2.1 Database

- Backend is already configured for RDS in `backend/src/main/resources/application.properties`.
- Ensure your **local machine or EC2** can reach the RDS host:  
  `postgresforpro.cw52wo446izi.us-east-1.rds.amazonaws.com:5432`  
  (RDS security group must allow inbound from your IP or EC2 security group.)

### 2.2 Build and run

```bash
cd /home/pranam/Desktop/Dyganox-4/backend
mvn clean package -DskipTests
java -jar target/ev-charging-backend-0.0.1-SNAPSHOT.jar
```

- Backend will listen on **port 8081** and create/update tables (including **`requests`**) on first run (`ddl-auto=update`).

### 2.3 Quick test

```bash
curl -X POST http://localhost:8081/api/mechanic \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","phone":"9999999999","shopName":"Test Shop","approvalStatus":"PENDING"}'
```

- You should get a **201** response and a JSON body with an `id`. The row is stored in the **`requests`** table.

---

## 3. Backend – Run on EC2 (for mobile app / “Connection refused” fix)

The app uses **`34.228.113.212:8081`**. For it to work, the backend must be running on that IP and port **8081** must be open.

### 3.1 EC2 security group

1. AWS Console → EC2 → Security Groups → select the group attached to your instance.
2. **Inbound rules** → Edit → Add:
   - **Type:** Custom TCP  
   - **Port:** 8081  
   - **Source:** 0.0.0.0/0 (or your network only)  
   - **Description:** Spring Boot API  
3. Save.

### 3.2 Deploy backend to EC2

From your **project root** (e.g. `/home/pranam/Desktop/Dyganox-4`):

```bash
cd /home/pranam/Desktop/Dyganox-4

# Use your actual SSH key path
./deploy-backend-simple.sh 34.228.113.212 ~/.ssh/id_rsa

# If you use a .pem file:
# ./deploy-backend-simple.sh 34.228.113.212 /path/to/your-key.pem
```

- Script will: upload backend source → build on EC2 → stop old process on 8081 → start new JAR.

### 3.3 If you don’t have the script or prefer manual steps

**A. Build locally and upload JAR**

```bash
cd /home/pranam/Desktop/Dyganox-4/backend
mvn clean package -DskipTests
scp -i /path/to/your-key.pem target/ev-charging-backend-0.0.1-SNAPSHOT.jar ec2-user@34.228.113.212:/home/ec2-user/backend-app/
```

**B. SSH and run on EC2**

```bash
ssh -i /path/to/your-key.pem ec2-user@34.228.113.212
```

On EC2:

```bash
# Stop anything on 8081
sudo lsof -t -i:8081 | xargs sudo kill -9 2>/dev/null || true

# Run backend (create backend-app if needed: mkdir -p ~/backend-app)
cd ~/backend-app
nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar > backend.log 2>&1 &

# Wait a few seconds, then check
sleep 5
curl http://localhost:8081/api/mechanic
```

- From your **phone or laptop**, test:  
  `http://34.228.113.212:8081/api/mechanic`  
  (e.g. in browser or Postman; GET may return `[]`, which is fine).

---

## 4. Flutter app – API configuration

The app decides backend URL from `lib/services/api_config.dart`.

### 4.1 Use EC2 backend (current “production” setup)

- In `api_config.dart` you already have:
  - `_useLocalServer = false`
  - `_ec2PublicIp = '34.228.113.212'`
- So the app will use: **`http://34.228.113.212:8081`**.
- No change needed if EC2 IP stays the same.

### 4.2 Use local backend (phone and laptop on same Wi‑Fi)

1. Find your computer’s IP (e.g. `192.168.11.73`).
2. In `lib/services/api_config.dart` set:
   - `_useLocalServer = true`
   - `_localIpAddress = '192.168.11.73'`  // your machine’s IP
3. Run backend locally (Section 2).
4. Run app on device/emulator; it will call `http://192.168.11.73:8081`.

### 4.3 Android emulator

- In `api_config.dart`: `_useLocalServer = true`, `_useEmulator = true`.
- Backend URL will be `http://10.0.2.2:8081`.

---

## 5. Verify mechanic registration and `requests` table

1. **Backend running** (local or EC2 on 8081).
2. **App** pointed to that backend (Section 4).
3. In the app: **Register as Mechanic** → fill all steps → **Submit**.
4. You should see success (e.g. “Registration submitted! Admin will review…”).
5. In the database, check the **`requests`** table:

```sql
SELECT id, name, email, shop_name, approval_status, created_at
FROM requests
ORDER BY created_at DESC
LIMIT 10;
```

- Each submission creates one row in **`requests`** with all form fields (name, email, phone, shop name, address, city, state, pincode, country, lat/long, services, timing, working days, etc.).

---

## 6. Troubleshooting

| Issue | What to do |
|-------|------------|
| **Connection refused** (e.g. to 34.228.113.212:8081) | Backend not running on that host, or port 8081 not open. Start backend on EC2 (Section 3) and add inbound rule for 8081. |
| **404 on /api/mechanic** | Backend JAR is old or wrong. Redeploy with `deploy-backend-simple.sh` or manual steps (Section 3). |
| **App can’t reach local backend** | Same Wi‑Fi; correct `_localIpAddress` in `api_config.dart`; firewall on computer must allow port 8081. |
| **Table `requests` missing** | Start backend once; with `ddl-auto=update` it creates the table. Check RDS connectivity and backend logs. |

---

## 7. Summary checklist

- [ ] RDS reachable from the machine running the backend.
- [ ] Backend runs (local or EC2) on port **8081**.
- [ ] If using EC2: security group allows **TCP 8081** from the internet (or your network).
- [ ] `api_config.dart`: `_useLocalServer` / `_ec2PublicIp` / `_localIpAddress` match where the backend runs.
- [ ] Mechanic registration submits without “Connection refused”; rows appear in **`requests`**.

For deploy script details, see `DEPLOY_BACKEND_NOW.md` and `deploy-backend-simple.sh`.
