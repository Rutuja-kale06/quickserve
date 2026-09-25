import React, { useMemo, useState } from 'react';
import { assignAgent, setStatus } from '../api';
import RequestDetailsModal from './RequestDetailsModal';

const STATUSES = ['created', 'assigned', 'accepted', 'in_progress', 'completed', 'cancelled'];

export default function RequestsPanel({ requests, agents, onChanged, onError }) {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all');
  const [selected, setSelected] = useState(null);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return requests.filter(
      (r) =>
        (filter === 'all' || r.status === filter) &&
        (q === '' ||
          `${r.request_code} ${r.description} ${r.customer?.full_name ?? ''} ${r.services?.name ?? ''}`
            .toLowerCase()
            .includes(q))
    );
  }, [requests, search, filter]);

  const tryAction = async (fn) => {
    try {
      await fn();
      onChanged();
    } catch (err) {
      onError(err.message);
    }
  };

  return (
    <section className="panel">
      <div className="toolbar">
        <input
          placeholder="Search request, customer or service…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="all">All statuses</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>{s.replace('_', ' ')}</option>
          ))}
        </select>
      </div>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Request</th>
              <th>Customer</th>
              <th>Service</th>
              <th>Status</th>
              <th>Priority</th>
              <th>Assigned agent</th>
              <th>Change status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((r) => (
              <tr key={r.id}>
                <td>
                  <b>{r.request_code}</b>
                  <small>{new Date(r.created_at).toLocaleString()}</small>
                </td>
                <td>
                  {r.customer?.full_name ?? '-'}
                  <small>{r.customer?.phone ?? ''}</small>
                </td>
                <td>{r.services?.name ?? '-'}</td>
                <td><span className="badge">{r.status.replace('_', ' ')}</span></td>
                <td>{r.priority}</td>
                <td>
                  <select
                    value={r.assigned_agent_id ?? ''}
                    onChange={(e) =>
                      tryAction(() => assignAgent(r.id, e.target.value))
                    }
                  >
                    <option value="">Unassigned</option>
                    {agents.map((a) => (
                      <option key={a.id} value={a.id}>{a.full_name || a.id.slice(0, 8)}</option>
                    ))}
                  </select>
                </td>
                <td>
                  <select
                    value={r.status}
                    onChange={(e) => tryAction(() => setStatus(r.id, e.target.value))}
                  >
                    {STATUSES.map((s) => (
                      <option key={s} value={s}>{s.replace('_', ' ')}</option>
                    ))}
                  </select>
                </td>
                <td>
                  <button className="ghost" onClick={() => setSelected(r)}>Details</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {selected && (
        <RequestDetailsModal request={selected} onClose={() => setSelected(null)} />
      )}
    </section>
  );
}