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

- Restart the Spring Boot backend.

**Locally:** put the same properties in `application.properties` or in a profile-specific file.

## 5. Verify

- In **Admin dashboard**: add a banner (upload image) → Save. It should succeed and the image should appear.
- In the **app**: banners, poster (when active), and vehicle catalog images should load from S3 URLs.

If upload fails with “S3 is not configured”, the backend did not get valid `aws.s3.bucket`, `aws.access-key-id`, and `aws.secret-access-key` (e.g. wrong path for `application-ec2.properties` on EC2 or typo in property names).
