package db.migration;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

/** PostgreSQL write protection; H2 test fixtures do not emulate PostgreSQL triggers. */
public class V28__RecruitmentAuditAppendOnly extends BaseJavaMigration {
 @Override public void migrate(Context context) throws Exception {
  if(!context.getConnection().getMetaData().getDatabaseProductName().equals("PostgreSQL"))return;
  try(var statement=context.getConnection().createStatement()){
   statement.execute("CREATE FUNCTION recruitment_audit_write_guard() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Recruitment audit is append-only'; END; $$");
   statement.execute("CREATE TRIGGER recruitment_audit_no_changes BEFORE UPDATE OR DELETE ON recruitment_audit FOR EACH ROW EXECUTE FUNCTION recruitment_audit_write_guard()");
   statement.execute("CREATE TRIGGER recruitment_audit_no_truncate BEFORE TRUNCATE ON recruitment_audit FOR EACH STATEMENT EXECUTE FUNCTION recruitment_audit_write_guard()");
  }
 }
}
