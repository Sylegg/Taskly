import test from 'node:test';
import assert from 'node:assert/strict';
import { pricingDraft, pricingPayload } from '../src/lib/service-pricing.mjs';

const valid = { mode: 'FIELD', quantityField: 'units', baseAmount: '10000', unitAmount: '120000', platformFeeAmount: '5000', quoteTtlMinutes: '15', enabled: true };
const fields = [{ key: 'units', label: 'Số máy' }];

test('pricing setup produces the actual backend rule without catalogue price fields', () => {
  assert.deepEqual(pricingPayload(valid, fields), { mode: 'FIELD', quantityField: 'units', baseAmount: 10000, unitAmount: 120000, platformFeeAmount: 5000, quoteTtlMinutes: 15, enabled: true });
  assert.equal(pricingPayload({ ...valid, mode: 'FIXED', unitAmount: 'stale' }, fields).unitAmount, 0);
  assert.equal(pricingPayload({ ...valid, mode: 'HOURLY' }, fields).quantityField, null);
});
test('pricing setup rejects absent numeric fields, fractions, excessive amounts and invalid lifetimes', () => {
  for (const options of [null, [], [{ key: 'other' }]]) assert.throws(() => pricingPayload(valid, options));
  for (const value of ['', '-1', '1.5', '1e4', '1000000001']) assert.throws(() => pricingPayload({ ...valid, baseAmount: value }, fields));
  for (const value of ['0', '61', '1.5']) assert.throws(() => pricingPayload({ ...valid, quoteTtlMinutes: value }, fields));
  assert.throws(() => pricingPayload({ ...valid, mode: 'unknown' }, fields));
});
test('unconfigured or disabled pricing can be saved without enabling free quotes', () => {
  const empty = pricingDraft(null);
  assert.equal(pricingPayload(empty, []).enabled, false);
  assert.throws(() => pricingPayload({ ...empty, enabled: true }, []));
});
test('loaded pricing is preserved and malformed responses cannot turn into default values', () => {
  const payload = pricingPayload(valid, fields);
  assert.deepEqual(pricingPayload(pricingDraft(payload), fields), payload);
  for (const response of [undefined, {}, { ...payload, baseAmount: -1 }, { ...payload, quantityField: null }, { ...payload, enabled: 'true' }]) assert.throws(() => pricingDraft(response));
});

test('percentage fees preserve decimal rates and reject invalid percentages', () => {
 const payload=pricingPayload({...valid, platformFeePercent:'12.5'},fields);
 assert.equal(payload.platformFeePercent,12.5);
 assert.equal(payload.platformFeeAmount,0);
 for(const rate of ['101','-1','1.234','bad']) assert.throws(()=>pricingPayload({...valid,platformFeePercent:rate},fields));
 assert.equal(pricingDraft(payload).platformFeePercent,'12.5');
});
