import React, { useState } from 'react';
import { toast } from 'react-toastify';
import { userService } from '../services/api';

export default function UserManagement({ onUsersCreated }) {
  const [loading, setLoading] = useState(false);
  const [bulkCount, setBulkCount] = useState(50);
  const [manualEmail, setManualEmail] = useState('');
  const [manualName, setManualName] = useState('');
  const [createdUsers, setCreatedUsers] = useState([]);

  const handleCreateBulkUsers = async () => {
    if (bulkCount < 1 || bulkCount > 1000) {
      toast.error('Please enter a number between 1 and 1000');
      return;
    }

    setLoading(true);
    try {
      const response = await userService.createBulkUsers(bulkCount);
      
      if (response.data.success) {
        setCreatedUsers(response.data.users || []);
        toast.success(`✅ Created ${response.data.created_count} users successfully!`);
        onUsersCreated?.();
      } else {
        toast.error(`❌ Error: ${response.data.error}`);
      }
    } catch (error) {
      toast.error(`❌ Error creating users: ${error.message}`);
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateManualUser = async () => {
    if (!manualEmail.trim() || !manualName.trim()) {
      toast.error('Please fill in all fields');
      return;
    }

    if (!manualEmail.includes('@')) {
      toast.error('Please enter a valid email');
      return;
    }

    setLoading(true);
    try {
      const response = await userService.createUser(manualEmail, manualName);
      
      if (response.data.success) {
        toast.success(`✅ User created: ${response.data.name}`);
        setManualEmail('');
        setManualName('');
        setCreatedUsers([response.data, ...createdUsers]);
        onUsersCreated?.();
      } else {
        toast.error(`❌ Error: ${response.data.error}`);
      }
    } catch (error) {
      toast.error(`❌ Error creating user: ${error.message}`);
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* Bulk User Creation */}
      <div className="card">
        <h3 className="text-2xl font-bold mb-4">📦 Bulk User Creation</h3>
        <p className="text-gray-600 mb-4">
          Create multiple dummy users at once. Each user gets an initial balance of $1000.
        </p>

        <div className="mb-4">
          <label className="block text-sm font-semibold mb-2">Number of users:</label>
          <input
            type="number"
            min="1"
            max="1000"
            value={bulkCount}
            onChange={(e) => setBulkCount(parseInt(e.target.value) || 1)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          />
          <p className="text-xs text-gray-500 mt-1">Max 1000 users per request</p>
        </div>

        <button
          onClick={handleCreateBulkUsers}
          disabled={loading}
          className={`w-full btn-primary ${loading ? 'opacity-50 cursor-not-allowed' : ''}`}
        >
          {loading ? '⏳ Creating...' : '➕ Create Bulk Users'}
        </button>
      </div>

      {/* Manual User Creation */}
      <div className="card">
        <h3 className="text-2xl font-bold mb-4">➕ Create Single User</h3>
        <p className="text-gray-600 mb-4">
          Manually create a single user with custom details.
        </p>

        <div className="mb-4">
          <label className="block text-sm font-semibold mb-2">Email:</label>
          <input
            type="email"
            value={manualEmail}
            onChange={(e) => setManualEmail(e.target.value)}
            placeholder="user@example.com"
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          />
        </div>

        <div className="mb-4">
          <label className="block text-sm font-semibold mb-2">Name:</label>
          <input
            type="text"
            value={manualName}
            onChange={(e) => setManualName(e.target.value)}
            placeholder="John Doe"
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          />
        </div>

        <button
          onClick={handleCreateManualUser}
          disabled={loading}
          className={`w-full btn-primary ${loading ? 'opacity-50 cursor-not-allowed' : ''}`}
        >
          {loading ? '⏳ Creating...' : '✨ Create User'}
        </button>
      </div>

      {/* Created Users List */}
      {createdUsers.length > 0 && (
        <div className="card lg:col-span-2">
          <h3 className="text-2xl font-bold mb-4">📋 Recently Created Users ({createdUsers.length})</h3>
          
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-2 text-left font-semibold">User ID</th>
                  <th className="px-4 py-2 text-left font-semibold">Email</th>
                  <th className="px-4 py-2 text-left font-semibold">Name</th>
                  <th className="px-4 py-2 text-left font-semibold">Initial Balance</th>
                </tr>
              </thead>
              <tbody>
                {createdUsers.slice(0, 10).map(user => (
                  <tr key={user.user_id} className="table-row">
                    <td className="px-4 py-2 font-mono text-blue-600">{user.user_id}</td>
                    <td className="px-4 py-2">{user.email}</td>
                    <td className="px-4 py-2">{user.name}</td>
                    <td className="px-4 py-2 font-semibold text-green-600">
                      ${user.initial_balance || 1000.00}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {createdUsers.length > 10 && (
            <p className="text-gray-500 text-sm mt-2">
              Showing 10 of {createdUsers.length} users. Scroll down to see more.
            </p>
          )}
        </div>
      )}

      {/* Info Card */}
      <div className="card lg:col-span-2 bg-blue-50">
        <h3 className="text-lg font-bold mb-2">ℹ️ How It Works</h3>
        <ul className="text-sm text-gray-700 space-y-2">
          <li>✅ Users are stored in Cloud SQL (PostgreSQL)</li>
          <li>✅ Each user gets an account with $1000 initial balance</li>
          <li>✅ Database triggers automatically publish notifications to Pub/Sub</li>
          <li>✅ Cloud Functions process notifications and send emails</li>
          <li>✅ All operations are logged and monitored</li>
        </ul>
      </div>
    </div>
  );
}
