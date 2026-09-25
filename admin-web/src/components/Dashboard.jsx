import React, { useEffect, useState } from 'react';

const STATUSES = ['created', 'assigned', 'accepted', 'in_progress', 'completed', 'cancelled'];

function Stat({ label, value }) {
  return (
    <div className="stat">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

export default function Dashboard({ requests }) {
  const count = (s) => requests.filter((r) => r.status === s).length;
  return (
    <div className="stats">
      <Stat label="Total" value={requests.length} />
      <Stat label="New" value={count('created')} />
      <Stat label="Assigned" value={count('assigned')} />
      <Stat label="In Progress" value={count('in_progress')} />
      <Stat label="Completed" value={count('completed')} />
      <Stat label="Cancelled" value={count('cancelled')} />
    </div>
  );
}