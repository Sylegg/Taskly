package com.taskly.recruitment;

import com.taskly.user.entity.UserAccount;
import com.taskly.user.entity.UserProfile;
import com.taskly.user.repository.UserAccountRepository;
import com.taskly.user.repository.UserProfileRepository;
import com.taskly.rbac.repository.RoleRepository;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Explicit, repeatable development fixtures. Never runs by default or in production. */
@Component
@ConditionalOnProperty(name="app.recruitment.demo-seed",havingValue="true")
public class RecruitmentDemoSeed implements ApplicationRunner {
 private final JdbcTemplate db;private final UserAccountRepository users;private final UserProfileRepository profiles;private final RoleRepository roles;private final PasswordEncoder passwords;private final RecruitmentService recruitment;private final RecruitmentExamService exams;private final RecruitmentUniformService uniforms;
 @Value("${app.environment:production}") private String environment;
 public RecruitmentDemoSeed(JdbcTemplate db,UserAccountRepository users,UserProfileRepository profiles,RoleRepository roles,PasswordEncoder passwords,RecruitmentService recruitment,RecruitmentExamService exams,RecruitmentUniformService uniforms){this.db=db;this.users=users;this.profiles=profiles;this.roles=roles;this.passwords=passwords;this.recruitment=recruitment;this.exams=exams;this.uniforms=uniforms;}
 private UUID id(String value){return UUID.nameUUIDFromBytes(("taskly-recruitment-demo:"+value).getBytes(StandardCharsets.UTF_8));}
 @Override @Transactional public void run(ApplicationArguments args){
  if(!Set.of("development","dev","local","test").contains(environment))throw new IllegalStateException("Recruitment demo seed requires development/test environment");
  var states=List.of("REGISTERED","WAITLISTED","EXAM_FAILED","TRAINING_REQUIRED","TRAINING_REQUIRED","PROFILE_INCOMPLETE","PRELIMINARY_REVIEW","ACTION_REQUIRED","PRELIMINARY_APPROVED","UNIFORM_PENDING","DOCUMENTS_RECEIVED","FINAL_REVIEW","ACTIVE","REJECTED","SUSPENDED");
  UUID actor=null;
  for(int n=0;n<states.size();n++){
   String email="partner-fixture-"+n+"@example.test";
   var found=db.queryForList("SELECT id FROM users WHERE email=?",UUID.class,email);
   UUID user;
   if(found.isEmpty()){
    var account=new UserAccount(email,null,passwords.encode(UUID.randomUUID().toString()+UUID.randomUUID()),roles.findByKey("CUSTOMER").orElseThrow(),Instant.now());account.verifyEmail(Instant.now());account=users.saveAndFlush(account);profiles.saveAndFlush(new UserProfile(account,"DEMO ứng viên "+(n+1),Instant.now()));user=account.getId();
    var a=recruitment.current(user);
    // Queue fixtures intentionally have no eligibility bypass: ACTIVE label alone cannot accept jobs.
    db.update("UPDATE partner_applications SET full_name=?,status=?,reason=? WHERE id=?","DEMO ứng viên "+(n+1),states.get(n),"Dữ liệu hư cấu kiểm tra hàng đợi; không phải hồ sơ đã xác minh",a.id());
    recruitment.audit(user,a.id(),"DEMO_QUEUE_FIXTURE_CREATED","REGISTERED",states.get(n),"No identity evidence or eligibility granted");
   }else user=found.getFirst();
   if(actor==null)actor=user;
  }
  String[][] bank={
   {"Trước khi vào nhà khách cần làm gì?","Chào hỏi và xác nhận phạm vi công việc","Tự ý vào nhà","Làm việc khác yêu cầu","Bỏ qua xác nhận"},
   {"Khi phát hiện vật dụng đã hỏng?","Báo khách và ghi nhận trước khi làm","Giấu đi","Tự ý vứt bỏ","Đổ lỗi"},
   {"Có được chia sẻ ảnh giấy tờ khách?","Không, bảo vệ dữ liệu cá nhân","Đăng mạng xã hội","Gửi bạn bè","Dùng quảng cáo"},
   {"Nếu hóa chất không có nhãn?","Ngừng sử dụng và báo người phụ trách","Trộn thử","Ngửi trực tiếp","Đổ vào chai nước"},
   {"Đồ điện cần vệ sinh thế nào?","Ngắt nguồn và tuân thủ hướng dẫn an toàn","Xịt nước khi đang chạy","Dùng tay ướt","Tháo tùy ý"},
   {"Nếu khách yêu cầu ngoài phạm vi?","Xác nhận điều chỉnh qua quy trình TaskLy","Thu tiền riêng","Tự quyết giá","Bỏ việc"},
   {"Khi bị trễ giờ hẹn?","Báo sớm qua kênh hỗ trợ","Không báo","Đổi giờ tùy ý","Nhờ người khác giả danh"},
   {"Đồ thất lạc tìm thấy nên xử lý?","Thông báo và bàn giao cho khách","Mang về","Bán lại","Giấu trong túi"},
   {"Khi có nguy cơ cháy điện?","Dừng việc, bảo đảm an toàn và gọi hỗ trợ","Tiếp tục làm","Dùng nước tùy ý","Bỏ qua"},
   {"Thông tin địa chỉ khách dùng để?","Thực hiện công việc được giao","Gửi quảng cáo riêng","Chia sẻ công khai","Bán dữ liệu"},
   {"Khi khách phản hồi chất lượng?","Lắng nghe và xử lý theo quy trình","Tranh cãi","Chặn khách","Xóa thông tin"},
   {"Đồng phục khi làm việc nên?","Sạch sẽ và đúng quy định","Mặc tùy ý","Cho người khác mượn tài khoản","Che danh tính"},
   {"Trước khi nâng đồ nặng?","Đánh giá rủi ro và dùng kỹ thuật an toàn","Nâng bất kỳ sức nặng","Kéo qua dây điện","Làm một mình bất chấp"},
   {"Nếu chưa biết dùng thiết bị?","Hỏi hướng dẫn trước khi sử dụng","Thử tùy ý","Tháo thiết bị","Bỏ bảo hộ"},
   {"Khi kết thúc công việc?","Kiểm tra, xác nhận và cập nhật trạng thái","Rời đi không báo","Đánh dấu trước khi làm","Yêu cầu trả tiền riêng"},
   {"Bảo hộ phù hợp cần dùng khi nào?","Theo rủi ro và hướng dẫn công việc","Không bao giờ","Chỉ để chụp ảnh","Dùng chung đồ bẩn"},
   {"Tài khoản Partner nên sử dụng thế nào?","Chỉ chủ tài khoản đã được duyệt sử dụng","Cho bạn mượn","Bán tài khoản","Chia sẻ mật khẩu"},
   {"Hóa chất vệ sinh nên bảo quản?","Có nhãn, đúng hướng dẫn, xa trẻ em","Trong chai thực phẩm","Để trên bàn ăn","Trộn tất cả"},
   {"Khi gặp tình huống không an toàn?","Dừng công việc và liên hệ hỗ trợ","Cố làm tiếp","Che giấu","Tự ý sửa nguy hiểm"},
   {"Chỉ khi nào được nhận việc?","Khi ACTIVE và phù hợp kỹ năng, vùng, lịch","Vừa đăng ký","Chỉ mua đồng phục","Chỉ thi đạt"}
  };
  for(int n=0;n<bank.length;n++){UUID key=id("question-"+n);if(db.queryForObject("SELECT COUNT(*) FROM recruitment_questions WHERE id=?",Integer.class,key)==0)exams.save(actor,key,new RecruitmentExamService.QuestionWrite("DEMO — "+bank[n][0],List.of(bank[n][1],bank[n][2],bank[n][3],bank[n][4]),0,"An toàn và tác phong",1,true,0));}

 }
}

