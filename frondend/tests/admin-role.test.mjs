import test from 'node:test';
import assert from 'node:assert/strict';
import { isAdmin, isRecruitmentStaff } from '../src/lib/admin-role.mjs';
test('only active administrator accounts can enter the dashboard', () => {
  for (const roles of [['CUSTOMER'], ['TASKER'], ['CUSTOMER','TASKER'], ['KYC_ADMIN'], ['SUPPORT_ADMIN'], ['FINANCE_ADMIN'], []])
    assert.equal(isAdmin({status:'ACTIVE', roles}), false);
  for (const role of ['ADMIN','SUPER_ADMIN']) {
    assert.equal(isAdmin({status:'ACTIVE',roles:[role]}), true);
    for (const status of ['PENDING_VERIFICATION','SUSPENDED','DISABLED'])
      assert.equal(isAdmin({status,roles:[role]}), false);
  }
  assert.equal(isAdmin(null), false);
  assert.equal(isAdmin({status:'ACTIVE',roles:'ADMIN'}), false);
});
test('scoped recruitment staff never receive general administrator access',()=>{
 for(const role of ['RECRUITMENT_STAFF','TRAINING_MANAGER','KYC_STAFF','RECEPTION_STAFF','FINANCE_STAFF','OPERATIONS_MANAGER']){
  assert.equal(isRecruitmentStaff({status:'ACTIVE',roles:[role]}),true);
  assert.equal(isAdmin({status:'ACTIVE',roles:[role]}),false);
  assert.equal(isRecruitmentStaff({status:'SUSPENDED',roles:[role]}),false);
 }
 assert.equal(isRecruitmentStaff({status:'ACTIVE',roles:['CUSTOMER','TASKER']}),false);
});
