# Deployment Order - Step by Step

## 🎯 Quick Answer: Which Files to Run First

Run these commands **in this exact order**:

---

## ✅ STEP 1: Set Up Authentication (REQUIRED FIRST)

```bash
gcloud auth application-default login
```

**What it does:**
- Authenticates you with your Google account
- Grants necessary permissions (cloud-platform scope)
- Stores credentials for Terraform to use

**Expected output:**
- Opens browser for authentication
- Shows "Authentication successful"

**Time:** 2-3 minutes

---

## ✅ STEP 2: Verify Project Configuration

```bash
gcloud config set project decoded-flag-455607-c3
gcloud config list --format='value(core.project)'
```

**Expected output:**
```
decoded-flag-455607-c3
```

**Time:** 30 seconds

---

## ✅ STEP 3: Initialize Terraform

```bash
cd /workspaces/GCP-Project/terraform
terraform init
```

**What it does:**
- Downloads the Google provider (~100MB)
- Sets up Terraform working directory
- Prepares `.terraform/` folder

**Expected output:**
```
Terraform has been successfully initialized!
```

**Time:** 2-5 minutes (first time only)

---

## ✅ STEP 4: Validate Configuration

```bash
terraform validate
```

**What it does:**
- Checks all Terraform files for syntax errors
- Verifies variable declarations
- Ensures resource references are correct

**Expected output:**
```
Success! The configuration is valid.
```

**Time:** 10 seconds

---

## ✅ STEP 5: Preview Changes (Plan)

```bash
terraform plan
```

**What it does:**
- Shows what will be created (51 resources)
- Lists all variables being used
- Shows resource dependencies

**Expected output:**
```
Plan: 51 to add, 0 to change, 0 to destroy.
```

**Time:** 30-60 seconds

---

## ✅ STEP 6: Deploy Infrastructure (Apply)

```bash
terraform apply
```

**What it does:**
- Creates all 51 GCP resources
- Sets up databases, functions, pub/sub, etc.
- Takes 15-30 minutes

**When prompted:** Type `yes` and press Enter

**Expected output:**
```
Apply complete! Resources: 51 added, 0 changed, 0 destroyed.
```

**Time:** 15-30 minutes (mostly waiting for Cloud SQL instance)

---

## ✅ STEP 7: Verify Deployment

```bash
terraform output
```

**What it does:**
- Shows deployment outputs (bucket names, URLs, etc.)
- Confirms all resources were created

**Expected output:**
```
cloud_sql_instance_name = "gcp-bank-db"
frontend_bucket_name = "decoded-flag-455607-c3-banking-app"
vpc_connector_name = "gcp-bank-connector"
...
```

**Time:** 10 seconds

---

## ✅ STEP 8: (Optional) Deploy Frontend & Backend

After Terraform succeeds, run:

```bash
cd /workspaces/GCP-Project
bash deployment/deploy.sh
```

**What it does:**
- Uploads frontend to Cloud Storage
- Deploys Cloud Functions
- Initializes database
- Runs smoke tests

**Time:** 10-15 minutes

---

## 📋 Complete Command Summary

Copy & paste this to run everything:

```bash
# Step 1: Authenticate
gcloud auth application-default login

# Step 2: Set project
gcloud config set project decoded-flag-455607-c3

# Step 3-7: Deploy with Terraform
cd /workspaces/GCP-Project/terraform
terraform init
terraform validate
terraform plan
terraform apply

# Step 8: Verify
terraform output

# Step 9: Deploy application (optional)
cd /workspaces/GCP-Project
bash deployment/deploy.sh
```

---

## 🚨 If Something Goes Wrong

### Error: "ACCESS_TOKEN_SCOPE_INSUFFICIENT"
**Solution:** Did you run Step 1? Run `gcloud auth application-default login`

### Error: "terraform: command not found"
**Solution:** Terraform not installed. Install from: https://www.terraform.io/downloads

### Error: "Project not found"
**Solution:** Run `gcloud config set project decoded-flag-455607-c3`

### Error: "Invalid credentials"
**Solution:** Run Step 1 again: `gcloud auth application-default login`

---

## ⏱️ Total Time Estimates

| Step | Time | Phase |
|------|------|-------|
| Step 1: Authentication | 2-3 min | Setup |
| Step 2: Verify Config | 30 sec | Setup |
| Step 3: Terraform Init | 2-5 min | Preparation |
| Step 4: Terraform Validate | 10 sec | Verification |
| Step 5: Terraform Plan | 30-60 sec | Preview |
| Step 6: Terraform Apply | 15-30 min | **Deployment** |
| Step 7: Verify Output | 10 sec | Verification |
| **Total (without Step 8)** | **~20-40 min** | |
| Step 8: Full Deploy Script | 10-15 min | Additional |

---

## 🎯 YOU ARE HERE

```
1. Set up gcloud auth ← YOU START HERE
   ↓
2. Verify project
   ↓
3. terraform init
   ↓
4. terraform validate
   ↓
5. terraform plan
   ↓
6. terraform apply  ← THIS DOES THE ACTUAL DEPLOYMENT
   ↓
7. terraform output
   ↓
8. bash deployment/deploy.sh (optional)
   ↓
✅ DONE! Your GCP infrastructure is deployed
```

---

## ✅ Files You Don't Need to Run Directly

These are **documentation only** (read them for reference):

- ❌ `QUICK_REFERENCE.md` - For reference only
- ❌ `TERRAFORM_ALL_FIXES.md` - For reference only
- ❌ `AUTHENTICATION_FIX.md` - For reference only
- ❌ `DEPLOYMENT_STATUS.md` - For reference only
- ❌ `FINAL_STATUS.md` - For reference only
- ❌ `fix-service-account-permissions.sh` - Already handled

---

## ✅ Files You WILL Run

These are **action files**:

1. ✅ `gcloud` commands (authentication)
2. ✅ `terraform init` (initialize)
3. ✅ `terraform validate` (check)
4. ✅ `terraform plan` (preview)
5. ✅ `terraform apply` (deploy)
6. ✅ `deployment/deploy.sh` (optional, deploy app)

---

## 💡 Pro Tips

1. **Copy the complete command summary** (above) into your terminal
2. **Run it line by line** (not all at once)
3. **Watch for errors** after each step
4. **Don't worry about warnings** in terraform output
5. **Step 6 (terraform apply) takes the longest** - mostly waiting for Cloud SQL

---

## 🎓 What Gets Created

After `terraform apply`, you'll have:

✅ VPC Network & Connector  
✅ Cloud SQL Database (PostgreSQL)  
✅ 2 Cloud Functions  
✅ 5 Pub/Sub Topics  
✅ Cloud Storage Bucket  
✅ Monitoring & Alerts  
✅ 51 Resources total  

---

**Ready to start? Run this first:**

```bash
gcloud auth application-default login
```

Then follow the steps above!
