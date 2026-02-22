# EC2 – Fix 404 / 1MB limit / poster: run these two scripts

Everything is fixed in code. For the fixes to work **on your EC2 server**, you must deploy the latest backend and admin.

## 1. Deploy latest backend (fixes vehicle catalog 404, banner &gt; 1MB, poster, S3)

From the **project root** (e.g. `~/Desktop/Dyganox-7`):

```bash
./update-backend-ec2.sh
```

This will:

- Build the backend (with 25MB upload limit, vehicle catalog, poster, banners, S3 uploads).
- Deploy the JAR to EC2 and restart the backend.

**Before it works:**

- On EC2, ensure `~/backend-app/application-ec2.properties` has your **S3 credentials** (bucket, access-key-id, secret-access-key). Without them, banner/poster/catalog uploads will fail.

## 2. Deploy latest admin dashboard (fixes Nginx 25MB if you proxy API later)

From the **project root**:

```bash
./update-and-restart-admin-ec2.sh
```

This updates the admin files and Nginx config (including 25MB body size) and restarts Nginx.

---

## Summary

| Issue | Fix |
|-------|-----|
| Vehicle catalog “Failed to load HTTP 404” | Run `./update-backend-ec2.sh` so EC2 has the latest backend with `/api/vehicle/makes` and `/api/vehicle/models`. |
| Banner upload only works for files &lt; 1MB | Backend now allows 25MB. Run `./update-backend-ec2.sh` so EC2 uses the new JAR. |
| Marketing poster “not found” | Backend now returns 200 when there’s no poster; app only shows overlay when there’s an image URL. Run `./update-backend-ec2.sh` and redeploy the app if you use a custom build. |

**Order:** Run **1** first (backend), then **2** (admin). After that, vehicle catalog, banners (up to 25MB), and poster should work.
