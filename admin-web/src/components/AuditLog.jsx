import React, { useState } from 'react';

export default function AuditLog({ logs }) {
  const [open, setOpen] = useState(false);
  return (
    <section className="panel">
      <h2>Audit / Activity</h2>
      {logs.length === 0 ? (
        <p className="muted">No audit events yet.</p>
      ) : (
        <>
          <div className="activity">
            {(open ? logs : logs.slice(0, 12)).map((l) => (
              <div className="activity-row" key={l.id}>
                <span className="badge">{l.event_type}</span>
                <span>
                  {l.request_id ? `Request ${l.request_id.slice(0, 8)}` : 'System'}
                  {l.metadata && Object.keys(l.metadata).length ? ` · ${JSON.stringify(l.metadata)}` : ''}
                </span>
                <time>{new Date(l.created_at).toLocaleString()}</time>
              </div>
            ))}
          </div>
          {logs.length > 12 && (
            <button className="ghost" onClick={() => setOpen(!open)}>
              {open ? 'Show fewer' : `Show all (${logs.length})`}
            </button>
          )}
        </>
      )}
    </section>
  );
}