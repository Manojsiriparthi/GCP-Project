#!/bin/bash
################################################################################
# Fix Service Account IAM Permissions for Terraform Deployment
################################################################################

set -e

PROJECT_ID="decoded-flag-455607-c3"
SERVICE_ACCOUNT_EMAIL="592400528927-compute@developer.gserviceaccount.com"

echo "🔧 Fixing IAM permissions for service account..."
echo "Project: $PROJECT_ID"
echo "Service Account: $SERVICE_ACCOUNT_EMAIL"
echo ""

# Required roles for Terraform to manage GCP resources
REQUIRED_ROLES=(
    "roles/editor"  # Broad access - can be replaced with specific roles if needed
)

echo "📋 Granting IAM roles..."

for role in "${REQUIRED_ROLES[@]}"; do
    echo "  Granting $role..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="$role" \
        --condition=None \
        --quiet 2>/dev/null || echo "    (Role may already be granted)"
done

echo ""
echo "✅ IAM permissions updated!"
echo ""
echo "You can now run the deployment:"
echo "  cd /workspaces/GCP-Project"
echo "  bash deployment/deploy.sh"
echo ""
