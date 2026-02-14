# Mechanic Cognito Setup (Separate User Pool)

Mechanics use a **separate AWS Cognito User Pool** from regular app users. This keeps mechanic accounts and user accounts independent.

---

## 1. Create a new User Pool in AWS

1. Open **AWS Console** → **Cognito** → **User Pools** → **Create user pool**.

2. **Sign-in options**
   - Choose **Email** (or Email and phone if you want both).
   - Leave other options as needed → **Next**.

3. **Configure security requirements**
   - Password policy: e.g. minimum 8 characters.
   - MFA: optional (e.g. no MFA for mechanics).
   - **User account recovery**: enable **Send email message** (for forgot password).
   - **Next**.

4. **Sign-up experience**
   - **Required attributes**: add **email**, **name**, **phone_number** (or as per your app).
   - **Custom attributes**: add any you need.
   - **Next**.

5. **Message delivery**
   - **Send email with Cognito** (or your SES if configured).
   - **Next**.

6. **Integrate your app**
   - User pool name: e.g. `dyganox-mechanics`.
   - **App client**: Create new.
     - App type: **Public client** (mobile app).
     - App client name: e.g. `dyganox-mechanic-app`.
     - **Don’t** generate client secret (for public/mobile clients).
     - Authentication flows: enable **ALLOW_USER_PASSWORD_AUTH**, **ALLOW_REFRESH_TOKEN_AUTH**, **ALLOW_USER_SRP_AUTH** (as needed).
   - **Next**.

7. **Review and create** → **Create user pool**.

---

## 2. Get Pool ID and Client ID

1. Open your new **User pool** (e.g. `dyganox-mechanics`).
2. **User pool overview**:
   - Copy **User pool ID** (e.g. `us-east-1_AbCdEfGhI`).
3. **App integration** tab → under **App client list** → open your app client:
   - Copy **Client ID** (e.g. `1a2b3c4d5e6f7g8h9i0j...`).

---

## 3. Email verification (OTP)

1. In the User pool → **Sign-in experience** (or **Messaging**):
   - **Verification message** → ensure **Email** is used for verification (code sent to email).
2. **Attributes**:
   - **email** should be required and used as username (or as alias).
3. If you use **email as sign-in**:
   - **Sign-in experience** → **Username requirements**: choose **Email** (or **Preferred username** and set email as alias).

---

## 4. Put values in the app

1. Open **`lib/services/cognito_service.dart`** in your project.

2. Find the mechanic pool constants (around the top of the file):

   ```dart
   static const String _mechanicUserPoolId = 'us-east-1_XXXXXXXXX';   // Replace
   static const String _mechanicClientId = 'xxxxxxxxxxxxxxxxxxxxxxxxxx'; // Replace
   ```

3. Replace with your values:

   ```dart
   static const String _mechanicUserPoolId = 'us-east-1_AbCdEfGhI';   // Your mechanic pool ID
   static const String _mechanicClientId = '1a2b3c4d5e6f7g8h9i0j';   // Your mechanic app client ID
   ```

4. Save the file. Mechanics will now use this pool for:
   - Create account (sign up)
   - Email OTP verification
   - Login (after approval / password from WhatsApp)

---

## 5. Summary

| Use case              | Cognito pool   | Where configured              |
|-----------------------|----------------|-------------------------------|
| App users (customers) | User pool 1    | `_userPoolId`, `_clientId`   |
| Mechanics             | Mechanic pool  | `_mechanicUserPoolId`, `_mechanicClientId` |

- **User pool**: same region as your existing user pool (e.g. `us-east-1`).
- **App client**: no client secret; enable the auth flows your app uses (e.g. USER_PASSWORD_AUTH, REFRESH_TOKEN).
- After changing pool IDs, rebuild the app and test mechanic **Create account** → **OTP** → **Form** and **Login**.
