import React, { useState } from 'react';
import { toast } from 'react-toastify';
import { paymentService } from '../services/api';

export default function PaymentSimulator({ onPaymentCreated }) {
  const [loading, setLoading] = useState(false);
  const [paymentType, setPaymentType] = useState('manual');
  const [fromUserId, setFromUserId] = useState('');
  const [toUserId, setToUserId] = useState('');
  const [amount, setAmount] = useState('');
  const [bulkCount, setBulkCount] = useState(50);
  const [createdTransactions, setCreatedTransactions] = useState([]);

  const handleCreateManualPayment = async () => {
    if (!fromUserId || !toUserId || !amount) {
      toast.error('Please fill in all fields');
      return;
    }

    if (fromUserId === toUserId) {
      toast.error('Cannot transfer to the same user');
      return;
    }

    if (parseFloat(amount) <= 0) {
      toast.error('Amount must be greater than 0');
      return;
    }

    setLoading(true);
    try {
      const response = await paymentService.createPayment(
        parseInt(fromUserId),
        parseInt(toUserId),
        parseFloat(amount),
        'Manual payment'
      );

      if (response.data.success) {
        toast.success(`✅ Payment created: Transaction ID ${response.data.transaction_id}`);
        setCreatedTransactions([response.data, ...createdTransactions]);
        setFromUserId('');
        setToUserId('');
        setAmount('');
        onPaymentCreated?.();
      } else {
        toast.error(`❌ Error: ${response.data.error}`);
      }
    } catch (error) {
      toast.error(`❌ Error creating payment: ${error.message}`);
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateBulkPayments = async () => {
    if (bulkCount < 1 || bulkCount > 500) {
      toast.error('Please enter a number between 1 and 500');
      return;
    }

    setLoading(true);
    try {
      const response = await paymentService.createBulkPayments(bulkCount);

      if (response.data.success) {
        setCreatedTransactions(response.data.transactions || []);
        toast.success(`✅ Created ${response.data.created_count} transactions!`);
        onPaymentCreated?.();
      } else {
        toast.error(`❌ Error: ${response.data.error}`);
      }
    } catch (error) {
      toast.error(`❌ Error creating payments: ${error.message}`);
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* Manual Payment */}
      <div className="card">
        <h3 className="text-2xl font-bold mb-4">💳 Create Single Payment</h3>
        <p className="text-gray-600 mb-4">
          Transfer money between specific users.
        </p>

        <div className="mb-4">
          <label className="block text-sm font-semibold mb-2">From User ID:</label>
          <input
            type="number"
            value={fromUserId}
            onChange={(e) => setFromUserId(e.target.value)}
            placeholder="e.g., 1"
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          />
        </div>

        <div className="mb-4">
          <label className="block text-sm font-semibold mb-2">To User ID:</label>
          <input
            type="number"
            value={toUserId}
            onChange={(e) => setToUserId(e.target.value)}
            placeholder="e.g., 2"
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          />
        </div>

        <div className="mb-4">
          <label className="block text-sm font-semibold mb-2">Amount:</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="e.g., 100.00"
            step="0.01"
            min="0"
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          />
        </div>

        <button
          onClick={handleCreateManualPayment}
          disabled={loading}
          className={`w-full btn-primary ${loading ? 'opacity-50 cursor-not-allowed' : ''}`}
        >
          {loading ? '⏳ Processing...' : '➡️ Send Payment'}
        </button>
      </div>

      {/* Bulk Payments */}
      <div className="card">
        <h3 className="text-2xl font-bold mb-4">🚀 Bulk Payments Simulator</h3>
        <p className="text-gray-600 mb-4">
          Create multiple random transactions between users.
        </p>

        <div className="mb-4">
          <label className="block text-sm font-semibold mb-2">Number of transactions:</label>
          <input
            type="number"
            min="1"
            max="500"
            value={bulkCount}
            onChange={(e) => setBulkCount(parseInt(e.target.value) || 1)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          />
          <p className="text-xs text-gray-500 mt-1">Max 500 transactions per request</p>
        </div>

        <div className="bg-blue-50 p-3 rounded mb-4 text-sm">
          <p className="font-semibold mb-1">📊 Simulation Details:</p>
          <ul className="text-gray-700 space-y-1">
            <li>✓ Random users selected</li>
            <li>✓ Incremental amounts: $10, $20, $30...</li>
            <li>✓ Automatic balance updates</li>
            <li>✓ Notifications sent via Pub/Sub</li>
          </ul>
        </div>

        <button
          onClick={handleCreateBulkPayments}
          disabled={loading}
          className={`w-full btn-primary ${loading ? 'opacity-50 cursor-not-allowed' : ''}`}
        >
          {loading ? '⏳ Processing...' : `🎯 Create ${bulkCount} Payments`}
        </button>
      </div>

      {/* Created Transactions */}
      {createdTransactions.length > 0 && (
        <div className="card lg:col-span-2">
          <h3 className="text-2xl font-bold mb-4">📜 Recent Transactions ({createdTransactions.length})</h3>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-2 text-left font-semibold">TX ID</th>
                  <th className="px-4 py-2 text-left font-semibold">From → To</th>
                  <th className="px-4 py-2 text-left font-semibold">Amount</th>
                  <th className="px-4 py-2 text-left font-semibold">Status</th>
                  <th className="px-4 py-2 text-left font-semibold">Reference</th>
                </tr>
              </thead>
              <tbody>
                {createdTransactions.slice(0, 10).map((tx, idx) => (
                  <tr key={idx} className="table-row">
                    <td className="px-4 py-2 font-mono text-blue-600">{tx.transaction_id}</td>
                    <td className="px-4 py-2">
                      {tx.from_user_id} → {tx.to_user_id}
                    </td>
                    <td className="px-4 py-2 font-semibold text-green-600">
                      ${parseFloat(tx.amount).toFixed(2)}
                    </td>
                    <td className="px-4 py-2">
                      <span className={`px-2 py-1 rounded text-xs font-semibold ${
                        tx.status === 'completed' 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-yellow-100 text-yellow-800'
                      }`}>
                        {tx.status}
                      </span>
                    </td>
                    <td className="px-4 py-2 text-xs text-gray-500 font-mono">
                      {tx.reference_id?.substring(0, 8)}...
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {createdTransactions.length > 10 && (
            <p className="text-gray-500 text-sm mt-2">
              Showing 10 of {createdTransactions.length} transactions
            </p>
          )}
        </div>
      )}

      {/* Flow Explanation */}
      <div className="card lg:col-span-2 bg-purple-50">
        <h3 className="text-lg font-bold mb-2">🔄 Payment Flow</h3>
        <div className="space-y-2 text-sm text-gray-700">
          <div className="flex items-center">
            <span className="font-bold text-purple-600 mr-2">1.</span>
            <span>Frontend sends payment data to API Handler (HTTP)</span>
          </div>
          <div className="flex items-center">
            <span className="font-bold text-purple-600 mr-2">2.</span>
            <span>API validates & stores transaction in Cloud SQL</span>
          </div>
          <div className="flex items-center">
            <span className="font-bold text-purple-600 mr-2">3.</span>
            <span>Database trigger publishes to Pub/Sub topic</span>
          </div>
          <div className="flex items-center">
            <span className="font-bold text-purple-600 mr-2">4.</span>
            <span>Notification Handler processes message</span>
          </div>
          <div className="flex items-center">
            <span className="font-bold text-purple-600 mr-2">5.</span>
            <span>Email notifications sent to users</span>
          </div>
          <div className="flex items-center">
            <span className="font-bold text-purple-600 mr-2">6.</span>
            <span>All logs aggregated in Cloud Logging</span>
          </div>
        </div>
      </div>
    </div>
  );
}
