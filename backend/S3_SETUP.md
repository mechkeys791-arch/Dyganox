# S3 setup for Banners, Posters & Vehicle Catalog

All uploads (banners, marketing poster, vehicle catalog images) are stored in **AWS S3**. The app shows these images using the S3 URLs returned by the backend. No local storage is used.

## Why wasn’t my S3 config used?

The backend on EC2 reads S3 settings from **only one place**:  
**`~/backend-app/application-ec2.properties`** on the EC2 server (when run with `--spring.profiles.active=ec2`).

- That file is **not** in the repo (secrets stay on the server).
- The deploy script creates it **once** from `application-ec2.properties.template` if it doesn’t exist – with **placeholder** values (`your-bucket-name`, `YOUR_ACCESS_KEY_ID`, …). So S3 stays “not configured” until you edit the file **on EC2** with your real bucket and IAM keys.
- If you added S3 in the repo (e.g. in `application.properties` or the template), that does **not** update the existing file on EC2; the script never overwrites `~/backend-app/application-ec2.properties`.

So: add your real S3 credentials in **`~/backend-app/application-ec2.properties` on the EC2 machine**, then restart the backend.

## 1. Create an S3 bucket

1. In AWS Console go to **S3** → **Create bucket**.
2. Choose a name (e.g. `dyganox-app-assets`) and region (e.g. `us-east-1`).
3. **Block Public Access**: either leave default and use a bucket policy below, or uncheck “Block all public access” if you want objects to be public.
4. Create the bucket.

## 2. Allow public read for app images (so the app can show them)

In the bucket → **Permissions** → **Bucket policy**, add (replace `YOUR-BUCKET-NAME`):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"

            
        }
    ]
}
```

This makes objects in the bucket publicly readable so the app and admin dashboard can load images.

## 3. IAM user for the backend (upload only)

1. **IAM** → **Users** → **Create user** (e.g. `dyganox-s3-upload`).
2. **Attach policy** → Create inline or use a policy like:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:PutObject", "s3:PutObjectAcl"],
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
        }
    ]
}
```

3. **Create access key** for this user and note the **Access key ID** and **Secret access key**.

## 4. Configure the backend

**On EC2** (recommended):

- In `~/backend-app/` ensure there is an `application-ec2.properties` (copy from `application-ec2.properties.template` in the repo).
- Set:

```properties
aws.s3.bucket=YOUR-BUCKET-NAME
aws.s3.region=us-east-1
aws.access-key-id=AKIA...
aws.secret-access-key=your-secret-key
```

- **Important:** If your bucket is **not** in `us-east-1`, set `aws.s3.region` to the bucket’s region (e.g. `eu-west-1`). The backend uses this to build correct image URLs; wrong or missing region can cause "not found" when the app loads icons or images from S3.

- Restart the Spring Boot backend.

**Locally:** put the same properties in `application.properties` or in a profile-specific file.

## 5. Verify

- In **Admin dashboard**: add a banner (upload image) → Save. It should succeed and the image should appear.
- In the **app**: banners, poster (when active), and vehicle catalog images should load from S3 URLs.

If upload fails with “S3 is not configured”, the backend did not get valid `aws.s3.bucket`, `aws.access-key-id`, and `aws.secret-access-key` (e.g. wrong path for `application-ec2.properties` on EC2 or typo in property names).

---

## Auth background video (Login / Sign up)

A **background video** can be shown on the **Login** and **Sign up** screens. It is uploaded to S3 and configured in the **Admin dashboard** → **Frontend** → **Auth Background Video**.

- **Format:** MP4 only (H.264 recommended for compatibility).
- **Aspect ratio:** For mobile full-screen background, use **9:16 (portrait)**, e.g. **1080×1920**. The app uses `BoxFit.cover`, so the video fills the screen (sides or top/bottom may be cropped on different devices). 16:9 also works but may crop more on portrait phones.
- **Size:** Prefer **under 15 MB** for faster load on mobile.
- **Where to add:** Admin dashboard → **Auth Background Video** → choose MP4 file → **Upload to S3** → check **Show video on Login & Sign up** → **Save**. The app fetches the URL from `GET /api/config/auth-video` and plays it muted and looping behind the form.

**If the video or app logo does not appear in the app:**
1. **Upload first** – Click "Upload to S3" and wait for the URL to appear in the field. If you see an error (e.g. "S3 is not configured"), set AWS credentials and bucket in `application.properties` (see above).
2. **Then Save** – Click **Save** so the backend stores the URL.
3. **Restart the app** – Fully close and reopen the app (or at least reopen the login/splash screen) so it fetches the new config.
4. **S3 must be readable by the app** – The bucket (or the objects under `auth-video/` and `app-branding/`) must allow public read, or the app will get the URL but the video/image load will fail (you’ll see the gradient/fallback instead).

---

## Home hero graphic (transparent overlay on red header)

A **transparent graphic** (Lottie or GIF) can be shown on the **home screen red header** (the “Hello!” / “What service do you need today?” area). The **red gradient stays as background**; only the graphic is overlaid (no background, fully transparent).

- **Formats:** **Lottie (.json)** or **GIF**. Both support transparency. Standard video (MP4) does not support alpha, so use Lottie or GIF for a “graphic design” look.
- **Where to add:** Admin dashboard → **Frontend** → **Home Hero Graphic** → upload `.json` (Lottie) or `.gif` → **Upload to S3** → choose type → **Save**. The app fetches from `GET /api/config/home-hero-media` and overlays the graphic on the red header.
