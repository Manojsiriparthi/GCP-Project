# Cloud SQL Instance
resource "google_sql_database_instance" "bank_app" {
  name             = var.db_instance_name
  database_version = "POSTGRES_${var.db_version}"
  region           = local.region
  deletion_protection = var.environment == "production" ? true : false

  settings {
    tier              = var.db_tier
    availability_type = var.environment == "production" ? "REGIONAL" : "ZONAL"
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = var.environment == "production" ? 30 : 7
        retention_unit   = "COUNT"
      }
    }

    database_flags {
      name  = "cloudsql_iam_authentication"
      value = "on"
    }

    ip_configuration {
      require_ssl = true
      ipv4_enabled = true
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
    }

    user_labels = var.labels
  }

  depends_on = [google_project_service.required_apis]
}

# Cloud SQL Database
resource "google_sql_database" "bank_app" {
  name            = var.db_name
  instance        = google_sql_database_instance.bank_app.name
  charset         = "UTF8"
  collation       = "en_US.UTF8"
  deletion_policy = "ABANDON"

  depends_on = [google_sql_database_instance.bank_app]
}

# Cloud SQL User (password will be generated and stored in Secret Manager)
resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "google_sql_user" "bank_app" {
  name     = var.db_user
  instance = google_sql_database_instance.bank_app.name
  password = var.db_password != "" ? var.db_password : random_password.db_password.result

  depends_on = [google_sql_database_instance.bank_app]
}

# Store DB password in Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "bank-app-db-password"
  labels    = var.labels

  replication {}

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = google_sql_user.bank_app.password

  depends_on = [google_secret_manager_secret.db_password]
}

# Store DB connection string in Secret Manager
resource "google_secret_manager_secret" "db_connection_string" {
  secret_id = "bank-app-db-connection-string"
  labels    = var.labels

  replication {}

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_connection_string" {
  secret = google_secret_manager_secret.db_connection_string.id
  secret_data = "postgresql://${var.db_user}:${google_sql_user.bank_app.password}@${google_sql_database_instance.bank_app.private_ip_address}:5432/${var.db_name}"

  depends_on = [google_secret_manager_secret.db_connection_string]
}

# Outputs
output "cloud_sql_instance_name" {
  description = "Cloud SQL Instance Name"
  value       = google_sql_database_instance.bank_app.name
}

output "cloud_sql_instance_connection_name" {
  description = "Cloud SQL Instance Connection Name"
  value       = google_sql_database_instance.bank_app.connection_name
}

output "cloud_sql_instance_private_ip" {
  description = "Cloud SQL Instance Private IP"
  value       = google_sql_database_instance.bank_app.private_ip_address
}

output "cloud_sql_instance_public_ip" {
  description = "Cloud SQL Instance Public IP"
  value       = google_sql_database_instance.bank_app.public_ip_address
}

output "db_password_secret_id" {
  description = "Secret Manager Secret ID for DB Password"
  value       = google_secret_manager_secret.db_password.secret_id
}

output "db_connection_string_secret_id" {
  description = "Secret Manager Secret ID for DB Connection String"
  value       = google_secret_manager_secret.db_connection_string.secret_id
}
