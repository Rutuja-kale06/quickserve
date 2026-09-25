export const STATUSES = ['created', 'assigned', 'accepted', 'in_progress', 'completed', 'cancelled'];

export function filterRequests(requests, search = '', filter = 'all') {
  const q = String(search ?? '').trim().toLowerCase();
  return requests.filter(
    (r) =>
      (filter === 'all' || r.status === filter) &&
      (q === '' ||
        `${r.request_code} ${r.description} ${r.customer?.full_name ?? ''} ${r.services?.name ?? ''}`
          .toLowerCase()
          .includes(q))
  );
}

export function humanizeStatus(status) {
  return String(status ?? '').replaceAll('_', ' ');
}