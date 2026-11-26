terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.0"
}

locals {
  project_id = var.gcp_project_id != "" ? var.gcp_project_id : var.project_id
  region     = var.gcp_region != "us-central1" ? var.gcp_region : var.region
}

provider "google" {
  project = local.project_id
  region  = local.region
  
  # Request full cloud platform access for all APIs
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "sqladmin.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "pubsub.googleapis.com",
    "cloudlogging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "storage-api.googleapis.com",
    "vpcaccess.googleapis.com",
    "compute.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}
