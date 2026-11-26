# Quick Authentication Fix for Terraform

## Problem
The compute service account (`592400528927-compute@developer.gserviceaccount.com`) has insufficient OAuth scopes.

## Solution: Use Your User Account for Terraform

Run these commands in your terminal (where you have gcloud configured):

### Step 1: Authenticate as your user account
```bash
gcloud auth application-default login
```

This will open a browser to authenticate with your Google account and grant the necessary scopes.

### Step 2: Set the project
```bash
gcloud config set project decoded-flag-455607-c3
```

### Step 3: Verify authentication
```bash
gcloud auth list
gcloud config list --format='value(core.project)'
```

You should see your personal account listed, not the service account.

### Step 4: Run Terraform
```bash
cd /workspaces/GCP-Project/terraform
terraform init
terraform plan
terraform apply
```

---

## Why This Works

When you run `gcloud auth application-default login`:
1. It authenticates as your personal Google account
2. It stores credentials in `~/.config/gcloud/application_default_credentials.json`
3. Terraform automatically reads these credentials
4. Your account has the necessary `cloud-platform` scope
5. Terraform can now provision all GCP resources

---

## Alternative: Use a Service Account Key File

If the above doesn't work, create a service account with proper scopes:

```bash
# From your personal account (with full permissions)
PROJECT_ID="decoded-flag-455607-c3"

# Create a service account for Terraform
gcloud iam service-accounts create terraform-deployer \
  --display-name="Terraform Deployer" \
  --project=$PROJECT_ID

# Grant it Editor role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:terraform-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor"

# Create a key
gcloud iam service-accounts keys create /tmp/terraform-key.json \
  --iam-account="terraform-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

# Set Terraform to use this key
export GOOGLE_APPLICATION_CREDENTIALS=/tmp/terraform-key.json

# Run Terraform
cd /workspaces/GCP-Project/terraform
terraform init
terraform plan
terraform apply
```

---

## Troubleshooting

### If you get "Permission denied" errors:
- Make sure you're using `gcloud auth application-default login` (not just `gcloud login`)
- Verify: `gcloud auth list` - you should see your personal account with `✓` active

### If Terraform still can't connect:
- Clear Terraform cache: `rm -rf .terraform`
- Reinitialize: `terraform init`
- Check credentials: `gcloud auth list`

### If you're on a GCE instance with limited scopes:
- You MUST use `gcloud auth application-default login` from your personal account
- The compute service account scopes are read-only and can't be changed from within the instance

---

## Expected Result

After completing these steps:
```
✓ gcloud auth list shows your personal account
✓ gcloud config shows project: decoded-flag-455607-c3
✓ terraform plan shows 51 resources to be created
✓ terraform apply deploys all resources successfully
```

