import React, { useState, useEffect } from 'react';
import { toast } from 'react-toastify';
import { userService } from '../services/api';

export default function TransactionHistory() {
  const [userId, setUserId] = useState('');
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [userInfo, setUserInfo] = useState(null);

  const handleFetchHistory = async () => {
    if (!userId.trim()) {
      toast.error('Please enter a user ID');
      return;
    }

    setLoading(true);
    try {
      const response = await userService.getUserTransactions(parseInt(userId));

      if (response.data.success) {
        setTransactions(response.data.transactions || []);
        toast.success(`✅ Loaded ${response.data.transaction_count} transactions`);
      } else {
        toast.error(`❌ Error: ${response.data.error}`);
        setTransactions([]);
      }
    } catch (error) {
      toast.error(`❌ Error fetching history: ${error.message}`);
      console.error(error);
      setTransactions([]);
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      handleFetchHistory();
    }
  };

  const getTransactionType = (tx) => {
    return parseInt(userId) === tx.from_user_id ? 'sent' : 'received';
  };

  const getTransactionColor = (tx) => {
    if (parseInt(userId) === tx.from_user_id) {
      return 'text-red-600';
    }
    return 'text-green-600';
  };

  const getTransactionIcon = (tx) => {
    if (parseInt(userId) === tx.from_user_id) {
      return '📤';
    }
    return '📥';
  };

  return (
    <div className="max-w-6xl mx-auto">
      {/* Search Card */}
      <div className="card mb-6">
        <h3 className="text-2xl font-bold mb-4">🔍 Transaction History</h3>
        
        <div className="flex gap-2">
          <input
            type="number"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Enter user ID..."
            className="flex-1 px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          />
          <button
            onClick={handleFetchHistory}
            disabled={loading}
            className={`btn-primary ${loading ? 'opacity-50 cursor-not-allowed' : ''}`}
          >
            {loading ? '⏳ Loading...' : '🔎 Search'}
          </button>
        </div>
        
        <p className="text-xs text-gray-500 mt-2">
          Enter a user ID to view all transactions they sent or received
        </p>
      </div>

      {/* Transactions List */}
      {transactions.length > 0 ? (
        <div className="space-y-4">
          <div className="card">
            <h3 className="text-lg font-bold mb-4">
              📋 {transactions.length} Transaction{transactions.length !== 1 ? 's' : ''} Found
            </h3>

            <div className="space-y-3">
              {transactions.map((tx, idx) => {
                const type = getTransactionType(tx);
                const isReceived = type === 'received';

                return (
                  <div
                    key={idx}
                    className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-3 mb-2">
                          <span className="text-2xl">
                            {getTransactionIcon(tx)}
                          </span>
                          <div>
                            <p className="font-semibold">
                              {isReceived ? 'Received from' : 'Sent to'} User {isReceived ? tx.from_user_id : tx.to_user_id}
                            </p>
                            <p className="text-xs text-gray-500">
                              Transaction ID: {tx.transaction_id}
                            </p>
                          </div>
                        </div>
                      </div>

                      <div className="text-right">
                        <p className={`text-2xl font-bold ${getTransactionColor(tx)}`}>
                          {isReceived ? '+' : '-'}${parseFloat(tx.amount).toFixed(2)}
                        </p>
                        <p className="text-xs text-gray-500">
                          {new Date(tx.created_at).toLocaleString()}
                        </p>
                      </div>
                    </div>

                    {/* Transaction Details */}
                    <div className="mt-3 pt-3 border-t border-gray-100 flex justify-between text-sm">
                      <div>
                        <span className="text-gray-600">Status: </span>
                        <span className={`font-semibold ${
                          tx.status === 'completed' 
                            ? 'text-green-600' 
                            : tx.status === 'pending'
                            ? 'text-yellow-600'
                            : 'text-red-600'
                        }`}>
                          {tx.status.toUpperCase()}
                        </span>
                      </div>
                      <span className="text-gray-600">
                        Type: <span className="font-semibold">Transfer</span>
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Summary Card */}
          <div className="card bg-gradient-to-r from-blue-50 to-indigo-50">
            <h3 className="font-bold mb-3">📊 Summary</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
              <div>
                <p className="text-gray-600">Total Transactions</p>
                <p className="text-2xl font-bold text-blue-600">{transactions.length}</p>
              </div>
              <div>
                <p className="text-gray-600">Total Sent</p>
                <p className="text-2xl font-bold text-red-600">
                  ${transactions
                    .filter(t => t.from_user_id === parseInt(userId))
                    .reduce((sum, t) => sum + parseFloat(t.amount), 0)
                    .toFixed(2)}
                </p>
              </div>
              <div>
                <p className="text-gray-600">Total Received</p>
                <p className="text-2xl font-bold text-green-600">
                  ${transactions
                    .filter(t => t.to_user_id === parseInt(userId))
                    .reduce((sum, t) => sum + parseFloat(t.amount), 0)
                    .toFixed(2)}
                </p>
              </div>
            </div>
          </div>
        </div>
      ) : userId && !loading ? (
        <div className="card bg-yellow-50">
          <p className="text-yellow-800">
            ⚠️ No transactions found for user {userId}. Try a different user ID or create transactions first.
          </p>
        </div>
      ) : null}

      {/* Info Card */}
      <div className="card mt-6 bg-green-50">
        <h3 className="font-bold mb-2">ℹ️ Transaction History Features</h3>
        <ul className="text-sm text-gray-700 space-y-1">
          <li>✓ View all transactions sent by user</li>
          <li>✓ View all transactions received by user</li>
          <li>✓ See transaction status (completed/pending/failed)</li>
          <li>✓ Transaction amounts and timestamps</li>
          <li>✓ Summary statistics (total sent/received)</li>
          <li>✓ All data fetched from Cloud SQL in real-time</li>
        </ul>
      </div>
    </div>
  );
}
