# GCP Authentication Scopes Fix - Terraform Deployment

## Issue
Your Terraform deployment is failing with `ACCESS_TOKEN_SCOPE_INSUFFICIENT` errors. This means the compute service account (`592400528927-compute@developer.gserviceaccount.com`) doesn't have the proper OAuth scopes enabled.

## Solution

### Option 1: Use Application Default Credentials with Cloud SDK (Recommended for Cloud Shell/Compute)

```bash
# 1. Set the default project
gcloud config set project decoded-flag-455607-c3

# 2. Create application default credentials with full scopes
gcloud auth application-default login

# 3. Run the deployment
cd /workspaces/GCP-Project
bash deployment/deploy.sh
```

### Option 2: Create a Custom Service Account (Recommended for Production)

```bash
# 1. Create a new service account for Terraform
gcloud iam service-accounts create terraform-deployer \
  --display-name="Terraform Deployer" \
  --project=decoded-flag-455607-c3

# 2. Grant necessary roles
gcloud projects add-iam-policy-binding decoded-flag-455607-c3 \
  --member=serviceAccount:terraform-deployer@decoded-flag-455607-c3.iam.gserviceaccount.com \
  --role=roles/editor \
  --quiet

# 3. Create and download service account key
gcloud iam service-accounts keys create /tmp/terraform-key.json \
  --iam-account=terraform-deployer@decoded-flag-455607-c3.iam.gserviceaccount.com

# 4. Set the key as your authentication
export GOOGLE_APPLICATION_CREDENTIALS=/tmp/terraform-key.json

# 5. Run the deployment
cd /workspaces/GCP-Project
bash deployment/deploy.sh
```

### Option 3: Grant Scopes to Existing Compute Instance (If Running on GCE)

If you're running this on a Google Compute Engine instance, you can add scopes:

```bash
# Stop the instance first (if it exists)
gcloud compute instances stop INSTANCE_NAME --zone=ZONE

# Set the scopes
gcloud compute instances set-service-account INSTANCE_NAME \
  --service-account=default \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --zone=ZONE

# Start the instance
gcloud compute instances start INSTANCE_NAME --zone=ZONE
```

Replace `INSTANCE_NAME` and `ZONE` with your actual values.

### Option 4: Use gcloud for Authentication (Simplest)

```bash
# 1. Authenticate with your personal account
gcloud auth login

# 2. Set the default project
gcloud config set project decoded-flag-455607-c3

# 3. Create application default credentials
gcloud auth application-default login

# 4. Verify credentials
gcloud auth list
gcloud config list --format='value(core.project)'

# 5. Run the deployment
cd /workspaces/GCP-Project
bash deployment/deploy.sh
```

## Verification

After applying one of the options above, verify your authentication:

```bash
# Check which account is active
gcloud auth list

# Check which project is set
gcloud config list --format='value(core.project)'

# Test GCP access
gcloud projects describe decoded-flag-455607-c3

# Test a specific API (Compute)
gcloud compute networks list
```

## Terraform Troubleshooting

If you still get scope errors after authentication:

1. Clear Terraform cache:
```bash
cd /workspaces/GCP-Project/terraform
rm -rf .terraform
terraform init
```

2. Add provider configuration to `main.tf`:
```hcl
provider "google" {
  project = local.project_id
  region  = local.region
  
  # Optional: explicitly request scopes
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]
}
```

3. Run with debugging:
```bash
export TF_LOG=DEBUG
terraform apply
```

## OAuth Scopes Required

For full Terraform functionality, your credentials need access to:
- `https://www.googleapis.com/auth/cloud-platform` (Full cloud access)

Or individually:
- `https://www.googleapis.com/auth/compute` (Compute Engine)
- `https://www.googleapis.com/auth/pubsub` (Pub/Sub)
- `https://www.googleapis.com/auth/sqlservice.admin` (Cloud SQL)
- `https://www.googleapis.com/auth/devstorage.full_control` (Cloud Storage)
- `https://www.googleapis.com/auth/logging.admin` (Cloud Logging)
- `https://www.googleapis.com/auth/monitoring` (Cloud Monitoring)

## Current Environment Info

```
Active Account: 592400528927-compute@developer.gserviceaccount.com
Project: decoded-flag-455607-c3
Issue: Service account lacks cloud-platform scope
```

## Next Steps

1. Choose an authentication option from above
2. Test with the verification commands
3. Run: `bash deployment/deploy.sh`
4. The deployment will:
   - Initialize Terraform
   - Create VPC, Cloud SQL, Pub/Sub, Cloud Functions
   - Deploy frontend to Cloud Storage
   - Deploy backend services
   - Run smoke tests
