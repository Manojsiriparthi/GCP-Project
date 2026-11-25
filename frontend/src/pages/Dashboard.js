import React from 'react';

export default function Dashboard({ stats }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
      {/* Stats Cards */}
      <div className="card">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-gray-500 text-sm font-semibold">Total Users</p>
            <p className="text-3xl font-bold text-blue-600">{stats.totalUsers || 0}</p>
          </div>
          <div className="text-5xl">👥</div>
        </div>
      </div>

      <div className="card">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-gray-500 text-sm font-semibold">Total Transactions</p>
            <p className="text-3xl font-bold text-green-600">{stats.totalTransactions || 0}</p>
          </div>
          <div className="text-5xl">💱</div>
        </div>
      </div>

      <div className="card">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-gray-500 text-sm font-semibold">Total Volume</p>
            <p className="text-3xl font-bold text-purple-600">${stats.totalVolume || 0}</p>
          </div>
          <div className="text-5xl">💰</div>
        </div>
      </div>

      {/* Information Cards */}
      <div className="card md:col-span-2">
        <h3 className="text-xl font-bold mb-4">📋 Architecture Overview</h3>
        <div className="space-y-3 text-sm">
          <div className="flex items-start">
            <span className="font-bold text-blue-600 mr-2">1.</span>
            <p><strong>Frontend:</strong> React app hosted on Cloud Storage (static files)</p>
          </div>
          <div className="flex items-start">
            <span className="font-bold text-blue-600 mr-2">2.</span>
            <p><strong>API Handler:</strong> Cloud Function routes requests to database</p>
          </div>
          <div className="flex items-start">
            <span className="font-bold text-blue-600 mr-2">3.</span>
            <p><strong>Database:</strong> Cloud SQL (PostgreSQL) with triggers</p>
          </div>
          <div className="flex items-start">
            <span className="font-bold text-blue-600 mr-2">4.</span>
            <p><strong>Messaging:</strong> Pub/Sub topics with DLQ for event handling</p>
          </div>
          <div className="flex items-start">
            <span className="font-bold text-blue-600 mr-2">5.</span>
            <p><strong>Notifications:</strong> Email notifications via Gmail API</p>
          </div>
          <div className="flex items-start">
            <span className="font-bold text-blue-600 mr-2">6.</span>
            <p><strong>Monitoring:</strong> Cloud Logging & Cloud Monitoring dashboards</p>
          </div>
        </div>
      </div>

      <div className="card">
        <h3 className="text-xl font-bold mb-4">🚀 Quick Start</h3>
        <ul className="space-y-2 text-sm">
          <li>✅ Create users (single or bulk)</li>
          <li>✅ Simulate payments</li>
          <li>✅ View transaction history</li>
          <li>✅ Monitor activity logs</li>
          <li>✅ Check email notifications</li>
        </ul>
      </div>

      {/* Features */}
      <div className="card md:col-span-3">
        <h3 className="text-xl font-bold mb-4">🎯 Key Features</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="border-l-4 border-blue-600 pl-4">
            <h4 className="font-bold">Bulk Operations</h4>
            <p className="text-gray-600 text-sm">Create 50+ users and transactions at once</p>
          </div>
          <div className="border-l-4 border-green-600 pl-4">
            <h4 className="font-bold">Real-time Notifications</h4>
            <p className="text-gray-600 text-sm">Email alerts for every transaction</p>
          </div>
          <div className="border-l-4 border-purple-600 pl-4">
            <h4 className="font-bold">Transaction Simulator</h4>
            <p className="text-gray-600 text-sm">Simulate random payments between users</p>
          </div>
          <div className="border-l-4 border-orange-600 pl-4">
            <h4 className="font-bold">Complete Audit Trail</h4>
            <p className="text-gray-600 text-sm">All transactions logged and monitored</p>
          </div>
        </div>
      </div>

      {/* GCP Services Info */}
      <div className="card md:col-span-3 bg-gradient-to-r from-blue-50 to-indigo-50">
        <h3 className="text-xl font-bold mb-4">☁️ GCP Services Used</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
          <div>
            <span className="font-bold text-blue-600">Cloud Storage</span>
            <p className="text-gray-600">Static website hosting</p>
          </div>
          <div>
            <span className="font-bold text-blue-600">Cloud SQL</span>
            <p className="text-gray-600">PostgreSQL database</p>
          </div>
          <div>
            <span className="font-bold text-blue-600">Cloud Functions</span>
            <p className="text-gray-600">Serverless compute</p>
          </div>
          <div>
            <span className="font-bold text-blue-600">Pub/Sub</span>
            <p className="text-gray-600">Message queue with DLQ</p>
          </div>
          <div>
            <span className="font-bold text-blue-600">Cloud Logging</span>
            <p className="text-gray-600">Log aggregation</p>
          </div>
          <div>
            <span className="font-bold text-blue-600">Cloud Monitoring</span>
            <p className="text-gray-600">Metrics & dashboards</p>
          </div>
          <div>
            <span className="font-bold text-blue-600">IAM</span>
            <p className="text-gray-600">Least privilege access</p>
          </div>
          <div>
            <span className="font-bold text-blue-600">Secret Manager</span>
            <p className="text-gray-600">Secure credentials</p>
          </div>
        </div>
      </div>
    </div>
  );
}
