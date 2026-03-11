# FCM Notification Not Coming – Troubleshooting

When you create a mechanic request, the app shows "Request OK" but the **mechanic does not get a notification**. Use this checklist.

---

## 0. Quick checklist

- **Same backend:** In `lib/services/api_config.dart`, `_useLocalServer` must be **false** so both customer and mechanic apps talk to EC2. If the mechanic app was built with `_useLocalServer = true`, the token was sent to your local machine, not EC2, so notifications won’t arrive.
- **Mechanic opens dashboard first:** On the **mechanic’s phone**, open the app → log in as that mechanic → open **Mechanic Dashboard** and wait a few seconds. The app registers the FCM token with the backend on every dashboard open and when the app resumes.
- **Backend has Firebase key:** EC2 backend must have `firebase-service-account.json` (redeploy after adding it).
- **Backend is latest:** EC2 must be running the code that sends FCM (run `./update-backend-ec2.sh` to redeploy).
- **Check FCM status:** `curl http://YOUR_SERVER:8081/api/fcm-status` — should return `fcmInitialized: true`.

---

## 1. Check backend logs on EC2

SSH into EC2 and look at what the backend printed when the request was created (e.g. requestId=12):

```bash
# Replace with your key path and EC2 IP if different
ssh -i "/c/Users/naikh/Downloads/springbootEC2key.pem" ec2-user@34.228.113.212 "tail -100 ~/backend-app/backend.log | grep -E 'FCM|Request|Firebase'"
```

Or follow logs live, then create a request from the app:

```bash
ssh -i "YOUR_KEY.pem" ec2-user@34.228.113.212 "tail -f ~/backend-app/backend.log"
```

**What to look for:**

| Log message | Meaning |
|-------------|--------|
| `📢 [Broadcast] requestId=X radius=5km: 3 mechanics in range, 2 with FCM token, 2 notifications sent` | Broadcast OK – X mechanics notified. |
| `⚠️ [Broadcast] NO mechanics within 20km for category=...` | No mechanics in 5/10/20km radius. Check mechanic shop locations (lat/lng) and that they're not Offline. |
| `✅ [FCM] SENT requestId=12 -> ...` | FCM was sent. If mechanic still gets nothing, check device (Do Not Disturb, app battery, Firebase app config). |
| `⚠️ [FCM] NOT INITIALIZED` | Backend has no Firebase key. Do **Step 2**. |
| `⚠️ [Request 12] Mechanic X has no FCM token` | Mechanic has not registered a token. Do **Step 3**. |
| `❌ [FCM] SEND FAILED` | FCM rejected the request (e.g. invalid/expired token or wrong project). Check Firebase project and that mechanic app uses same project. |

---

## 2. FCM not initialized (missing key on EC2)

- Get the **service account JSON** from Firebase Console → Project settings → Service accounts → Generate new private key.
- Save it as `backend/src/main/resources/firebase-service-account.json` on your **local** machine (see FIREBASE_SETUP.md).
- **Redeploy** so EC2 gets the file:
  ```bash
  cd /c/Users/naikh/Desktop/Dyganox
  ./update-backend-ec2.sh 34.228.113.212 "/c/Users/naikh/Downloads/springbootEC2key.pem"
  ```
- After deploy, check logs again for `✅ Firebase initialized for FCM`.

---

## 3. Mechanic has no FCM token

The backend can only send to a device whose **FCM token** is stored for that mechanic. The token is saved when the **mechanic** does this **on the device that should receive notifications**:

1. Open the **Dyganox** app.
2. Log in as the **mechanic** (the one you selected when creating the request).
3. Go to **Mechanic Dashboard** (the main mechanic home screen).

On first load, the app calls `PUT /api/mechanic/{id}/fcm-token` and saves the device token. After that, new requests to that mechanic will trigger a notification on that device.

**So:** Before testing, have the mechanic open the app and open the dashboard at least once on the phone that should get the notification. Then create a new request from the customer side.

---

## 4. Quick test order

1. **Mechanic device:** Open app → log in as mechanic → open Mechanic Dashboard (wait a few seconds).
2. **Customer device:** Create a new mechanic request for that mechanic.
3. **EC2:** Run the `tail -100 ... grep FCM` command above and confirm you see `[FCM] SENT` or one of the warning messages.

If you see `[FCM] SENT` but still no notification, the issue is on the device or Firebase app config (package name, google-services.json, etc.).
