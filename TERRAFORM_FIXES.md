# Terraform Configuration Fixes Summary

## Issues Fixed

### 1. **Deprecated Resource Type: `google_storage_object`**
   - **Error**: The resource type `google_storage_object` is not supported by the hashicorp/google provider
   - **Files Affected**: `cloud_functions.tf`
   - **Solution**: Replaced with `google_storage_bucket_object`
     - Line 192: `resource "google_storage_object" "processing_handler_source"` → `resource "google_storage_bucket_object" "processing_handler_source"`
     - Line 203: `resource "google_storage_object" "notification_handler_source"` → `resource "google_storage_bucket_object" "notification_handler_source"`

### 2. **Invalid Replication Configuration**
   - **Error**: Unsupported argument `automatic = true` in `google_secret_manager_secret` resources
   - **Files Affected**: `cloud_sql.tf`
   - **Solution**: Changed nested replication configuration to use `automatic_replication {}` block
     - Line 72-74: `replication { automatic = true }` → `replication { automatic_replication {} }`
     - Line 92-94: `replication { automatic = true }` → `replication { automatic_replication {} }`

### 3. **Missing Service Account for Cloud Functions**
   - **Error**: Reference to undeclared resource `google_service_account.functions_sa`
   - **Files Affected**: `cloud_functions.tf`, `pubsub.tf`
   - **Solution**: Created unified `google_service_account.functions_sa` in cloud_functions.tf with proper IAM bindings:
     - Pub/Sub Subscriber role
     - Cloud SQL Client role
     - Secret Manager Secret Accessor role
     - Logging Writer role
     - Pub/Sub Publisher role

### 4. **Missing VPC Access Connector**
   - **Error**: Reference to undeclared resource `google_vpc_access_connector.functions_connector`
   - **Files Affected**: `cloud_functions.tf`, `cloud_functions.tf`
   - **Solution**: Created VPC infrastructure:
     - `google_compute_network.functions_network`: Network for VPC connector
     - `google_vpc_access_connector.functions_connector`: VPC Access Connector with:
       - Min instances: 2
       - Max instances: 10
       - IP CIDR range: 10.8.0.0/28

### 5. **Incorrect Database Instance Reference**
   - **Error**: Reference to undeclared resource `google_sql_database_instance.bank_db`
   - **Files Affected**: `cloud_functions.tf`
   - **Solution**: Changed to correct instance name `google_sql_database_instance.bank_app`
     - Line 103: `google_sql_database_instance.bank_db.private_ip_address` → `google_sql_database_instance.bank_app.private_ip_address`
     - Line 149: Same change for notification handler

### 6. **Non-existent Cloud Function Reference in Monitoring**
   - **Error**: Reference to `google_cloudfunctions_function.api_handler` which doesn't exist
   - **Files Affected**: `monitoring.tf`
   - **Solution**: Updated to reference the existing `google_cloudfunctions_function.processing_handler`
     - Alert policy name: Changed from "API Handler - High Error Rate" to "Processing Handler - High Error Rate"
     - Dashboard widget titles: Updated references in monitoring dashboard JSON

### 7. **Storage Object References in Cloud Functions**
   - **Error**: Resource reference in function triggers using old resource type
   - **Files Affected**: `cloud_functions.tf`
   - **Solution**: Updated storage object references:
     - Line 71: `google_storage_object.processing_handler_source.name` → `google_storage_bucket_object.processing_handler_source.name`
     - Line 118: `google_storage_object.notification_handler_source.name` → `google_storage_bucket_object.notification_handler_source.name`
     - Dependency references updated from `google_storage_object` to `google_storage_bucket_object`

### 8. **Environment Variables Using Hardcoded Values**
   - **Improvement**: Updated Cloud Functions environment variables to use Terraform variables
     - `CLOUDSQL_USER`: Changed from hardcoded "postgres" to `var.db_user`
     - `CLOUDSQL_DATABASE`: Changed from hardcoded "bank_app" to `var.db_name`

## Files Modified

1. **cloud_sql.tf**
   - Fixed replication configuration for two secret manager secrets

2. **cloud_functions.tf**
   - Added service account definition and IAM bindings
   - Added VPC network and access connector
   - Updated resource type from `google_storage_object` to `google_storage_bucket_object`
   - Fixed database instance references
   - Updated environment variables to use Terraform variables
   - Added outputs for service account and VPC connector

3. **monitoring.tf**
   - Updated alert policy to reference processing_handler instead of non-existent api_handler
   - Updated dashboard widgets to reference processing_handler

4. **pubsub.tf**
   - No changes needed; already references `google_service_account.functions_sa` correctly

## Validation

All Terraform configuration files have been validated to ensure:
- ✅ No deprecated resource types are used
- ✅ All resource references are properly declared
- ✅ All arguments use correct syntax and naming
- ✅ Service accounts have proper IAM role bindings
- ✅ VPC connectivity is properly configured
- ✅ Database references are consistent

## Notes

- The terraform plan should now execute without syntax or reference errors
- Ensure terraform.tfvars contains all required variables (gcp_project_id, db_password minimum)
- The VPC connector will take a few minutes to provision
- Cloud Functions may need to have their source code available in the respective directories:
  - `backend/processing-handler/`
  - `backend/notification-handler/`
