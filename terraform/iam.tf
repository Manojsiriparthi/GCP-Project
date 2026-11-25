# Service Account for API Handler
resource "google_service_account" "api_handler" {
  account_id   = "api-handler-sa"
  display_name = "API Handler Service Account"
  description  = "Service account for API Handler Cloud Function"

  depends_on = [google_project_service.required_apis]
}

# Service Account for Notification Handler
resource "google_service_account" "notification_handler" {
  account_id   = "notification-handler-sa"
  display_name = "Notification Handler Service Account"
  description  = "Service account for Notification Handler Cloud Function"

  depends_on = [google_project_service.required_apis]
}

# API Handler - Cloud SQL Client Role
resource "google_project_iam_member" "api_handler_sql_client" {
  project = var.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api_handler.email}"
}

# API Handler - Logging Writer Role
resource "google_project_iam_member" "api_handler_logging_writer" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.api_handler.email}"
}

# API Handler - Monitoring Metric Writer Role
resource "google_project_iam_member" "api_handler_monitoring_writer" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.api_handler.email}"
}

# API Handler - Pub/Sub Publisher Role
resource "google_project_iam_member" "api_handler_pubsub_publisher" {
  project = var.gcp_project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.api_handler.email}"
}

# API Handler - Secret Accessor Role
resource "google_project_iam_member" "api_handler_secret_accessor" {
  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.api_handler.email}"
}

# Notification Handler - Cloud SQL Client Role
resource "google_project_iam_member" "notification_handler_sql_client" {
  project = var.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.notification_handler.email}"
}

# Notification Handler - Logging Writer Role
resource "google_project_iam_member" "notification_handler_logging_writer" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.notification_handler.email}"
}

# Notification Handler - Monitoring Metric Writer Role
resource "google_project_iam_member" "notification_handler_monitoring_writer" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.notification_handler.email}"
}

# Notification Handler - Pub/Sub Publisher Role
resource "google_project_iam_member" "notification_handler_pubsub_publisher" {
  project = var.gcp_project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.notification_handler.email}"
}

# Notification Handler - Secret Accessor Role
resource "google_project_iam_member" "notification_handler_secret_accessor" {
  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.notification_handler.email}"
}

# Outputs
output "api_handler_service_account_email" {
  description = "API Handler Service Account Email"
  value       = google_service_account.api_handler.email
}

output "notification_handler_service_account_email" {
  description = "Notification Handler Service Account Email"
  value       = google_service_account.notification_handler.email
}
