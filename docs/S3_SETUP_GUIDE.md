# S3 Setup Guide – Profile & File Storage

This guide walks you through setting up AWS S3 for storing profile photos and documents in ProMech/Dyganox.

---

## 1. AWS Console Setup

### 1.1 Create S3 Bucket

1. Log in to [AWS Console](https://console.aws.amazon.com/) → **S3** → **Create bucket**
2. **Bucket name**: e.g. `promech-profiles-dev` (must be globally unique)
3. **Region**: e.g. `us-east-1` (same as your RDS if possible)
4. **Block Public Access**: Uncheck "Block all public access" for public URLs, OR use presigned URLs (recommended: keep block public access, use presigned URLs)
5. Create bucket

### 1.2 Bucket Policy (for Public Read)

If you want public URLs for profile images (simpler), add a bucket policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::promech-profiles-dev/*",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["profiles/*", "documents/*"]
        }
      }
    }
  ]
}
```

Or allow all objects under the bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::promech-profiles-dev/*"
    }
  ]
}
```

Replace `promech-profiles-dev` with your bucket name.

### 1.3 CORS Configuration

In bucket → **Permissions** → **CORS**:

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": ["ETag"]
  }
]
```

---

## 2. IAM User for S3 Access

### 2.1 Create IAM User

1. **IAM** → **Users** → **Create user** → e.g. `promech-s3-upload`
2. Attach policy (or create custom policy):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::promech-profiles-dev",
        "arn:aws:s3:::promech-profiles-dev/*"
      ]
    }
  ]
}
```

3. **Security credentials** → **Create access key** → Copy **Access Key ID** and **Secret Access Key**

---

## 3. Application Configuration

Add to `backend/src/main/resources/application.properties`:

```properties
# AWS S3
aws.s3.bucket=promech-profiles-dev
aws.s3.region=us-east-1
aws.access-key-id=YOUR_ACCESS_KEY_ID
aws.secret-access-key=YOUR_SECRET_ACCESS_KEY
```

Or use environment variables (recommended for production):

```properties
aws.s3.bucket=${AWS_S3_BUCKET:promech-profiles-dev}
aws.s3.region=${AWS_REGION:us-east-1}
aws.access-key-id=${AWS_ACCESS_KEY_ID}
aws.secret-access-key=${AWS_SECRET_ACCESS_KEY}
```

**Security:** Never commit real keys to git.

**EC2:** Use `application-ec2.properties` in `~/backend-app/` on the server:
1. First deploy creates it from `application-ec2.properties.template`
2. Edit: `nano ~/backend-app/application-ec2.properties`
3. Add your real `aws.access-key-id` and `aws.secret-access-key`
4. Backend starts with `--spring.profiles.active=ec2` to load it

---

## 4. Folder Structure in S3

| Path                     | Purpose                          |
|--------------------------|----------------------------------|
| `profiles/mechanic/{id}/`| Mechanic profile photos          |
| `profiles/user/{email}/` | User profile photos (future)     |
| `documents/mechanic/{id}/`| Mechanic documents (Aadhar, etc) |
| `banners/`               | Homepage carousel / banner images|

---

## 5. API Endpoints

| Method | Endpoint                              | Purpose                         |
|--------|---------------------------------------|---------------------------------|
| POST   | `/api/upload/profile/mechanic`        | Upload mechanic profile photo   |
| POST   | `/api/upload/banner`                  | Upload carousel/banner image    |
| POST   | `/api/upload/mechanic/{id}/document`  | Upload mechanic document        |
| GET    | `/api/banners`                        | Get active banners (for app)    |

---

## 6. Checklist

- [ ] S3 bucket created
- [ ] Bucket policy or presigned URL strategy decided
- [ ] CORS configured
- [ ] IAM user with S3 permissions created
- [ ] Access key and secret key saved securely
- [ ] `application.properties` updated (or env vars set)
- [ ] Backend restarted
- [ ] Flutter app tested (mechanic registration with photo)
- [ ] Admin dashboard tested (document upload)
- [ ] Carousel/Banners section tested (upload banner images)
