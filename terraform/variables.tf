variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
  validation {
    condition     = length(var.gcp_project_id) > 0
    error_message = "GCP Project ID must not be empty."
  }
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

# Cloud SQL Configuration
variable "db_instance_name" {
  description = "Cloud SQL instance name"
  type        = string
  default     = "bank-app-db"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "bank_app"
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 12
    error_message = "Database password must be at least 12 characters."
  }
}

variable "db_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "db_tier" {
  description = "Machine tier for Cloud SQL"
  type        = string
  default     = "db-f1-micro"
}

# Pub/Sub Configuration
variable "pubsub_topics" {
  description = "Pub/Sub topics to create"
  type = map(object({
    description        = string
    retention_duration = string
  }))
  default = {
    "user-notifications" = {
      description        = "User notification events"
      retention_duration = "86400s"
    }
    "send-email" = {
      description        = "Email sending tasks"
      retention_duration = "86400s"
    }
  }
}

# Cloud Functions Configuration
variable "function_timeout" {
  description = "Cloud Function timeout in seconds"
  type        = number
  default     = 60
}

variable "function_memory" {
  description = "Cloud Function memory in MB"
  type        = number
  default     = 256
}

variable "runtime" {
  description = "Cloud Function runtime"
  type        = string
  default     = "python39"
}

# IAM Configuration
variable "enable_least_privilege" {
  description = "Enable least privilege IAM roles"
  type        = bool
  default     = true
}

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    "app"         = "gcp-bank-app"
    "managed_by"  = "terraform"
    "environment" = "production"
  }
}
