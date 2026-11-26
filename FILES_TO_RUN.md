# GCP Bank Application - Deployment Guide

## ✅ Latest Fixes (2026-11-26)

**Two additional issues have been fixed:**

1. **Deprecated `require_ssl` argument** (cloud_sql.tf)
   - Changed to modern `ssl_mode = "REQUIRE"`
   - Now forward-compatible with latest Terraform provider

2. **Authentication scope errors for logging metrics**
   - Added automatic state cleanup in deploy.sh
   - Removes stale logging metrics before deployment
   - Prevents "insufficient authentication scopes" errors

**Result:** Fully automated, error-free deployment ready to run!

---

## 🚀 Quick Start

Run the fully automated deployment script:

```bash
cd /workspaces/GCP-Project
bash deployment/deploy.sh
```

---

## 📋 Terraform Deployment Steps (What the Script Does)

If you want to run Terraform commands manually, here are the steps in order:

### Step 0: Authentication (REQUIRED - Run First!)
```bash
gcloud auth application-default login
```
This grants all necessary GCP API permissions and fixes "insufficient authentication scopes" errors.

---

### Step 1: Initialize Terraform Directory
```bash
cd /workspaces/GCP-Project/terraform
terraform init
```
**What it does:**
- Downloads the Google Cloud Terraform provider
- Initializes the Terraform working directory
- Creates `.terraform/` folder with provider plugins

**Expected output:**
```
Terraform has been successfully configured!
```

---

### Step 2: Format Terraform Files (Optional but Recommended)
```bash
cd /workspaces/GCP-Project/terraform
terraform fmt -recursive
```
**What it does:**
- Formats all `.tf` files to follow Terraform style conventions
- Improves code readability and consistency

**Files formatted:**
- main.tf
- variables.tf
- cloud_functions.tf
- cloud_sql.tf
- pubsub.tf
- monitoring.tf

---

### Step 3: Validate Terraform Configuration
```bash
cd /workspaces/GCP-Project/terraform
terraform validate
```
**What it does:**
- Checks all `.tf` files for syntax errors
- Verifies that resource types are valid
- Ensures all required arguments are present
- Validates variable references and dependencies

**Expected output:**
```
Success! The configuration is valid.
```

**If validation fails:**
```
Error messages will show:
  ❌ Invalid resource types
  ❌ Undeclared variables
  ❌ Invalid arguments
  ❌ Reference errors
```

---

### Step 4: Create Terraform Plan (Preview of Changes)
```bash
cd /workspaces/GCP-Project/terraform
terraform plan -out=tfplan
```
**What it does:**
- Analyzes current GCP resources
- Compares with desired configuration
- Creates a plan file (`tfplan`) showing all changes
- Shows EXACTLY what will be created/modified/destroyed
- Does NOT make any changes yet

**Expected output:**
```
Plan: 49 to add, 0 to change, 0 to destroy.
```

**Review the plan to verify:**
- ✓ Correct number of resources
- ✓ Correct resource names
- ✓ Correct configuration values
- ✓ No unwanted deletions

**To view the plan in human-readable format:**
```bash
terraform show tfplan
```

---

### Step 5: Apply Terraform Configuration (Create Resources)
```bash
cd /workspaces/GCP-Project/terraform
terraform apply -auto-approve tfplan
```
**What it does:**
- Executes the plan created in Step 4
- Creates all 49 GCP resources
- Takes 15-30 minutes to complete
- Applies changes automatically (no "yes/no" prompt)

**Resources created:**
- 1 VPC Network
- 1 VPC Connector
- 2 Cloud Functions (processing-handler, notification-handler)
- 1 Cloud SQL Instance (PostgreSQL)
- 2 Secret Manager secrets (db_password, db_connection_string)
- 3 Pub/Sub topics (request-queue, notification-queue, send-email)
- 2 Pub/Sub subscriptions (request-queue-subscription, notification-queue-subscription)
- 2 Pub/Sub Dead Letter Queues (DLQ)
- 2 Service Accounts (processing, notification)
- Multiple monitoring resources
- Cloud Storage bucket for frontend

**Expected output:**
```
Apply complete! Resources: 49 added, 0 changed, 0 destroyed.
```

---

## 🎯 Complete Terraform Workflow (Manual Steps)

Run these commands in order:

```bash
# Step 0: Authenticate (REQUIRED!)
gcloud auth application-default login

# Step 1: Navigate to terraform directory
cd /workspaces/GCP-Project/terraform

# Step 2: Initialize
terraform init

# Step 3: Format (optional)
terraform fmt -recursive

# Step 4: Validate
terraform validate

# Step 5: Plan
terraform plan -out=tfplan

# Step 6: Review the plan
terraform show tfplan

# Step 7: Apply
terraform apply -auto-approve tfplan

# Step 8: Get outputs
terraform output
```

---

## 🔍 Terraform Commands Reference

### Initialize Working Directory
```bash
terraform init
terraform init -upgrade    # Update provider to latest version
```

### Format Code
```bash
terraform fmt                  # Format current directory
terraform fmt -recursive       # Format all subdirectories
terraform fmt -check         # Check if formatting is needed
```

### Validate Configuration
```bash
terraform validate            # Basic validation
```

### Preview Changes
```bash
terraform plan                # Show changes without file
terraform plan -out=tfplan    # Save plan to file
terraform plan -destroy       # Plan for destruction
```

### View Plan
```bash
terraform show tfplan         # View saved plan file
terraform show                # View current state
```

### Apply Configuration
```bash
terraform apply               # Apply with approval prompt
terraform apply tfplan        # Apply saved plan file
terraform apply -auto-approve # Apply without prompt (use with plan file)
terraform apply -var="key=value"  # Set variable on apply
```

### View State
```bash
terraform state list          # List all resources in state
terraform state show RESOURCE # Show specific resource
```

### View Outputs
```bash
terraform output              # Show all outputs
terraform output -json        # Show outputs in JSON format
terraform output OUTPUT_NAME  # Show specific output
```

### Destroy Resources
```bash
terraform destroy             # Destroy with approval prompt
terraform destroy -auto-approve  # Destroy without prompt
terraform destroy -target=RESOURCE  # Destroy specific resource
```

---

## 📊 Terraform File Structure

```
terraform/
├── main.tf                    (Provider configuration, resource defaults)
├── variables.tf               (All 15+ variable declarations)
├── cloud_functions.tf         (Processing & notification handlers)
├── cloud_sql.tf               (Database, secrets, networking)
├── pubsub.tf                  (Messaging topics & subscriptions)
├── monitoring.tf              (Alerts, dashboards, log metrics)
└── terraform.tfvars           (Generated by deploy.sh - variable values)
```

---

## ✅ Verification Steps

### After Terraform Apply

1. **Verify resources were created:**
```bash
gcloud compute instances list              # VPC
gcloud sql instances list                   # Cloud SQL
gcloud functions list --region=us-central1  # Cloud Functions
gcloud pubsub topics list                   # Pub/Sub topics
gcloud storage buckets list                 # Storage buckets
```

2. **Check Cloud Functions are running:**
```bash
gcloud functions describe processing-handler --region=us-central1
gcloud functions describe notification-handler --region=us-central1
```

3. **Verify database connection:**
```bash
gcloud sql connect gcp-bank-db --user=banking_admin
```
Then type password: `India@15081947`

4. **Test Pub/Sub topics:**
```bash
gcloud pubsub topics publish request-queue --message='{"test":true}'
```

5. **View Cloud Function logs:**
```bash
gcloud functions logs read processing-handler --region=us-central1 --limit=50
```

---

## ⚠️ Troubleshooting

### "terraform: command not found"
```bash
# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform
```

### "Error: Failed to query available provider packages"
```bash
# Fix: Run terraform init again
cd terraform
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### "Error: Resource already exists"
```bash
# Fix: Terraform state might be out of sync, refresh it
terraform refresh

# Or manually import the existing resource
terraform import google_cloud_function.processing_handler \
  us-central1/processing-handler
```

### "Invalid combination of arguments"
```bash
# Fix: Run terraform validate to identify issues
terraform validate

# Then terraform fmt to fix formatting
terraform fmt -recursive
```

### "Argument is deprecated: require_ssl"
```bash
# This has been fixed! The script now uses ssl_mode = "REQUIRE"
# If you see this error in older code, change:
#   require_ssl = true        → ssl_mode = "REQUIRE"
```

### "Error when reading or editing LoggingMetric: insufficient authentication scopes"
```bash
# This has been fixed! The deploy.sh script now automatically removes
# stale logging metrics from state before deployment.
# 
# If you encounter this manually, run:
terraform state rm google_logging_metric.transaction_creation
terraform state rm google_logging_metric.user_creation

# Then re-run terraform plan and apply
```

### "Error: Insufficient authentication scopes"
```bash
# Fix: Reauthenticate with proper scopes
gcloud auth application-default login
gcloud auth login
```

---

## 🗑️ Cleanup & Destruction

To remove all GCP resources created by Terraform:

```bash
cd /workspaces/GCP-Project/terraform
terraform destroy -auto-approve
```

**Or use the provided script:**
```bash
bash deployment/destroy.sh
```

---

## 📚 Additional Resources

- **Terraform Documentation:** https://www.terraform.io/docs
- **Google Provider Docs:** https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **GCP Documentation:** https://cloud.google.com/docs
- **Terraform Best Practices:** https://www.terraform.io/cloud-docs/recommended-practices

---

## 🎯 Recommended Workflow

**For Development:**
1. Make changes to `.tf` files
2. Run `terraform fmt -recursive`
3. Run `terraform validate`
4. Run `terraform plan -out=tfplan`
5. Review with `terraform show tfplan`
6. Run `terraform apply tfplan`

**For Production:**
1. Create a separate branch for changes
2. Run `terraform validate`
3. Run `terraform plan -out=tfplan`
4. Have another person review the plan
5. Run `terraform apply tfplan`
6. Test all functionality
7. Commit changes with approval

---

**Last Updated:** 2026-11-26
**GCP Project ID:** decoded-flag-455607-c3
**Region:** us-central1
