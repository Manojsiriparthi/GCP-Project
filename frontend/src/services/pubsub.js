import { PubSub } from '@google-cloud/pubsub';

// Initialize Pub/Sub client (uses GOOGLE_APPLICATION_CREDENTIALS env var)
const pubsub = new PubSub({
  projectId: process.env.REACT_APP_GCP_PROJECT_ID,
});

/**
 * Publish message to Pub/Sub topic
 * @param {string} topicName - Topic name (e.g., 'request-queue')
 * @param {object} message - Message data
 * @returns {Promise<string>} Message ID
 */
export const publishToPubSub = async (topicName, message) => {
  try {
    const topic = pubsub.topic(topicName);
    const messageData = JSON.stringify(message);
    const messageId = await topic.publish(Buffer.from(messageData));
    
    console.log(`Message ${messageId} published to ${topicName}`);
    return messageId;
  } catch (error) {
    console.error(`Failed to publish to ${topicName}:`, error);
    throw error;
  }
};

/**
 * Create a user - Publish to request-queue
 * @param {string} phone - User phone number
 * @returns {Promise<object>} Response object
 */
export const createUser = async (phone) => {
  try {
    const message = {
      type: 'create_user',
      data: {
        phone,
        request_id: `user-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        created_at: new Date().toISOString(),
      },
    };

    const messageId = await publishToPubSub('request-queue', message);
    
    return {
      success: true,
      message: 'User creation queued for processing',
      messageId,
      status: 'pending',
    };
  } catch (error) {
    return {
      success: false,
      message: `Failed to queue user creation: ${error.message}`,
      error: error.message,
    };
  }
};

/**
 * Create a payment - Publish to request-queue
 * @param {number} fromUserId - Sender user ID
 * @param {number} toUserId - Recipient user ID
 * @param {number} amount - Payment amount
 * @returns {Promise<object>} Response object
 */
export const createPayment = async (fromUserId, toUserId, amount) => {
  try {
    // Validate inputs
    if (!fromUserId || !toUserId || !amount) {
      throw new Error('Missing required fields: fromUserId, toUserId, amount');
    }

    if (fromUserId === toUserId) {
      throw new Error('Cannot send payment to yourself');
    }

    if (amount <= 0) {
      throw new Error('Amount must be greater than 0');
    }

    const message = {
      type: 'create_payment',
      data: {
        from_user_id: parseInt(fromUserId),
        to_user_id: parseInt(toUserId),
        amount: parseFloat(amount),
        request_id: `payment-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        created_at: new Date().toISOString(),
      },
    };

    const messageId = await publishToPubSub('request-queue', message);
    
    return {
      success: true,
      message: 'Payment request queued for processing',
      messageId,
      status: 'pending',
    };
  } catch (error) {
    return {
      success: false,
      message: `Failed to queue payment: ${error.message}`,
      error: error.message,
    };
  }
};

/**
 * Batch create users - Multiple messages to queue
 * @param {number} count - Number of users to create
 * @returns {Promise<object>} Batch result
 */
export const batchCreateUsers = async (count) => {
  try {
    if (count < 1 || count > 500) {
      throw new Error('Count must be between 1 and 500');
    }

    const messageIds = [];
    const failed = [];

    for (let i = 0; i < count; i++) {
      try {
        const phone = `${Math.floor(Math.random() * 9000000000) + 1000000000}`;
        const result = await createUser(phone);
        
        if (result.success) {
          messageIds.push(result.messageId);
        } else {
          failed.push({ phone, error: result.message });
        }

        // Add slight delay to avoid rate limiting
        if (i % 10 === 0) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      } catch (error) {
        failed.push({ index: i, error: error.message });
      }
    }

    return {
      success: failed.length === 0,
      queued: messageIds.length,
      failed: failed.length,
      failedDetails: failed,
      message: `Queued ${messageIds.length}/${count} user creations`,
    };
  } catch (error) {
    return {
      success: false,
      message: `Batch create failed: ${error.message}`,
      error: error.message,
    };
  }
};

/**
 * Batch create payments - Multiple messages to queue
 * @param {array} payments - Array of {from_user_id, to_user_id, amount}
 * @returns {Promise<object>} Batch result
 */
export const batchCreatePayments = async (payments) => {
  try {
    if (!Array.isArray(payments) || payments.length === 0) {
      throw new Error('Payments must be a non-empty array');
    }

    if (payments.length > 500) {
      throw new Error('Maximum 500 payments per batch');
    }

    const messageIds = [];
    const failed = [];

    for (let i = 0; i < payments.length; i++) {
      try {
        const { from_user_id, to_user_id, amount } = payments[i];
        const result = await createPayment(from_user_id, to_user_id, amount);
        
        if (result.success) {
          messageIds.push(result.messageId);
        } else {
          failed.push({ payment: payments[i], error: result.message });
        }

        // Add slight delay
        if (i % 10 === 0) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      } catch (error) {
        failed.push({ payment: payments[i], error: error.message });
      }
    }

    return {
      success: failed.length === 0,
      queued: messageIds.length,
      failed: failed.length,
      failedDetails: failed,
      message: `Queued ${messageIds.length}/${payments.length} payment requests`,
    };
  } catch (error) {
    return {
      success: false,
      message: `Batch payment failed: ${error.message}`,
      error: error.message,
    };
  }
};

/**
 * Get queue status - Check message depth in topics
 * @returns {Promise<object>} Queue status
 */
export const getQueueStatus = async () => {
  try {
    const requestQueueSub = pubsub.subscription('request-queue-subscription');
    const notificationQueueSub = pubsub.subscription('notification-queue-subscription');

    const [requestStats] = await requestQueueSub.getMetadata();
    const [notificationStats] = await notificationQueueSub.getMetadata();

    return {
      success: true,
      queues: {
        request: {
          approx_size: requestStats.messageCount || 0,
          oldest_message_age: requestStats.oldestMessageAge || 0,
        },
        notification: {
          approx_size: notificationStats.messageCount || 0,
          oldest_message_age: notificationStats.oldestMessageAge || 0,
        },
      },
    };
  } catch (error) {
    console.warn('Could not fetch queue status:', error.message);
    return {
      success: false,
      message: 'Could not fetch queue status',
      error: error.message,
    };
  }
};

export default {
  publishToPubSub,
  createUser,
  createPayment,
  batchCreateUsers,
  batchCreatePayments,
  getQueueStatus,
};
