import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8080/api';

const API = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  }
});

// Add error interceptor
API.interceptors.response.use(
  response => response,
  error => {
    console.error('API Error:', error);
    return Promise.reject(error);
  }
);

export const userService = {
  createUser: (email, name) => 
    API.post('/operations', {
      type: 'user',
      data: { email, name }
    }),
  
  createBulkUsers: (count) =>
    API.post('/operations', {
      type: 'bulk',
      count
    }),

  getUserTransactions: (userId, limit = 50) =>
    API.post('/operations', {
      type: 'history',
      user_id: userId,
      limit
    })
};

export const paymentService = {
  createPayment: (fromUserId, toUserId, amount, description = '') =>
    API.post('/operations', {
      type: 'payment',
      data: {
        from_user_id: fromUserId,
        to_user_id: toUserId,
        amount,
        description
      }
    }),

  createBulkPayments: (count) =>
    API.post('/operations', {
      type: 'bulk_payments',
      count
    })
};

export const healthService = {
  check: () => API.get('/health')
};

export default API;
