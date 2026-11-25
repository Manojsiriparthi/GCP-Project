-- GCP Bank App - PostgreSQL Cloud SQL Schema
-- Database: bank_app

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create ENUM types
CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'failed', 'cancelled');
CREATE TYPE operation_type AS ENUM ('transfer', 'deposit', 'withdrawal', 'payment');

-- Users Table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) DEFAULT 'admin',
    
    INDEX idx_email (email),
    INDEX idx_created_at (created_at)
);

-- Accounts Table
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE,
    account_number VARCHAR(20) NOT NULL UNIQUE,
    balance DECIMAL(15, 2) DEFAULT 1000.00,
    currency VARCHAR(3) DEFAULT 'USD',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_account_number (account_number)
);

-- Transactions Table
CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_user_id INTEGER NOT NULL,
    to_user_id INTEGER NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status transaction_status DEFAULT 'pending',
    operation_type operation_type DEFAULT 'transfer',
    reference_id VARCHAR(100) UNIQUE,
    description TEXT,
    failure_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    
    FOREIGN KEY (from_user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (to_user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    INDEX idx_from_user (from_user_id),
    INDEX idx_to_user (to_user_id),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    INDEX idx_reference (reference_id)
);

-- Payment Status Table (for tracking)
CREATE TABLE payment_status (
    payment_status_id SERIAL PRIMARY KEY,
    transaction_id INTEGER NOT NULL UNIQUE,
    status transaction_status DEFAULT 'pending',
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    last_error VARCHAR(500),
    next_retry_at TIMESTAMP,
    notification_sent BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    INDEX idx_transaction_id (transaction_id),
    INDEX idx_status (status),
    INDEX idx_notification_sent (notification_sent)
);

-- Audit Logs Table
CREATE TABLE audit_logs (
    audit_id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id INTEGER,
    action VARCHAR(50) NOT NULL,
    changes JSONB,
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    
    INDEX idx_entity (entity_type, entity_id),
    INDEX idx_created_at (created_at),
    INDEX idx_action (action)
);

-- Notifications Table
CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    transaction_id INTEGER,
    email VARCHAR(255) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    email_sent BOOLEAN DEFAULT false,
    email_sent_at TIMESTAMP,
    email_failed BOOLEAN DEFAULT false,
    failure_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_email_sent (email_sent),
    INDEX idx_created_at (created_at)
);

-- ===== TRIGGERS =====

-- Trigger: Update updated_at timestamp on users
CREATE OR REPLACE FUNCTION update_users_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_users_timestamp
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_users_timestamp();

-- Trigger: Update updated_at timestamp on accounts
CREATE OR REPLACE FUNCTION update_accounts_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_accounts_timestamp
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION update_accounts_timestamp();

-- Trigger: Update updated_at timestamp on transactions
CREATE OR REPLACE FUNCTION update_transactions_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_transactions_timestamp
BEFORE UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION update_transactions_timestamp();

-- Trigger: Audit log on transaction insert
CREATE OR REPLACE FUNCTION audit_transaction_insert()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (entity_type, entity_id, action, changes, created_by)
    VALUES (
        'transaction',
        NEW.transaction_id,
        'INSERT',
        jsonb_build_object(
            'from_user_id', NEW.from_user_id,
            'to_user_id', NEW.to_user_id,
            'amount', NEW.amount,
            'status', NEW.status
        ),
        'system'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_audit_transaction_insert
AFTER INSERT ON transactions
FOR EACH ROW
EXECUTE FUNCTION audit_transaction_insert();

-- Trigger: Create notification when transaction completes
CREATE OR REPLACE FUNCTION create_notification_on_transaction()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        INSERT INTO notifications (user_id, transaction_id, email, subject, message)
        SELECT 
            u.user_id,
            NEW.transaction_id,
            u.email,
            'Transaction Completed',
            FORMAT('Your transaction of %s %s to user %s has been completed.',
                NEW.amount, NEW.currency, NEW.to_user_id)
        FROM users u
        WHERE u.user_id = NEW.from_user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_notification
AFTER UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION create_notification_on_transaction();

-- ===== STORED PROCEDURES =====

-- Procedure: Create bulk users
CREATE OR REPLACE FUNCTION create_bulk_users(
    p_count INTEGER,
    p_created_by VARCHAR DEFAULT 'admin'
)
RETURNS TABLE(user_id INTEGER, email VARCHAR, name VARCHAR) AS $$
DECLARE
    i INTEGER;
    v_user_id INTEGER;
BEGIN
    FOR i IN 1..p_count LOOP
        INSERT INTO users (email, name, created_by)
        VALUES (
            FORMAT('user_%s_%s@bank.local', i, CURRENT_TIMESTAMP::DATE),
            FORMAT('User %s', i),
            p_created_by
        )
        RETURNING users.user_id, users.email, users.name INTO v_user_id, $1, $2;
        
        -- Create corresponding account
        INSERT INTO accounts (user_id, account_number, balance)
        VALUES (
            v_user_id,
            FORMAT('ACC%010s', v_user_id),
            1000.00
        );
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Procedure: Process payment transaction
CREATE OR REPLACE FUNCTION process_payment(
    p_from_user_id INTEGER,
    p_to_user_id INTEGER,
    p_amount DECIMAL,
    p_reference_id VARCHAR DEFAULT NULL
)
RETURNS TABLE(success BOOLEAN, transaction_id INTEGER, error_message VARCHAR) AS $$
DECLARE
    v_transaction_id INTEGER;
    v_from_balance DECIMAL;
    v_error_msg VARCHAR;
BEGIN
    -- Check if users exist
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_from_user_id) THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'From user does not exist'::VARCHAR;
        RETURN;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_to_user_id) THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'To user does not exist'::VARCHAR;
        RETURN;
    END IF;
    
    -- Check balance
    SELECT balance INTO v_from_balance FROM accounts WHERE user_id = p_from_user_id;
    
    IF v_from_balance < p_amount THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Insufficient balance'::VARCHAR;
        RETURN;
    END IF;
    
    -- Create transaction
    INSERT INTO transactions (from_user_id, to_user_id, amount, status, reference_id)
    VALUES (p_from_user_id, p_to_user_id, p_amount, 'completed', COALESCE(p_reference_id, gen_random_uuid()::VARCHAR))
    RETURNING transaction_id INTO v_transaction_id;
    
    -- Update balances
    UPDATE accounts SET balance = balance - p_amount WHERE user_id = p_from_user_id;
    UPDATE accounts SET balance = balance + p_amount WHERE user_id = p_to_user_id;
    
    -- Update payment status
    INSERT INTO payment_status (transaction_id, status, notification_sent)
    VALUES (v_transaction_id, 'completed', false);
    
    RETURN QUERY SELECT true, v_transaction_id, NULL::VARCHAR;
END;
$$ LANGUAGE plpgsql;

-- Procedure: Get user transaction history
CREATE OR REPLACE FUNCTION get_user_transactions(
    p_user_id INTEGER,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    transaction_id INTEGER,
    from_user_id INTEGER,
    to_user_id INTEGER,
    amount DECIMAL,
    status VARCHAR,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.transaction_id,
        t.from_user_id,
        t.to_user_id,
        t.amount,
        t.status::VARCHAR,
        t.created_at
    FROM transactions t
    WHERE t.from_user_id = p_user_id OR t.to_user_id = p_user_id
    ORDER BY t.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- ===== SAMPLE DATA =====

-- Insert sample users (optional - for testing)
-- INSERT INTO users (email, name) VALUES
-- ('user1@bank.local', 'John Doe'),
-- ('user2@bank.local', 'Jane Smith'),
-- ('user3@bank.local', 'Bob Johnson');

-- ===== INDEXES FOR PERFORMANCE =====

CREATE INDEX idx_transactions_composite ON transactions(from_user_id, to_user_id, created_at);
CREATE INDEX idx_accounts_balance ON accounts(balance) WHERE is_active = true;
CREATE INDEX idx_notifications_unread ON notifications(user_id, email_sent) WHERE email_sent = false;

