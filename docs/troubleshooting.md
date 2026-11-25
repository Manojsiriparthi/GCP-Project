# Troubleshooting Guide: GCP Bank Application

## Overview

This comprehensive guide covers troubleshooting for Cloud Pub/Sub, Cloud Functions, Cloud Monitoring, and application-side issues. Each section includes problem identification, root cause analysis, and detailed solutions.

---

## Part 1: Pub/Sub Troubleshooting

### Understanding Pub/Sub Architecture

Pub/Sub is a message queue service. Problems typically occur in three areas:
1. **Publishing** - Messages not reaching the queue
2. **Subscription** - Messages not being delivered to Cloud Function
3. **Acknowledgement** - Messages stuck in queue (not acknowledged as processed)

### Scenario 1: Messages Publishing But Not Being Processed

**Symptoms:**
- Frontend successfully publishes messages
- Cloud Logging shows messages published
- Cloud Functions not being triggered
- Queue depth keeps growing (gcloud pubsub subscriptions pull shows unacked messages)

**Root Cause Identification:**

```bash
# Step 1: Check if subscription exists
gcloud pubsub subscriptions list
# Output should include: request-queue-sub, notification-queue-sub

# Step 2: Check if subscription has delivery configuration
gcloud pubsub subscriptions describe request-queue-sub
# Output should show:
# pushConfig:
#   pushEndpoint: https://...cloudfunctions.net/processing-handler

# Step 3: Verify subscription is not in error state
gcloud pubsub subscriptions describe request-queue-sub --format='value(state)'
# Output should be: ACTIVE (not ERROR or CREATING)
```

**Solution Steps:**

```bash
# If subscription doesn't exist, create it
gcloud pubsub subscriptions create request-queue-sub \
  --topic=request-queue \
  --push-endpoint="https://us-central1-PROJECT_ID.cloudfunctions.net/processing-handler" \
  --push-auth-service-account=gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com

# If push endpoint is wrong, update it
gcloud pubsub subscriptions update request-queue-sub \
  --push-endpoint="https://us-central1-PROJECT_ID.cloudfunctions.net/processing-handler"

# Wait 60 seconds for subscription to become ACTIVE
sleep 60

# Verify subscription is active
gcloud pubsub subscriptions describe request-queue-sub --format='value(state)'
```

**Why this happens:** Push subscriptions require the Cloud Function URL and authentication. If misconfigured, Pub/Sub can't deliver messages.

---

### Scenario 2: "Dead Letter Queue" Accumulating Messages

**Symptoms:**
- Messages appearing in request-queue-dlq
- Notifications appearing in notification-queue-dlq
- main messages processing normally
- DLQ growing over time

**Root Cause Identification:**

```bash
# Step 1: Check how many messages in DLQ
gcloud pubsub subscriptions pull request-queue-dlq-sub --limit=10 --auto-ack

# Step 2: Examine failed message details
gcloud pubsub subscriptions pull request-queue-dlq-sub --limit=1 --format=json

# Example output:
# {
#   "ackId": "...",
#   "message": {
#     "data": "eyJ0eXBlIjogImNyZWF0ZV91c2VyIiwgImRhdGEiOiB7InBob25lIjogIjk4NzY1NDMyMTAifX0=",
#     "attributes": {
#       "deadLetterSourceSubscription": "request-queue-sub",
#       "deadLetterSourceTimestamp": "1732123456"
#     }
#   }
# }

# Step 3: Decode message to understand what failed
echo "eyJ0eXBlIjogImNyZWF0ZV91c2VyIiwgImRhdGEiOiB7InBob25lIjogIjk4NzY1NDMyMTAifX0=" | base64 -d
# Output: {"type": "create_user", "data": {"phone": "9876543210"}}

# Step 4: Check Cloud Function logs for errors
gcloud functions logs read processing-handler --limit=50 --filter='severity:ERROR'

# Example error:
# ERROR: psycopg2.IntegrityError: duplicate key value violates unique constraint
```

**Solution Steps (Common Causes and Fixes):**

**Case A: Database Connection Failed**

```bash
# Error in logs: "could not connect to server: Connection refused"

# Check if Cloud SQL instance is running
gcloud sql instances describe gcp-bank-sql --format='value(state)'
# Output should be: RUNNABLE

# If STOPPED, start it
gcloud sql instances patch gcp-bank-sql --no-database-flags
gcloud sql instances restart gcp-bank-sql

# Wait for restart
gcloud sql operations wait --project=PROJECT_ID <OPERATION_ID>

# Republish test message
gcloud pubsub topics publish request-queue \
  --message='{"type": "create_user", "data": {"phone": "9999999999"}}'

# Check if processed (DLQ message count should decrease)
gcloud pubsub subscriptions pull request-queue-dlq-sub --limit=10 | wc -l
```

**Case B: Duplicate Phone Number**

```bash
# Error in logs: "duplicate key value violates unique constraint"
# This means phone already exists in database

# Check existing users
gcloud sql connect gcp-bank-sql --user=postgres
# In psql:
SELECT phone FROM users WHERE phone = '9876543210';

# If found, either:
# 1. Use different phone in frontend
# 2. Delete the user:
DELETE FROM users WHERE phone = '9876543210';
# 3. Clear idempotency cache for clean retry:
DELETE FROM idempotency_keys WHERE request_id LIKE 'user-%9876543210%';
\\q
```

**Case C: Insufficient Database Permissions**

```bash
# Error in logs: "permission denied for schema public"

# Check database user permissions
gcloud sql connect gcp-bank-sql --user=postgres

# In psql:
# Grant all permissions to postgres user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

# Verify
\\dp

\\q
```

**Manual Retry of Dead Letter Messages:**

```bash
# Pull and examine DLQ messages
gcloud pubsub subscriptions pull request-queue-dlq-sub --limit=5 --format=json

# If problem is fixed, republish to main queue
gcloud pubsub topics publish request-queue \
  --message='<BASE64_ENCODED_MESSAGE>'

# Or, acknowledge (delete) message from DLQ if it's not important
gcloud pubsub subscriptions pull request-queue-dlq-sub --auto-ack --limit=100
```

---

### Scenario 3: Duplicate Messages Processing

**Symptoms:**
- Same user created twice with same phone number
- Same payment processed twice
- Idempotency not working

**Root Cause Identification:**

```bash
# Step 1: Check if idempotency table is being used
gcloud sql connect gcp-bank-sql --user=postgres

# In psql:
SELECT COUNT(*) FROM idempotency_keys;
# If 0, idempotency is not being used

# Check if idempotency_keys table exists
\\dt idempotency_keys
# If not found, table wasn't created

\\q

# Step 2: Check Cloud Function code
# Verify processing-handler/main.py has this check:
# SELECT * FROM idempotency_keys WHERE request_id = %s
```

**Solution Steps:**

```bash
# If table doesn't exist, create it
gcloud sql connect gcp-bank-sql --user=postgres

# In psql:
CREATE TABLE idempotency_keys (
  request_id VARCHAR(255) PRIMARY KEY,
  result JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_idempotency_created ON idempotency_keys(created_at);

\\q

# Redeploy Cloud Function with updated code
gcloud functions deploy processing-handler \
  --runtime=python311 \
  --trigger-topic=request-queue \
  --source=backend/processing-handler

# Test idempotency
REQUEST_ID="test-idempotency-$(date +%s)"

# Publish same message twice
gcloud pubsub topics publish request-queue \
  --message="{\"type\": \"create_user\", \"data\": {\"phone\": \"5555555555\", \"request_id\": \"$REQUEST_ID\"}}"

gcloud pubsub topics publish request-queue \
  --message="{\"type\": \"create_user\", \"data\": {\"phone\": \"5555555555\", \"request_id\": \"$REQUEST_ID\"}}"

# Wait 5 seconds for processing
sleep 5

# Check if only 1 user created
gcloud sql connect gcp-bank-sql --user=postgres
# In psql:
SELECT COUNT(*) FROM users WHERE phone = '5555555555';
# Output: 1 (not 2) ✓

\\q
```

---

## Part 2: Cloud Functions Troubleshooting

### Understanding Cloud Function Lifecycle

Cloud Functions process messages in this order:
1. Message arrives in Pub/Sub topic
2. Pub/Sub pushes to Cloud Function endpoint
3. Cloud Function processes (or times out)
4. If success: acknowledge message (remove from queue)
5. If failure/timeout: retry with backoff

### Scenario 1: Cloud Function Timing Out

**Symptoms:**
- Messages take very long (many seconds)
- Some messages timeout (504 Gateway Timeout)
- Error: "Function execution took X seconds, exceeding timeout of 540s"

**Root Cause Identification:**

```bash
# Step 1: Check function timeout setting
gcloud functions describe processing-handler --format='value(timeout)'
# Output should be: 540

# Step 2: Check function logs for slow operations
gcloud functions logs read processing-handler --limit=50

# Look for slow database queries:
# [Processing] Starting create_user
# [Database] SELECT from users table took 15s <- SLOW!
# [Database] INSERT into users table took 20s <- VERY SLOW!

# Step 3: Check Cloud SQL instance performance
gcloud sql instances describe gcp-bank-sql --format='json' | grep -A5 settings.backupConfiguration

# Step 4: Check database connection pool
# If pool is depleted, new connections hang waiting for one to free up
gcloud sql instances describe gcp-bank-sql --format='value(settings.ipConfiguration.ipv4Enabled)'
# Should be false (private IP only, no public access)
```

**Solution Steps:**

**Case A: Slow Database Queries**

```bash
# Step 1: Enable query logging
gcloud sql instances patch gcp-bank-sql \
  --database-flags=log_duration=on,log_min_duration_statement=1000

# Step 2: Wait for update
gcloud sql operations wait --project=PROJECT_ID <OPERATION_ID>

# Step 3: Check slow query logs
gcloud sql operations list --instance=gcp-bank-sql --limit=5

# Step 4: Review query logs in Cloud Logging
gcloud logging read "resource.type=cloudsql_database AND severity=WARNING" --limit=50

# Step 5: Create indexes if missing
gcloud sql connect gcp-bank-sql --user=postgres
# In psql:
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_payments_from ON payments(from_user_id);
CREATE INDEX idx_payments_to ON payments(to_user_id);

\\q

# Step 6: Redeploy function
gcloud functions deploy processing-handler \
  --runtime=python311 \
  --trigger-topic=request-queue \
  --source=backend/processing-handler
```

**Case B: Connection Pool Exhaustion**

```bash
# Error in logs: "could not allocate connection slot"

# Step 1: Increase connection pool size in code
# In backend/processing-handler/main.py:

# BEFORE:
# connection_pool = psycopg2.pool.SimpleConnectionPool(1, 10, ...)

# AFTER:
# connection_pool = psycopg2.pool.SimpleConnectionPool(1, 50, ...)

# Step 2: Redeploy
gcloud functions deploy processing-handler \
  --runtime=python311 \
  --trigger-topic=request-queue \
  --source=backend/processing-handler \
  --memory=512MB

# Step 3: Verify function has enough memory for larger pool
gcloud functions describe processing-handler --format='value(runtime,memory)'
# Should show: python311, 512
# If only 256, increase it
```

---

### Scenario 2: "Cannot Find Cloud SQL Instance"

**Symptoms:**
- Error: "Cannot find Cloud SQL instance with IP address..."
- Error: "Name resolution failed for host..."
- Database operations fail in Cloud Function

**Root Cause Identification:**

```bash
# Step 1: Verify VPC Connector exists
gcloud compute networks vpc-access connectors list --region=us-central1

# Step 2: Check if Cloud Function is using VPC connector
gcloud functions describe processing-handler --format='value(vpcConnector)'
# Output should show: projects/PROJECT_ID/locations/us-central1/connectors/default

# Step 3: Verify Cloud SQL instance has private IP
gcloud sql instances describe gcp-bank-sql --format='value(ipAddresses[0].ipAddress)'
# Output: 10.x.x.x (private IP)
# If output is public IP, instance is misconfigured

# Step 4: Check if Cloud SQL instance is on same VPC as VPC connector
gcloud sql instances describe gcp-bank-sql --format='json' | grep networkName
```

**Solution Steps:**

```bash
# Step 1: Ensure Cloud SQL has private IP
gcloud sql instances describe gcp-bank-sql
# Should show:
# ipAddresses:
# - ipAddress: 10.x.x.x
#   type: PRIVATE
# NOT LISTED: (no public IP)

# If public IP exists, update instance
gcloud sql instances patch gcp-bank-sql --no-assign-ip

# Step 2: Verify VPC Connector
gcloud compute networks vpc-access connectors describe default \
  --region=us-central1

# Step 3: Update Cloud Function to use VPC Connector
gcloud functions deploy processing-handler \
  --runtime=python311 \
  --trigger-topic=request-queue \
  --source=backend/processing-handler \
  --vpc-connector="projects/PROJECT_ID/locations/us-central1/connectors/default"

# Step 4: Test connectivity
# Publish test message
gcloud pubsub topics publish request-queue \
  --message='{"type": "create_user", "data": {"phone": "7777777777"}}'

# Check logs for success
gcloud functions logs read processing-handler --limit=10 | grep -E "ERROR|SUCCESS|Connected"
```

---

### Scenario 3: "Secret Manager Access Denied"

**Symptoms:**
- Error: "AccessDenied: Permission denied on resource..."
- Error: "403 Forbidden" when accessing secrets
- Database password not loading

**Root Cause Identification:**

```bash
# Step 1: Check if service account has secret accessor role
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:gcp-bank-app-sa@*" \
  --format='table(bindings.role)'

# Output should include: roles/secretmanager.secretAccessor

# Step 2: Verify secret exists
gcloud secrets list | grep cloudsql-password

# Step 3: Check if secret has recent version
gcloud secrets versions list cloudsql-password
```

**Solution Steps:**

```bash
# Step 1: Grant service account access to secret
gcloud secrets add-iam-policy-binding cloudsql-password \
  --member="serviceAccount:gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Step 2: Redeploy Cloud Function
gcloud functions deploy processing-handler \
  --runtime=python311 \
  --trigger-topic=request-queue \
  --source=backend/processing-handler \
  --service-account=gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com

# Step 3: Test
gcloud pubsub topics publish request-queue \
  --message='{"type": "create_user", "data": {"phone": "8888888888"}}'

# Check logs
gcloud functions logs read processing-handler --limit=10 | grep -i "secret\|password\|error"
```

---

## Part 3: Cloud Monitoring & Logging Troubleshooting

### Scenario 1: "No Log Entries Appearing"

**Symptoms:**
- Cloud Function runs but no logs visible
- gcloud functions logs read shows nothing
- Cloud Logging console is empty

**Root Cause Identification:**

```bash
# Step 1: Check if logging is enabled
gcloud projects describe PROJECT_ID --format='value(labels)'

# Step 2: Verify function has logging permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:gcp-bank-app-sa@*" \
  | grep logging

# Step 3: Check if function actually ran
gcloud functions describe processing-handler --format='value(lastUpdateTime)'
# Should show recent timestamp
```

**Solution Steps:**

```bash
# Step 1: Enable Cloud Logging API
gcloud services enable logging.googleapis.com

# Step 2: Grant logging permissions to service account
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"

# Step 3: Redeploy function
gcloud functions deploy processing-handler \
  --runtime=python311 \
  --trigger-topic=request-queue \
  --source=backend/processing-handler

# Step 4: Trigger message
gcloud pubsub topics publish request-queue \
  --message='{"type": "create_user", "data": {"phone": "6666666666"}}'

# Step 5: Wait 5 seconds and check logs
sleep 5
gcloud functions logs read processing-handler --limit=10

# Or check in Cloud Logging
gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=processing-handler" --limit=10
```

---

### Scenario 2: "Monitoring Dashboard Shows No Data"

**Symptoms:**
- Cloud Monitoring shows "No data available"
- Metrics not updating
- Cannot create alerts

**Root Cause Identification:**

```bash
# Step 1: Check if Monitoring API is enabled
gcloud services list --enabled | grep monitoring

# Step 2: Check if metrics are being written
gcloud monitoring time-series list \
  --filter='metric.type="cloudfunctions.googleapis.com/function/execution_times"' \
  --format='table(resource.labels.function_name,metric.type)' \
  --limit=10

# Step 3: Check Pub/Sub metrics
gcloud monitoring time-series list \
  --filter='metric.type="pubsub.googleapis.com/subscription/num_undelivered_messages"' \
  --limit=10
```

**Solution Steps:**

```bash
# Step 1: Enable Cloud Monitoring API
gcloud services enable monitoring.googleapis.com

# Step 2: Grant monitoring permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/monitoring.metricWriter"

# Step 3: Wait 5 minutes for metrics to appear (initially slow)

# Step 4: Verify metrics available
gcloud monitoring time-series list \
  --filter='resource.type="cloud_function"' \
  --limit=5

# Step 5: Create dashboard
# In Cloud Console: Monitoring > Dashboards > Create Dashboard > Add Charts
# Select metric: cloudfunctions.googleapis.com/function/execution_times
# Select metric: pubsub.googleapis.com/subscription/num_undelivered_messages
```

---

## Part 4: Application-Side Troubleshooting

### Scenario 1: "Frontend Can't Connect to Pub/Sub"

**Symptoms:**
- Browser console shows error: "Cannot find module '@google-cloud/pubsub'"
- Error: "Failed to authenticate with Google Cloud"
- Frontend messages don't publish

**Root Cause Identification:**

```bash
# Step 1: Check if Pub/Sub client is installed
cd frontend
npm list @google-cloud/pubsub

# Step 2: Check if environment credentials are set
echo $GOOGLE_APPLICATION_CREDENTIALS

# Step 3: Check if credentials file exists
test -f /path/to/credentials.json && echo "File exists" || echo "File missing"

# Step 4: Verify credentials format
cat $GOOGLE_APPLICATION_CREDENTIALS | jq .
# Should show: type, project_id, private_key, client_email
```

**Solution Steps:**

```bash
# Step 1: Install Pub/Sub client library
cd frontend
npm install @google-cloud/pubsub

# Step 2: Set up Google Cloud credentials
# Download service account key from GCP Console
gcloud iam service-accounts keys create sa-key.json \
  --iam-account=gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com

# Step 3: Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/sa-key.json"

# Step 4: Verify credentials
node -e "console.log(require('fs').existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS))"
# Output: true

# Step 5: Test Pub/Sub connection
npm run dev
# Check browser console: "Pub/Sub connected successfully"
```

---

### Scenario 2: "Frontend Publishing But Getting 403 Errors"

**Symptoms:**
- Browser console: "Error 403: Forbidden"
- Error: "User does not have permission to publish..."
- Messages not reaching Pub/Sub

**Root Cause Identification:**

```bash
# Step 1: Check service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:gcp-bank-app-sa@*" \
  --format='table(bindings.role)'

# Output should include: roles/pubsub.publisher

# Step 2: Check if service account has valid keys
gcloud iam service-accounts keys list \
  --iam-account=gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com
```

**Solution Steps:**

```bash
# Step 1: Grant Pub/Sub Publisher role
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:gcp-bank-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher"

# Step 2: If using user credentials instead of service account
# (In browser/frontend environment)
# Use gcloud auth instead:
gcloud auth login
gcloud config set project PROJECT_ID

# Step 3: Get user credentials
gcloud auth application-default login

# Step 4: Restart frontend
npm run dev

# Step 5: Test publishing
# In browser console:
publishToPubSub('request-queue', {type: 'create_user', data: {phone: '9999999998'}})
# Should succeed without 403 error
```

---

### Scenario 3: "Messages Stuck in Frontend Queue"

**Symptoms:**
- getQueueStatus() returns high numbers
- Many messages still in request-queue topic
- Frontend seems frozen

**Root Cause Identification:**

```bash
# Step 1: Check queue depth
gcloud pubsub subscriptions describe request-queue-sub \
  --format='value(ackDeadlineSeconds)'

# Step 2: Check if subscription is pushing
gcloud pubsub subscriptions describe request-queue-sub \
  --format='value(pushConfig.pushEndpoint)'

# Step 3: Check if Cloud Function is healthy
gcloud functions describe processing-handler --format='value(state)'
# Should be: ACTIVE

# Step 4: Check if Cloud Function has errors
gcloud functions logs read processing-handler --limit=50 | grep -i error
```

**Solution Steps:**

```bash
# Step 1: Check if Cloud Function is running
gcloud functions list --filter="name=processing-handler"

# Step 2: If not ACTIVE, redeploy
gcloud functions deploy processing-handler \
  --runtime=python311 \
  --trigger-topic=request-queue \
  --source=backend/processing-handler

# Step 3: Increase Cloud Function instances
gcloud functions deploy processing-handler \
  --max-instances=100

# Step 4: Monitor processing
# In one terminal, watch queue depth:
watch -n 2 'gcloud pubsub subscriptions describe request-queue-sub --format="value(stats.unackedMessages)"'

# In another terminal, check function logs:
watch -n 5 'gcloud functions logs read processing-handler --limit=5'

# Queue depth should decrease over time
```

---

## Part 5: Diagnosis Workflow

### Quick Diagnostic Checklist

When something breaks, follow this order:

```bash
# 1. Check if Pub/Sub topics exist
gcloud pubsub topics list | grep -E "request-queue|notification-queue"

# 2. Check if Cloud Functions are deployed
gcloud functions list --format='table(name,state,trigger)'

# 3. Check if Cloud SQL is running
gcloud sql instances list --format='table(name,state)'

# 4. Check if messages are being published
gcloud pubsub subscriptions describe request-queue-sub --format='value(stats.unackedMessages)'

# 5. Check Cloud Function logs for errors
gcloud functions logs read processing-handler --limit=50 | grep ERROR

# 6. Check if database is accessible
gcloud sql connect gcp-bank-sql --user=postgres
# In psql: SELECT COUNT(*) FROM users;
# Should return a number (not connection error)
\\q

# 7. Check monitoring
gcloud monitoring time-series list \
  --filter='resource.type="cloud_function"' \
  --limit=1
```

### Complete System Test

```bash
# Run this end-to-end test

# Step 1: Verify all components ready
echo "=== Component Status ==="
gcloud functions list --filter="name:(processing-handler OR notification-handler)" \
  --format='table(name,state)'
gcloud sql instances list --format='table(name,state)'
gcloud pubsub topics list --format='table(name)' | wc -l

# Step 2: Publish test message
TEST_ID="test-$(date +%s)"
gcloud pubsub topics publish request-queue \
  --message="{\"type\": \"create_user\", \"data\": {\"phone\": \"5555555554\", \"request_id\": \"$TEST_ID\"}}"

echo "Published message with request_id: $TEST_ID"

# Step 3: Wait for processing
sleep 10

# Step 4: Check if processed
gcloud functions logs read processing-handler --limit=5 | grep -E "$TEST_ID|ERROR"

# Step 5: Verify in database
gcloud sql connect gcp-bank-sql --user=postgres
# In psql:
SELECT phone, balance FROM users WHERE phone = '5555555554' LIMIT 1;
# Should show: 5555555554 | 1000
\\q

echo "=== Test Complete ==="
```

---

## Part 6: Common Error Messages & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `duplicate key value violates unique constraint` | Phone already exists | Use different phone or delete user first |
| `could not connect to server: Connection refused` | Cloud SQL stopped | `gcloud sql instances restart gcp-bank-sql` |
| `Function execution took X seconds, exceeding timeout` | Long-running operation | Increase timeout or optimize query |
| `AccessDenied: Permission denied on resource` | Missing IAM role | Grant appropriate role to service account |
| `Cannot find Cloud SQL instance` | No VPC connector | Add VPC connector to Cloud Function |
| `deadLetterSourceSubscription: request-queue-sub` | Message failed 5 times | Check logs, fix root cause, republish |
| `pubsub.PublishError: Deadline exceeded` | Pub/Sub unreachable | Check credentials and network |
| `'NoneType' object is not subscriptable` | Parsing error in function | Check message format matches expected schema |

---

**All troubleshooting completed. System should be fully operational.**