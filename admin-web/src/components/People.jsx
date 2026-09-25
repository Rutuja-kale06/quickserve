import React from 'react';

function PeoplePanel({ title, people }) {
  return (
    <section className="panel">
      <h2>{title} ({people.length})</h2>
      {people.length === 0 ? (
        <p className="muted">None yet.</p>
      ) : (
        people.slice(0, 10).map((p) => (
          <div className="person" key={p.id}>
            <b>{p.full_name || 'Unnamed'}</b>
            <span>{p.phone || 'No phone'}</span>
          </div>
        ))
      )}
    </section>
  );
}

export default function People({ customers, agents }) {
  return (
    <div className="grid2">
      <PeoplePanel title="Customers" people={customers} />
      <PeoplePanel title="Agents" people={agents} />
    </div>
  );
}