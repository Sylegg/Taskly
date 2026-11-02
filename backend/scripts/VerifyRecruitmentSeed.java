import java.nio.file.*;
import java.sql.*;
import java.util.*;

/** Read-only local development verification; prints counts, never credentials or personal records. */
class VerifyRecruitmentSeed {
 public static void main(String[] args) throws Exception {
  var settings=new HashMap<String,String>();
  for(var line:Files.readAllLines(Path.of(".env"))){int separator=line.indexOf('=');if(separator>0)settings.put(line.substring(0,separator),line.substring(separator+1));}
  String environment=settings.getOrDefault("APP_ENV","production"),url=settings.getOrDefault("DATABASE_URL","");
  if(!Set.of("development","dev","local","test").contains(environment)||!url.matches("jdbc:postgresql://(localhost|127\\.0\\.0\\.1)(:.*|/.*)"))throw new IllegalStateException("Only existing local development database permitted");
  Class.forName("org.postgresql.Driver");
  try(var connection=DriverManager.getConnection(url,settings.get("POSTGRES_USER"),settings.get("POSTGRES_PASSWORD"))){
   connection.setReadOnly(true);
   var queries=Map.of("demoApplicants","SELECT COUNT(*) FROM users WHERE email LIKE 'partner-fixture-%@example.test'","demoQuestions","SELECT COUNT(*) FROM recruitment_questions WHERE text LIKE 'DEMO — %'","demoUniformPackages","SELECT COUNT(*) FROM partner_uniform_packages WHERE name LIKE '%DEMO'","latestMigration","SELECT MAX(installed_rank) FROM flyway_schema_history WHERE success=true");
   for(var query:queries.entrySet())try(var statement=connection.createStatement();var result=statement.executeQuery(query.getValue())){result.next();System.out.println(query.getKey()+"="+result.getLong(1));}
   try(var statement=connection.createStatement();var result=statement.executeQuery("SELECT COUNT(*) FROM pg_trigger WHERE tgrelid='recruitment_audit'::regclass AND tgname IN ('recruitment_audit_no_changes','recruitment_audit_no_truncate') AND tgenabled='O'")){result.next();System.out.println("auditWriteGuards="+result.getInt(1));}
   if(Arrays.asList(args).contains("--test-audit-write-guard")){
    connection.setReadOnly(false);connection.setAutoCommit(false);
    try(var statement=connection.createStatement()){
     try{statement.executeUpdate("UPDATE recruitment_audit SET reason=reason WHERE id=(SELECT id FROM recruitment_audit LIMIT 1)");throw new IllegalStateException("Audit UPDATE was not rejected");}
     catch(SQLException expected){if(!"P0001".equals(expected.getSQLState()))throw expected;System.out.println("appendOnlyUpdateTest=PASS");}
    }finally{connection.rollback();}
   }
  }
 }
}
