"""
Notification Handler Cloud Function
Triggered by: Pub/Sub topic 'notification-queue'
Purpose: Send notifications & publish to email topic
"""

import base64
import json
import logging
import os
from datetime import datetime
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
SEND_EMAIL_TOPIC = f'projects/{PROJECT_ID}/topics/send-email'

# Database configuration
DB_HOST = os.environ.get('CLOUDSQL_HOST', 'localhost')
DB_USER = os.environ.get('CLOUDSQL_USER', 'postgres')
DB_NAME = os.environ.get('CLOUDSQL_DATABASE', 'bank_app')
DB_PASSWORD = None


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
        DB_PASSWORD = get_secret('cloudsql-password')
        
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


def fetch_user(user_id):
    """Fetch user details from database"""
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute(
            '''
            SELECT u.id, u.phone, a.balance, a.created_at as account_created
            FROM users u
            JOIN accounts a ON u.id = a.user_id
            WHERE u.id = %s
            ''',
            (user_id,)
        )
        
        user = cur.fetchone()
        return user if user else None
    
    except Exception as e:
        logger.error(f"Failed to fetch user {user_id}: {str(e)}")
        raise
    
    finally:
        if conn:
            return_db_connection(conn)


def publish_to_send_email_topic(to_email, subject, body, html_body=None):
    """
    Publish email message to send-email topic
    Will be processed by email service
    """
    try:
        message = {
            'to': to_email,
            'subject': subject,
            'body': body,
            'html_body': html_body,
            'timestamp': datetime.utcnow().isoformat(),
        }
        
        message_json = json.dumps(message)
        future = publisher.publish(SEND_EMAIL_TOPIC, message_json.encode('utf-8'))
        message_id = future.result()
        
        logger.info(f"Email published to send-email topic: to={to_email}, message_id={message_id}")
        return message_id
    
    except Exception as e:
        logger.error(f"Failed to publish email: {str(e)}")
        raise


def format_user_created_email(user):
    """Format email for user creation notification"""
    subject = "🎉 Welcome to Bank!"
    
    body = f"""
Hello,

Welcome to Bank! Your account has been successfully created.

Account Details:
- Phone: {user['phone']}
- Initial Balance: ${float(user['balance']):.2f}
- Account Created: {user['account_created']}

You can now:
✓ View your balance
✓ Send payments to other users
✓ Receive payments from others
✓ Track your transaction history

Best regards,
Bank Team
"""
    
    return subject, body, None


def format_payment_sent_email(user, notification):
    """Format email for payment sent notification"""
    subject = f"💸 Payment Sent - ${notification.get('amount', 0):.2f}"
    
    body = f"""
Hello,

Your payment has been successfully processed.

Payment Details:
- Amount: ${notification.get('amount', 0):.2f}
- Recipient User ID: {notification.get('to_user_id', 'N/A')}
- Transaction ID: {notification.get('transaction_id', 'N/A')}
- Date: {datetime.utcnow().isoformat()}

Your new balance: ${notification.get('new_balance', 0):.2f}

Best regards,
Bank Team
"""
    
    return subject, body, None


def format_payment_received_email(user, notification):
    """Format email for payment received notification"""
    subject = f"💰 Payment Received - ${notification.get('amount', 0):.2f}"
    
    body = f"""
Hello,

You have received a payment!

Payment Details:
- Amount: ${notification.get('amount', 0):.2f}
- From User ID: {notification.get('from_user_id', 'N/A')}
- Transaction ID: {notification.get('transaction_id', 'N/A')}
- Date: {datetime.utcnow().isoformat()}

Your new balance: ${notification.get('new_balance', 0):.2f}

Best regards,
Bank Team
"""
    
    return subject, body, None


def notification_handler(event, context):
    """
    Cloud Function triggered by Pub/Sub topic 'notification-queue'
    
    Message format:
    {
        "user_id": 1,
        "event": "user_created|payment_sent|payment_received",
        "timestamp": "2024-01-15T10:30:00Z",
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
        notification = json.loads(message_data)
        
        logger.info(f"Processing notification: event={notification.get('event')}, user_id={notification.get('user_id')}")
        
        # 3. Get event type and user
        event_type = notification.get('event')
        user_id = notification.get('user_id')
        
        # 4. Fetch user details
        user = fetch_user(user_id)
        if not user:
            raise ValueError(f"User {user_id} not found")
        
        # 5. Format email based on event type
        subject = None
        body = None
        html_body = None
        
        if event_type == 'user_created':
            subject, body, html_body = format_user_created_email(user)
        
        elif event_type == 'payment_sent':
            subject, body, html_body = format_payment_sent_email(user, notification)
        
        elif event_type == 'payment_received':
            subject, body, html_body = format_payment_received_email(user, notification)
        
        else:
            logger.warning(f"Unknown event type: {event_type}")
            return 'OK', 200
        
        # 6. Publish to send-email topic
        to_email = f"user_{user_id}@bank.example.com"
        message_id = publish_to_send_email_topic(to_email, subject, body, html_body)
        
        logger.info(f"Notification processed: event={event_type}, user_id={user_id}, message_id={message_id}")
        
        # 7. Return success
        return 'OK', 200
    
    except Exception as e:
        logger.error(f"Error processing notification: {str(e)}", exc_info=True)
        raise


def health_check(request):
    """Health check endpoint"""
    try:
        initialize_db_pool()
        return 'OK', 200
    except Exception as e:
        return f'UNHEALTHY: {str(e)}', 500
