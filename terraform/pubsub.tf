# Pub/Sub Topics & Subscriptions
# Queue-based architecture pattern

# Main request queue topic
resource "google_pubsub_topic" "request_queue" {
  name              = "request-queue"
  message_retention_duration = "604800s"  # 7 days

  labels = {
    environment = "production"
    purpose     = "request-processing"
  }
}

# Dead Letter Queue for failed requests
resource "google_pubsub_topic" "request_queue_dlq" {
  name = "request-queue-dlq"

  labels = {
    environment = "production"
    purpose     = "dead-letter-queue"
  }
}

# Notification queue topic
resource "google_pubsub_topic" "notification_queue" {
  name              = "notification-queue"
  message_retention_duration = "604800s"  # 7 days

  labels = {
    environment = "production"
    purpose     = "notifications"
  }
}

# Dead Letter Queue for failed notifications
resource "google_pubsub_topic" "notification_queue_dlq" {
  name = "notification-queue-dlq"

  labels = {
    environment = "production"
    purpose     = "dead-letter-queue"
  }
}

# Email dispatch topic
resource "google_pubsub_topic" "send_email" {
  name = "send-email"

  labels = {
    environment = "production"
    purpose     = "email-dispatch"
  }
}

# =============================================================
# SUBSCRIPTIONS
# =============================================================

# Processing Handler subscription
resource "google_pubsub_subscription" "request_queue_subscription" {
  name  = "request-queue-subscription"
  topic = google_pubsub_topic.request_queue.name

  # Push configuration to Cloud Function
  push_config {
    push_endpoint = google_cloudfunctions_function.processing_handler.https_trigger_url
  }

  # Dead Letter Policy
  dead_letter_policy {
    dead_letter_topic       = google_pubsub_topic.request_queue_dlq.id
    max_delivery_attempts   = 5
  }

  # Retry policy
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"  # 10 minutes
  }

  ack_deadline_seconds    = 60
  message_retention_duration = "604800s"  # 7 days

  labels = {
    environment = "production"
    function    = "processing-handler"
  }

  depends_on = [
    google_cloudfunctions_function.processing_handler
  ]
}

# Notification Handler subscription
resource "google_pubsub_subscription" "notification_queue_subscription" {
  name  = "notification-queue-subscription"
  topic = google_pubsub_topic.notification_queue.name

  # Push configuration to Cloud Function
  push_config {
    push_endpoint = google_cloudfunctions_function.notification_handler.https_trigger_url
  }

  # Dead Letter Policy
  dead_letter_policy {
    dead_letter_topic       = google_pubsub_topic.notification_queue_dlq.id
    max_delivery_attempts   = 5
  }

  # Retry policy
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  ack_deadline_seconds    = 60
  message_retention_duration = "604800s"

  labels = {
    environment = "production"
    function    = "notification-handler"
  }

  depends_on = [
    google_cloudfunctions_function.notification_handler
  ]
}

# DLQ subscriptions (for monitoring/manual processing)
resource "google_pubsub_subscription" "request_queue_dlq_subscription" {
  name  = "request-queue-dlq-subscription"
  topic = google_pubsub_topic.request_queue_dlq.name

  ack_deadline_seconds    = 60
  message_retention_duration = "2592000s"  # 30 days

  labels = {
    environment = "production"
    type        = "dlq"
  }
}

resource "google_pubsub_subscription" "notification_queue_dlq_subscription" {
  name  = "notification-queue-dlq-subscription"
  topic = google_pubsub_topic.notification_queue_dlq.name

  ack_deadline_seconds    = 60
  message_retention_duration = "2592000s"  # 30 days

  labels = {
    environment = "production"
    type        = "dlq"
  }
}

# =============================================================
# TOPIC EXPORTS (for reference)
# =============================================================

output "request_queue_topic_name" {
  value       = google_pubsub_topic.request_queue.name
  description = "Name of the request queue topic"
}

output "notification_queue_topic_name" {
  value       = google_pubsub_topic.notification_queue.name
  description = "Name of the notification queue topic"
}

output "request_queue_subscription_name" {
  value       = google_pubsub_subscription.request_queue_subscription.name
  description = "Name of the request queue subscription"
}

output "notification_queue_subscription_name" {
  value       = google_pubsub_subscription.notification_queue_subscription.name
  description = "Name of the notification queue subscription"
}
