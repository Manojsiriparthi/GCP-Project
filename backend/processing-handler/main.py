"""
Processing Handler Cloud Function
Triggered by: Pub/Sub topic 'request-queue'
Purpose: Process user creation and payment requests
"""

import base64
import json
import logging
import os
from datetime import datetime
from decimal import Decimal
from google.cloud import secretmanager
from google.cloud import pubsub_v1
import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2.pool import SimpleConnectionPool

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global connection pool
db_pool = None

# Pub/Sub publisher
publisher = pubsub_v1.PublisherClient()

# Configuration
PROJECT_ID = os.environ.get('GCP_PROJECT_ID')
NOTIFICATION_TOPIC = f'projects/{PROJECT_ID}/topics/notification-queue'
REQUEST_DLQ_TOPIC = f'projects/{PROJECT_ID}/topics/request-queue-dlq'

# Database configuration
DB_HOST = os.environ.get('CLOUDSQL_HOST', 'localhost')
DB_USER = os.environ.get('CLOUDSQL_USER', 'postgres')
DB_NAME = os.environ.get('CLOUDSQL_DATABASE', 'bank_app')
DB_PASSWORD = None  # Loaded from Secret Manager


def get_secret(secret_id, version_id='latest'):
    """Fetch secret from Google Cloud Secret Manager"""
    try:
        client = secretmanager.SecretManagerServiceClient()
        name = client.secret_version_path(PROJECT_ID, secret_id, version_id)
        response = client.access_secret_version(request={'name': name})
        return response.payload.data.decode('UTF-8')
    except Exception as e:
        logger.error(f"Failed to load secret {secret_id}: {str(e)}")
        raise


def initialize_db_pool():
    """Initialize database connection pool"""
    global db_pool, DB_PASSWORD
    
    if db_pool is not None:
        return
    
    try:
        # Load database password from Secret Manager
        DB_PASSWORD = get_secret('cloudsql-password')
        
        # Create connection pool
        db_pool = SimpleConnectionPool(
            1, 20,
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=5,
            sslmode='require'
        )
        logger.info("Database connection pool initialized")
    except Exception as e:
        logger.error(f"Failed to initialize database pool: {str(e)}")
        raise


def get_db_connection():
    """Get a connection from the pool"""
    if db_pool is None:
        initialize_db_pool()
    return db_pool.getconn()


def return_db_connection(conn):
    """Return connection to pool"""
    if db_pool is not None:
        db_pool.putconn(conn)


def publish_to_notification_queue(user_id, event, data=None):
    """
    Publish notification to notification-queue topic
    Will be processed by notification-handler
    """
    try:
        message = {
            'user_id': user_id,
            'event': event,
            'timestamp': datetime.utcnow().isoformat(),
        }
        
        if data:
            message.update(data)
        
        message_json = json.dumps(message)
        future = publisher.publish(NOTIFICATION_TOPIC, message_json.encode('utf-8'))
        message_id = future.result()
        
        logger.info(f"Published notification: user_id={user_id}, event={event}, message_id={message_id}")
        return message_id
    except Exception as e:
        logger.error(f"Failed to publish notification: {str(e)}")
        raise


def validate_user_data(data):
    """Validate user creation data"""
    errors = []
    
    if not data.get('phone'):
        errors.append('Phone number is required')
    
    if len(str(data.get('phone', ''))) != 10:
        errors.append('Phone number must be 10 digits')
    
    if not data.get('request_id'):
        errors.append('Request ID is required')
    
    if errors:
        raise ValueError(', '.join(errors))


def validate_payment_data(data):
    """Validate payment data"""
    errors = []
    
    if not data.get('from_user_id'):
        errors.append('From user ID is required')
    
    if not data.get('to_user_id'):
        errors.append('To user ID is required')
    
    if data.get('from_user_id') == data.get('to_user_id'):
        errors.append('Cannot send payment to yourself')
    
    if not data.get('amount') or float(data.get('amount', 0)) <= 0:
        errors.append('Amount must be greater than 0')
    
    if not data.get('request_id'):
        errors.append('Request ID is required')
    
    if errors:
        raise ValueError(', '.join(errors))


def create_user(data):
    """
    Create a new user and account
    
    Steps:
    1. Check if user already exists (idempotency)
    2. Insert into users table
    3. Insert into accounts table
    4. Database trigger publishes to notification-queue
    """
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # 1. Check if request already processed (idempotency)
        cur.execute(
            'SELECT id FROM users WHERE request_id = %s LIMIT 1',
            (data['request_id'],)
        )
        existing_user = cur.fetchone()
        
        if existing_user:
            logger.info(f"User already created for request_id={data['request_id']}")
            return existing_user
        
        # 2. Check if phone already exists
        cur.execute(
            'SELECT id FROM users WHERE phone = %s LIMIT 1',
            (data['phone'],)
        )
        if cur.fetchone():
            raise ValueError(f"Phone number {data['phone']} already exists")
        
        # 3. Insert user
        cur.execute(
            '''
            INSERT INTO users (phone, request_id, created_at)
            VALUES (%s, %s, %s)
            RETURNING id, phone, created_at
            ''',
            (data['phone'], data['request_id'], datetime.utcnow())
        )
        user = cur.fetchone()
        
        # 4. Insert account with initial balance
        cur.execute(
            '''
            INSERT INTO accounts (user_id, balance, created_at)
            VALUES (%s, %s, %s)
            RETURNING user_id, balance
            ''',
            (user['id'], 1000.0, datetime.utcnow())
        )
        account = cur.fetchone()
        
        # 5. Commit transaction
        conn.commit()
        
        logger.info(f"User created: id={user['id']}, phone={user['phone']}")
        
        # 6. Database trigger should publish to notification-queue
        # But we also do it here to ensure delivery
        publish_to_notification_queue(
            user['id'],
            'user_created',
            {'phone': user['phone']}
        )
        
        return {
            'id': user['id'],
            'phone': user['phone'],
            'balance': float(account['balance']),
        }
    
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f"Failed to create user: {str(e)}")
        raise
    
    finally:
        if conn:
            return_db_connection(conn)


def create_payment(data):
    """
    Create a payment transaction
    
    Steps:
    1. Validate users exist and have balance
    2. Create transaction record
    3. Update sender balance (deduct amount)
    4. Update receiver balance (add amount)
    5. Database triggers publish to notification-queue
    """
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # 1. Check if request already processed (idempotency)
        cur.execute(
            'SELECT id FROM transactions WHERE request_id = %s LIMIT 1',
            (data['request_id'],)
        )
        existing_transaction = cur.fetchone()
        
        if existing_transaction:
            logger.info(f"Transaction already created for request_id={data['request_id']}")
            return existing_transaction
        
        # 2. Validate both users exist
        cur.execute('SELECT id FROM users WHERE id = %s', (data['from_user_id'],))
        if not cur.fetchone():
            raise ValueError(f"Sender user {data['from_user_id']} not found")
        
        cur.execute('SELECT id FROM users WHERE id = %s', (data['to_user_id'],))
        if not cur.fetchone():
            raise ValueError(f"Recipient user {data['to_user_id']} not found")
        
        # 3. Check sender has sufficient balance
        cur.execute(
            'SELECT balance FROM accounts WHERE user_id = %s FOR UPDATE',
            (data['from_user_id'],)
        )
        sender_account = cur.fetchone()
        
        if not sender_account:
            raise ValueError(f"Sender account not found for user {data['from_user_id']}")
        
        amount = float(data['amount'])
        if float(sender_account['balance']) < amount:
            raise ValueError(
                f"Insufficient balance. Available: ${sender_account['balance']:.2f}, "
                f"Required: ${amount:.2f}"
            )
        
        # 4. Create transaction
        cur.execute(
            '''
            INSERT INTO transactions 
            (from_user_id, to_user_id, amount, status, request_id, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id, from_user_id, to_user_id, amount, status, created_at
            ''',
            (
                data['from_user_id'],
                data['to_user_id'],
                amount,
                'completed',
                data['request_id'],
                datetime.utcnow()
            )
        )
        transaction = cur.fetchone()
        
        # 5. Update sender balance (deduct)
        cur.execute(
            '''
            UPDATE accounts
            SET balance = balance - %s, updated_at = %s
            WHERE user_id = %s
            RETURNING user_id, balance
            ''',
            (amount, datetime.utcnow(), data['from_user_id'])
        )
        sender_updated = cur.fetchone()
        
        # 6. Update receiver balance (add)
        cur.execute(
            '''
            UPDATE accounts
            SET balance = balance + %s, updated_at = %s
            WHERE user_id = %s
            RETURNING user_id, balance
            ''',
            (amount, datetime.utcnow(), data['to_user_id'])
        )
        receiver_updated = cur.fetchone()
        
        # 7. Commit transaction
        conn.commit()
        
        logger.info(
            f"Payment created: id={transaction['id']}, "
            f"from={data['from_user_id']}, to={data['to_user_id']}, "
            f"amount=${amount:.2f}"
        )
        
        # 8. Database triggers should publish notifications
        # We also do it here to ensure delivery
        publish_to_notification_queue(
            data['from_user_id'],
            'payment_sent',
            {
                'transaction_id': transaction['id'],
                'to_user_id': data['to_user_id'],
                'amount': amount,
                'new_balance': float(sender_updated['balance']),
            }
        )
        
        publish_to_notification_queue(
            data['to_user_id'],
            'payment_received',
            {
                'transaction_id': transaction['id'],
                'from_user_id': data['from_user_id'],
                'amount': amount,
                'new_balance': float(receiver_updated['balance']),
            }
        )
        
        return {
            'id': transaction['id'],
            'from_user_id': transaction['from_user_id'],
            'to_user_id': transaction['to_user_id'],
            'amount': float(transaction['amount']),
            'status': transaction['status'],
        }
    
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f"Failed to create payment: {str(e)}")
        raise
    
    finally:
        if conn:
            return_db_connection(conn)


def processing_handler(event, context):
    """
    Cloud Function triggered by Pub/Sub topic 'request-queue'
    
    Message format:
    {
        "type": "create_user" or "create_payment",
        "data": {...}
    }
    """
    try:
        # 1. Initialize database pool
        initialize_db_pool()
        
        # 2. Decode Pub/Sub message
        if 'message' not in event:
            raise ValueError("No message in event")
        
        message_data = base64.b64decode(event['message']['data']).decode('utf-8')
        message = json.loads(message_data)
        
        logger.info(f"Processing message: {message.get('type')}")
        
        # 3. Parse request type
        request_type = message.get('type')
        request_data = message.get('data', {})
        
        # 4. Route to appropriate handler
        if request_type == 'create_user':
            validate_user_data(request_data)
            result = create_user(request_data)
            logger.info(f"User creation succeeded: {result}")
        
        elif request_type == 'create_payment':
            validate_payment_data(request_data)
            result = create_payment(request_data)
            logger.info(f"Payment creation succeeded: {result}")
        
        else:
            raise ValueError(f"Unknown request type: {request_type}")
        
        # 5. Return success
        logger.info("Message processed successfully")
        return 'OK', 200
    
    except ValueError as e:
        # Validation error - don't retry (send to DLQ)
        logger.error(f"Validation error: {str(e)}")
        # Pub/Sub will send to DLQ after max retries
        raise
    
    except Exception as e:
        # Unexpected error - log and retry
        logger.error(f"Error processing message: {str(e)}", exc_info=True)
        # Pub/Sub will retry with exponential backoff
        raise


# Health check endpoint (for Cloud Functions)
def health_check(request):
    """Health check endpoint"""
    try:
        initialize_db_pool()
        return 'OK', 200
    except Exception as e:
        return f'UNHEALTHY: {str(e)}', 500
