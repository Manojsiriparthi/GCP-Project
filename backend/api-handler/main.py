"""
GCP Bank App - API Handler Cloud Function
Handles HTTP requests for user/payment operations
Triggered by: HTTP requests
Routes to: Cloud SQL (PostgreSQL)
"""

import json
import logging
import os
from datetime import datetime
from decimal import Decimal
from typing import Dict, Any, Tuple
import uuid

import functions_framework
import psycopg2
from psycopg2 import pool, sql
from google.cloud import secretmanager
from google.cloud import logging as cloud_logging

# Initialize logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Cloud Logging integration
cloud_logger = cloud_logging.Client().logger("api-handler")

# Environment variables
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "your-project-id")
REGION = os.getenv("GCP_REGION", "us-central1")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "bank_app")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")  # Fetch from Secret Manager
DB_PORT = int(os.getenv("DB_PORT", "5432"))

# Connection pool
connection_pool = None


def get_db_connection():
    """Get database connection from pool"""
    global connection_pool
    
    if connection_pool is None:
        connection_pool = psycopg2.pool.SimpleConnectionPool(
            1, 20,
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            port=DB_PORT,
            connect_timeout=10,
            application_name="api-handler"
        )
    
    return connection_pool.getconn()


def return_db_connection(conn):
    """Return connection to pool"""
    global connection_pool
    if connection_pool:
        connection_pool.putconn(conn)


def get_secret(secret_id: str) -> str:
    """Fetch secret from Secret Manager"""
    try:
        client = secretmanager.SecretManagerServiceClient()
        name = f"projects/{PROJECT_ID}/secrets/{secret_id}/versions/latest"
        response = client.access_secret_version(request={"name": name})
        return response.payload.data.decode("UTF-8")
    except Exception as e:
        logger.error(f"Failed to fetch secret {secret_id}: {str(e)}")
        raise


def validate_request(data: Dict[str, Any]) -> Tuple[bool, str]:
    """Validate incoming request"""
    if not data:
        return False, "Request body is empty"
    
    operation_type = data.get("type")
    if not operation_type:
        return False, "Missing 'type' field"
    
    if operation_type not in ["user", "payment", "bulk", "history", "transactions"]:
        return False, f"Invalid operation type: {operation_type}"
    
    return True, ""


def create_user(conn, email: str, name: str, created_by: str = "admin") -> Dict[str, Any]:
    """Create a single user with account"""
    try:
        cursor = conn.cursor()
        
        # Check if user exists
        cursor.execute("SELECT user_id FROM users WHERE email = %s", (email,))
        if cursor.fetchone():
            cursor.close()
            return {"success": False, "error": "User already exists", "user_id": None}
        
        # Create user
        cursor.execute(
            """
            INSERT INTO users (email, name, created_by)
            VALUES (%s, %s, %s)
            RETURNING user_id
            """,
            (email, name, created_by)
        )
        user_id = cursor.fetchone()[0]
        
        # Create account with initial balance
        cursor.execute(
            """
            INSERT INTO accounts (user_id, account_number, balance)
            VALUES (%s, %s, %s)
            """,
            (user_id, f"ACC{user_id:010d}", 1000.00)
        )
        
        conn.commit()
        cursor.close()
        
        cloud_logger.log_struct({
            "event": "USER_CREATED",
            "user_id": user_id,
            "email": email,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        return {
            "success": True,
            "user_id": user_id,
            "email": email,
            "name": name,
            "initial_balance": 1000.00
        }
    
    except psycopg2.Error as e:
        logger.error(f"Database error creating user: {str(e)}")
        conn.rollback()
        return {"success": False, "error": str(e), "user_id": None}


def create_bulk_users(conn, count: int, created_by: str = "admin") -> Dict[str, Any]:
    """Create bulk users"""
    try:
        cursor = conn.cursor()
        created_users = []
        
        for i in range(count):
            email = f"user_{i+1}_{datetime.now().strftime('%Y%m%d%H%M%S')}@bank.local"
            name = f"User {i+1}"
            
            cursor.execute(
                """
                INSERT INTO users (email, name, created_by)
                VALUES (%s, %s, %s)
                RETURNING user_id
                """,
                (email, name, created_by)
            )
            user_id = cursor.fetchone()[0]
            
            cursor.execute(
                """
                INSERT INTO accounts (user_id, account_number, balance)
                VALUES (%s, %s, %s)
                """,
                (user_id, f"ACC{user_id:010d}", 1000.00)
            )
            
            created_users.append({
                "user_id": user_id,
                "email": email,
                "name": name
            })
        
        conn.commit()
        cursor.close()
        
        cloud_logger.log_struct({
            "event": "BULK_USERS_CREATED",
            "count": count,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        return {
            "success": True,
            "created_count": len(created_users),
            "users": created_users
        }
    
    except psycopg2.Error as e:
        logger.error(f"Database error creating bulk users: {str(e)}")
        conn.rollback()
        return {"success": False, "error": str(e), "created_count": 0}


def create_payment(conn, from_user_id: int, to_user_id: int, amount: float, description: str = "") -> Dict[str, Any]:
    """Create a payment transaction"""
    try:
        cursor = conn.cursor()
        reference_id = str(uuid.uuid4())
        
        # Validate users exist
        cursor.execute("SELECT user_id FROM users WHERE user_id = %s", (from_user_id,))
        if not cursor.fetchone():
            cursor.close()
            return {"success": False, "error": "From user not found", "transaction_id": None}
        
        cursor.execute("SELECT user_id FROM users WHERE user_id = %s", (to_user_id,))
        if not cursor.fetchone():
            cursor.close()
            return {"success": False, "error": "To user not found", "transaction_id": None}
        
        # Check balance
        cursor.execute("SELECT balance FROM accounts WHERE user_id = %s", (from_user_id,))
        balance_row = cursor.fetchone()
        if not balance_row or balance_row[0] < amount:
            cursor.close()
            return {"success": False, "error": "Insufficient balance", "transaction_id": None}
        
        # Create transaction
        cursor.execute(
            """
            INSERT INTO transactions 
            (from_user_id, to_user_id, amount, status, reference_id, description, operation_type)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING transaction_id
            """,
            (from_user_id, to_user_id, amount, "completed", reference_id, description, "transfer")
        )
        transaction_id = cursor.fetchone()[0]
        
        # Update balances
        cursor.execute("UPDATE accounts SET balance = balance - %s WHERE user_id = %s",
                      (amount, from_user_id))
        cursor.execute("UPDATE accounts SET balance = balance + %s WHERE user_id = %s",
                      (amount, to_user_id))
        
        # Create payment status
        cursor.execute(
            """
            INSERT INTO payment_status (transaction_id, status, notification_sent)
            VALUES (%s, %s, %s)
            """,
            (transaction_id, "completed", False)
        )
        
        conn.commit()
        cursor.close()
        
        cloud_logger.log_struct({
            "event": "PAYMENT_CREATED",
            "transaction_id": transaction_id,
            "from_user_id": from_user_id,
            "to_user_id": to_user_id,
            "amount": amount,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        return {
            "success": True,
            "transaction_id": transaction_id,
            "from_user_id": from_user_id,
            "to_user_id": to_user_id,
            "amount": amount,
            "reference_id": reference_id,
            "status": "completed"
        }
    
    except psycopg2.Error as e:
        logger.error(f"Database error creating payment: {str(e)}")
        conn.rollback()
        return {"success": False, "error": str(e), "transaction_id": None}


def get_user_transactions(conn, user_id: int, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
    """Get user transaction history"""
    try:
        cursor = conn.cursor()
        
        cursor.execute(
            """
            SELECT 
                transaction_id, from_user_id, to_user_id, 
                amount, status, created_at
            FROM transactions
            WHERE from_user_id = %s OR to_user_id = %s
            ORDER BY created_at DESC
            LIMIT %s OFFSET %s
            """,
            (user_id, user_id, limit, offset)
        )
        
        transactions = []
        for row in cursor.fetchall():
            transactions.append({
                "transaction_id": row[0],
                "from_user_id": row[1],
                "to_user_id": row[2],
                "amount": float(row[3]),
                "status": row[4],
                "created_at": row[5].isoformat() if row[5] else None
            })
        
        cursor.close()
        
        return {
            "success": True,
            "user_id": user_id,
            "transaction_count": len(transactions),
            "transactions": transactions
        }
    
    except psycopg2.Error as e:
        logger.error(f"Database error fetching transactions: {str(e)}")
        return {"success": False, "error": str(e), "transactions": []}


def create_bulk_payments(conn, count: int) -> Dict[str, Any]:
    """Create bulk random payment transactions"""
    try:
        cursor = conn.cursor()
        
        # Get all user IDs
        cursor.execute("SELECT user_id FROM users ORDER BY RANDOM() LIMIT %s", (count * 2,))
        user_ids = [row[0] for row in cursor.fetchall()]
        
        if len(user_ids) < 2:
            cursor.close()
            return {"success": False, "error": "Not enough users for transactions"}
        
        created_transactions = []
        for i in range(min(count, len(user_ids) - 1)):
            from_user = user_ids[i]
            to_user = user_ids[(i + 1) % len(user_ids)]
            amount = (i + 1) * 10  # 10, 20, 30, ... amounts
            
            # Check balance before transaction
            cursor.execute("SELECT balance FROM accounts WHERE user_id = %s", (from_user,))
            balance = cursor.fetchone()
            if not balance or balance[0] < amount:
                continue
            
            reference_id = str(uuid.uuid4())
            cursor.execute(
                """
                INSERT INTO transactions 
                (from_user_id, to_user_id, amount, status, reference_id, operation_type)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING transaction_id
                """,
                (from_user, to_user, amount, "completed", reference_id, "transfer")
            )
            transaction_id = cursor.fetchone()[0]
            
            cursor.execute("UPDATE accounts SET balance = balance - %s WHERE user_id = %s",
                          (amount, from_user))
            cursor.execute("UPDATE accounts SET balance = balance + %s WHERE user_id = %s",
                          (amount, to_user))
            
            created_transactions.append({"transaction_id": transaction_id, "amount": amount})
        
        conn.commit()
        cursor.close()
        
        return {
            "success": True,
            "created_count": len(created_transactions),
            "transactions": created_transactions
        }
    
    except psycopg2.Error as e:
        logger.error(f"Database error creating bulk payments: {str(e)}")
        conn.rollback()
        return {"success": False, "error": str(e)}


@functions_framework.http
def api_handler(request: 'flask.Request') -> Tuple[str, int]:
    """Main API Handler Cloud Function"""
    
    # CORS headers
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
        "Content-Type": "application/json"
    }
    
    # Handle OPTIONS request
    if request.method == "OPTIONS":
        return "", 204
    
    if request.method != "POST":
        return json.dumps({"success": False, "error": "Method not allowed"}), 405, headers
    
    try:
        data = request.get_json()
        
        # Validate request
        is_valid, error_msg = validate_request(data)
        if not is_valid:
            return json.dumps({"success": False, "error": error_msg}), 400, headers
        
        operation_type = data.get("type")
        conn = get_db_connection()
        response = None
        
        try:
            if operation_type == "user":
                operation_data = data.get("data", {})
                response = create_user(
                    conn,
                    email=operation_data.get("email"),
                    name=operation_data.get("name", ""),
                    created_by=operation_data.get("created_by", "admin")
                )
            
            elif operation_type == "bulk":
                count = data.get("count", 50)
                response = create_bulk_users(conn, count)
            
            elif operation_type == "payment":
                operation_data = data.get("data", {})
                response = create_payment(
                    conn,
                    from_user_id=operation_data.get("from_user_id"),
                    to_user_id=operation_data.get("to_user_id"),
                    amount=operation_data.get("amount"),
                    description=operation_data.get("description", "")
                )
            
            elif operation_type == "bulk_payments":
                count = data.get("count", 50)
                response = create_bulk_payments(conn, count)
            
            elif operation_type == "history":
                user_id = data.get("user_id")
                response = get_user_transactions(conn, user_id)
            
            else:
                response = {"success": False, "error": "Unknown operation type"}
        
        finally:
            return_db_connection(conn)
        
        status_code = 200 if response.get("success") else 400
        return json.dumps(response), status_code, headers
    
    except json.JSONDecodeError:
        error = {"success": False, "error": "Invalid JSON"}
        return json.dumps(error), 400, headers
    
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        error = {"success": False, "error": "Internal server error"}
        return json.dumps(error), 500, headers


@functions_framework.http
def health_check(request: 'flask.Request') -> Tuple[str, int]:
    """Health check endpoint"""
    headers = {"Content-Type": "application/json"}
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        return_db_connection(conn)
        
        return json.dumps({"status": "healthy", "timestamp": datetime.utcnow().isoformat()}), 200, headers
    
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return json.dumps({"status": "unhealthy", "error": str(e)}), 500, headers

