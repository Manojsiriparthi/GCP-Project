#!/bin/bash

# Cleanup script to remove all failed resources from terraform state
# This allows retry without permission errors

cd /workspaces/GCP-Project/terraform

echo "🧹 Cleaning up failed terraform state resources..."

# Remove all project IAM members
terraform state rm google_project_iam_member.api_handler_sql_client 2>/dev/null || true
terraform state rm google_project_iam_member.api_handler_logging_writer 2>/dev/null || true
terraform state rm google_project_iam_member.api_handler_monitoring_writer 2>/dev/null || true
terraform state rm google_project_iam_member.api_handler_pubsub_publisher 2>/dev/null || true
terraform state rm google_project_iam_member.api_handler_secret_accessor 2>/dev/null || true

terraform state rm google_project_iam_member.notification_handler_sql_client 2>/dev/null || true
terraform state rm google_project_iam_member.notification_handler_logging_writer 2>/dev/null || true
terraform state rm google_project_iam_member.notification_handler_monitoring_writer 2>/dev/null || true
terraform state rm google_project_iam_member.notification_handler_pubsub_publisher 2>/dev/null || true
terraform state rm google_project_iam_member.notification_handler_secret_accessor 2>/dev/null || true

terraform state rm google_project_iam_member.functions_pubsub_subscriber 2>/dev/null || true
terraform state rm google_project_iam_member.functions_cloudsql_client 2>/dev/null || true
terraform state rm google_project_iam_member.functions_secret_accessor 2>/dev/null || true
terraform state rm google_project_iam_member.functions_logging_writer 2>/dev/null || true
terraform state rm google_project_iam_member.functions_pubsub_publisher 2>/dev/null || true

# Remove failed resources
terraform state rm google_vpc_access_connector.functions_connector 2>/dev/null || true
terraform state rm google_sql_database_instance.bank_app 2>/dev/null || true
terraform state rm time_sleep.wait_for_api_propagation 2>/dev/null || true

echo "✅ Cleanup complete. Ready to retry."
