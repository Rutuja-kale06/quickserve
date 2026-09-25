import React, { useState } from 'react';
import { logEvent, supabase } from '../api';

export default function Login({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const submit = async (e) => {
    e.preventDefault();
    setError('');
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      await logEvent('LOGIN_FAILED', { email, reason: error.message });
      setError(error.message);
      return;
    }
    const { data: profile } = await supabase.from('profiles').select('*').eq('id', data.user.id).single();
    if (profile?.role !== 'admin') {
      // Still signed in briefly so the authorisation failure can be audited.
      await logEvent('AUTHORIZATION_FAILED', { email, reason: 'non-admin attempted admin portal' });
      await supabase.auth.signOut();
      setError('This portal is for administrators only.');
      return;
    }
    await logEvent('LOGIN_SUCCESS', { email });
    onLogin(profile);
  };

  return (
    <div className="login">
      <div className="login-card">
        <div className="brand">QuickServe <span>Admin</span></div>
        <p className="muted">SWASIQ Administration Portal</p>
        <form onSubmit={submit}>
          <label>Email<input value={email} onChange={(e) => setEmail(e.target.value)} type="email" required /></label>
          <label>Password<input value={password} onChange={(e) => setPassword(e.target.value)} type="password" required /></label>
          {error && <div className="error">{error}</div>}
          <button className="primary">Login</button>
        </form>
      </div>
    </div>
  );
}