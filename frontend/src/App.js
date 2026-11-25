import React, { useState, useEffect } from 'react';
import { ToastContainer, toast } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
import Dashboard from './pages/Dashboard';
import UserManagement from './pages/UserManagement';
import PaymentSimulator from './pages/PaymentSimulator';
import TransactionHistory from './pages/TransactionHistory';
import API from './services/api';

export default function App() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalTransactions: 0,
    totalVolume: 0
  });

  useEffect(() => {
    // Load stats
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      // This would fetch stats from backend
      // For now, we'll keep it simple
    } catch (error) {
      console.error('Error loading stats:', error);
    }
  };

  const renderTab = () => {
    switch (activeTab) {
      case 'dashboard':
        return <Dashboard stats={stats} />;
      case 'users':
        return <UserManagement onUsersCreated={() => loadStats()} />;
      case 'payments':
        return <PaymentSimulator onPaymentCreated={() => loadStats()} />;
      case 'history':
        return <TransactionHistory />;
      default:
        return <Dashboard stats={stats} />;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <ToastContainer />
      
      {/* Header */}
      <header className="bg-white shadow-md">
        <div className="container mx-auto px-4 py-6">
          <h1 className="text-3xl font-bold text-blue-600">🏦 GCP Bank Transaction Simulator</h1>
          <p className="text-gray-600 mt-2">Learn GCP Services: Cloud SQL, Pub/Sub, Cloud Functions, Monitoring</p>
        </div>
      </header>

      {/* Navigation Tabs */}
      <nav className="bg-white border-b border-gray-200 sticky top-0 z-50">
        <div className="container mx-auto px-4">
          <div className="flex space-x-8">
            {[
              { key: 'dashboard', label: '📊 Dashboard', icon: '📊' },
              { key: 'users', label: '👥 User Management', icon: '👥' },
              { key: 'payments', label: '💳 Payment Simulator', icon: '💳' },
              { key: 'history', label: '📜 Transaction History', icon: '📜' }
            ].map(tab => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`py-4 px-4 font-semibold transition-colors border-b-2 ${
                  activeTab === tab.key
                    ? 'border-blue-600 text-blue-600'
                    : 'border-transparent text-gray-700 hover:text-blue-600'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-8">
        {renderTab()}
      </main>

      {/* Footer */}
      <footer className="bg-gray-800 text-white mt-12">
        <div className="container mx-auto px-4 py-6 text-center">
          <p>GCP Bank App v1.0 | Demonstrating Cloud Storage, Cloud SQL, Pub/Sub, Cloud Functions, Monitoring & IAM</p>
        </div>
      </footer>
    </div>
  );
}
