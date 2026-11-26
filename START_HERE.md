# QUICK START GUIDE

## 🚀 TL;DR - Run These Commands in Order

```bash
# 1. AUTHENTICATE (DO THIS FIRST!)
gcloud auth application-default login

# 2. SET PROJECT
gcloud config set project decoded-flag-455607-c3

# 3. GO TO TERRAFORM DIRECTORY
cd /workspaces/GCP-Project/terraform

# 4. INITIALIZE
terraform init

# 5. VALIDATE
terraform validate

# 6. PREVIEW
terraform plan

# 7. DEPLOY (This creates all the infrastructure!)
terraform apply
# When prompted, type: yes

# 8. CHECK RESULTS
terraform output

# 9. (OPTIONAL) Deploy the full application
cd /workspaces/GCP-Project
bash deployment/deploy.sh
```

---

## 📊 Execution Flow

```
START
  │
  ├─► gcloud auth application-default login
  │        ↓
  │   (Opens browser - authenticate & grant permissions)
  │
  ├─► gcloud config set project decoded-flag-455607-c3
  │        ↓
  │   (Sets your project)
  │
  ├─► cd /workspaces/GCP-Project/terraform
  │        ↓
  │   (Changes to Terraform folder)
  │
  ├─► terraform init
  │        ↓
  │   (Downloads provider, ~100MB, takes 2-5 min)
  │
  ├─► terraform validate
  │        ↓
  │   (Checks syntax - should say "valid")
  │
  ├─► terraform plan
  │        ↓
  │   (Shows 51 resources to create)
  │
  ├─► terraform apply
  │        ↓
  │   (CREATES ALL INFRASTRUCTURE - 15-30 minutes)
  │        ↓
  │   (Watch the progress, says "Apply complete")
  │
  ├─► terraform output
  │        ↓
  │   (Shows what was created)
  │
  └─► DONE! ✅
       Infrastructure deployed successfully
```

---

## 📝 Which File / Command Do What?

| Command | What It Does | Time |
|---------|------------|------|
| `gcloud auth application-default login` | **Authenticate with Google** - MUST DO THIS FIRST! | 2-3 min |
| `gcloud config set project ...` | Set which GCP project to use | 30 sec |
| `terraform init` | Download Google provider & prepare Terraform | 2-5 min |
| `terraform validate` | Check if Terraform files are correct | 10 sec |
| `terraform plan` | Show what will be created (don't create yet) | 30-60 sec |
| `terraform apply` | **ACTUALLY CREATE THE INFRASTRUCTURE** (the main one!) | 15-30 min |
| `terraform output` | Show what was created (URLs, names, etc.) | 10 sec |
| `bash deployment/deploy.sh` | Deploy the application (frontend, backend, database) | 10-15 min |

---

## ✅ Check Your Progress

After each step, here's what you should see:

### Step 1: `gcloud auth application-default login`
```
Credential saved to file: [/home/user/.config/gcloud/application_default_credentials.json]
```

### Step 2: `gcloud config set project ...`
No output = good

### Step 3: `terraform init`
```
Terraform has been successfully initialized!
```

### Step 4: `terraform validate`
```
Success! The configuration is valid.
```

### Step 5: `terraform plan`
```
Plan: 51 to add, 0 to change, 0 to destroy.
```

### Step 6: `terraform apply` → Type `yes` when prompted
```
Apply complete! Resources: 51 added, 0 changed, 0 destroyed.

Outputs:
cloud_sql_instance_name = "gcp-bank-db"
frontend_bucket_name = "decoded-flag-455607-c3-banking-app"
...
```

### Step 7: `terraform output`
Shows all the resources created

---

## 🛑 STOP! Before You Start

✅ Do you have `terraform` installed?
```bash
terraform --version
```

✅ Do you have `gcloud` CLI installed?
```bash
gcloud --version
```

If either says "command not found", install them first:
- Terraform: https://www.terraform.io/downloads
- Google Cloud CLI: https://cloud.google.com/sdk/docs/install

---

## 🚨 Common Errors & Fixes

| Error | Fix |
|-------|-----|
| `ACCESS_TOKEN_SCOPE_INSUFFICIENT` | Did you run `gcloud auth application-default login`? Run it again! |
| `terraform: command not found` | Install Terraform: https://www.terraform.io/downloads |
| `gcloud: command not found` | Install Google Cloud SDK: https://cloud.google.com/sdk |
| `Project not found: decoded-flag-455607-c3` | Run `gcloud config set project decoded-flag-455607-c3` |
| `Error: Unsupported argument` | The Terraform files are fixed! Make sure you're in `/workspaces/GCP-Project/terraform` |

---

## 📞 Need Help?

1. **Read:** [DEPLOYMENT_ORDER.md](/workspaces/GCP-Project/DEPLOYMENT_ORDER.md) - Full step-by-step guide
2. **Read:** [AUTHENTICATION_FIX.md](/workspaces/GCP-Project/AUTHENTICATION_FIX.md) - Auth troubleshooting
3. **Read:** [QUICK_REFERENCE.md](/workspaces/GCP-Project/QUICK_REFERENCE.md) - Useful commands

---

## 🎯 Remember

```
Step 1: gcloud auth application-default login  ← DO THIS FIRST! ⭐
Step 2-7: Run terraform commands
Step 8: Done! Infrastructure deployed ✅
```

**Start here:**
```bash
gcloud auth application-default login
```
