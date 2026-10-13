UPDATE recruitment_questions SET active=false,version=version+1 WHERE text LIKE 'DEMO%' AND active=true;
