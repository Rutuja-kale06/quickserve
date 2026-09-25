import React, { useEffect, useState } from 'react';
import { fetchHistory } from '../api';

export default function RequestDetailsModal({ request, onClose }) {
  const [history, setHistory] = useState([]);

  useEffect(() => {
    fetchHistory(request.id)
      .then(setHistory)
      .catch(() => setHistory([]));
  }, [request.id]);

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <h2>{request.request_code}</h2>
          <button className="ghost" onClick={onClose}>Close</button>
        </div>
        <div className="modal-body">
          <div className="detail-grid">
            <div><label>Service</label><p>{request.services?.name ?? '-'}</p></div>
            <div><label>Status</label><p><span className="badge">{request.status.replace('_', ' ')}</span></p></div>
            <div><label>Priority</label><p>{request.priority}</p></div>
            <div><label>Created</label><p>{new Date(request.created_at).toLocaleString()}</p></div>
            <div><label>Customer</label><p>{request.customer?.full_name ?? '-'}{request.customer?.phone ? ` · ${request.customer.phone}` : ''}</p></div>
            <div><label>Assigned agent</label><p>{request.agent?.full_name ?? 'Unassigned'}</p></div>
            <div><label>Preferred</label><p>{new Date(request.preferred_at).toLocaleString()}</p></div>
            <div><label>Address</label><p>{request.address}</p></div>
          </div>
          <label>Description</label>
          <p className="detail-description">{request.description}</p>
          {request.notes && (<><label>Progress notes</label><p className="detail-description">{request.notes}</p></>)}

          <label>Status history</label>
          {history.length === 0 ? (
            <p className="muted">No history recorded.</p>
          ) : (
            <ul className="timeline">
              {history.map((h, i) => (
                <li key={i}>
                  <b>
                    {h.old_status ? `${h.old_status.replace('_', ' ')} → ${h.new_status.replace('_', ' ')}` : h.new_status.replace('_', ' ')}
                  </b>
                  <span>
                    {h.changed_by?.full_name ?? 'System'} · {new Date(h.created_at).toLocaleString()}
                    {h.note ? ` · ${h.note}` : ''}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}