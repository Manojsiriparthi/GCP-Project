# GCP Bank Application - Queue-Based Architecture

## Overview

A production-grade banking application built on Google Cloud Platform demonstrating queue-based async architecture (similar to AWS SQS pattern). The system handles user creation and payment transactions asynchronously through Pub/Sub messaging, with automatic notifications via email.

**Key Concept:** Frontend publishes messages to Pub/Sub → Cloud Functions process asynchronously → Database stores results → Notifications sent to users.

---

## Project Structure

```
GCP-Project/
│
├── README.md                           (This file - Project overview)
│
├── docs/                               (📚 Documentation)
│   ├── deploy-app.md                   (Deployment guide - automation & manual steps)
│   ├── code-overview.md                (Code-level explanation - all components)
│   └── troubleshooting.md              (Debugging scenarios & solutions)
│
├── frontend/                           (🎨 React Frontend)
│   └── src/
│       └── services/
│           └── pubsub.js               (257 lines)
│               ├── publishToPubSub()       - Publish messages to Pub/Sub
│               ├── createUser()            - Create single user
│               ├── createPayment()         - Create payment transaction
│               ├── batchCreateUsers()      - Create multiple users
│               ├── getQueueStatus()        - Check queue status
│               └── Error handling & retry logic
│
├── backend/                            (⚙️ Python Backend)
│   │
│   ├── processing-handler/             (Main Request Processor)
│   │   ├── main.py                     (458 lines)
│   │   │   ├── process_create_user()       - Handle user creation messages
│   │   │   ├── process_create_payment()    - Handle payment messages
│   │   │   ├── processing_handler()        - Main entry point (triggered by Pub/Sub)
│   │   │   ├── Idempotency logic
│   │   │   ├── Database connection pooling
│   │   │   └── Error handling & DLQ routing
│   │   │
│   │   └── requirements.txt             (Python dependencies)
│   │       └── google-cloud-sql-connector, google-cloud-pubsub, etc.
│   │
│   └── notification-handler/           (Notification Sender)
│       ├── main.py                     (291 lines)
│       │   ├── format_notification()       - Format email messages
│       │   ├── send_email()                - Send via email service
│       │   ├── notification_handler()      - Main entry point (triggered by Pub/Sub)
│       │   ├── Database query logic
│       │   └── Error handling with DLQ
│       │
│       └── requirements.txt             (Python dependencies)
│           └── google-cloud-sql-connector, sendgrid, etc.
│
├── terraform/                          (🏗️ Infrastructure as Code)
│   ├── provider.tf                     (GCP provider configuration)
│   ├── variables.tf                    (Input variables)
│   │
│   ├── pubsub.tf                       (Pub/Sub topics & subscriptions)
│   │   ├── request-queue topic
│   │   ├── request-queue-dlq (Dead Letter Queue)
│   │   ├── notification-queue topic
│   │   ├── notification-queue-dlq
│   │   └── send-email topic
│   │
│   ├── cloud_functions.tf              (Cloud Functions deployment)
│   │   ├── processing-handler function
│   │   │   ├─ Runtime: Python 3.11
│   │   │   ├─ Timeout: 540 seconds
│   │   │   ├─ Memory: 512 MB
│   │   │   └─ Triggers: Pub/Sub (request-queue)
│   │   │
│   │   ├── notification-handler function
│   │   │   ├─ Runtime: Python 3.11
│   │   │   ├─ Timeout: 300 seconds
│   │   │   ├─ Memory: 256 MB
│   │   │   └─ Triggers: Pub/Sub (notification-queue)
│   │   │
│   │   └── VPC Connector for secure Cloud SQL access
│   │
│   ├── cloud_sql.tf                    (Cloud SQL Database)
│   │   ├── PostgreSQL 15 instance
│   │   ├── users table schema
│   │   ├── payments table schema
│   │   ├── Database triggers (publish to Pub/Sub)
│   │   └── Private IP configuration
│   │
│   ├── iam.tf                          (IAM Roles & Permissions)
│   │   ├── Service account for processing-handler
│   │   │   └─ Roles: pubsub.subscriber, cloudsql.client, etc.
│   │   │
│   │   ├── Service account for notification-handler
│   │   │   └─ Roles: pubsub.subscriber, cloudsql.client, etc.
│   │   │
│   │   └── Least privilege access configuration
│   │
│   ├── secrets.tf                      (Secret Manager)
│   │   ├── Database password secret
│   │   ├── API keys & credentials
│   │   └── Service account secret management
│   │
│   ├── monitoring.tf                   (Cloud Monitoring & Alerting)
│   │   ├── Pub/Sub message rate metric
│   │   ├── Cloud Function latency metric
│   │   ├── Database connection pool metric
│   │   ├── Custom dashboard
│   │   └── Alert policies
│   │
│   └── terraform.tfvars                (Environment Variables)
│       ├── Project ID
│       ├── Region configuration
│       └── Resource naming
│
└── .gitignore                          (Git ignore patterns)
    └── Terraform state files, secrets, .env files

```

### 📂 Directory Breakdown

| Directory | Purpose | Key Files | Lines |
|-----------|---------|-----------|-------|
| `frontend/` | React.js web application | `pubsub.js` | 257 |
| `backend/processing-handler/` | Main request processor | `main.py` | 458 |
| `backend/notification-handler/` | Email notification sender | `main.py` | 291 |
| `terraform/` | Infrastructure as Code | 8 files | ~1200 |
| `docs/` | Documentation | 3 markdown files | ~2500 |

### 🔑 Key Files Summary

| File | Responsibility | Triggered By |
|------|-----------------|--------------|
| `frontend/pubsub.js` | Publishes user/payment messages to Pub/Sub | User interactions |
| `backend/processing-handler/main.py` | Processes messages, updates database | Pub/Sub push config |
| `backend/notification-handler/main.py` | Sends notification emails | Database triggers |
| `terraform/pubsub.tf` | Pub/Sub topics & subscriptions setup | Infrastructure deployment |
| `terraform/cloud_functions.tf` | Deploys Cloud Functions | Infrastructure deployment |
| `terraform/cloud_sql.tf` | Database & triggers setup | Infrastructure deployment |
| `terraform/iam.tf` | Service accounts & permissions | Infrastructure deployment |
| `terraform/monitoring.tf` | Dashboards & alerts | Infrastructure deployment |

**Total Production Code:** 1,006 lines (frontend + backend) | **Infrastructure:** ~1,200 lines (Terraform)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        FRONTEND (React)                         │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │  Create User │    │   Payment    │    │    Batch     │    │
│  │   (Pub/Sub)  │    │ Transaction  │    │  Operations  │    │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘    │
│         │                   │                    │            │
│         └───────────────────┼────────────────────┘            │
│                             │                                 │
│                   publishToPubSub()                           │
└─────────────────────────────┼─────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Google Cloud Pub/Sub (request-queue)   │
        │  - 7-day message retention              │
        │  - Auto-triggered push config           │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Processing Handler (Cloud Function)    │
        │  - Validates data                       │
        │  - Checks balances                      │
        │  - Inserts into Cloud SQL               │
        │  - Idempotency protection               │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │      Cloud SQL (PostgreSQL)             │
        │  - Users table                          │
        │  - Payments table                       │
        │  - Triggers publish to notification Q   │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Pub/Sub (notification-queue)           │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Notification Handler (Cloud Function)  │
        │  - Fetches user details                 │
        │  - Formats email                        │
        │  - Publishes to send-email topic        │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Email Dispatch Service                 │
        │  - Sends notification emails            │
        └─────────────────────────────────────────┘
```

---

## How It Works

### 1. User Creation Flow
```
Frontend: Call createUser("9876543210")
   ↓
Pub/Sub publishes: {type: "create_user", data: {phone: "9876543210", request_id: "user-123456"}}
   ↓
Processing Handler receives message
   ├─ Validates phone format
   ├─ Checks if request_id already exists (idempotency)
   └─ Inserts user into Cloud SQL
   ↓
Database trigger publishes: {user_id: 123, event: "user_created"}
   ↓
Notification Handler formats & sends welcome email
```

### 2. Payment Transaction Flow
```
Frontend: Call createPayment(fromUserId=1, toUserId=2, amount=50)
   ↓
Pub/Sub publishes: {type: "create_payment", data: {from_user_id: 1, to_user_id: 2, amount: 50}}
   ↓
Processing Handler receives message
   ├─ Validates users exist
   ├─ Checks sender has sufficient balance
   ├─ Deducts from sender, adds to recipient
   └─ Inserts transaction record
   ↓
Database triggers publish 2 notifications
   ├─ {user_id: 1, event: "payment_sent"}
   └─ {user_id: 2, event: "payment_received"}
   ↓
Notification Handler sends emails to both users
```

### 3. Batch Operations
```
Frontend: Call batchCreateUsers(50)
   ↓
Loop 50 times with 100ms delay between requests
   ├─ Each publishes to request-queue
   ├─ Processing Handler processes independently
   └─ All 50 users created asynchronously
   ↓
Frontend: Call batchCreatePayments([...])
   ↓
Similar async batch processing for payments
```

### 4. Error Handling
```
If Processing Handler fails:
   ├─ Automatic retry with exponential backoff
   │  └─ Wait: 10s, 20s, 40s, 80s, 160s (5 attempts)
   │
   └─ After 5 failures → Message sent to Dead Letter Queue (request-queue-dlq)
                        └─ Stored for manual investigation

Same pattern for Notification Handler → notification-queue-dlq
```

---

## Learning Outcomes

### 1. **Pub/Sub (Messaging)**
- Topics: Named resources where messages are published
- Subscriptions: Consumers receive messages from topics
- Push vs Pull: Configured for push (auto-trigger Cloud Functions)
- Message retention: Configure how long to keep unprocessed messages
- Dead Letter Queues: Handle messages that fail after retries

### 2. **Cloud Functions (Serverless Computing)**
- Event-driven: Triggered by Pub/Sub messages (not HTTP polling)
- Stateless: Each invocation is independent
- Scaling: Automatic based on message rate
- Timeouts: Processing Handler = 540s, Notification Handler = 300s
- VPC Connectors: Secure access to private Cloud SQL instances

### 3. **Cloud SQL (Database)**
- Managed PostgreSQL: No infrastructure management
- Private IP: Accessible only via VPC connectors
- Triggers: Database-level functions that publish to Pub/Sub
- Connection Pooling: Reuse connections across function invocations
- Transactions: ACID compliance for data consistency

### 4. **Cloud Logging (Observability)**
- Structured logs: JSON format with metadata
- Log queries: Search and filter with LogQL
- Error tracking: Exceptions with full stack traces
- Latency monitoring: Track function execution time

### 5. **Cloud Monitoring (Alerting)**
- Metrics: Track Pub/Sub message rates, function latency, database connections
- Dashboards: Visualize system health in real-time
- Alerting: Send notifications when metrics exceed thresholds
- SLOs: Define and track service level objectives

### 6. **IAM (Security)**
- Service Accounts: Separate identity for each service
- Roles: Grant minimal required permissions (Least Privilege)
- Example: Processing Handler only has: "pubsub.subscriber", "cloudsql.client", "secretmanager.secretAccessor"

### 7. **Secret Manager (Credentials)**
- Secure storage: Never hardcode database passwords
- Versioning: Track secret changes
- Audit logs: See who accessed secrets
- Rotation: Change secrets without redeploying code

---

**Total Production Code:** 1,006 lines across frontend, backend, and infrastructure.
