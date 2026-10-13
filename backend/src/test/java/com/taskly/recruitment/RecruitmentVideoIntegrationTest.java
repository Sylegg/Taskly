package com.taskly.recruitment;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.repository.UserAccountRepository;
import com.taskly.rbac.repository.RoleRepository;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") @Transactional
class RecruitmentVideoIntegrationTest {
 @Autowired MockMvc mvc; @Autowired JdbcTemplate db; @Autowired UserAccountRepository users;
 @Autowired RoleRepository roles; @Autowired RecruitmentService recruitment; @Autowired RecruitmentTrainingService training;
 private final ObjectMapper json=new ObjectMapper();
 private UserAccount user(){var now=Instant.now();var u=new UserAccount(UUID.randomUUID()+"@example.test",null,"hash",roles.findByKey("CUSTOMER").orElseThrow(),now);u.verifyEmail(now);return users.saveAndFlush(u);}
 private byte[] video(){return new byte[]{0,0,0,20,'f','t','y','p','i','s','o','m',0,0,0,1,5,6,7,8};}
 @Test void uploadsArePermissionCheckedAndRealPublishedLessonsExposeDurationAndSeekableVideo() throws Exception {
  var admin=user();var partner=user();var file=new MockMultipartFile("video","training.mp4","video/mp4",video());
  mvc.perform(multipart("/api/v1/admin/recruitment/training-videos").file(file).with(jwt().jwt(j->j.subject(partner.getId().toString())))).andExpect(status().isForbidden());
  var upload=mvc.perform(multipart("/api/v1/admin/recruitment/training-videos").file(file).with(jwt().jwt(j->j.subject(admin.getId().toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_TRAINING")))).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
  var data=json.readTree(upload).get("data");var id=UUID.fromString(data.get("id").asText());var url=data.get("videoUrl").asText();
  var lesson=UUID.randomUUID();training.save(admin.getId(),lesson,new RecruitmentTrainingService.LessonWrite("Video đã tải",url,125,0.9,"Câu kiểm tra",List.of("A","B","C","D"),0,true,false,true,0,0));
  mvc.perform(get(url).with(jwt().jwt(j->j.subject(partner.getId().toString())))).andExpect(status().isUnprocessableEntity());
  var application=recruitment.current(partner.getId());db.update("UPDATE partner_applications SET exam_passed=true,status='TRAINING_REQUIRED' WHERE id=?",application.id());
  mvc.perform(get("/api/v1/partner/training/courses").with(jwt().jwt(j->j.subject(partner.getId().toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].lesson.durationSeconds").value(125)).andExpect(jsonPath("$.data[0].lesson.videoUrl").value(url));
  mvc.perform(get(url).header("Range","bytes=4-11").with(jwt().jwt(j->j.subject(partner.getId().toString())))).andExpect(status().isPartialContent()).andExpect(header().string("Content-Range","bytes 4-11/20")).andExpect(content().bytes(Arrays.copyOfRange(video(),4,12)));
  mvc.perform(get(url).header("Range","bytes=100-").with(jwt().jwt(j->j.subject(partner.getId().toString())))).andExpect(status().isRequestedRangeNotSatisfiable());
  mvc.perform(get("/api/v1/admin/recruitment/training-videos/"+id).with(jwt().jwt(j->j.subject(partner.getId().toString())))).andExpect(status().isForbidden());
  db.update("UPDATE partner_training_lessons SET active=false WHERE id=?",lesson);
  mvc.perform(get(url).with(jwt().jwt(j->j.subject(partner.getId().toString())))).andExpect(status().isNotFound());
 }
 @Test void fakeMp4FilesAreRejectedAndEmptyAcademyHasNoFabricatedLessons() throws Exception {
  var admin=user();
  mvc.perform(multipart("/api/v1/admin/recruitment/training-videos").file(new MockMultipartFile("video","fake.mp4","video/mp4",new byte[20])).with(jwt().jwt(j->j.subject(admin.getId().toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_TRAINING")))).andExpect(status().isUnprocessableEntity());
  var application=recruitment.current(admin.getId());db.update("UPDATE partner_applications SET exam_passed=true WHERE id=?",application.id());
  mvc.perform(get("/api/v1/partner/training/courses").with(jwt().jwt(j->j.subject(admin.getId().toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data").isEmpty());
 }
}
