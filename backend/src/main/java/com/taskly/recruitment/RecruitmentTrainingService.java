package com.taskly.recruitment;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;
@Service
public class RecruitmentTrainingService {
 public record Lesson(UUID id,String title,String videoUrl,int durationSeconds,double watchRatio,String quizText,List<String> quizOptions,boolean required,boolean demo,boolean active,int displayOrder,long version) {}
 public record LessonWrite(@NotBlank @Size(max=200) String title,@NotBlank @Size(max=1000) String videoUrl,@Min(10) @Max(14400) int durationSeconds,@DecimalMin("0.5") @DecimalMax("1.0") double watchRatio,@NotBlank @Size(max=2000) String quizText,@NotNull @Size(min=4,max=4) List<@NotBlank @Size(max=500) String> quizOptions,@Min(0) @Max(3) int correctOption,boolean required,boolean demo,boolean active,@Min(0) int displayOrder,@PositiveOrZero long version) {}
 public record Progress(Lesson lesson,String status,int positionSeconds,int watchedSeconds,boolean quizPassed) {}
 public record Heartbeat(@Min(0) @Max(14400) int positionSeconds) {}
 public record Quiz(@Min(0) @Max(3) int answer) {}
 private final JdbcTemplate db;private final RecruitmentService recruitment;private final ObjectMapper json=new ObjectMapper();
 public RecruitmentTrainingService(JdbcTemplate db,RecruitmentService recruitment){this.db=db;this.recruitment=recruitment;}
 public List<Lesson> lessons(){return db.query("SELECT * FROM partner_training_lessons ORDER BY display_order,id",(r,n)->new Lesson(r.getObject("id",UUID.class),r.getString("title"),r.getString("video_url"),r.getInt("duration_seconds"),r.getDouble("watch_ratio"),r.getString("quiz_text"),json.readValue(r.getString("quiz_options"),new TypeReference<List<String>>(){}),r.getBoolean("required"),r.getBoolean("demo"),r.getBoolean("active"),r.getInt("display_order"),r.getLong("version")));}
 public List<Map<String,Object>> adminLessons(){return lessons().stream().map(lesson->{Map<String,Object> value=json.convertValue(lesson,new TypeReference<Map<String,Object>>(){});value.put("correctOption",db.queryForObject("SELECT correct_option FROM partner_training_lessons WHERE id=?",Integer.class,lesson.id()));return value;}).toList();}
 @Transactional public Lesson save(UUID actor,UUID id,LessonWrite w){
  if(w.videoUrl().matches("/api/v1/partner/training/videos/[0-9a-f-]{36}")){
   var media=UUID.fromString(w.videoUrl().substring(w.videoUrl().lastIndexOf('/')+1));
   if(db.queryForObject("SELECT COUNT(*) FROM partner_training_videos WHERE id=?",Integer.class,media)==0)throw RecruitmentService.invalid("Video tải lên không tồn tại.");
  }else{
   java.net.URI uri;
   try{uri=java.net.URI.create(w.videoUrl());}catch(IllegalArgumentException e){throw RecruitmentService.invalid("Đường dẫn video không hợp lệ.");}
   if(!"https".equals(uri.getScheme())||uri.getHost()==null||uri.getUserInfo()!=null)throw RecruitmentService.invalid("Video phải là tệp tải lên hoặc URL HTTPS hợp lệ.");
  }
  if(w.quizOptions().stream().map(String::trim).distinct().count()!=4)throw RecruitmentService.invalid("Bốn lựa chọn phải khác nhau.");
  boolean exists=db.queryForObject("SELECT COUNT(*) FROM partner_training_lessons WHERE id=?",Integer.class,id)>0;
  if(exists){if(db.update("UPDATE partner_training_lessons SET title=?,video_url=?,duration_seconds=?,watch_ratio=?,quiz_text=?,quiz_options=?,correct_option=?,required=?,demo=?,active=?,display_order=?,version=version+1 WHERE id=? AND version=?",w.title(),w.videoUrl(),w.durationSeconds(),w.watchRatio(),w.quizText(),json.writeValueAsString(w.quizOptions()),w.correctOption(),w.required(),w.demo(),w.active(),w.displayOrder(),id,w.version())!=1)throw RecruitmentService.conflict();}
  else{if(w.version()!=0)throw RecruitmentService.conflict();db.update("INSERT INTO partner_training_lessons VALUES(?,?,?,?,?,?,?,?,?,?,?,?,0)",id,w.title(),w.videoUrl(),w.durationSeconds(),w.watchRatio(),w.quizText(),json.writeValueAsString(w.quizOptions()),w.correctOption(),w.required(),w.demo(),w.active(),w.displayOrder());}
  // Version change invalidates completion at next access; past progress remains as evidence.
  recruitment.audit(actor,null,"TRAINING_LESSON_UPDATED",null,null,"Bài học "+id);return lessons().stream().filter(l->l.id().equals(id)).findFirst().orElseThrow();
 }
 @Transactional public List<Progress> progress(UUID user){
  var app=recruitment.current(user);if(!app.eligibility().get("exam_passed"))throw RecruitmentService.invalid("Hoàn thành bài thi đầu vào trước khi học.");
  boolean unlocked=true;var result=new ArrayList<Progress>();
  for(var lesson:lessons().stream().filter(Lesson::active).toList()){
   var rows=db.queryForList("SELECT * FROM partner_learning_progress WHERE application_id=? AND lesson_id=?",app.id(),lesson.id());
   int position=0,watched=0;boolean quiz=false,completed=false;
   if(!rows.isEmpty()&&((Number)rows.getFirst().get("lesson_version")).longValue()==lesson.version()){var r=rows.getFirst();position=((Number)r.get("position_seconds")).intValue();watched=((Number)r.get("watched_seconds")).intValue();quiz=(Boolean)r.get("quiz_passed");completed=r.get("completed_at")!=null;}
   result.add(new Progress(lesson,completed?"COMPLETED":!unlocked?"LOCKED":watched>0?"IN_PROGRESS":"AVAILABLE",position,watched,quiz));
   if(lesson.required()&&!completed)unlocked=false;
  }return result;
 }
 @Transactional public Progress heartbeat(UUID user,UUID lessonId,Heartbeat w){
  var app=recruitment.current(user);var p=progress(user).stream().filter(x->x.lesson().id().equals(lessonId)).findFirst().orElseThrow(()->RecruitmentService.invalid("Không tìm thấy bài học."));
  if(p.status().equals("LOCKED"))throw RecruitmentService.invalid("Hoàn thành bài học trước.");var lesson=p.lesson();if(w.positionSeconds()>lesson.durationSeconds())throw RecruitmentService.invalid("Mốc video vượt thời lượng.");
  var now=Instant.now();var rows=db.query("SELECT lesson_version,last_heartbeat_at FROM partner_learning_progress WHERE application_id=? AND lesson_id=?",(r,n)->Map.of("version",r.getLong(1),"at",r.getTimestamp(2).toInstant()),app.id(),lessonId);
  if(rows.isEmpty()){db.update("INSERT INTO partner_learning_progress(application_id,lesson_id,lesson_version,last_heartbeat_at) VALUES(?,?,?,?)",app.id(),lessonId,lesson.version(),Timestamp.from(now));return p;}
  if(((Number)rows.getFirst().get("version")).longValue()!=lesson.version()){db.update("UPDATE partner_learning_progress SET lesson_version=?,position_seconds=0,watched_seconds=0,quiz_passed=false,completed_at=NULL,last_heartbeat_at=? WHERE application_id=? AND lesson_id=?",lesson.version(),Timestamp.from(now),app.id(),lessonId);return progress(user).stream().filter(x->x.lesson().id().equals(lessonId)).findFirst().orElseThrow();}
  int elapsed=(int)Duration.between((Instant)rows.getFirst().get("at"),now).getSeconds();int delta=w.positionSeconds()-p.positionSeconds();
  if(delta<0){db.update("UPDATE partner_learning_progress SET position_seconds=?,last_heartbeat_at=? WHERE application_id=? AND lesson_id=?",w.positionSeconds(),Timestamp.from(now),app.id(),lessonId);}
  else {if(delta>Math.min(20,elapsed+2))throw RecruitmentService.invalid("Mốc xem không liên tục. Phát video để lưu tiến độ.");int watched=Math.min(lesson.durationSeconds(),Math.max(p.watchedSeconds(),p.positionSeconds()+Math.min(delta,elapsed)));db.update("UPDATE partner_learning_progress SET position_seconds=?,watched_seconds=?,last_heartbeat_at=? WHERE application_id=? AND lesson_id=?",w.positionSeconds(),watched,Timestamp.from(now),app.id(),lessonId);}
  return progress(user).stream().filter(x->x.lesson().id().equals(lessonId)).findFirst().orElseThrow();
 }
 @Transactional public Progress complete(UUID user,UUID id,Quiz w){
  var app=recruitment.current(user);var p=progress(user).stream().filter(x->x.lesson().id().equals(id)).findFirst().orElseThrow(()->RecruitmentService.invalid("Không tìm thấy bài học."));
  if(p.watchedSeconds()<Math.ceil(p.lesson().durationSeconds()*p.lesson().watchRatio()))throw RecruitmentService.invalid("Chưa xem đủ video bắt buộc.");
  boolean passed=db.queryForObject("SELECT correct_option FROM partner_training_lessons WHERE id=?",Integer.class,id)==w.answer();
  db.update("UPDATE partner_learning_progress SET quiz_passed=?,completed_at=? WHERE application_id=? AND lesson_id=?",passed,passed?Timestamp.from(Instant.now()):null,app.id(),id);
  if(!passed)throw RecruitmentService.invalid("Câu trả lời chưa đúng. Xem lại nội dung và thử lại.");
  var all=progress(user);boolean ready=all.stream().anyMatch(x->x.lesson().required())&&all.stream().filter(x->x.lesson().required()).allMatch(x->x.status().equals("COMPLETED"));
  if(ready&&app.status().equals("TRAINING_REQUIRED")){db.update("UPDATE partner_applications SET training_complete=true,status='AGREEMENT_REQUIRED',version=version+1,updated_at=? WHERE id=?",Timestamp.from(Instant.now()),app.id());recruitment.audit(user,app.id(),"ACADEMY_COMPLETED",app.status(),"AGREEMENT_REQUIRED","");}
  return progress(user).stream().filter(x->x.lesson().id().equals(id)).findFirst().orElseThrow();
 }
}
