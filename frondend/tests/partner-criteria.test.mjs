import assert from 'node:assert/strict';
import test from 'node:test';
import { getPartnerCriteriaProgress, partnerCriteria } from '../src/lib/partner-criteria.ts';

test('the recruitment progress counts 12 distinct criteria and excludes KYC checks', () => {
  const checks = Object.fromEntries(partnerCriteria.map(({ key }) => [key, true]));
  assert.equal(Object.keys(checks).length, 12);
  assert.deepEqual(getPartnerCriteriaProgress({ ...checks, identity_complete: false, identity_approved: false }),
    { passed: 12, total: 12, percentage: 100 });
  assert.deepEqual(getPartnerCriteriaProgress({ identity_complete: true, identity_approved: true }),
    { passed: 0, total: 12, percentage: 0 });
  assert.deepEqual(getPartnerCriteriaProgress({ ...checks, availability_configured: false }),
    { passed: 11, total: 12, percentage: 92 });
  assert.deepEqual(getPartnerCriteriaProgress(), { passed: 0, total: 12, percentage: 0 });
});
