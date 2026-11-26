# Service Account for API Handler
resource "google_service_account" "api_handler" {
  account_id   = "api-handler-sa"
  display_name = "API Handler Service Account"
  description  = "Service account for API Handler Cloud Function"

  depends_on = [
    google_project_service.required_apis,
    time_sleep.wait_for_api_propagation
  ]
}

# Service Account for Notification Handler
resource "google_service_account" "notification_handler" {
  account_id   = "notification-handler-sa"
  display_name = "Notification Handler Service Account"
  description  = "Service account for Notification Handler Cloud Function"

  depends_on = [
    google_project_service.required_apis,
    time_sleep.wait_for_api_propagation
  ]
}

# IAM Roles disabled due to insufficient permissions on service account
# These need to be assigned manually via GCP Console or gcloud commands:
# gcloud projects add-iam-policy-binding PROJECT_ID --member=serviceAccount:api-handler-sa@PROJECT_ID.iam.gserviceaccount.com --role=roles/cloudsql.client
# gcloud projects add-iam-policy-binding PROJECT_ID --member=serviceAccount:api-handler-sa@PROJECT_ID.iam.gserviceaccount.com --role=roles/logging.logWriter
# gcloud projects add-iam-policy-binding PROJECT_ID --member=serviceAccount:api-handler-sa@PROJECT_ID.iam.gserviceaccount.com --role=roles/monitoring.metricWriter
# gcloud projects add-iam-policy-binding PROJECT_ID --member=serviceAccount:api-handler-sa@PROJECT_ID.iam.gserviceaccount.com --role=roles/pubsub.publisher
# gcloud projects add-iam-policy-binding PROJECT_ID --member=serviceAccount:api-handler-sa@PROJECT_ID.iam.gserviceaccount.com --role=roles/secretmanager.secretAccessor
# gcloud projects add-iam-policy-binding PROJECT_ID --member=serviceAccount:notification-handler-sa@PROJECT_ID.iam.gserviceaccount.com --role=roles/cloudsql.client
# gcloud projects add-iam-policy-binding PROJECT_ID --member=serviceAccount:notification-handler-sa@PROJECT_ID.iam.gserviceaccount.com --role=roles/logging.logWriter
# gcloud projects add-iam-policy-binding PROJECT_ID --member=serviceAccount:notification-handler-sa@PROJECT_ID.iam.gserviceaccount.com --role=roles/monitoring.metricWriter
# gcloud projects add-iam-policy-binding PROJECT_ID --member=serviceAccount:notification-handler-sa@PROJECT_ID.iam.gserviceaccount.com --role=roles/pubsub.publisher
# gcloud projects add-iam-policy-binding PROJECT_ID --member=serviceAccount:notification-handler-sa@PROJECT_ID.iam.gserviceaccount.com --role=roles/secretmanager.secretAccessor

# resource "google_project_iam_member" "api_handler_sql_client" {
#   project = local.project_id
#   role    = "roles/cloudsql.client"
#   member  = "serviceAccount:${google_service_account.api_handler.email}"
#   
#   depends_on = [time_sleep.wait_for_api_propagation]
# }
#
# resource "google_project_iam_member" "api_handler_logging_writer" {
#   project = local.project_id
#   role    = "roles/logging.logWriter"
#   member  = "serviceAccount:${google_service_account.api_handler.email}"
#   
#   depends_on = [time_sleep.wait_for_api_propagation]
# }
#
# resource "google_project_iam_member" "api_handler_monitoring_writer" {
#   project = local.project_id
#   role    = "roles/monitoring.metricWriter"
#   member  = "serviceAccount:${google_service_account.api_handler.email}"
#   
#   depends_on = [time_sleep.wait_for_api_propagation]
# }
#
# resource "google_project_iam_member" "api_handler_pubsub_publisher" {
#   project = local.project_id
#   role    = "roles/pubsub.publisher"
#   member  = "serviceAccount:${google_service_account.api_handler.email}"
#   
#   depends_on = [time_sleep.wait_for_api_propagation]
# }
#
# resource "google_project_iam_member" "api_handler_secret_accessor" {
#   project = local.project_id
#   role    = "roles/secretmanager.secretAccessor"
#   member  = "serviceAccount:${google_service_account.api_handler.email}"
#   
#   depends_on = [time_sleep.wait_for_api_propagation]
# }
#
# resource "google_project_iam_member" "notification_handler_sql_client" {
#   project = local.project_id
#   role    = "roles/cloudsql.client"
#   member  = "serviceAccount:${google_service_account.notification_handler.email}"
#   
#   depends_on = [time_sleep.wait_for_api_propagation]
# }
#
# resource "google_project_iam_member" "notification_handler_logging_writer" {
#   project = local.project_id
#   role    = "roles/logging.logWriter"
#   member  = "serviceAccount:${google_service_account.notification_handler.email}"
#   
#   depends_on = [time_sleep.wait_for_api_propagation]
# }
#
# resource "google_project_iam_member" "notification_handler_monitoring_writer" {
#   project = local.project_id
#   role    = "roles/monitoring.metricWriter"
#   member  = "serviceAccount:${google_service_account.notification_handler.email}"
#   
#   depends_on = [time_sleep.wait_for_api_propagation]
# }
#
# resource "google_project_iam_member" "notification_handler_pubsub_publisher" {
#   project = local.project_id
#   role    = "roles/pubsub.publisher"
#   member  = "serviceAccount:${google_service_account.notification_handler.email}"
#   
#   depends_on = [time_sleep.wait_for_api_propagation]
# }
#
# resource "google_project_iam_member" "notification_handler_secret_accessor" {
#   project = local.project_id
#   role    = "roles/secretmanager.secretAccessor"
#   member  = "serviceAccount:${google_service_account.notification_handler.email}"
#   
#   depends_on = [time_sleep.wait_for_api_propagation]
# }

# Outputs
output "api_handler_service_account_email" {
  description = "API Handler Service Account Email"
  value       = google_service_account.api_handler.email
}

output "notification_handler_service_account_email" {
  description = "Notification Handler Service Account Email"
  value       = google_service_account.notification_handler.email
}
