# Cloud Storage bucket for frontend application
# Serves the React frontend application

# Frontend bucket
resource "google_storage_bucket" "frontend" {
  name          = "${local.project_id}-frontend-${random_id.frontend_bucket_suffix.hex}"
  location      = local.region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    environment = "production"
    purpose     = "frontend"
    app         = "bank-app"
  }

  depends_on = [
    google_project_service.required_apis,
    time_sleep.wait_for_api_propagation
  ]
}

# Random suffix for unique bucket naming
resource "random_id" "frontend_bucket_suffix" {
  byte_length = 4
}

# Frontend index.html
resource "google_storage_bucket_object" "frontend_index" {
  name   = "index.html"
  bucket = google_storage_bucket.frontend.name
  source = data.archive_file.frontend_build.output_path

  content_type = "text/html"

  depends_on = [
    google_storage_bucket.frontend,
    data.archive_file.frontend_build
  ]
}

# Archive the frontend build directory
data "archive_file" "frontend_build" {
  type        = "zip"
  source_dir  = "${path.module}/../frontend/public"
  output_path = "/tmp/frontend-build.zip"
}

# =============================================================
# FRONTEND BUCKET OUTPUTS
# =============================================================

output "frontend_bucket_name" {
  value       = google_storage_bucket.frontend.name
  description = "Name of the frontend storage bucket"
}

output "frontend_bucket_url" {
  value       = "gs://${google_storage_bucket.frontend.name}"
  description = "URL of the frontend storage bucket"
}

output "frontend_bucket_location" {
  value       = google_storage_bucket.frontend.location
  description = "Location of the frontend storage bucket"
}
