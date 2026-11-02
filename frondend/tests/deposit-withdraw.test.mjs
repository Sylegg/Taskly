import test from 'node:test';
import assert from 'node:assert/strict';
import rawNav from '../src/data/navigation.json' with { type: 'json' };
import rawHeadings from '../src/data/headings.json' with { type: 'json' };
import { portalForRoute } from '../src/lib/admin-navigation.ts';

test('payments route is renamed to Nạp & Rút tiền in navigation and headings', () => {
  // 1. Verify navigation label
  const financeGroup = rawNav.find(([group]) => group === 'Tài chính');
  assert.ok(financeGroup, 'Finance navigation group must exist');

  const paymentsItem = financeGroup[1].find(([route]) => route === 'payments');
  assert.ok(paymentsItem, 'Payments route must exist in finance group');
  assert.equal(paymentsItem[2], 'Nạp & Rút tiền', 'Route label must be Nạp & Rút tiền');

  // 2. Verify headings title & description
  assert.ok(rawHeadings.payments, 'Headings must contain payments entry');
  assert.equal(rawHeadings.payments[0], 'Quản lý Nạp & Rút tiền');
  assert.match(rawHeadings.payments[1], /nạp ví.*rút tiền/i);

  // 3. Verify route is accessible in both Customer and Partner portals
  assert.equal(portalForRoute('payments'), null, 'payments route must be accessible across all portals');
});
