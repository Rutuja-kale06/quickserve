import React, { useCallback, useEffect, useState } from 'react';
import Login from './components/Login';
import Dashboard from './components/Dashboard';
import RequestsPanel from './components/RequestsPanel';
import People from './components/People';
import AuditLog from './components/AuditLog';
import { fetchDashboard, logEvent, supabase } from './api';

export default function App() {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [data, setData] = useState({ requests: [], agents: [], customers: [], logs: [] });
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState(null);

  const notify = useCallback((message, type = 'error') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 4000);
  }, []);

  const load = useCallback(async () => {
    try {
      setData(await fetchDashboard());
    } catch (err) {
      notify(err.message);
    }
  }, [notify]);

  useEffect(() => {
    supabase.auth.getSession().then(async ({ data: d }) => {
      if (d.session) {
        const { data: p } = await supabase.from('profiles').select('*').eq('id', d.session.user.id).single();
        if (p?.role === 'admin') {
          setSession(d.session);
          setProfile(p);
          await load();
        }
      }
      setLoading(false);
    }).catch(() => setLoading(false));
  }, [load]);

  const handleLogin = async (p) => {
    const { data } = await supabase.auth.getSession();
    setSession(data.session);
    setProfile(p);
    await load();
  };

  const logout = async () => {
    await logEvent('LOGOUT', {});
    await supabase.auth.signOut();
    setSession(null);
    setProfile(null);
  };

  if (loading) return <div className="center">Loading…</div>;
  if (!session) return <Login onLogin={handleLogin} />;

  const { requests, agents, customers, logs } = data;

  return (
    <div className="app">
      <header>
        <div className="brand">QuickServe <span>Admin</span></div>
        <div className="header-right">
          {profile.full_name || 'Admin'}
          <button onClick={logout}>Logout</button>
        </div>
      </header>

      <main>
        <div className="welcome">
          <div>
            <h1>Operations Dashboard</h1>
            <p className="muted">Manage service requests, assignments and activity.</p>
          </div>
          <button className="ghost" onClick={load}>Refresh</button>
        </div>

        <Dashboard requests={requests} />
        <RequestsPanel requests={requests} agents={agents} onChanged={load} onError={notify} />
        <People customers={customers} agents={agents} />
        <AuditLog logs={logs} />
      </main>

      {toast && <div className={`toast ${toast.type === 'error' ? 'toast-error' : 'toast-ok'}`}>{toast.message}</div>}
    </div>
  );
}