UPDATE partner_applications SET status=CASE WHEN agreements_current THEN 'PROFILE_INCOMPLETE' ELSE 'AGREEMENT_REQUIRED' END, version=version+1 WHERE status='TRAINING_REQUIRED' AND exam_passed=true;
