# AWS Cognito Setup Guide

This guide will help you set up AWS Cognito for authentication in your Dyganox app.

## Step 1: Create AWS Cognito User Pool

1. Go to AWS Console → **Cognito** → **User Pools**
2. Click **Create user pool**
3. Configure sign-in options:
   - Select **Email** and **Phone number**
   - Click **Next**
4. Configure security requirements:
   - Password policy: Choose your requirements (minimum 8 characters recommended)
   - Multi-factor authentication: Optional (can enable later)
   - Click **Next**
5. Configure sign-up experience:
   - Self-service sign-up: **Enable**
   - Cognito-assisted verification: **Enable**
   - Required attributes: Select **email** and **phone_number**
   - Click **Next**
6. Configure message delivery:
   - Email provider: Choose **Send email with Cognito** (or configure SES)
   - SMS provider: Choose **Send SMS with Cognito** (or configure SNS)
   - Click **Next**
7. Integrate your app:
   - User pool name: `dyganox-user-pool` (or your preferred name)
   - App client name: `dyganox-app-client`
   - **IMPORTANT**: Uncheck "Generate client secret" (Flutter apps don't use client secrets)
   - Click **Next**
8. Review and create

## Step 2: Get Your Credentials

After creating the user pool:

1. Note your **User Pool ID** (format: `us-east-1_XXXXXXXXX`)
2. Go to **App integration** tab
3. Find your app client and note the **Client ID**

## Step 3: Update Cognito Service

Edit `lib/services/cognito_service.dart` and replace:

```dart
static const String _userPoolId = 'YOUR_USER_POOL_ID'; // e.g., 'us-east-1_XXXXXXXXX'
static const String _clientId = 'YOUR_CLIENT_ID'; // e.g., '1a2b3c4d5e6f7g8h9i0j'
static const String _region = 'us-east-1'; // Your AWS region
```

With your actual values:

```dart
static const String _userPoolId = 'us-east-1_XXXXXXXXX'; // Your actual User Pool ID
static const String _clientId = '1a2b3c4d5e6f7g8h9i0j'; // Your actual Client ID
static const String _region = 'us-east-1'; // Your AWS region (e.g., us-east-1, us-west-2)
```

## Step 4: Configure Phone Number Format

In `lib/screens/auth/signup_page.dart`, the phone number format is set to `+1` (US). If you need a different country code, update:

```dart
if (!phone.startsWith('+')) {
  phone = '+1$phone'; // Change +1 to your country code (e.g., +91 for India)
}
```

## Step 5: Test the Authentication Flow

1. Run the app
2. You should see the Login page
3. Click "New to app? Sign Up"
4. Fill in:
   - Full Name
   - Email
   - Phone Number
   - Password (min 8 characters)
5. Click "Continue"
6. You'll receive an OTP via SMS/Email
7. Enter the 6-digit OTP
8. After verification, you'll be logged in and redirected to Home

## Important Notes

- **User Data Isolation**: Each user's data is stored separately using their unique user ID (email)
- **Persistent Login**: Once logged in, users won't be asked to login again until they sign out
- **Google Sign In**: The Google sign-in button is UI-only for now. You'll need to configure Google OAuth separately when ready

## Troubleshooting

### OTP Not Received
- Check your phone number format (must include country code)
- Check AWS Cognito SMS settings
- Verify your AWS account has SMS sending permissions

### Sign Up Fails
- Check that email and phone number are valid
- Ensure password meets requirements (min 8 characters)
- Check AWS Cognito console for error logs

### Sign In Fails
- Verify user exists in Cognito User Pool
- Check that user has verified their email/phone
- Ensure credentials are correct

## Security Best Practices

1. **Never commit credentials to Git**: Keep your User Pool ID and Client ID in environment variables or secure config
2. **Enable MFA**: Consider enabling multi-factor authentication for production
3. **Use HTTPS**: Always use HTTPS in production
4. **Token Refresh**: Implement token refresh logic for long sessions
5. **Sign Out**: Always provide a sign-out option to clear tokens
