# Deploy-App: GCP Bank Application Deployment Guide

## Overview

This guide explains both automated (Terraform) and manual (gcloud CLI) deployment methods for the GCP Bank Application. Choose based on your preference: Terraform for infrastructure as code or manual CLI commands for step-by-step control.

---

## Part 1: Prerequisites (Required for Both Methods)

### Step 1.1: Install Required Tools

Before deploying, ensure you have installed:

```bash
# Install Google Cloud SDK
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Windows
# Download installer from: https://cloud.google.com/sdk/docs/install
```

Verify installation:
```bash
gcloud --version
# Output: Google Cloud SDK 123.456.789

which gcloud
# Output: /usr/local/bin/gcloud (or similar path)
```

For Terraform deployment, also install Terraform:
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify
terraform --version
# Output: Terraform v1.6.0
```

### Step 1.2: Set Up Google Cloud Project

Create a new GCP project if you don't have one:

```bash
# Set project ID (use lowercase, hyphens allowed, no underscores)
export PROJECT_ID="gcp-bank-app-$(date +%s)"
export REGION="us-central1"
export ZONE="us-central1-a"

# Create project
gcloud projects create ${PROJECT_ID} --name="GCP Bank Application"

# Set as default
gcloud config set project ${PROJECT_ID}

# Verify
gcloud config get-value project
# Output: gcp-bank-app-1732123456
```

### Step 1.3: Enable Required APIs

Enable all necessary Google Cloud APIs:

```bash
# Cloud Pub/Sub API
gcloud services enable pubsub.googleapis.com

# Cloud Functions API
gcloud services enable cloudfunctions.googleapis.com

# Cloud Logging API
gcloud services enable logging.googleapis.com

# Cloud Monitoring API
gcloud services enable monitoring.googleapis.com

# Cloud SQL API
gcloud services enable sqladmin.googleapis.com

# Cloud Compute API (for VPC, networks)
gcloud services enable compute.googleapis.com

# Cloud Resource Manager API
gcloud services enable cloudresourcemanager.googleapis.com

# Secret Manager API
gcloud services enable secretmanager.googleapis.com

# Cloud Build API (for deploying functions)
gcloud services enable cloudbuild.googleapis.com

# Verify all are enabled
gcloud services list --enabled | grep -E "pubsub|cloudfunctions|logging|monitoring|sqladmin"
```

### Step 1.4: Set Up Service Account

Create a service account for Terraform (if using automated method) or for manual deployments:

```bash
# Create service account
gcloud iam service-accounts create gcp-bank-app-sa \
  --display-name="GCP Bank Application Service Account"

# Get service account email
SA_EMAIL="gcp-bank-app-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant necessary roles to service account
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/pubsub.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/cloudfunctions.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/cloudsql.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.admin"

# Verify roles
gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SA_EMAIL}"
```

### Step 1.5: Create Storage Bucket for Cloud Function Code

Cloud Functions need their code stored in Cloud Storage:

```bash
# Create unique bucket name
BUCKET_NAME="gcp-bank-app-functions-${PROJECT_ID}"

# Create bucket
gsutil mb -l ${REGION} gs://${BUCKET_NAME}/

# Verify bucket created
gsutil ls | grep ${BUCKET_NAME}
# Output: gs://gcp-bank-app-functions-...
```

---

## Part 2: AUTOMATED DEPLOYMENT (Terraform)

### Step 2.1: Configure Terraform Variables

Edit `terraform/terraform.tfvars` with your project details:

```bash
cat > terraform/terraform.tfvars << 'TFEOF'
project_id = "gcp-bank-app-123456"
region     = "us-central1"
zone       = "us-central1-a"

# Database configuration
db_instance_name = "gcp-bank-sql"
db_name          = "bank_db"
db_user          = "postgres"
db_password      = "SecurePassword123!"

# Cloud Functions configuration
processing_handler_memory   = 512
notification_handler_memory = 256
TFEOF

# Verify file created
cat terraform/terraform.tfvars
```

### Step 2.2: Initialize Terraform

Terraform needs to download provider plugins and set up backend:

```bash
cd /workspaces/GCP-Project/terraform

# Initialize Terraform (downloads plugins, prepares backend)
terraform init

# Output should show:
# - Downloading plugin: google provider
# - Terraform has been successfully initialized!
# - Backend initialized successfully

# Verify initialization
ls -la .terraform/
# Output: .terraform directory with plugins
```

### Step 2.3: Validate Terraform Configuration

Ensure all Terraform files are syntactically correct:

```bash
# Validate syntax
terraform validate

# Output: Success! The configuration is valid.

# Check for issues
terraform fmt -check

# If files need formatting:
terraform fmt -recursive .
```

### Step 2.4: Plan Terraform Deployment

Create a plan to see what resources will be created:

```bash
# Generate plan (dry-run)
terraform plan -out=tfplan

# Output shows:
# - 15+ resources to create (Pub/Sub topics, subscriptions, Cloud Functions, etc.)
# - Example:
#   google_pubsub_topic.request_queue will be created
#   google_pubsub_subscription.request_queue_subscription will be created
#   google_cloudfunctions_function.processing_handler will be created
#   etc.

# Review plan details
terraform plan -out=tfplan | head -50
```

### Step 2.5: Apply Terraform Configuration

Deploy all infrastructure:

```bash
# Apply terraform (creates all resources)
terraform apply tfplan

# Output shows real-time creation:
# google_pubsub_topic.request_queue: Creating...
# google_pubsub_topic.request_queue: Creation complete after 2s
# google_cloudfunctions_function.processing_handler: Creating...
# google_cloudfunctions_function.processing_handler: Creation complete after 45s

# Total time: approximately 5-10 minutes depending on Cloud SQL creation

# Save outputs
terraform output > deployment-outputs.txt
```

### Step 2.6: Verify Terraform Deployment

Confirm all resources created successfully:

```bash
# List all Terraform resources
terraform state list

# Check specific resources
terraform state show google_pubsub_topic.request_queue

# Verify in GCP Console
gcloud pubsub topics list
# Output: NAME (projects/PROJECT_ID/topics/request-queue, etc.)

gcloud functions list
# Output: NAME RUNTIME STATUS
# processing-handler python311 ACTIVE
# notification-handler python311 ACTIVE

gcloud sql instances list
# Output: NAME DATABASE_VERSION LOCATION STATE
# gcp-bank-sql POSTGRES_15 us-central1 RUNNABLE
```

### Step 2.7: Deploy Cloud Functions Code

Upload processing and notification handler code:

```bash
# Package processing handler
cd backend/processing-handler
zip -r ../../processing-handler.zip .
cd ../../

# Deploy processing handler
gcloud functions deploy processing-handler \
  --runtime=python311 \
  --trigger-topic=request-queue \
  --entry-point=processing_handler \
  --source=backend/processing-handler \
  --memory=512MB \
  --timeout=540s \
  --max-instances=100 \
  --service-account=gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com

# Output: Deploying function...
# API [cloudfunctions.googleapis.com] not enabled on project...
# (If error, enable API with gcloud services enable cloudfunctions.googleapis.com)

# Package notification handler
cd backend/notification-handler
zip -r ../../notification-handler.zip .
cd ../../

# Deploy notification handler
gcloud functions deploy notification-handler \
  --runtime=python311 \
  --trigger-topic=notification-queue \
  --entry-point=notification_handler \
  --source=backend/notification-handler \
  --memory=256MB \
  --timeout=300s \
  --max-instances=50 \
  --service-account=gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com

# Verify both deployed
gcloud functions list --filter="name:(processing-handler OR notification-handler)"
```

---

## Part 3: MANUAL DEPLOYMENT (gcloud CLI)

### Step 3.1: Create Cloud SQL Instance

Manually create PostgreSQL database:

```bash
# Create Cloud SQL instance (takes 5-10 minutes)
gcloud sql instances create gcp-bank-sql \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-central1 \
  --no-assign-ip \
  --network=default \
  --availability-type=ZONAL

# Output: Creating Cloud SQL instance...
#         Instance creation is complete

# Verify instance created
gcloud sql instances describe gcp-bank-sql
# Output: name: gcp-bank-sql
#         state: RUNNABLE
#         ipAddresses:
#         - ipAddress: 10.x.x.x (private IP)

# Wait for instance to be fully ready
gcloud sql instances wait-until-ready gcp-bank-sql
```

### Step 3.2: Create Cloud SQL Database and User

Set up database and credentials:

```bash
# Create database
gcloud sql databases create bank_db \
  --instance=gcp-bank-sql

# Output: Creating Cloud SQL database...
#         Database creation complete

# Create database user (password will be prompted)
gcloud sql users create postgres \
  --instance=gcp-bank-sql \
  --password

# When prompted, enter a secure password like: SecurePass123!

# Store password in Secret Manager for secure access
gcloud secrets create cloudsql-password \
  --data-file=/dev/stdin
  
# (Then paste password and press Ctrl+D)

# Verify secret created
gcloud secrets versions list cloudsql-password
```

### Step 3.3: Initialize Database Schema

Connect to Cloud SQL and create tables:

```bash
# Get Cloud SQL instance connection name
gcloud sql instances describe gcp-bank-sql --format='value(connectionName)'

# Install psql (PostgreSQL client)
# macOS
brew install postgresql

# Linux (Ubuntu)
sudo apt-get install postgresql-client

# Connect to database
gcloud sql connect gcp-bank-sql --user=postgres

# In psql prompt, run these SQL commands:

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  phone VARCHAR(10) UNIQUE NOT NULL,
  balance DECIMAL(10, 2) DEFAULT 1000,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payments (
  id SERIAL PRIMARY KEY,
  from_user_id INTEGER REFERENCES users(id),
  to_user_id INTEGER REFERENCES users(id),
  amount DECIMAL(10, 2) NOT NULL,
  status VARCHAR(20) DEFAULT 'completed',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE idempotency_keys (
  request_id VARCHAR(255) PRIMARY KEY,
  result JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payments_from_user ON payments(from_user_id);
CREATE INDEX idx_payments_to_user ON payments(to_user_id);

# Exit psql
\\q
```

### Step 3.4: Create Pub/Sub Topics

Manually create all message topics:

```bash
# Create request-queue topic
gcloud pubsub topics create request-queue \
  --message-retention-duration=7d

# Create notification-queue topic
gcloud pubsub topics create notification-queue \
  --message-retention-duration=7d

# Create send-email topic
gcloud pubsub topics create send-email \
  --message-retention-duration=7d

# Create Dead Letter Queues
gcloud pubsub topics create request-queue-dlq \
  --message-retention-duration=30d

gcloud pubsub topics create notification-queue-dlq \
  --message-retention-duration=30d

# Verify all topics created
gcloud pubsub topics list
# Output: NAME (projects/PROJECT_ID/topics/...)
#         - request-queue
#         - notification-queue
#         - send-email
#         - request-queue-dlq
#         - notification-queue-dlq
```

### Step 3.5: Create Pub/Sub Subscriptions

Create subscriptions with delivery policies:

```bash
# Request-queue subscription (processing handler)
gcloud pubsub subscriptions create request-queue-sub \
  --topic=request-queue \
  --push-endpoint="https://us-central1-PROJECT_ID.cloudfunctions.net/processing-handler" \
  --push-auth-service-account=gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com \
  --ack-deadline=60 \
  --message-retention-duration=7d

# Notification-queue subscription (notification handler)
gcloud pubsub subscriptions create notification-queue-sub \
  --topic=notification-queue \
  --push-endpoint="https://us-central1-PROJECT_ID.cloudfunctions.net/notification-handler" \
  --push-auth-service-account=gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com \
  --ack-deadline=60 \
  --message-retention-duration=7d

# Dead Letter Queue subscriptions (pull-based, manual processing)
gcloud pubsub subscriptions create request-queue-dlq-sub \
  --topic=request-queue-dlq

gcloud pubsub subscriptions create notification-queue-dlq-sub \
  --topic=notification-queue-dlq

# Verify subscriptions created
gcloud pubsub subscriptions list
```

### Step 3.6: Deploy Processing Handler Cloud Function

Deploy first Cloud Function:

```bash
# Package source code
cd backend/processing-handler
zip -r ../../processing-handler.zip . -x "*.git*"
cd ../../

# Deploy function
gcloud functions deploy processing-handler \
  --runtime=python311 \
  --trigger-topic=request-queue \
  --entry-point=processing_handler \
  --source=backend/processing-handler \
  --memory=512MB \
  --timeout=540 \
  --max-instances=100 \
  --service-account=gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com

# Output: Deploying function...
#         Waiting for operation to complete...
#         Deploying function complete! Function details:
#         Name: processing-handler
#         Status: ACTIVE
#         Trigger: projects/PROJECT_ID/topics/request-queue

# Verify deployment
gcloud functions describe processing-handler

# Check logs
gcloud functions logs read processing-handler --limit=50
```

### Step 3.7: Deploy Notification Handler Cloud Function

Deploy second Cloud Function:

```bash
# Package source code
cd backend/notification-handler
zip -r ../../notification-handler.zip . -x "*.git*"
cd ../../

# Deploy function
gcloud functions deploy notification-handler \
  --runtime=python311 \
  --trigger-topic=notification-queue \
  --entry-point=notification_handler \
  --source=backend/notification-handler \
  --memory=256MB \
  --timeout=300 \
  --max-instances=50 \
  --service-account=gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com

# Verify deployment
gcloud functions describe notification-handler

# Check logs
gcloud functions logs read notification-handler --limit=50
```

### Step 3.8: Set Up Secret Manager

Store sensitive data securely:

```bash
# Store database password
gcloud secrets create cloudsql-password --data-file=/dev/stdin

# Store API keys
gcloud secrets create api-key --data-file=/dev/stdin

# Grant Cloud Functions access to secrets
gcloud secrets add-iam-policy-binding cloudsql-password \
  --member="serviceAccount:gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Verify secrets
gcloud secrets list
```

---

## Part 4: Verification and Testing

### Step 4.1: Verify All Components

Test everything is running:

```bash
# Check Cloud SQL
gcloud sql instances describe gcp-bank-sql --format='value(state)'
# Output: RUNNABLE

# Check Pub/Sub topics
gcloud pubsub topics list --format='value(name)' | wc -l
# Output: 5 (should have 5 topics)

# Check Cloud Functions
gcloud functions list --format='value(name)'
# Output: processing-handler
#         notification-handler

# Check subscriptions
gcloud pubsub subscriptions list --format='value(name)' | wc -l
# Output: 5 (3 active + 2 DLQ)
```

### Step 4.2: Test Message Publishing

Publish test message to Pub/Sub:

```bash
# Create test message
gcloud pubsub topics publish request-queue \
  --message='{"type": "create_user", "data": {"phone": "9876543210", "request_id": "test-001"}}'

# Output: messageIds:
#         - '12345678901234'

# Check Cloud Functions logs
gcloud functions logs read processing-handler --limit=10

# Should show message received and processed
```

### Step 4.3: Verify Database

Check if data was inserted:

```bash
# Connect to database
gcloud sql connect gcp-bank-sql --user=postgres

# In psql:
SELECT * FROM users;
# Output: Shows newly created user with phone 9876543210

SELECT * FROM idempotency_keys;
# Output: Shows test-001 request_id

\\q
```

### Step 4.4: Check Cloud Logging

View all system logs:

```bash
# View processing handler logs
gcloud functions logs read processing-handler --limit=50

# View notification handler logs
gcloud functions logs read notification-handler --limit=50

# View Pub/Sub metrics
gcloud monitoring time-series list --filter='metric.type="pubsub.googleapis.com/subscription/num_undelivered_messages"'

# View Cloud SQL logs
gcloud sql operations list --instance=gcp-bank-sql --limit=10
```

---

## Part 5: Cleanup (If Removing Deployment)

### Step 5.1: Remove All Resources

Delete all deployed resources:

```bash
# Using Terraform (easiest)
cd terraform
terraform destroy -auto-approve

# Or manually delete with gcloud:

# Delete Cloud Functions
gcloud functions delete processing-handler --quiet
gcloud functions delete notification-handler --quiet

# Delete Pub/Sub
gcloud pubsub subscriptions delete request-queue-sub --quiet
gcloud pubsub subscriptions delete notification-queue-sub --quiet
gcloud pubsub subscriptions delete request-queue-dlq-sub --quiet
gcloud pubsub subscriptions delete notification-queue-dlq-sub --quiet
gcloud pubsub topics delete request-queue --quiet
gcloud pubsub topics delete notification-queue --quiet
gcloud pubsub topics delete send-email --quiet
gcloud pubsub topics delete request-queue-dlq --quiet
gcloud pubsub topics delete notification-queue-dlq --quiet

# Delete Cloud SQL
gcloud sql instances delete gcp-bank-sql --quiet

# Delete Secrets
gcloud secrets delete cloudsql-password --quiet

# Delete Storage Bucket
gsutil -m rm -r gs://gcp-bank-app-functions-123456

# Delete project (optional - permanent)
gcloud projects delete gcp-bank-app-123456
```

---

## Troubleshooting Guide

### Issue: "API not enabled"
**Problem:** Error says "API X is not enabled"
**Solution:** Enable the required API:
```bash
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable sqladmin.googleapis.com
```

### Issue: "Permission denied"
**Problem:** Error says "Permission denied on resource"
**Solution:** Grant yourself admin role:
```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:YOUR_EMAIL@gmail.com" \
  --role="roles/owner"
```

### Issue: "Cloud Function deployment timeout"
**Problem:** Deployment takes too long and times out
**Solution:** Increase timeout and retry:
```bash
gcloud functions deploy processing-handler \
  --update-env-vars="TIMEOUT=600"
```

### Issue: "Database connection refused"
**Problem:** Cloud Function cannot connect to Cloud SQL
**Solution:** Ensure database user has correct password:
```bash
gcloud sql users set-password postgres \
  --instance=gcp-bank-sql \
  --password
```

---

**Deployment Complete!** Your GCP Bank Application is now live and ready to process user creation and payment transactions asynchronously through Pub/Sub messaging.