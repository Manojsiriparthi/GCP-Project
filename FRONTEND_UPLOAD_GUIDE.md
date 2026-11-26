# Frontend Upload to GCP Cloud Storage

## Overview

The frontend is automatically uploaded to GCP Cloud Storage during the main deployment process. This guide explains the process and manual options.

## Automatic Deployment (Recommended)

The main deployment script handles everything:

```bash
cd /workspaces/GCP-Project
bash deployment/deploy.sh
```

This will:
1. ✅ Initialize Terraform
2. ✅ Deploy all GCP infrastructure (including frontend bucket)
3. ✅ Build the frontend (npm run build)
4. ✅ Upload all files to Cloud Storage
5. ✅ Set proper MIME types
6. ✅ Configure public web access
7. ✅ Deploy Cloud Functions
8. ✅ Initialize database
9. ✅ Run tests

## Terraform Configuration: `terraform/cloud_storage_frontend.tf`

**Resources created:**
- `google_storage_bucket.frontend` - Frontend storage bucket
- `google_storage_bucket_object.frontend_index` - Frontend files archive
- `random_id.frontend_bucket_suffix` - Unique bucket naming

**Outputs:**
- `frontend_bucket_name` - Bucket name
- `frontend_bucket_url` - Bucket URL (gs://)
- `frontend_bucket_location` - Bucket location

## Bucket Configuration

The deployment script configures:

✅ **Uniform Bucket-Level Access**: Security by default  
✅ **Public IAM Policy**: `allUsers:roles/storage.objectViewer`  
✅ **Content Types**: Proper MIME types for all files  
✅ **Web Hosting**: index.html as main page, 404.html as error page

## Manual Frontend Upload

If you need to upload frontend files manually after deployment:

```bash
# 1. Build frontend
cd /workspaces/GCP-Project/frontend
npm install
npm run build

# 2. Get bucket name
PROJECT_ID="decoded-flag-455607-c3"
BUCKET=$(gcloud storage ls --project=$PROJECT_ID | grep frontend | head -1 | tr -d ':/')

# 3. Upload files
gcloud storage cp build/** gs://$BUCKET/ --recursive --project=$PROJECT_ID

# 4. Set content types
gcloud storage objects update gs://$BUCKET/index.html --content-type="text/html"
gcloud storage objects update gs://$BUCKET/**.js --content-type="application/javascript"
gcloud storage objects update gs://$BUCKET/**.css --content-type="text/css"
```

## Access Control

### Default (Secure)
Bucket has uniform bucket-level access - no public access.

### Enable Public Access
```bash
PROJECT_ID="decoded-flag-455607-c3"
BUCKET=$(gcloud storage ls --project=$PROJECT_ID | grep frontend | head -1 | tr -d ':/')

gcloud storage buckets add-iam-policy-binding gs://$BUCKET \
  --member=allUsers \
  --role=roles/storage.objectViewer \
  --project=$PROJECT_ID
```

### Restrict to Service Account
```bash
gcloud storage buckets add-iam-policy-binding gs://$BUCKET \
  --member=serviceAccount:<EMAIL> \
  --role=roles/storage.objectViewer
```

## Frontend URL

After deployment, access your frontend at:

```
https://storage.googleapis.com/<bucket-name>/index.html
```

Or use a custom domain with Cloud CDN (see below).

## Cloud CDN Integration

To serve frontend via Cloud CDN with caching:

1. Create a Cloud Load Balancer
2. Add backend bucket pointing to Cloud Storage
3. Enable Cloud CDN
4. Configure SSL certificate
5. Set up custom domain (optional)

```bash
# Create load balancer backend bucket
gcloud compute backend-buckets create frontend-backend \
  --gcs-uri-prefix=gs://$BUCKET \
  --enable-cdn
```

## Troubleshooting

### "Bucket not found" error
```bash
# Verify bucket was created
gcloud storage ls --project=$PROJECT_ID | grep frontend
```

### "Permission denied" uploading
```bash
# Check IAM permissions
gcloud projects get-iam-policy $PROJECT_ID
# Need: roles/storage.admin or roles/storage.bucketAdmin
```

### Files not accessible
```bash
# Verify bucket configuration
gcloud storage buckets describe gs://$BUCKET

# Check object permissions
gcloud storage objects update gs://$BUCKET/index.html \
  --add-iam-policy-binding user=allUsers:roles/storage.objectViewer
```

## Best Practices

✅ **Uniform Access Control** - Configured by default  
✅ **Content Type Headers** - Properly set for all files  
✅ **Versioning** - Disabled by default (enable if rollback needed)  
✅ **Lifecycle Policies** - Delete old versions automatically  
✅ **Encryption** - Server-side encryption enabled by default  
✅ **CDN** - Use Cloud CDN for better performance  
✅ **HTTPS** - Always enforced by Cloud Storage

## Monitoring

View bucket activity:

```bash
# List files in bucket
gcloud storage ls --recursive gs://$BUCKET/

# View bucket metadata
gcloud storage buckets describe gs://$BUCKET/

# Monitor access logs
gcloud logging read \
  "resource.type=gcs_bucket AND resource.labels.bucket_name=$BUCKET" \
  --limit 50 \
  --format json
```

## Cost Optimization

**Storage Class:** Standard (frequently accessed)  
**Pricing:** $0.020/GB (us-central1)  
**Example:** 50 MB frontend = $0.001/month  

Reduce costs with:
- Cloud CDN (caches at edge)
- Lifecycle policies (auto-archive old files)
- Object versioning (disable if not needed)

## Deployment Flow

```
deploy.sh
├── Step 1: Validate GCP environment
├── Step 2: Configure Terraform variables
├── Step 3: Deploy infrastructure (Terraform)
│   └── Creates frontend bucket
├── Step 4: Upload frontend to Cloud Storage ← Integrated here
│   ├── Build frontend (npm run build)
│   └── Upload files with correct MIME types
├── Step 5: Configure bucket for web access
│   ├── Enable uniform bucket access
│   ├── Add public IAM policy
│   └── Configure web hosting
├── Step 6: Deploy Cloud Functions
├── Step 7: Initialize database
├── Step 8: Run smoke tests
├── Step 9: Run integration tests
└── Step 10: Display deployment summary
```

## Related Documentation

- **Main deployment:** `deployment/deploy.sh`
- **Destroy infrastructure:** `deployment/destroy.sh`
- **Terraform configuration:** `terraform/cloud_storage_frontend.tf`
