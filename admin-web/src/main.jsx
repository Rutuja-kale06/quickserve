import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { supabase } from './supabase';
import './styles.css';

const statuses = ['created','assigned','accepted','in_progress','completed','cancelled'];

function Login({onLogin}) {
  const [email,setEmail]=useState('');
  const [password,setPassword]=useState('');
  const [error,setError]=useState('');
  const submit=async e=>{
    e.preventDefault(); setError('');
    const {data,error}=await supabase.auth.signInWithPassword({email,password});
    if(error){setError(error.message);return;}
    const {data:p}=await supabase.from('profiles').select('*').eq('id',data.user.id).single();
    if(p?.role!=='admin'){await supabase.auth.signOut();setError('This portal is for administrators only.');return;}
    onLogin(p);
  };
  return <div className="login"><div className="login-card">
    <div className="brand">⚙️ QuickServe</div>
    <p className="muted">SWASIQ Administration Portal</p>
    <form onSubmit={submit}>
      <label>Email<input value={email} onChange={e=>setEmail(e.target.value)} type="email" required/></label>
      <label>Password<input value={password} onChange={e=>setPassword(e.target.value)} type="password" required/></label>
      {error&&<div className="error">{error}</div>}
      <button className="primary">Login</button>
    </form>
  </div></div>
}

function App(){
  const [session,setSession]=useState(null);
  const [profile,setProfile]=useState(null);
  const [requests,setRequests]=useState([]);
  const [agents,setAgents]=useState([]);
  const [customers,setCustomers]=useState([]);
  const [logs,setLogs]=useState([]);
  const [filter,setFilter]=useState('all');
  const [search,setSearch]=useState('');
  const [loading,setLoading]=useState(true);

  useEffect(()=>{
    supabase.auth.getSession().then(async ({data})=>{
      if(data.session){
        const {data:p}=await supabase.from('profiles').select('*').eq('id',data.session.user.id).single();
        if(p?.role==='admin'){setSession(data.session);setProfile(p);await load();}
      }
      setLoading(false);
    });
  },[]);

  async function load(){
    const [{data:r},{data:a},{data:c},{data:l}] = await Promise.all([
      supabase.from('service_requests').select('*, services(name), customer:profiles!service_requests_customer_id_fkey(full_name,phone), agent:profiles!service_requests_assigned_agent_id_fkey(full_name)').order('created_at',{ascending:false}),
      supabase.from('profiles').select('*').eq('role','agent').order('full_name'),
      supabase.from('profiles').select('*').eq('role','customer').order('full_name'),
      supabase.from('audit_logs').select('*').order('created_at',{ascending:false}).limit(100)
    ]);
    setRequests(r||[]);setAgents(a||[]);setCustomers(c||[]);setLogs(l||[]);
  }

  async function logout(){await supabase.auth.signOut();setSession(null);setProfile(null);}
  if(loading) return <div className="center">Loading…</div>;
  if(!session) return <Login onLogin={async p=>{const {data}=await supabase.auth.getSession();setSession(data.session);setProfile(p);load();}}/>;

  const filtered=requests.filter(r=>
    (filter==='all'||r.status===filter) &&
    (`${r.request_code} ${r.description} ${r.customer?.full_name||''}`.toLowerCase().includes(search.toLowerCase()))
  );
  const count=s=>requests.filter(r=>r.status===s).length;

  async function assign(id, agentId){
    const {error}=await supabase.from('service_requests').update({assigned_agent_id:agentId||null,status:agentId?'assigned':'created'}).eq('id',id);
    if(error) alert(error.message); else load();
  }
  async function status(id,status){
    const {error}=await supabase.from('service_requests').update({status}).eq('id',id);
    if(error) alert(error.message); else load();
  }

  return <div className="app">
    <header><div className="brand">⚙️ QuickServe <span>Admin</span></div><div className="header-right">{profile.full_name} <button onClick={logout}>Logout</button></div></header>
    <main>
      <div className="welcome"><div><h1>Operations Dashboard</h1><p className="muted">Manage service requests, assignments and activity.</p></div><button onClick={load}>↻ Refresh</button></div>
      <div className="stats">
        <Stat label="Total" value={requests.length}/>
        <Stat label="New" value={count('created')}/>
        <Stat label="Assigned" value={count('assigned')}/>
        <Stat label="In Progress" value={count('in_progress')}/>
        <Stat label="Completed" value={count('completed')}/>
        <Stat label="Cancelled" value={count('cancelled')}/>
      </div>
      <section className="panel">
        <div className="toolbar"><input placeholder="Search request/customer…" value={search} onChange={e=>setSearch(e.target.value)}/>
          <select value={filter} onChange={e=>setFilter(e.target.value)}><option value="all">All statuses</option>{statuses.map(s=><option key={s} value={s}>{s.replace('_',' ')}</option>)}</select>
        </div>
        <div className="table-wrap"><table><thead><tr><th>Request</th><th>Customer</th><th>Service</th><th>Status</th><th>Priority</th><th>Agent</th><th>Action</th></tr></thead>
        <tbody>{filtered.map(r=><tr key={r.id}>
          <td><b>{r.request_code}</b><small>{new Date(r.created_at).toLocaleString()}</small></td>
          <td>{r.customer?.full_name||'—'}<small>{r.customer?.phone||''}</small></td>
          <td>{r.services?.name||'—'}</td>
          <td><span className="badge">{r.status.replace('_',' ')}</span></td>
          <td>{r.priority}</td>
          <td><select value={r.assigned_agent_id||''} onChange={e=>assign(r.id,e.target.value)}><option value="">Unassigned</option>{agents.map(a=><option key={a.id} value={a.id}>{a.full_name||a.id.slice(0,8)}</option>)}</select></td>
          <td><select value={r.status} onChange={e=>status(r.id,e.target.value)}>{statuses.map(s=><option key={s} value={s}>{s.replace('_',' ')}</option>)}</select></td>
        </tr>)}</tbody></table></div>
      </section>
      <div className="grid2">
        <section className="panel"><h2>Customers ({customers.length})</h2>{customers.slice(0,10).map(c=><div className="person" key={c.id}><b>{c.full_name||'Unnamed'}</b><span>{c.phone||'No phone'}</span></div>)}</section>
        <section className="panel"><h2>Agents ({agents.length})</h2>{agents.map(a=><div className="person" key={a.id}><b>{a.full_name||'Unnamed'}</b><span>{a.phone||'Available'}</span></div>)}</section>
      </div>
      <section className="panel"><h2>Audit / Activity</h2><div className="activity">{logs.map(l=><div className="activity-row" key={l.id}><span className="badge">{l.event_type}</span><span>{l.request_id?`Request ${l.request_id.slice(0,8)}`:'System'}</span><time>{new Date(l.created_at).toLocaleString()}</time></div>)}</div></section>
    </main>
  </div>
}

function Stat({label,value}){return <div className="stat"><span>{label}</span><strong>{value}</strong></div>}
createRoot(document.getElementById('root')).render(<App/>);
