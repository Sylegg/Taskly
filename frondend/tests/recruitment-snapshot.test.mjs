import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseRecruitmentSnapshot, importRecruitmentDemo } from '../src/lib/recruitment-snapshot.mjs';

const flags = Object.fromEntries('registrationComplete recruiting examPassed trainingComplete agreementsCurrent profileComplete preliminaryApproved uniformResolved appointmentCheckedIn documentsValid finalApproved skillsConfigured areasConfigured availabilityConfigured'.split(' ').map(key => [key,false]));
const snapshot = () => ({schema:'taskly.partner-recruitment',version:1,mode:'DEMO_METADATA_ONLY',applications:[{id:'demo-1',userId:'fictional-1',createdAt:'2026-10-09T00:00:00.000Z',updatedAt:'2026-10-09T00:00:00.000Z',status:'registered',version:0,eligibility:{...flags,recruiting:true},documentsReceivedAt:null,activatedAt:null,requiredChanges:[],reason:''}],audit:[],requests:{}});
const admin = {id:'demo-admin',role:'superAdmin'};
test('Admin reads the actual Dart-generated fifteen-applicant fixture', () => {
  const source = readFileSync(new URL('./fixtures/partner-recruitment-v1.json',import.meta.url),'utf8');
  const parsed = parseRecruitmentSnapshot(source);
  assert.equal(parsed.applications.length,15);
  assert.equal(parsed.applications.filter(a => a.status === 'active').length,1);
  assert.deepEqual(importRecruitmentDemo(source,null,admin),parsed);
});
test('Partner v1 metadata round-trips without changing eligibility', () => {
  const s = snapshot();
  assert.deepEqual(parseRecruitmentSnapshot(JSON.stringify(s)),s);
  assert.deepEqual(importRecruitmentDemo(JSON.stringify(s),s,admin),s);
});
test('reject personal fields, invalid dates, duplicate users and forged ACTIVE', () => {
  for (const mutate of [s => {s.applications[0].identityNumber='fake';},s => {s.applications[0].createdAt='invalid';},s => {s.applications.push({...s.applications[0],id:'other'});},s => {s.applications[0].status='active';},s => {s.audit.push({identityImage:'fake'});}]) {
    const s = snapshot(); mutate(s);
    assert.throws(() => parseRecruitmentSnapshot(JSON.stringify(s)));
  }
});
test('imports reject unauthorized, stale, missing and reassigned applications', () => {
  const current = snapshot(); current.applications[0].version=2;
  assert.throws(() => importRecruitmentDemo(JSON.stringify(snapshot()),current,admin));
  const missing = snapshot(); missing.applications=[];
  assert.throws(() => importRecruitmentDemo(JSON.stringify(missing),current,admin));
  const reassigned = structuredClone(current); reassigned.applications[0].userId='someone-else';
  assert.throws(() => importRecruitmentDemo(JSON.stringify(reassigned),current,admin));
  assert.throws(() => importRecruitmentDemo(JSON.stringify(current),null,{id:'user',role:'applicant'}));
  assert.equal(current.applications[0].version,2);
});
