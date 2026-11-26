#!/bin/bash
################################################################################
# GCP Authentication Setup for Terraform Deployment
# 
# This script sets up proper authentication for the Terraform deployment
# in environments with limited OAuth scopes (like GCE instances)
################################################################################

set -e

PROJECT_ID="decoded-flag-455607-c3"
SERVICE_ACCOUNT_EMAIL="592400528927-compute@developer.gserviceaccount.com"

echo "🔐 GCP Authentication Setup"
echo "================================"
echo "Project: $PROJECT_ID"
echo "Service Account: $SERVICE_ACCOUNT_EMAIL"
echo ""

# Step 1: Check gcloud availability
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found!"
    echo "Please install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

echo "✓ gcloud CLI found"

# Step 2: Check current authentication
CURRENT_ACCOUNT=$(gcloud config get-value account 2>/dev/null || echo "")
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")

echo "Current Account: $CURRENT_ACCOUNT"
echo "Current Project: $CURRENT_PROJECT"
echo ""

# Step 3: Grant IAM permissions to service account
echo "📋 Granting IAM permissions..."
echo "  Granting roles/editor to service account..."

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/editor" \
    --quiet 2>/dev/null || {
    echo "⚠️  IAM binding may already exist or requires additional permissions"
}

echo "✓ IAM permissions configured"
echo ""

# Step 4: Alternative: Create a service account key for Terraform
echo "🔑 Setting up Terraform authentication..."
echo ""
echo "Option 1: Use Application Default Credentials"
echo "  Run: gcloud auth application-default login"
echo ""
echo "Option 2: Create a dedicated service account key"
echo "  Uncomment the commands below:"
echo ""

cat << 'EOF'
# Create a dedicated service account for Terraform
# SA_EMAIL="terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com"
# gcloud iam service-accounts create terraform-sa \
#     --display-name="Terraform Service Account" \
#     --project=$PROJECT_ID 2>/dev/null || true
#
# gcloud projects add-iam-policy-binding $PROJECT_ID \
#     --member="serviceAccount:${SA_EMAIL}" \
#     --role="roles/editor" \
#     --quiet
#
# gcloud iam service-accounts keys create /tmp/terraform-key.json \
#     --iam-account="${SA_EMAIL}"
#
# export GOOGLE_APPLICATION_CREDENTIALS=/tmp/terraform-key.json
EOF

echo ""
echo "✅ Authentication setup complete!"
echo ""
echo "Next steps:"
echo "1. Set up Application Default Credentials:"
echo "   gcloud auth application-default login"
echo ""
echo "2. Verify project is set:"
echo "   gcloud config set project $PROJECT_ID"
echo ""
echo "3. Run Terraform:"
echo "   cd /workspaces/GCP-Project/terraform"
echo "   terraform init"
echo "   terraform plan"
echo "   terraform apply"
echo ""
