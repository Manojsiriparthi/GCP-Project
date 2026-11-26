# Cloud Monitoring Notification Channel (Email)
resource "google_monitoring_notification_channel" "email" {
  display_name = "Bank App Admin Email"
  type         = "email"
  labels = {
    email_address = "admin@example.com"
  }
  enabled = true
}

# Alert Policy - High Error Rate in Processing Handler
# Commented out: Metrics take up to 10 minutes to become available after function deployment
# Uncomment after metrics are ready
# resource "google_monitoring_alert_policy" "api_handler_errors" {
#   display_name = "Processing Handler - High Error Rate"
#   combiner     = "OR"
#   enabled      = true
#
#   conditions {
#     display_name = "Error Rate > 5%"
#
#     condition_threshold {
#       filter          = "resource.type=\"cloud_function\" resource.labels.function_name=\"${google_cloudfunctions_function.processing_handler.name}\" metric.type=\"cloudfunctions.googleapis.com/execution_count\" metric.labels.status=\"error\""
#       duration        = "60s"
#       comparison      = "COMPARISON_GT"
#       threshold_value = 5
#
#       aggregations {
#         alignment_period     = "60s"
#         per_series_aligner   = "ALIGN_RATE"
#         cross_series_reducer = "REDUCE_SUM"
#       }
#     }
#   }
#
#   notification_channels = [google_monitoring_notification_channel.email.id]
#   alert_strategy {
#     auto_close = "1800s"
#   }
# }

# Alert Policy - High Pub/Sub Message Lag
resource "google_monitoring_alert_policy" "pubsub_lag" {
  display_name = "Pub/Sub - High Message Lag"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Message Lag > 1 minute"

    condition_threshold {
      filter          = "resource.type=\"pubsub_subscription\" metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 1000

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  alert_strategy {
    auto_close = "1800s"
  }
}

# Alert Policy - Cloud SQL CPU Usage
resource "google_monitoring_alert_policy" "cloudsql_cpu" {
  display_name = "Cloud SQL - High CPU Usage"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "CPU Usage > 80%"

    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  alert_strategy {
    auto_close = "1800s"
  }
}

# Dashboard for Bank App Metrics
resource "google_monitoring_dashboard" "bank_app" {
  dashboard_json = jsonencode({
    displayName = "GCP Bank App Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Processing Handler - Requests"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter          = "resource.type=\"cloud_function\" resource.labels.function_name=\"${google_cloudfunctions_function.processing_handler.name}\" metric.type=\"cloudfunctions.googleapis.com/execution_count\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Processing Handler - Errors"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter          = "resource.type=\"cloud_function\" resource.labels.function_name=\"${google_cloudfunctions_function.processing_handler.name}\" metric.type=\"cloudfunctions.googleapis.com/execution_count\" metric.labels.status=\"error\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Pub/Sub - Undelivered Messages"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter          = "resource.type=\"pubsub_subscription\" metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\""
                    aggregation = {
                      alignmentPeriod   = "60s"
                      perSeriesAligner  = "ALIGN_MAX"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Cloud SQL - CPU Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter          = "resource.type=\"cloudsql_database\" metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
                    aggregation = {
                      alignmentPeriod   = "60s"
                      perSeriesAligner  = "ALIGN_MEAN"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}

# Log-based Metric - Track Transaction Creation
# NOTE: Requires additional logging.admin scope - commented out for compute instance compatibility
# Uncomment when using proper authentication (gcloud auth application-default login)
# resource "google_logging_metric" "transaction_creation" {
#   name   = "transaction_creation"
#   filter = "resource.type=\"cloud_function\" jsonPayload.event=\"PAYMENT_CREATED\""
#
#   metric_descriptor {
#     metric_kind = "DELTA"
#     value_type  = "INT64"
#   }
# }

# Log-based Metric - Track User Creation
# NOTE: Requires additional logging.admin scope - commented out for compute instance compatibility
# Uncomment when using proper authentication (gcloud auth application-default login)
# resource "google_logging_metric" "user_creation" {
#   name   = "user_creation"
#   filter = "resource.type=\"cloud_function\" jsonPayload.event=\"USER_CREATED\""
#
#   metric_descriptor {
#     metric_kind = "DELTA"
#     value_type  = "INT64"
#   }
# }

# Outputs
output "monitoring_dashboard_id" {
  description = "Cloud Monitoring Dashboard ID"
  value       = google_monitoring_dashboard.bank_app.id
}

output "alert_policies" {
  description = "Alert Policies Created"
  value = {
    api_handler_errors = google_monitoring_alert_policy.api_handler_errors.id
    pubsub_lag         = google_monitoring_alert_policy.pubsub_lag.id
    cloudsql_cpu       = google_monitoring_alert_policy.cloudsql_cpu.id
  }
}
