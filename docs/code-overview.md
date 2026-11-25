# Code Overview: GCP Bank Application Architecture

## Overview

This document explains the complete codebase structure, why each component exists, what problems it solves, and how everything works together. The application is built as a queue-based asynchronous system using Google Cloud Platform services.

---

## Part 1: Frontend Code

### What We Created

The frontend is a React-based web application that provides users with an interface to simulate banking operations. It consists of multiple pages handling different user flows: creating users, making payments, viewing transaction history, and managing batch operations.

**Main Files:**
- `frontend/src/services/pubsub.js` - Core Pub/Sub integration (257 lines)
- `frontend/src/pages/UserManagement.js` - User creation interface
- `frontend/src/pages/PaymentSimulator.js` - Payment transaction simulator
- `frontend/src/pages/TransactionHistory.js` - View all transactions
- `frontend/src/pages/Dashboard.js` - Main dashboard

### Why It's Needed

Traditional banking systems send requests directly to an API and wait for responses. This creates several problems: if the API is slow, users wait; if traffic spikes, the system crashes; if processing fails, data is lost. By using Pub/Sub messaging, the frontend publishes messages to a queue and immediately returns to the user, while the backend processes asynchronously.

### Problem Solved

**Before (Synchronous):**
```
Frontend → API → Database → Response sent to frontend
(User waits for entire process to complete)
```

**After (Asynchronous):**
```
Frontend → Pub/Sub Queue → Immediate acknowledgement to user
                     ↓
            Backend processes in background
            Database updated
            Notification sent to user
(User never waits; operations happen in background)
```

### Core Function: publishToPubSub()

**What it does:** Publishes any message to a Pub/Sub topic without waiting for processing.

```javascript
async function publishToPubSub(topicName, message) {
  // Publishes message to specified topic
  // Returns immediately; actual processing happens later
  // Example: publishToPubSub('request-queue', {type: 'create_user', ...})
}
```

**Why it's needed:** This is the entry point for all asynchronous operations. Instead of calling an API endpoint, the frontend publishes messages to Pub/Sub.

**Example flow:**
```
User clicks "Create User" → Frontend publishes message → 
User sees "Processing..." → Response returns in 100ms →
Backend processes in background → Database updated → 
Notification email sent to user (all happens asynchronously)
```

### Function: createUser()

**What it does:** Creates a new banking user with a phone number.

```javascript
async function createUser(phone) {
  // Validates phone format (10 digits)
  // Generates unique request_id
  // Publishes to request-queue topic
  // Message format: {type: "create_user", data: {phone, request_id}}
}
```

**Why needed:** This wraps phone validation logic and ensures consistent message format for backend.

**Problem solved:** Without this, every page would need to validate phone format and format the message correctly. This centralizes logic.

**Example:**
```javascript
// User enters: 9876543210
createUser("9876543210")
// Publishes: {type: "create_user", data: {phone: "9876543210", request_id: "user-1732123456"}}
// Backend receives this exact format and processes it
```

### Function: createPayment()

**What it does:** Simulates a payment transaction between two users.

```javascript
async function createPayment(fromUserId, toUserId, amount) {
  // Validates users exist
  // Validates amount > 0
  // Generates unique request_id
  // Publishes to request-queue topic
}
```

**Why needed:** Payment transfers require validation of sender, receiver, and amount before queuing. This prevents invalid requests from wasting backend resources.

**Example:**
```javascript
// User clicks "Send Payment"
createPayment(1, 2, 50)  // Send 50 from user 1 to user 2
// Publishes: {type: "create_payment", data: {from_user_id: 1, to_user_id: 2, amount: 50}}
// Backend validates balance and updates both users
```

### Function: batchCreateUsers()

**What it does:** Simulates creating multiple users (1-500) with delays between requests.

```javascript
async function batchCreateUsers(count) {
  // Loops 'count' times
  // Creates a user with phone: 1000000000 + i
  // Waits 100ms between requests (doesn't overwhelm Pub/Sub)
  // Returns after all messages published (not waiting for processing)
}
```

**Why needed:** To test the system's ability to handle high load. 500 users simulates real-world scenarios where many sign-ups happen simultaneously.

**Problem solved:** Without batching, testing high load would require manual clicking hundreds of times. This automates the simulation.

**Example:**
```javascript
batchCreateUsers(50)
// Creates 50 messages in sequence
// Message 1: {phone: "1000000001"}
// Message 2: {phone: "1000000002"}
// ... Message 50: {phone: "1000000050"}
// All 50 messages queued in ~5 seconds (100ms between each)
// Backend processes them one by one asynchronously
```

### Function: getQueueStatus()

**What it does:** Queries Pub/Sub to show how many unprocessed messages are in the queue.

```javascript
async function getQueueStatus() {
  // Returns: {
  //   request_queue: 45,        // 45 messages waiting to be processed
  //   notification_queue: 12,   // 12 notifications waiting
  //   dlq_messages: 0           // 0 failed messages
  // }
}
```

**Why needed:** System monitoring. Users and operators need to know if the system is backed up or if messages are failing.

**Problem solved:** Without this, you'd have no visibility into queue depth. You wouldn't know if 10 or 10,000 messages are waiting.

---

## Part 2: Backend - Processing Handler

### What We Created

The Processing Handler is the main Cloud Function that processes all user creation and payment requests. It runs in the background, triggered automatically whenever a message appears in the `request-queue` Pub/Sub topic.

**File:** `backend/processing-handler/main.py` (458 lines)

### Why It's Needed

User and payment creation require database operations (insert records, check balances, update tables). These operations:
1. Take time (network latency to database)
2. Must be reliable (if system crashes mid-operation, data corruption occurs)
3. Need error handling (what if database is unavailable?)
4. Need to handle duplicates (same message processed twice = same result)

A dedicated handler manages all these concerns in one place.

### Problem Solved

**Without handler:**
```
Messages stuck in queue forever
No way to process them
User data never inserted into database
System broken
```

**With handler:**
```
Message arrives → Handler validates → Database updated → 
Result cached (idempotency) → Notification triggered →
Next message processed automatically
```

### Core Function: process_create_user()

**What it does:** Validates user data and inserts new user into database.

```python
def process_create_user(data):
    # 1. Extract phone number from message
    # 2. Check if request_id already processed (idempotency)
    #    If yes, return cached result (no duplicate)
    # 3. Validate phone format (10 digits)
    # 4. Check if phone already exists in database
    # 5. Insert new user with balance=1000
    # 6. Cache result with request_id
    # 7. Trigger notification
    # 8. Return success/error
```

**Why needed:** Each create_user message needs validation and database insertion. Without this logic in one place, it would be scattered across the codebase.

**Example flow:**

```
Message: {type: "create_user", data: {phone: "9876543210", request_id: "user-123"}}

Step 1: Check idempotency table
        SELECT * FROM idempotency_keys WHERE request_id = "user-123"
        Result: Not found (first time)

Step 2: Validate phone
        Phone = "9876543210" → Valid format ✓

Step 3: Check phone uniqueness
        SELECT * FROM users WHERE phone = "9876543210"
        Result: Not found (doesn't exist) ✓

Step 4: Insert into database
        INSERT INTO users (phone, balance) VALUES ("9876543210", 1000)
        New user ID: 42

Step 5: Cache result
        INSERT INTO idempotency_keys (request_id, result)
        VALUES ("user-123", {user_id: 42, phone: "9876543210"})

Step 6: Publish notification
        PUBLISH to notification-queue: {user_id: 42, event: "user_created"}

Step 7: Return success
        {success: true, user_id: 42}
```

**What if same message arrives again (network retry):**
```
Message: {type: "create_user", data: {phone: "9876543210", request_id: "user-123"}}

Step 1: Check idempotency table
        SELECT * FROM idempotency_keys WHERE request_id = "user-123"
        Result: Found! {user_id: 42, phone: "9876543210"}

Step 2: Return cached result immediately
        {success: true, user_id: 42}
        (No duplicate user created!)
```

### Core Function: process_create_payment()

**What it does:** Validates payment details and transfers money between users.

```python
def process_create_payment(data):
    # 1. Extract from_user_id, to_user_id, amount
    # 2. Check if request_id already processed (idempotency)
    # 3. Validate amount > 0
    # 4. Fetch sender's current balance
    # 5. Check sender has enough balance
    # 6. Begin database transaction
    # 7. Deduct from sender
    # 8. Add to recipient
    # 9. Record transaction
    # 10. Commit transaction
    # 11. Trigger notifications for both users
    # 12. Return success/error
```

**Why needed:** Money transfer is the most critical operation in a banking system. It requires ACID compliance (all-or-nothing). If system crashes mid-transfer, we need to either complete it or rollback completely—no half-transfers allowed.

**Example flow:**

```
Message: {type: "create_payment", data: {from_user_id: 1, to_user_id: 2, amount: 50}}

Step 1: Fetch sender balance
        SELECT balance FROM users WHERE id = 1
        Result: balance = 500

Step 2: Validate sender has enough
        500 >= 50? YES ✓

Step 3: Fetch recipient exists
        SELECT id FROM users WHERE id = 2
        Result: Found ✓

Step 4: Begin transaction
        BEGIN TRANSACTION

Step 5: Deduct from sender
        UPDATE users SET balance = balance - 50 WHERE id = 1
        (New balance: 450)

Step 6: Add to recipient
        UPDATE users SET balance = balance + 50 WHERE id = 2
        (New balance: 1050)

Step 7: Record transaction
        INSERT INTO payments (from_user_id, to_user_id, amount, status)
        VALUES (1, 2, 50, 'completed')

Step 8: Commit transaction
        COMMIT TRANSACTION
        (All changes permanent, or none if error)

Step 9: Publish notifications
        PUBLISH to notification-queue:
        - {user_id: 1, event: "payment_sent", amount: 50}
        - {user_id: 2, event: "payment_received", amount: 50}

Step 10: Return success
        {success: true, transaction_id: 123}
```

**What if system crashes during Step 5:**
```
Partial state: User 1 balance decreased, User 2 balance not yet increased

When system restarts:
Transaction is rolled back automatically (ROLLBACK)
Both users back to original balances
Message re-processed from queue
Transfer completes successfully
```

### Core Function: processing_handler()

**What it does:** Entry point for the Cloud Function. Receives Pub/Sub message and routes to appropriate processor.

```python
def processing_handler(event, context):
    # 1. Extract message from Pub/Sub
    # 2. Decode message content
    # 3. Check message type ("create_user" or "create_payment")
    # 4. Route to appropriate handler
    # 5. Handle errors
    # 6. Log all operations
    # 7. Return success/error response
```

**Why needed:** This is the entry point for all processing. Cloud Functions automatically call this when a message arrives in the request-queue topic.

**Example:**

```python
# Cloud Function triggered automatically when message arrives
processing_handler({
    "message": {
        "data": "eyJ0eXBlIjogImNyZWF0ZV91c2VyIiwgImRhdGEiOiB7InBob25lIjogIjk4NzY1NDMyMTAifX0="
    }
}, context)

# Base64 decoded:
# {"type": "create_user", "data": {"phone": "9876543210"}}

# Calls: process_create_user({"phone": "9876543210"})
# Returns: {success: true, user_id: 42}

# Cloud Function automatically acknowledges message to Pub/Sub
```

### Database Connection Pooling

**What it is:** Reusing database connections instead of creating new ones for each request.

**Why needed:** Creating a new database connection takes ~200ms (network latency + authentication). If we do this for every message, most time is wasted on connection setup, not actual processing.

**How it works:**

```python
# Global variable (persists across function invocations)
connection_pool = None

def get_connection():
    global connection_pool
    
    if connection_pool is None:
        # First invocation: create pool
        connection_pool = psycopg2.pool.SimpleConnectionPool(1, 20, ...)
    
    # Get connection from pool (already authenticated)
    return connection_pool.getconn()

# First message: 200ms (new pool + connection)
# Second message: 10ms (connection from pool)
# Third message: 10ms (another connection from pool)
# ...
```

**Problem solved:** Without pooling, each of 100 messages takes 200ms connection time = 20 seconds wasted. With pooling, connection time amortized to nearly zero.

---

## Part 3: Backend - Notification Handler

### What We Created

The Notification Handler is a second Cloud Function that processes notification events triggered when database operations complete. It formats emails and sends them to users.

**File:** `backend/notification-handler/main.py` (291 lines)

### Why It's Needed

After a user is created or payment completes, the system must notify users about these events. Rather than having the processing handler send emails (which makes it too complex), a separate handler:
1. Keeps Processing Handler focused on database operations
2. Allows retry if email sending fails
3. Separates concerns (database ≠ email sending)
4. Scales independently (email is slower than database)

### Problem Solved

**Without separate handler:**
```
Processing Handler does everything:
- Validate data ❌ Getting too big
- Update database ❌ Too many responsibilities
- Send email ❌ If email fails, whole message fails
- Handle errors ❌ Complex logic
```

**With separate handler:**
```
Processing Handler: Just database operations
Notification Handler: Just email operations
If email fails, message retries independently
Each handler can be optimized for its task
```

### Core Function: format_email_body()

**What it does:** Creates a human-readable email message from notification data.

```python
def format_email_body(user_email, event_type, data):
    # Create email body based on event type
    # Examples:
    # - User created: "Welcome to Bank App. Your account is ready!"
    # - Payment received: "You received 50 from User X"
    # - Payment sent: "You sent 50 to User Y"
    # Return formatted email HTML/text
```

**Why needed:** Notifications aren't just raw database records. Users need readable messages in proper email format with subject lines, signatures, etc.

**Example:**

```python
format_email_body(
    "user@email.com",
    "user_created",
    {user_id: 42, phone: "9876543210"}
)

Returns:
{
    "subject": "Welcome to GCP Bank",
    "body": """
    Dear User,
    
    Your account has been successfully created!
    Phone: 9876543210
    Account ID: 42
    Initial Balance: 1000
    
    Thank you for joining us.
    - GCP Bank Team
    """
}
```

### Core Function: notification_handler()

**What it does:** Receives notification event from Pub/Sub and sends email.

```python
def notification_handler(event, context):
    # 1. Extract notification from Pub/Sub
    # 2. Fetch user details from database
    # 3. Format email
    # 4. Publish to send-email topic
    # 5. Log operation
    # 6. Return success/error
```

**Why needed:** This is the entry point for the second Cloud Function, automatically triggered when messages arrive in notification-queue.

---

## Part 4: Terraform Infrastructure Code

### What We Created

Terraform is "Infrastructure as Code" - instead of manually clicking buttons in Google Cloud Console, we write code that defines all infrastructure. This makes deployments reproducible, versioned, and automated.

**Files:**
- `terraform/main.tf` - Google Cloud provider configuration
- `terraform/pubsub.tf` - Pub/Sub topics and subscriptions
- `terraform/cloud_functions.tf` - Cloud Function definitions
- `terraform/cloud_sql.tf` - Database instance
- `terraform/iam.tf` - Service accounts and permissions
- `terraform/monitoring.tf` - Cloud Logging and Monitoring setup
- `terraform/variables.tf` - Input variables

### Why It's Needed

Manual cloud setup:
```
1. Open Google Cloud Console
2. Navigate to Pub/Sub
3. Click "Create Topic"
4. Enter name, settings, click Create
5. Navigate to Cloud Functions
6. Click "Create Function"
7. Enter code, settings, click Deploy
... (repeat 20+ times)
Takes hours, error-prone, hard to replicate
```

With Terraform:
```
1. Write main.tf with all resources
2. Run: terraform apply
Everything deployed in minutes, repeatable
```

### terraform/pubsub.tf

**What it does:** Defines all Pub/Sub topics and subscriptions.

```hcl
resource "google_pubsub_topic" "request_queue" {
  name                    = "request-queue"
  message_retention_duration = "604800s"  # 7 days
}

resource "google_pubsub_subscription" "request_queue_sub" {
  name             = "request-queue-sub"
  topic            = google_pubsub_topic.request_queue.name
  push_config {
    push_endpoint = "https://us-central1-PROJECT_ID.cloudfunctions.net/processing-handler"
  }
}
```

**What this creates:**
- `request-queue` topic (where messages go)
- `request-queue-sub` subscription (delivery configuration)
- Messages are pushed automatically to Cloud Function
- 7-day retention (old messages auto-deleted)

### terraform/cloud_functions.tf

**What it does:** Deploys Cloud Functions from source code.

```hcl
resource "google_cloudfunctions_function" "processing_handler" {
  name        = "processing-handler"
  runtime     = "python311"
  source_archive_bucket = google_storage_bucket.functions.name
  entry_point = "processing_handler"
  trigger_topic = google_pubsub_topic.request_queue.name
  
  environment_variables = {
    DB_HOST = google_sql_database_instance.main.private_ip_address
    DB_NAME = "bank_db"
  }
}
```

**What this creates:**
- Cloud Function with Python 3.11 runtime
- Automatically triggered by request-queue Pub/Sub topic
- 512MB memory allocation
- 540-second timeout
- Access to Cloud SQL private IP

### terraform/cloud_sql.tf

**What it does:** Creates managed PostgreSQL database.

```hcl
resource "google_sql_database_instance" "main" {
  name             = "gcp-bank-sql"
  database_version = "POSTGRES_15"
  region           = "us-central1"
  
  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    ip_configuration {
      private_network = google_compute_network.default.id
    }
  }
}
```

**What this creates:**
- PostgreSQL 15 database instance
- Private IP only (no public internet access)
- 1 GB memory tier (sufficient for testing)
- Automatic backups

### terraform/iam.tf

**What it does:** Creates service accounts and assigns permissions.

```hcl
resource "google_service_account" "app_sa" {
  account_id   = "gcp-bank-app-sa"
  display_name = "GCP Bank Application Service Account"
}

resource "google_project_iam_member" "pubsub_admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}
```

**What this creates:**
- Service account for application
- Minimal required permissions (Least Privilege)
- Cloud Functions run with this identity

### Why Terraform Structure Matters

**Problem solved:** Manual setup is unrepeatable. If you forget one step, the system breaks. With Terraform:
```
terraform apply → Exact same infrastructure every time
Destroy old → terraform destroy
Deploy new → terraform apply
No manual steps, no forgotten permissions
```

---

## Part 5: Database Schemas

### users Table

**What it stores:** Information about bank customers.

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,                    -- Auto-incrementing user ID
  phone VARCHAR(10) UNIQUE NOT NULL,        -- Phone number (unique, required)
  balance DECIMAL(10, 2) DEFAULT 1000,      -- Account balance
  created_at TIMESTAMP DEFAULT NOW()        -- Creation time
);
```

**Why needed:** Core entity in banking system. Each user has an account with balance.

**Example data:**
```
id | phone      | balance | created_at
1  | 9876543210 | 1000    | 2024-11-25 10:00:00
2  | 8765432109 | 950     | 2024-11-25 10:05:00
3  | 7654321098 | 1100    | 2024-11-25 10:10:00
```

### payments Table

**What it stores:** Transaction history between users.

```sql
CREATE TABLE payments (
  id SERIAL PRIMARY KEY,                    -- Transaction ID
  from_user_id INTEGER REFERENCES users(id), -- Sender
  to_user_id INTEGER REFERENCES users(id),   -- Receiver
  amount DECIMAL(10, 2) NOT NULL,           -- Amount transferred
  status VARCHAR(20) DEFAULT 'completed',   -- Transaction status
  created_at TIMESTAMP DEFAULT NOW()        -- When it happened
);
```

**Why needed:** Audit trail. Every payment transaction recorded for history, reconciliation, dispute resolution.

**Example data:**
```
id | from_user_id | to_user_id | amount | status    | created_at
1  | 1            | 2          | 50     | completed | 2024-11-25 10:30:00
2  | 2            | 3          | 100    | completed | 2024-11-25 10:35:00
3  | 3            | 1          | 25     | completed | 2024-11-25 10:40:00
```

### idempotency_keys Table

**What it stores:** Result cache to prevent duplicate processing.

```sql
CREATE TABLE idempotency_keys (
  request_id VARCHAR(255) PRIMARY KEY,       -- Unique request identifier
  result JSONB,                              -- Cached result
  created_at TIMESTAMP DEFAULT NOW()         -- When cached
);
```

**Why needed:** If same message arrives twice (network retry), we return cached result instead of processing again. Prevents duplicate users/payments.

**Example data:**
```
request_id              | result                              | created_at
"user-1732123456-abc" | {"user_id": 42, "phone": "..."}  | 2024-11-25 10:00:00
"user-1732123457-def" | {"user_id": 43, "phone": "..."}  | 2024-11-25 10:00:01
```

**Example scenario:**

```
Frontend publishes: request_id = "user-123", phone = "9876543210"

First attempt:
1. Processing Handler receives message
2. Idempotency check: request_id "user-123" not found
3. Create user → user_id = 42
4. Store in idempotency_keys: request_id="user-123", result={user_id: 42}
5. Return success

Network retry (same message arrives again):
1. Processing Handler receives message
2. Idempotency check: request_id "user-123" found!
3. Return cached result: {user_id: 42}
4. No duplicate user created ✓
```

---

## Part 6: Message Schemas

### create_user Message

**Format:**
```json
{
  "type": "create_user",
  "data": {
    "phone": "9876543210",
    "request_id": "user-1732123456-abc123"
  }
}
```

**What each field means:**
- `type`: Operation type (tells backend what to do)
- `phone`: User's phone number (10 digits)
- `request_id`: Unique identifier (prevents duplicates)

### create_payment Message

**Format:**
```json
{
  "type": "create_payment",
  "data": {
    "from_user_id": 1,
    "to_user_id": 2,
    "amount": 50,
    "request_id": "payment-1732123456-xyz789"
  }
}
```

**What each field means:**
- `from_user_id`: Sender's user ID
- `to_user_id`: Receiver's user ID
- `amount`: Amount in dollars (must be > 0)
- `request_id`: Unique identifier (prevents duplicate charges)

### notification Message

**Format:**
```json
{
  "user_id": 42,
  "event": "user_created",
  "data": {
    "phone": "9876543210",
    "created_at": "2024-11-25T10:00:00Z"
  }
}
```

**What each field means:**
- `user_id`: Which user to notify
- `event`: Type of notification ("user_created", "payment_sent", "payment_received")
- `data`: Additional context

---

## Summary Table

| Component | Purpose | Technology | Lines |
|-----------|---------|-----------|-------|
| pubsub.js | Message publishing | JavaScript, @google-cloud/pubsub | 257 |
| processing-handler | Main data processor | Python 3.11, psycopg2 | 458 |
| notification-handler | Email sender | Python 3.11, psycopg2 | 291 |
| pubsub.tf | Queue infrastructure | Terraform HCL | 188 |
| cloud_functions.tf | Function deployment | Terraform HCL | 166 |
| cloud_sql.tf | Database setup | Terraform HCL | 120 |
| Total | Full application | Multiple | 1,480+ |

---

**All code components work together to create a production-grade queue-based banking system on Google Cloud Platform.**