# AWS Cognito Email Verification Setup

## Problem: Email OTP Not Received

If you're not receiving email verification codes, it's likely because AWS Cognito is configured to send verification codes to **SMS (phone)** instead of **email**.

## Solution: Configure Cognito to Verify Email First

### Step 1: Check Current Configuration

1. Go to **AWS Console** → **Cognito** → **User Pools**
2. Select your user pool (`us-east-1_vXPHD9qbi`)
3. Go to **Sign-up experience** tab
4. Check the **Verification** section

### Step 2: Configure Email Verification

1. In the **Sign-up experience** tab, scroll to **Verification** section
2. Under **Which attributes do you want to verify?**, make sure **Email** is selected
3. **Important**: If both Email and Phone are selected, Cognito may prioritize Phone (SMS)
4. To ensure email verification:
   - **Option A**: Uncheck "Phone number" verification (only verify Email)
   - **Option B**: Keep both but ensure Email is listed first/prioritized

### Step 3: Configure Message Delivery

1. Go to **Message delivery** tab in your User Pool
2. Under **Email configuration**:
   - Choose **Send email with Cognito** (for testing)
   - OR configure **Amazon SES** (for production - requires SES setup)
3. **Important**: If using SES, ensure:
   - Your FROM email address is verified in SES
   - Your AWS account is out of SES sandbox mode
   - SES has proper IAM permissions

### Step 4: Check Email Settings

1. Go to **Message templates** tab
2. Select **Verification code** message type
3. Ensure the email template is properly configured
4. Check that the FROM email address is valid

### Step 5: Test Email Delivery

1. Try signing up again
2. Check your **email inbox** (and spam folder)
3. If still not receiving:
   - Check CloudWatch logs for email delivery errors
   - Verify your email address is correct
   - Try using a different email address

## Alternative: Use Only Email (Remove Phone Verification)

If you want to ensure emails are always sent:

1. Go to **Sign-up experience** tab
2. Under **Required attributes**, keep **email** but you can make **phone_number** optional
3. Under **Verification**, select only **Email** (uncheck Phone number)
4. This ensures all verification codes go to email

## Quick Fix: Check Spam Folder

Sometimes emails are delivered but end up in spam:
- Check your **Spam/Junk** folder
- Check **Promotions** tab (Gmail)
- Add `no-reply@verificationemail.com` (or your Cognito email) to contacts

## Verify Current Settings

To check where Cognito is currently sending codes:

1. Go to **AWS Console** → **Cognito** → **User Pools** → Your Pool
2. Go to **Sign-up experience** → **Verification**
3. See which attributes are marked for verification
4. The first one listed is usually prioritized

## Need Help?

If emails still don't arrive:
1. Check AWS CloudWatch logs for delivery errors
2. Verify SES configuration (if using SES)
3. Try using Cognito's built-in email (not SES) for testing
4. Contact AWS Support if issues persist
