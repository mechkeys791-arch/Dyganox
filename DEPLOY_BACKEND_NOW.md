# Deploy Backend with UserAddressController to EC2

## Quick Fix for 404 Error

The backend endpoint `/api/user-addresses` is returning 404 because the `UserAddressController` hasn't been deployed to EC2 yet.

## Option 1: Deploy Using Script (Recommended)

### Step 1: Find Your SSH Key

Your EC2 SSH key is usually:
- `~/.ssh/id_rsa` (if using RSA key)
- `~/.ssh/id_ed25519` (if using Ed25519 key)
- Or a `.pem` file you downloaded from AWS

**Find it:**
```bash
ls -la ~/.ssh/
```

### Step 2: Deploy Backend

```bash
cd /home/pranam/Desktop/Dyganox-4

# If you have a .pem key:
./update-backend-ec2.sh 34.228.113.212 /path/to/your-key.pem

# If you're using a regular SSH key (id_rsa, id_ed25519):
./update-backend-ec2.sh 34.228.113.212 ~/.ssh/id_rsa
```

## Option 2: Manual Deployment

### Step 1: Build Backend Locally

```bash
cd /home/pranam/Desktop/Dyganox-4/backend
mvn clean package -DskipTests
```

### Step 2: Upload to EC2

```bash
# Replace /path/to/key.pem with your actual key path
scp -i /path/to/key.pem target/ev-charging-backend-0.0.1-SNAPSHOT.jar ec2-user@34.228.113.212:/home/ec2-user/backend-app/
```

### Step 3: SSH and Restart Backend

```bash
ssh -i /path/to/key.pem ec2-user@34.228.113.212
```

Then on EC2:
```bash
# Stop old backend
sudo lsof -t -i:8081 | xargs sudo kill -9 2>/dev/null || true

# Start new backend
cd ~/backend-app
nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar > backend.log 2>&1 &

# Wait a few seconds
sleep 5

# Check if it's running
curl http://localhost:8081/api/user-addresses
```

## Option 3: Build on EC2 (If Maven Not Available Locally)

### Step 1: Upload Source Code

```bash
cd /home/pranam/Desktop/Dyganox-4
tar -czf backend-src.tar.gz backend/ --exclude="backend/target" --exclude="backend/.idea"
scp -i /path/to/key.pem backend-src.tar.gz ec2-user@34.228.113.212:/home/ec2-user/
```

### Step 2: SSH and Build on EC2

```bash
ssh -i /path/to/key.pem ec2-user@34.228.113.212
```

Then on EC2:
```bash
# Extract source
cd ~
tar -xzf backend-src.tar.gz

# Install Maven if needed
sudo yum install -y maven

# Build
cd backend
mvn clean package -DskipTests

# Stop old backend
sudo lsof -t -i:8081 | xargs sudo kill -9 2>/dev/null || true

# Deploy new JAR
mkdir -p ~/backend-app
cp target/ev-charging-backend-0.0.1-SNAPSHOT.jar ~/backend-app/

# Start backend
cd ~/backend-app
nohup java -jar ev-charging-backend-0.0.1-SNAPSHOT.jar > backend.log 2>&1 &

# Wait and test
sleep 5
curl http://localhost:8081/api/user-addresses
```

## Verify Deployment

After deployment, test the endpoint:

```bash
curl http://34.228.113.212:8081/api/user-addresses
```

You should get a response (even if it's an error about missing parameters, that means the endpoint exists).

## Troubleshooting

**If SSH fails:**
- Make sure your key has correct permissions: `chmod 400 /path/to/key.pem`
- Check EC2 security group allows SSH (port 22)

**If backend doesn't start:**
- Check logs: `tail -f ~/backend-app/backend.log`
- Check if port 8081 is in use: `sudo lsof -i:8081`
- Check Java is installed: `java -version`

**If endpoint still returns 404:**
- Verify the JAR was built with the new controller: `jar -tf ev-charging-backend-0.0.1-SNAPSHOT.jar | grep UserAddressController`
- Check backend logs for startup errors
