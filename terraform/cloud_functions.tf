# Cloud Functions - Processing Handler & Notification Handler
# Both are Pub/Sub triggered (event-driven)

# =============================================================
# PROCESSING HANDLER
# =============================================================

resource "google_cloudfunctions_function" "processing_handler" {
  name        = "processing-handler"
  description = "Process requests from Pub/Sub request-queue topic"
  runtime     = "python311"
  region      = var.gcp_region

  source_archive_bucket = google_storage_bucket.functions_source.name
  source_archive_object = google_storage_object.processing_handler_source.name

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.request_queue.id
  }

  entry_point            = "processing_handler"
  service_account_email  = google_service_account.functions_sa.email
  timeout                = 540  # 9 minutes
  available_memory_mb    = 512
  max_instances          = 100

  environment_variables = {
    GCP_PROJECT_ID         = var.gcp_project_id
    CLOUDSQL_HOST          = google_sql_database_instance.bank_db.private_ip_address
    CLOUDSQL_USER          = "postgres"
    CLOUDSQL_DATABASE      = "bank_app"
    FUNCTION_REGION        = var.gcp_region
  }

  vpc_connector = google_vpc_access_connector.functions_connector.id

  labels = {
    function = "processing-handler"
    trigger  = "pubsub"
  }

  depends_on = [
    google_project_iam_member.functions_pubsub_subscriber,
    google_project_iam_member.functions_cloudsql_client,
    google_project_iam_member.functions_secret_accessor,
    google_storage_object.processing_handler_source,
  ]
}

# =============================================================
# NOTIFICATION HANDLER
# =============================================================

resource "google_cloudfunctions_function" "notification_handler" {
  name        = "notification-handler"
  description = "Process notifications from Pub/Sub notification-queue topic"
  runtime     = "python311"
  region      = var.gcp_region

  source_archive_bucket = google_storage_bucket.functions_source.name
  source_archive_object = google_storage_object.notification_handler_source.name

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.notification_queue.id
  }

  entry_point            = "notification_handler"
  service_account_email  = google_service_account.functions_sa.email
  timeout                = 300  # 5 minutes
  available_memory_mb    = 256
  max_instances          = 50

  environment_variables = {
    GCP_PROJECT_ID         = var.gcp_project_id
    CLOUDSQL_HOST          = google_sql_database_instance.bank_db.private_ip_address
    CLOUDSQL_USER          = "postgres"
    CLOUDSQL_DATABASE      = "bank_app"
    FUNCTION_REGION        = var.gcp_region
  }

  vpc_connector = google_vpc_access_connector.functions_connector.id

  labels = {
    function = "notification-handler"
    trigger  = "pubsub"
  }

  depends_on = [
    google_project_iam_member.functions_pubsub_subscriber,
    google_project_iam_member.functions_cloudsql_client,
    google_project_iam_member.functions_secret_accessor,
    google_storage_object.notification_handler_source,
  ]
}

# =============================================================
# CLOUD STORAGE FOR FUNCTION SOURCE CODE
# =============================================================

resource "google_storage_bucket" "functions_source" {
  name          = "${var.gcp_project_id}-function-source-${random_id.bucket_suffix.hex}"
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    purpose = "function-source"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Processing Handler source code
resource "google_storage_object" "processing_handler_source" {
  name   = "processing-handler-${data.archive_file.processing_handler_source.output_base64sha256}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = data.archive_file.processing_handler_source.output_path
}

data "archive_file" "processing_handler_source" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/processing-handler"
  output_path = "/tmp/processing-handler.zip"
}

# Notification Handler source code
resource "google_storage_object" "notification_handler_source" {
  name   = "notification-handler-${data.archive_file.notification_handler_source.output_base64sha256}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = data.archive_file.notification_handler_source.output_path
}

data "archive_file" "notification_handler_source" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/notification-handler"
  output_path = "/tmp/notification-handler.zip"
}

# =============================================================
# OUTPUTS
# =============================================================

output "processing_handler_name" {
  value       = google_cloudfunctions_function.processing_handler.name
  description = "Name of the processing handler function"
}

output "processing_handler_url" {
  value       = google_cloudfunctions_function.processing_handler.https_trigger_url
  description = "URL of the processing handler function"
}

output "notification_handler_name" {
  value       = google_cloudfunctions_function.notification_handler.name
  description = "Name of the notification handler function"
}

output "notification_handler_url" {
  value       = google_cloudfunctions_function.notification_handler.https_trigger_url
  description = "URL of the notification handler function"
}
