package com.taskly.recruitment;
import com.taskly.common.exception.DomainException;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
public class RecruitmentExamService {
 public record Question(UUID id,String text,List<String> options,int correctOption,String category,int difficulty,boolean active,long version) {}
 public record QuestionWrite(@NotBlank @Size(max=2000) String text,@NotNull @Size(min=4,max=4) List<@NotBlank @Size(max=500) String> options,@Min(0) @Max(3) int correctOption,@NotBlank @Size(max=100) String category,@Min(1) @Max(5) int difficulty,boolean active,@PositiveOrZero long version) {}
 public record PublicQuestion(UUID id,String text,List<String> options,String category) {}
 public record Attempt(UUID id,String status,List<PublicQuestion> questions,Map<String,Integer> answers,Integer score,int passMark,Instant expiresAt,Instant submittedAt) {}
 public record AnswerWrite(@NotNull @Size(max=20) Map<String,@Min(0) @Max(3) Integer> answers) {}
 public record ConfigWrite(@Min(1) @Max(120) int examMinutes,@Min(1) @Max(20) int passMark,@Min(1) @Max(10) int attemptsPerDay,@PositiveOrZero long version) {}
 private final JdbcTemplate db;private final RecruitmentService recruitment;private final ObjectMapper json=new ObjectMapper();
 public RecruitmentExamService(JdbcTemplate db,RecruitmentService recruitment){this.db=db;this.recruitment=recruitment;}
 private List<Question> parseQuestions(String source){return json.readValue(source,new TypeReference<List<Question>>(){});}
 public List<Question> questions(){return db.query("SELECT * FROM recruitment_questions WHERE text NOT LIKE 'DEMO%' ORDER BY category,id",(r,n)->new Question(r.getObject("id",UUID.class),r.getString("text"),json.readValue(r.getString("options"),new TypeReference<List<String>>(){}),r.getInt("correct_option"),r.getString("category"),r.getInt("difficulty"),r.getBoolean("active"),r.getLong("version")));}
 public Map<String,Object> config(){return db.queryForMap("SELECT exam_minutes,pass_mark,attempts_per_day,version FROM recruitment_policy WHERE id=1");}
 @Transactional public Map<String,Object> partnerConfig(UUID user){
  var app=recruitment.current(user);var result=new HashMap<>(config());
  var day=LocalDate.now(ZoneOffset.UTC);int used=db.queryForObject("SELECT COUNT(*) FROM recruitment_exam_attempts WHERE application_id=? AND started_at>=?",Integer.class,app.id(),Timestamp.from(day.atStartOfDay().toInstant(ZoneOffset.UTC)));
  result.put("remaining_attempts",Math.max(0,((Number)result.get("attempts_per_day")).intValue()-used));
  result.put("retry_available_at",day.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC));
  var recent=db.queryForList("SELECT questions,answers FROM recruitment_exam_attempts WHERE application_id=? AND status IN ('FAILED','EXPIRED') ORDER BY started_at DESC LIMIT 1",app.id());
  var topics=new TreeSet<String>();if(!recent.isEmpty()){
   var row=recent.getFirst();var answers=json.readValue((String)row.get("answers"),new TypeReference<Map<String,Integer>>(){});
   parseQuestions((String)row.get("questions")).stream().filter(q->!Objects.equals(answers.get(q.id().toString()),q.correctOption())).forEach(q->topics.add(q.category()));
  }
  result.put("review_topics",topics);return result;
 }
 @Transactional public Question save(UUID actor,UUID id,QuestionWrite w){
  if(w.options().stream().map(String::trim).distinct().count()!=4)throw RecruitmentService.invalid("Bốn lựa chọn phải khác nhau.");
  var before=questions().stream().filter(q->q.id().equals(id)).findFirst();
  if(before.isPresent()){if(db.update("UPDATE recruitment_questions SET text=?,options=?,correct_option=?,category=?,difficulty=?,active=?,version=version+1,updated_at=? WHERE id=? AND version=?",w.text().trim(),json.writeValueAsString(w.options()),w.correctOption(),w.category().trim(),w.difficulty(),w.active(),Timestamp.from(Instant.now()),id,w.version())!=1)throw RecruitmentService.conflict();}
  else{if(w.version()!=0)throw RecruitmentService.conflict();db.update("INSERT INTO recruitment_questions VALUES(?,?,?,?,?,?,?,0,?)",id,w.text().trim(),json.writeValueAsString(w.options()),w.correctOption(),w.category().trim(),w.difficulty(),w.active(),Timestamp.from(Instant.now()));}
  recruitment.audit(actor,null,"EXAM_QUESTION_UPDATED",null,null,"Câu hỏi "+id);
  return questions().stream().filter(q->q.id().equals(id)).findFirst().orElseThrow();
 }
 @Transactional public void remove(UUID actor,UUID id){if(db.update("UPDATE recruitment_questions SET active=false,version=version+1 WHERE id=?",id)==0)throw RecruitmentService.invalid("Không tìm thấy câu hỏi.");recruitment.audit(actor,null,"EXAM_QUESTION_DISABLED",null,null,"Câu hỏi "+id);}
 @Transactional public Map<String,Object> saveConfig(UUID actor,ConfigWrite w){if(db.update("UPDATE recruitment_policy SET exam_minutes=?,pass_mark=?,attempts_per_day=?,version=version+1 WHERE id=1 AND version=?",w.examMinutes(),w.passMark(),w.attemptsPerDay(),w.version())!=1)throw RecruitmentService.conflict();recruitment.audit(actor,null,"EXAM_CONFIG_UPDATED",null,null,"Điểm đạt "+w.passMark()+"/20");return config();}
 public List<Attempt> results(UUID user){var app=recruitment.current(user);return db.queryForList("SELECT id FROM recruitment_exam_attempts WHERE application_id=? ORDER BY started_at DESC",UUID.class,app.id()).stream().map(this::find).toList();}
 private Attempt find(UUID id){return db.query("SELECT * FROM recruitment_exam_attempts WHERE id=?",(r,n)->new Attempt(id,r.getString("status"),parseQuestions(r.getString("questions")).stream().map(q->new PublicQuestion(q.id(),q.text(),q.options(),q.category())).toList(),json.readValue(r.getString("answers"),new TypeReference<Map<String,Integer>>(){}),r.getObject("score",Integer.class),r.getInt("pass_mark"),r.getTimestamp("expires_at").toInstant(),r.getTimestamp("submitted_at")==null?null:r.getTimestamp("submitted_at").toInstant()),id).getFirst();}
 @Transactional public Attempt start(UUID user){
  var a=recruitment.current(user);if(!Boolean.TRUE.equals(a.eligibility().get("exam_passed")) && !Set.of("REGISTERED","WAITLISTED","EXAM_REQUIRED","EXAM_FAILED","EXPIRED","EXAM_IN_PROGRESS").contains(a.status()))throw RecruitmentService.invalid("Bài thi chưa được mở ở bước này.");
  var ongoing=db.queryForList("SELECT id FROM recruitment_exam_attempts WHERE application_id=? AND status='IN_PROGRESS'",UUID.class,a.id());
  if(!ongoing.isEmpty()){var previous=find(ongoing.getFirst());if(previous.expiresAt().isAfter(Instant.now()))return previous;submit(user,previous.id(),new AnswerWrite(previous.answers()));}
  var c=config();var now=Instant.now();var day=LocalDate.now(ZoneOffset.UTC).atStartOfDay().toInstant(ZoneOffset.UTC);
  if(db.queryForObject("SELECT COUNT(*) FROM recruitment_exam_attempts WHERE application_id=? AND started_at>=?",Integer.class,a.id(),Timestamp.from(day))>=((Number)c.get("attempts_per_day")).intValue())throw new DomainException("EXAM_RETRY_LIMIT","Đã hết lượt thi hôm nay. Vui lòng thử lại vào ngày mai (UTC).",HttpStatus.CONFLICT);
  var bank=new ArrayList<>(questions().stream().filter(Question::active).filter(q->!q.text().startsWith("DEMO")).toList());if(bank.size()<20)throw RecruitmentService.invalid("Ngân hàng chưa đủ 20 câu đang hoạt động. Liên hệ bộ phận đào tạo.");Collections.shuffle(bank);var selected=new ArrayList<Question>();
  for(var q:bank.subList(0,20)){var indices=new ArrayList<>(List.of(0,1,2,3));Collections.shuffle(indices);selected.add(new Question(q.id(),q.text(),indices.stream().map(i->q.options().get(i)).toList(),indices.indexOf(q.correctOption()),q.category(),q.difficulty(),true,q.version()));}
  var id=UUID.randomUUID();var expires=now.plusSeconds(((Number)c.get("exam_minutes")).longValue()*60);
  db.update("INSERT INTO recruitment_exam_attempts(id,application_id,status,questions,pass_mark,config_version,started_at,expires_at) VALUES(?,?,'IN_PROGRESS',?,?,?,?,?)",id,a.id(),json.writeValueAsString(selected),c.get("pass_mark"),c.get("version"),Timestamp.from(now),Timestamp.from(expires));
  if(!Boolean.TRUE.equals(a.eligibility().get("exam_passed"))) db.update("UPDATE partner_applications SET status='EXAM_IN_PROGRESS',version=version+1,updated_at=? WHERE id=?",Timestamp.from(now),a.id());
  recruitment.audit(user,a.id(),"EXAM_STARTED",a.status(),"EXAM_IN_PROGRESS","");return find(id);
 }
 @Transactional public Attempt submit(UUID user,UUID id,AnswerWrite w){
  var a=recruitment.current(user);var rows=db.queryForList("SELECT * FROM recruitment_exam_attempts WHERE id=? AND application_id=? FOR UPDATE",id,a.id());
  if(rows.isEmpty())throw new DomainException("ATTEMPT_NOT_FOUND","Không tìm thấy lượt thi.",HttpStatus.NOT_FOUND);
  var row=rows.getFirst();if(!"IN_PROGRESS".equals(row.get("status")))return find(id);
  var qs=parseQuestions((String)row.get("questions"));var valid=qs.stream().map(q->q.id().toString()).toList();
  if(w.answers().keySet().stream().anyMatch(key->!valid.contains(key)))throw RecruitmentService.invalid("Đáp án chứa câu hỏi ngoài bài thi.");
  var now=Instant.now();boolean expired=!find(id).expiresAt().isAfter(now);
  int score=(int)qs.stream().filter(q->Objects.equals(w.answers().get(q.id().toString()),q.correctOption())).count();
  String status=expired?"EXPIRED":score>=((Number)row.get("pass_mark")).intValue()?"PASSED":"FAILED";
  db.update("UPDATE recruitment_exam_attempts SET status=?,answers=?,score=?,submitted_at=? WHERE id=?",status,json.writeValueAsString(w.answers()),score,Timestamp.from(now),id);
  String next=status.equals("PASSED")?(Boolean.TRUE.equals(a.eligibility().get("agreements_current"))?"PROFILE_INCOMPLETE":"AGREEMENT_REQUIRED"):status.equals("EXPIRED")?"EXPIRED":"EXAM_FAILED";
  if(!Boolean.TRUE.equals(a.eligibility().get("exam_passed"))) db.update("UPDATE partner_applications SET status=?,exam_passed=?,version=version+1,updated_at=? WHERE id=?",next,status.equals("PASSED"),Timestamp.from(now),a.id());
  recruitment.audit(user,a.id(),"EXAM_SUBMITTED",a.status(),next,"Điểm "+score+"/20");return find(id);
 }
 @Transactional public Attempt saveAnswers(UUID user,UUID id,AnswerWrite w){var a=recruitment.current(user);var rows=db.queryForList("SELECT id FROM recruitment_exam_attempts WHERE id=? AND application_id=? AND status='IN_PROGRESS'",UUID.class,id,a.id());if(rows.isEmpty())throw RecruitmentService.invalid("Lượt thi không còn mở.");var attempt=find(id);if(!attempt.expiresAt().isAfter(Instant.now()))return submit(user,id,w);if(w.answers().keySet().stream().anyMatch(key->attempt.questions().stream().noneMatch(q->q.id().toString().equals(key))))throw RecruitmentService.invalid("Câu hỏi không hợp lệ.");db.update("UPDATE recruitment_exam_attempts SET answers=? WHERE id=?",json.writeValueAsString(w.answers()),id);return find(id);}
}
