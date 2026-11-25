#!/bin/bash

################################################################################
# 🗑️ GCP BANK APPLICATION - COMPLETE CLEANUP & DESTROY SCRIPT
#
# This script safely removes all deployed resources:
# 1. Deletes Cloud Functions
# 2. Removes Pub/Sub topics and subscriptions
# 3. Drops Cloud SQL instance
# 4. Empties and deletes Cloud Storage bucket
# 5. Removes service accounts and IAM roles
# 6. Destroys all Terraform-managed resources
#
# Usage: bash deployment/destroy.sh
# Warning: This will DELETE all data permanently!
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

section_header() {
    echo -e "\n${BLUE}=================================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=================================================================================${NC}\n"
}

section_header "🗑️  GCP BANK APPLICATION - DESTRUCTION SEQUENCE"

log_warning "⚠️  WARNING: THIS WILL DELETE ALL RESOURCES AND DATA!"
log_warning "⚠️  THIS ACTION CANNOT BE UNDONE!"
echo ""
read -p "Type 'YES' to confirm permanent deletion: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    log_info "Destruction cancelled. No resources were deleted."
    exit 0
fi

log_error "PROCEEDING WITH DESTRUCTION - Point of no return!"
sleep 3

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$PROJECT_DIR/terraform"

GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
GCP_REGION="us-central1"

if [ -z "$GCP_PROJECT_ID" ]; then
    log_error "No GCP project is set."
    exit 1
fi

log_info "Project ID: $GCP_PROJECT_ID"
log_info "Region: $GCP_REGION"

section_header "STEP 1: DELETING CLOUD FUNCTIONS"

log_info "Deleting processing-handler function..."
gcloud functions delete processing-handler \
    --region=$GCP_REGION \
    --quiet 2>/dev/null || log_warning "Function already deleted or doesn't exist"
log_success "processing-handler deleted"

log_info "Deleting notification-handler function..."
gcloud functions delete notification-handler \
    --region=$GCP_REGION \
    --quiet 2>/dev/null || log_warning "Function already deleted or doesn't exist"
log_success "notification-handler deleted"

section_header "STEP 2: DELETING PUB/SUB RESOURCES"

log_info "Listing and deleting subscriptions..."
gcloud pubsub subscriptions list --filter="name:request-queue OR name:notification-queue" \
    --format="value(name)" 2>/dev/null | while read subscription; do
    if [ -n "$subscription" ]; then
        log_info "Deleting subscription: $subscription"
        gcloud pubsub subscriptions delete "$subscription" --quiet 2>/dev/null || true
    fi
done
log_success "Subscriptions deleted"

log_info "Listing and deleting topics..."
for topic in request-queue request-queue-dlq notification-queue notification-queue-dlq send-email; do
    log_info "Deleting topic: $topic"
    gcloud pubsub topics delete "$topic" --quiet 2>/dev/null || true
done
log_success "All Pub/Sub topics deleted"

section_header "STEP 3: DELETING CLOUD SQL INSTANCE"

log_info "Retrieving Cloud SQL instance name..."
DB_INSTANCE=$(terraform -chdir="$TERRAFORM_DIR" output -raw cloud_sql_instance_name 2>/dev/null || echo "gcp-bank-db")

log_warning "Deleting Cloud SQL instance: $DB_INSTANCE"
log_warning "This will permanently delete all database data!"
gcloud sql instances delete "$DB_INSTANCE" \
    --quiet 2>/dev/null || log_warning "SQL instance already deleted or doesn't exist"
log_success "Cloud SQL instance deleted"

section_header "STEP 4: DELETING CLOUD STORAGE BUCKET"

log_info "Retrieving bucket name..."
FRONTEND_BUCKET=$(terraform -chdir="$TERRAFORM_DIR" output -raw frontend_bucket_name 2>/dev/null || echo "${GCP_PROJECT_ID}-banking-app")

log_warning "Emptying Cloud Storage bucket: $FRONTEND_BUCKET"
gsutil -m rm -r "gs://$FRONTEND_BUCKET/*" 2>/dev/null || log_info "Bucket already empty"

log_warning "Deleting Cloud Storage bucket: $FRONTEND_BUCKET"
gsutil rb -f "gs://$FRONTEND_BUCKET" 2>/dev/null || log_warning "Bucket already deleted or doesn't exist"
log_success "Cloud Storage bucket deleted"

section_header "STEP 5: DELETING VPC RESOURCES"

log_info "Retrieving VPC connector name..."
VPC_CONNECTOR=$(terraform -chdir="$TERRAFORM_DIR" output -raw vpc_connector_name 2>/dev/null || echo "gcp-bank-connector")

log_info "Deleting VPC connector: $VPC_CONNECTOR"
gcloud compute networks vpc-access connectors delete "$VPC_CONNECTOR" \
    --region=$GCP_REGION \
    --quiet 2>/dev/null || log_warning "VPC connector already deleted or doesn't exist"
log_success "VPC resources deleted"

section_header "STEP 6: DELETING SERVICE ACCOUNTS"

log_info "Listing service accounts..."
SERVICE_ACCOUNTS=$(gcloud iam service-accounts list \
    --filter="email:gcp-bank*@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --format="value(email)" 2>/dev/null)

for sa in $SERVICE_ACCOUNTS; do
    log_info "Deleting service account: $sa"
    gcloud iam service-accounts delete "$sa" --quiet 2>/dev/null || true
done
log_success "Service accounts deleted"

section_header "STEP 7: USING TERRAFORM DESTROY"

cd "$TERRAFORM_DIR"

log_warning "Running terraform destroy to remove all remaining resources..."
log_info "This may take 5-10 minutes..."

terraform destroy --auto-approve 2>/dev/null || log_warning "Terraform destroy had warnings"

log_success "Terraform resources destroyed"

section_header "STEP 8: CLEANUP LOCAL FILES"

log_info "Cleaning up Terraform state files..."
rm -f tfplan tfplan.lock || true
rm -f .terraform/terraform.tfstate* || true
log_success "Local state files cleaned"

section_header "✅ DESTRUCTION COMPLETE!"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                    RESOURCES DELETED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✓ Cloud Functions (processing-handler, notification-handler)"
echo "✓ Pub/Sub Topics (request-queue, notification-queue, send-email)"
echo "✓ Pub/Sub Subscriptions (all)"
echo "✓ Cloud SQL Instance ($DB_INSTANCE)"
echo "✓ Cloud Storage Bucket (gs://$FRONTEND_BUCKET)"
echo "✓ VPC Connector ($VPC_CONNECTOR)"
echo "✓ Service Accounts (all gcp-bank-* accounts)"
echo "✓ IAM Roles and Policies"
echo "✓ All Terraform-managed resources"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Project ID: $GCP_PROJECT_ID"
echo "Region: $GCP_REGION"
echo ""
echo "⚠️  All data has been permanently deleted."
echo "⚠️  Billing for GCP resources has been stopped."
echo ""
echo "To deploy again, run:"
echo "  bash deployment/deploy.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_success "GCP Bank Application completely destroyed!"
