import { describe, it, expect } from 'vitest';
import { filterRequests, humanizeStatus, STATUSES } from '../src/utils';

const req = (id, status, extra = {}) => ({
  id,
  request_code: `REQ-2026-00${String(id).padStart(3, '0')}`,
  status,
  description: 'Fix the AC',
  customer: { full_name: 'Demo Customer' },
  services: { name: 'AC Servicing' },
  ...extra,
});

describe('filterRequests (search + status filter)', () => {
  const rows = [
    req(1, 'created'),
    req(2, 'assigned'),
    req(3, 'completed', { request_code: 'REQ-2026-000042' }),
  ];

  it('returns everything with no constraints', () => {
    expect(filterRequests(rows)).toHaveLength(3);
  });

  it('filters by status', () => {
    expect(filterRequests(rows, '', 'completed')).toHaveLength(1);
    expect(filterRequests(rows, '', 'bogus')).toHaveLength(0);
  });

  it('searches across code, description, customer and service', () => {
    expect(filterRequests(rows, '000042')).toHaveLength(1);
    expect(filterRequests(rows, 'Fix the AC')).toHaveLength(3);
    expect(filterRequests(rows, 'Demo Customer')).toHaveLength(3);
    expect(filterRequests(rows, 'servicing')).toHaveLength(3);
    expect(filterRequests(rows, 'zzz')).toHaveLength(0);
  });

  it('combines search and filter', () => {
    expect(filterRequests(rows, 'customer', 'created')).toHaveLength(1);
    expect(filterRequests(rows, 'customer', 'completed')).toHaveLength(1);
  });
});

describe('humanizeStatus / STATUSES', () => {
  it('converts underscores to spaces', () => {
    expect(humanizeStatus('in_progress')).toBe('in progress');
    expect(humanizeStatus('created')).toBe('created');
  });

  it('covers the full lifecycle', () => {
    expect(STATUSES).toEqual([
      'created', 'assigned', 'accepted', 'in_progress', 'completed', 'cancelled',
    ]);
  });
});