package com.taskly.recruitment;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.taskly.catalogue.entity.*;
import com.taskly.catalogue.repository.*;
import com.taskly.rbac.repository.RoleRepository;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.repository.UserAccountRepository;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;
@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") @Transactional
class RecruitmentIntegrationTest {
 @Test void approvedFinalDocumentsAreReadOnlyAndRejectReplacement() throws Exception {
  var applicant=user(true);var app=recruitment.current(applicant.getId());
  db.update("UPDATE partner_applications SET status='ACTIVE',final_approved=true WHERE id=?",app.id());
  db.update("INSERT INTO partner_final_documents VALUES(?,?,?,CURRENT_TIMESTAMP)",app.id(),"original portrait","original contract");
  var auth=jwt().jwt(j->j.subject(applicant.getId().toString()));
  mvc.perform(get("/api/v1/partner/final-documents").with(auth)).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].read_only").value(true)).andExpect(jsonPath("$.data[0].portrait").value("original portrait"));
  mvc.perform(post("/api/v1/partner/final-documents").with(auth).contentType(MediaType.APPLICATION_JSON).content("{\"portrait\":\"replacement\",\"contract\":\"replacement\"}")).andExpect(status().isUnprocessableEntity());
  org.junit.jupiter.api.Assertions.assertEquals("original portrait",db.queryForObject("SELECT portrait FROM partner_final_documents WHERE application_id=?",String.class,app.id()));
 }
 @Test void rejectedPartnerCanBeReopenedAtOfficeWithoutActivationAndRetryIsSafe() {
  var applicant=user(true);var admin=user(true);var app=recruitment.current(applicant.getId());
  db.update("UPDATE partner_applications SET status='REJECTED' WHERE id=?",app.id());
  app=recruitment.current(applicant.getId());
  var request=new RecruitmentActivationService.OfficeReopen(app.version(),UUID.randomUUID().toString(),"Partner đã đến văn phòng để đối chiếu lại hồ sơ.");
  var result=activation.reopenAtOffice(admin.getId(),app.id(),request);
  org.junit.jupiter.api.Assertions.assertEquals("PRELIMINARY_REVIEW",result.status());
  org.junit.jupiter.api.Assertions.assertFalse(result.eligibility().get("final_approved"));
  org.junit.jupiter.api.Assertions.assertTrue(result.reviewReady());
  org.junit.jupiter.api.Assertions.assertEquals(result.version(),activation.reopenAtOffice(admin.getId(),app.id(),request).version());
  org.junit.jupiter.api.Assertions.assertTrue(reviews.notifications(applicant.getId()).stream().anyMatch(n->"Hồ sơ được tiếp nhận xét duyệt lại".equals(n.get("title"))));
  final var reopened=result;
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->activation.reopenAtOffice(admin.getId(),reopened.id(),new RecruitmentActivationService.OfficeReopen(reopened.version(),UUID.randomUUID().toString(),"Mở lại lần nữa")));
 }
 @Test void identityApprovalNotificationIsVisibleToPartnerAndRedactsPrivateNumbers() {
  var applicant=user(true);recruitment.current(applicant.getId());
  recruitment.notifyIdentityApproved(applicant.getId(),"Đã đối chiếu CCCD 001234567890");
  var notice=reviews.notifications(applicant.getId()).getFirst();
  org.junit.jupiter.api.Assertions.assertEquals("CCCD đã được xác nhận hợp lệ",notice.get("title"));
  org.junit.jupiter.api.Assertions.assertEquals("DELIVERED",notice.get("status"));
  org.junit.jupiter.api.Assertions.assertFalse(notice.get("message").toString().contains("001234567890"));
 }
 @Test void requestedIdentityCorrectionReopensApprovedIdentityForPartner() {
  var applicant=user(true);var admin=user(true);var app=recruitment.current(applicant.getId());var identityId=UUID.randomUUID();
  db.update("INSERT INTO identity_verifications(id,user_id,status,legal_name,document_type,document_number_masked,document_number,created_at,updated_at) VALUES(?,?,'APPROVED','Ứng viên','NATIONAL_ID','*********890','001234567890',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",identityId,applicant.getId());
  db.update("UPDATE partner_applications SET status='PRELIMINARY_REVIEW',editable_until=? WHERE id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(1)),app.id());app=recruitment.current(applicant.getId());
  var result=reviews.preliminary(admin.getId(),app.id(),new RecruitmentReviewService.Decision(app.version(),UUID.randomUUID().toString(),"REQUEST_CHANGES","Cần bổ sung thông tin CCCD",List.of("Số CCCD / Mã định danh")));
  org.junit.jupiter.api.Assertions.assertEquals("ACTION_REQUIRED",result.status());
  org.junit.jupiter.api.Assertions.assertFalse(result.eligibility().get("identity_approved"));
  verification.updateDraft(applicant.getId(),identityId,new com.taskly.verification.dto.VerificationDtos.DraftRequest("Ứng viên","NATIONAL_ID","001234567891"));
  org.junit.jupiter.api.Assertions.assertEquals("001234567891",verification.currentOwner(applicant.getId()).documentNumber());
 }
 @Test void extendReviewPersistsDeadlineReasonNotificationAndIsIdempotent() {
  var applicant=user(true);var admin=user(true);var app=recruitment.current(applicant.getId());
  db.update("UPDATE partner_applications SET status='PRELIMINARY_REVIEW',editable_until=? WHERE id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(60)),app.id());
  app=recruitment.current(applicant.getId());
  var request=new RecruitmentReviewService.Decision(app.version(),UUID.randomUUID().toString(),"EXTEND_REVIEW","Cần đối chiếu thông tin định danh",List.of(),15);
  final var pending=app;
  for(Integer minutes:Arrays.asList(null,0,-1,1441)) {
   org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->reviews.preliminary(admin.getId(),pending.id(),new RecruitmentReviewService.Decision(pending.version(),UUID.randomUUID().toString(),"EXTEND_REVIEW","Cần đối chiếu thông tin định danh",List.of(),minutes)));
  }
  var before=Instant.now();var result=reviews.preliminary(admin.getId(),app.id(),request);
  org.junit.jupiter.api.Assertions.assertEquals("ESCALATED",result.status());
  org.junit.jupiter.api.Assertions.assertFalse(result.editable());
  org.junit.jupiter.api.Assertions.assertTrue(result.reviewReady());
  org.junit.jupiter.api.Assertions.assertTrue(result.editableUntil().isAfter(before.plusSeconds(899)));
  org.junit.jupiter.api.Assertions.assertTrue(result.editableUntil().isBefore(Instant.now().plusSeconds(901)));
  org.junit.jupiter.api.Assertions.assertTrue(result.reason().contains("Cần đối chiếu thông tin định danh"));
  org.junit.jupiter.api.Assertions.assertTrue(result.reason().contains("Thêm 15 phút"));
  org.junit.jupiter.api.Assertions.assertTrue(reviews.notifications(applicant.getId()).stream().anyMatch(n->result.reason().equals(n.get("message"))));
  var retry=reviews.preliminary(admin.getId(),app.id(),request);
  org.junit.jupiter.api.Assertions.assertEquals(result.editableUntil(),retry.editableUntil());
  var decided=reviews.preliminary(admin.getId(),result.id(),new RecruitmentReviewService.Decision(result.version(),UUID.randomUUID().toString(),"REJECT_WITH_REASON","Thông tin chưa hợp lệ",List.of()));
  org.junit.jupiter.api.Assertions.assertEquals("REJECTED",decided.status());
  db.update("UPDATE partner_applications SET editable_until=? WHERE id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(1)),result.id());
  org.junit.jupiter.api.Assertions.assertTrue(recruitment.current(applicant.getId()).reviewReady());
 }
 @Autowired MockMvc mvc; @Autowired JdbcTemplate db; @Autowired UserAccountRepository users;
 @Autowired RoleRepository roles; @Autowired ServiceCategoryRepository categories; @Autowired CatalogueServiceRepository services;
 final ObjectMapper json=new ObjectMapper();
 @Autowired RecruitmentExamService exams;
 @Autowired RecruitmentTrainingService training;
 @Autowired RecruitmentReviewService reviews;
 @Autowired RecruitmentUniformService uniforms;
 @Autowired RecruitmentOfficeService office;
 @Autowired RecruitmentActivationService activation;
 @Autowired RecruitmentService recruitment;
 @Autowired com.taskly.verification.VerificationService verification;
 @Autowired com.taskly.user.repository.UserProfileRepository profiles;
 @Autowired com.taskly.task.repository.CustomerTaskRepository tasks;
 @Autowired org.springframework.security.crypto.password.PasswordEncoder passwords;
 @Autowired RecruitmentCommunicationsService communications;
 @Autowired com.taskly.user.UserService userService;
 @Test void firstProfileSubmissionCreatesFixedTwelveHourWindowAndRetriesDoNotExtendIt() {
  var u=user(true);var admin=user(true);var app=recruitment.current(u.getId());
  db.update("UPDATE partner_applications SET exam_passed=true,training_complete=true,status='AGREEMENT_REQUIRED' WHERE id=?",app.id());
  for(var type:List.of("PARTNER_CONDUCT","PARTNER_SAFETY","PARTNER_COOPERATION","PARTNER_PRIVACY","PARTNER_UNIFORM")){
   var id=UUID.randomUUID();reviews.saveAgreement(admin.getId(),id,new RecruitmentReviewService.AgreementWrite(type,"window-1","https://example.test/terms",Instant.now().minusSeconds(60),true));reviews.accept(u.getId(),id);
  }
  var submitted=reviews.demoIdentity(u.getId());
  org.junit.jupiter.api.Assertions.assertEquals(Duration.ofHours(12),Duration.between(submitted.firstSubmittedAt(),submitted.editableUntil()));
  var retry=reviews.submitProfile(u.getId());
  org.junit.jupiter.api.Assertions.assertEquals(submitted.firstSubmittedAt(),retry.firstSubmittedAt());
  org.junit.jupiter.api.Assertions.assertEquals(submitted.editableUntil(),retry.editableUntil());
  org.junit.jupiter.api.Assertions.assertEquals(submitted.version(),retry.version());
  org.junit.jupiter.api.Assertions.assertTrue(retry.editable());
  org.junit.jupiter.api.Assertions.assertFalse(retry.reviewReady());
  var decision=new RecruitmentReviewService.Decision(retry.version(),"too-early","REQUEST_CHANGES","Bổ sung",List.of("CCCD"));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->reviews.preliminary(admin.getId(),app.id(),decision));
  var identity=verification.current(u.getId());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->verification.decide(admin.getId(),identity.id(),com.taskly.verification.entity.VerificationStatus.REJECTED,"Too early"));
  verification.updateDraft(u.getId(),identity.id(),new com.taskly.verification.dto.VerificationDtos.DraftRequest("Họ tên bổ sung","NATIONAL_ID","001234567890"));entityManager.flush();
  org.junit.jupiter.api.Assertions.assertEquals("Họ tên bổ sung",verification.current(u.getId()).legalName());
  org.junit.jupiter.api.Assertions.assertEquals(submitted.editableUntil(),recruitment.current(u.getId()).editableUntil());
  db.update("UPDATE partner_applications SET editable_until=? WHERE id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(1)),app.id());
  org.junit.jupiter.api.Assertions.assertFalse(recruitment.current(u.getId()).editable());
  org.junit.jupiter.api.Assertions.assertTrue(recruitment.current(u.getId()).reviewReady());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->verification.updateDraft(u.getId(),identity.id(),new com.taskly.verification.dto.VerificationDtos.DraftRequest("Không được sửa","NATIONAL_ID","001234567891")));
  reviews.preliminary(admin.getId(),app.id(),decision);
 }
 @Test void savedAmendmentsPersistAndExpireWithoutChangingAreasOrDeadline() {
  var u=user(true);var app=recruitment.current(u.getId());var deadline=Instant.now().plusSeconds(3600);
  var cat=categories.saveAndFlush(new ServiceCategory("edit-"+UUID.randomUUID(),"Mẫu","",0,Instant.now()));
  var service=services.saveAndFlush(new CatalogueService(cat,"edit-"+UUID.randomUUID(),"Dịch vụ","Mẫu","",0,100,"VND",60,0,Instant.now()));db.update("UPDATE services SET active=true WHERE id=?",service.getId());
  var area=UUID.randomUUID();recruitment.saveArea(u.getId(),area,new RecruitmentDtos.AreaWrite("Tỉnh mẫu","Khu mẫu",true,10,List.of(service.getId()),0));
  app=recruitment.save(u.getId(),new RecruitmentDtos.Registration(app.version(),"Họ tên mẫu","0900000051",LocalDate.of(1995,1,1),List.of(area),List.of(service.getId()),"Ban đầu","",""));
  db.update("UPDATE partner_applications SET status='PRELIMINARY_REVIEW',first_submitted_at=?,editable_until=? WHERE id=?",java.sql.Timestamp.from(deadline.minusSeconds(43200)),java.sql.Timestamp.from(deadline),app.id());
  var saved=recruitment.save(u.getId(),new RecruitmentDtos.Registration(app.version(),"Tên đã bổ sung","0900000051",LocalDate.of(1995,1,1),List.of(area),List.of(service.getId()),"Kinh nghiệm đã lưu","",""));
  org.junit.jupiter.api.Assertions.assertEquals("Kinh nghiệm đã lưu",recruitment.current(u.getId()).experience());
  org.junit.jupiter.api.Assertions.assertTrue(Duration.between(deadline,saved.editableUntil()).abs().toNanos()<1000);
  var atDeadline=new RecruitmentService(db,profiles,Clock.fixed(saved.editableUntil(),ZoneOffset.UTC)).current(u.getId());
  org.junit.jupiter.api.Assertions.assertFalse(atDeadline.editable());
  org.junit.jupiter.api.Assertions.assertTrue(atDeadline.reviewReady());
  org.junit.jupiter.api.Assertions.assertTrue(new RecruitmentService(db,profiles,Clock.fixed(saved.editableUntil().minusNanos(1),ZoneOffset.UTC)).current(u.getId()).editable());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.save(u.getId(),new RecruitmentDtos.Registration(saved.version(),"Tên đã bổ sung","0900000051",LocalDate.of(1995,1,1),List.of(),List.of(service.getId()),"","","")));
  var otherArea=UUID.randomUUID();recruitment.saveArea(u.getId(),otherArea,new RecruitmentDtos.AreaWrite("Tỉnh mẫu","Khu mới",true,0,List.of(service.getId()),0));
  var changeArea=new RecruitmentDtos.Registration(saved.version(),"Tên đã bổ sung","0900000051",LocalDate.of(1995,1,1),List.of(otherArea),List.of(service.getId()),"Kinh nghiệm đã lưu","","");
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.save(u.getId(),changeArea));
  recruitment.saveArea(u.getId(),otherArea,new RecruitmentDtos.AreaWrite("Tỉnh mẫu","Khu mới",true,5,List.of(service.getId()),0));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.save(u.getId(),changeArea));
  org.junit.jupiter.api.Assertions.assertEquals(List.of(area),recruitment.current(u.getId()).areaIds());
  db.update("UPDATE partner_applications SET editable_until=? WHERE id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(1)),app.id());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.save(u.getId(),new RecruitmentDtos.Registration(saved.version(),"Tên khác","0900000051",LocalDate.of(1995,1,1),List.of(otherArea),List.of(service.getId()),"","","")));
 }
 @Test void dossierShowsAllStagesAndKeepsPrivateIdentityPermission() throws Exception {
  var u=user(true);var admin=user(true);var app=recruitment.current(u.getId());
  db.update("UPDATE partner_applications SET full_name='Hồ sơ mẫu',date_of_birth=? WHERE id=?",LocalDate.of(1995,1,1),app.id());
  var path="/api/v1/admin/recruitment/applications/"+app.id()+"/dossier";
  mvc.perform(get(path).with(jwt().jwt(j->j.subject(u.getId().toString())))).andExpect(status().isForbidden());
  var metadata=json.readTree(call(admin.getId(),"GET",path,null,"RECRUITMENT_VIEW")).get("data");
  org.junit.jupiter.api.Assertions.assertTrue(metadata.get("application").path("dateOfBirth").isMissingNode() || metadata.get("application").path("dateOfBirth").isNull());
  org.junit.jupiter.api.Assertions.assertEquals("[email đã ẩn]",metadata.get("application").get("email").asText());
  var detail=json.readTree(call(admin.getId(),"GET",path,null,"RECRUITMENT_VIEW","RECRUITMENT_PRELIMINARY")).get("data");
  org.junit.jupiter.api.Assertions.assertEquals("1995-01-01",detail.get("application").get("dateOfBirth").asText());
  for(var section:List.of("areas","services","exams","lessons","agreements","identities","documents","uniforms","appointments","receipts","decisions","timeline","availability"))org.junit.jupiter.api.Assertions.assertTrue(detail.get(section).isArray(),section);
  org.junit.jupiter.api.Assertions.assertEquals("APPLICATION_CREATED",detail.get("timeline").get(0).get("action").asText());
 }
 @Test void adminSummaryUsesWholeDatabaseAndDoesNotExposeIdentity() throws Exception {
  var first=user(true);var second=user(true);var admin=user(true);var a=recruitment.current(first.getId());recruitment.current(second.getId());
  db.update("UPDATE partner_applications SET status='FINAL_REVIEW',documents_received_at=? WHERE id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(15*24*3600)),a.id());
  mvc.perform(get("/api/v1/admin/recruitment/summary").with(jwt().jwt(j->j.subject(first.getId().toString())))).andExpect(status().isForbidden());
  var response=json.readTree(call(admin.getId(),"GET","/api/v1/admin/recruitment/summary",null,"RECRUITMENT_VIEW")).get("data");
  org.junit.jupiter.api.Assertions.assertEquals(2,response.get("total").asInt());
  org.junit.jupiter.api.Assertions.assertEquals(1,response.get("awaitingReview").asInt());
  org.junit.jupiter.api.Assertions.assertEquals(1,response.get("overdueWorkingHours").asInt());
  org.junit.jupiter.api.Assertions.assertFalse(response.toString().contains("contactPhone"));
  org.junit.jupiter.api.Assertions.assertFalse(response.toString().contains(first.getId().toString()));
  var filtered=recruitment.page(0,1,"","FINAL_REVIEW",null,null);
  org.junit.jupiter.api.Assertions.assertEquals(1,filtered.total());org.junit.jupiter.api.Assertions.assertEquals(a.id(),filtered.items().getFirst().id());
  org.junit.jupiter.api.Assertions.assertEquals(0,recruitment.page(1,1,"","FINAL_REVIEW",null,null).items().size());
  org.junit.jupiter.api.Assertions.assertEquals(0,recruitment.page(0,1,"%' OR 1=1 --","",null,null).total());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.page(-1,50,"","",null,null));
  mvc.perform(get("/api/v1/admin/recruitment/applications-page").with(jwt().jwt(j->j.subject(first.getId().toString())))).andExpect(status().isForbidden());
  var calendar=Map.of("minimumHours",24,"maximumHours",48,"timezone","Asia/Bangkok","startHour",9,"endHour",18,"holidays",List.of("2026-10-12"),"version",0);
  var saved=json.readTree(call(admin.getId(),"PUT","/api/v1/admin/recruitment/sla-calendar",calendar,"RECRUITMENT_CONFIG")).get("data");
  org.junit.jupiter.api.Assertions.assertEquals("2026-10-12",saved.get("holidays").get(0).asText());org.junit.jupiter.api.Assertions.assertEquals(1,saved.get("version").asInt());
  mvc.perform(put("/api/v1/admin/recruitment/sla-calendar").with(jwt().jwt(j->j.subject(admin.getId().toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_VIEW"))).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(calendar))).andExpect(status().isForbidden());
 }
 @Test void benefitContentIsManagedByAdminAndLockedUntilEligible() throws Exception {
  var u=user(true);var admin=user(true);var id=UUID.randomUUID();
  var body=Map.of("name","Phúc lợi DEMO","description","Chính sách mẫu","contentUrl","https://example.test/demo-benefit","requiresActive",true,"active",true,"version",0);
  call(admin.getId(),"PUT","/api/v1/admin/recruitment/benefits/"+id,body,"RECRUITMENT_CONFIG");
  mvc.perform(get("/api/v1/partner/benefits").with(jwt().jwt(j->j.subject(u.getId().toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].eligible").value(false)).andExpect(jsonPath("$.data[0].content_url").value(""));
  var publicBody=new HashMap<String,Object>(body);publicBody.put("requiresActive",false);call(admin.getId(),"PUT","/api/v1/admin/recruitment/benefits/"+id,publicBody,"RECRUITMENT_CONFIG");
  mvc.perform(get("/api/v1/partner/benefits").with(jwt().jwt(j->j.subject(u.getId().toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].eligible").value(true));
  mvc.perform(put("/api/v1/admin/recruitment/benefits/"+id).with(jwt().jwt(j->j.subject(u.getId().toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_VIEW"))).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(publicBody))).andExpect(status().isForbidden());
 }
 @Test void recruitmentQuotaWaitlistsAdditionalApplicantsAndDoesNotOpenKyc() {
  var admin=user(true);var first=user(true);var second=user(true);var now=Instant.now();
  var cat=categories.saveAndFlush(new ServiceCategory("quota-"+UUID.randomUUID(),"Quota DEMO","",0,now));
  var service=services.saveAndFlush(new CatalogueService(cat,"quota-"+UUID.randomUUID(),"Dịch vụ DEMO","Mẫu","",0,100,"VND",60,0,now));db.update("UPDATE services SET active=true WHERE id=?",service.getId());
  var area=UUID.randomUUID();recruitment.saveArea(admin.getId(),area,new RecruitmentDtos.AreaWrite("Thành phố DEMO","Khu quota",true,1,List.of(service.getId()),0));
  for(var account:List.of(first,second)){var app=recruitment.current(account.getId());recruitment.save(account.getId(),new RecruitmentDtos.Registration(app.version(),"Ứng viên DEMO",account==first?"0900000081":"0900000082",LocalDate.of(1995,1,1),List.of(area),List.of(service.getId()),"","",""));app=recruitment.current(account.getId());recruitment.submit(account.getId(),new RecruitmentDtos.Submit(app.version(),"quota-submit"));}
  org.junit.jupiter.api.Assertions.assertEquals("EXAM_REQUIRED",recruitment.current(first.getId()).status());org.junit.jupiter.api.Assertions.assertEquals("WAITLISTED",recruitment.current(second.getId()).status());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->reviews.submitProfile(second.getId()));
 }
 @jakarta.persistence.PersistenceContext jakarta.persistence.EntityManager entityManager;
 @Test void identityWithoutCleanEvidenceCannotBeApproved() {
  var u=user(true);var admin=user(true);userService.enableTasker(u.getId());var kyc=verification.start(u.getId());entityManager.flush();
  db.update("UPDATE identity_verifications SET status='SUBMITTED',document_type='PASSPORT',legal_name='Fictional identity' WHERE id=?",kyc.id());entityManager.clear();
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->verification.decide(admin.getId(),kyc.id(),com.taskly.verification.entity.VerificationStatus.APPROVED,"Thử duyệt mẫu không ảnh"));
 }
 @Test void sandboxFailureExchangeHandoverAndRefundPreserveStockAndEligibility() throws Exception {
  var u=user(true);var admin=user(true);var app=recruitment.current(u.getId());db.update("UPDATE partner_applications SET status='PRELIMINARY_APPROVED',preliminary_approved=true WHERE id=?",app.id());
  var pack=UUID.randomUUID();uniforms.save(admin.getId(),pack,new RecruitmentUniformService.PackageWrite("Gói đổi DEMO","Mẫu",100,"Không chuyển tiền thật",true,0,Map.of("M",1,"L",1)));
  var order=uniforms.order(u.getId(),new RecruitmentUniformService.OrderWrite(pack,"M","ONLINE","online-order"));var id=(UUID)order.get("id");
  uniforms.sandboxPay(u.getId(),id,new RecruitmentUniformService.Payment("FAILURE"));org.junit.jupiter.api.Assertions.assertFalse(recruitment.current(u.getId()).eligibility().get("uniform_resolved"));
  uniforms.sandboxPay(u.getId(),id,new RecruitmentUniformService.Payment("SUCCESS"));
  var exchange=new RecruitmentUniformService.Adjustment("EXCHANGE","L",false,"Đổi size mẫu","exchange-once");uniforms.adjust(admin.getId(),id,exchange);uniforms.adjust(admin.getId(),id,exchange);
  org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT stock FROM partner_uniform_inventory WHERE package_id=? AND size='M'",Integer.class,pack));
  org.junit.jupiter.api.Assertions.assertEquals(0,db.queryForObject("SELECT stock FROM partner_uniform_inventory WHERE package_id=? AND size='L'",Integer.class,pack));
  uniforms.adjust(admin.getId(),id,new RecruitmentUniformService.Adjustment("HANDOVER",null,false,"Bàn giao mẫu","handover"));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->uniforms.adjust(admin.getId(),id,new RecruitmentUniformService.Adjustment("REFUND",null,false,"Chưa trả đồ","refund-no-return")));
  db.update("UPDATE partner_applications SET status='ACTIVE' WHERE id=?",app.id());
  var refund=new RecruitmentUniformService.Adjustment("REFUND",null,true,"Hoàn mô phỏng","refund-once");uniforms.adjust(admin.getId(),id,refund);uniforms.adjust(admin.getId(),id,refund);
  org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT stock FROM partner_uniform_inventory WHERE package_id=? AND size='L'",Integer.class,pack));
  org.junit.jupiter.api.Assertions.assertEquals(100L,db.queryForObject("SELECT amount FROM partner_uniform_adjustments WHERE request_key='refund-once'",Long.class));
  org.junit.jupiter.api.Assertions.assertEquals("SUSPENDED",recruitment.current(u.getId()).status());org.junit.jupiter.api.Assertions.assertFalse(recruitment.current(u.getId()).eligibility().get("uniform_resolved"));
  mvc.perform(post("/api/v1/admin/recruitment/uniform-orders/"+id+"/adjust").with(jwt().jwt(j->j.subject(u.getId().toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_RECEPTION"))).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(refund))).andExpect(status().isForbidden());
 }
 @Test void templatesSnapshotAndMockEmailRetryNeverClaimRealDelivery() throws Exception {
  var u=user(true);var admin=user(true);var app=recruitment.current(u.getId());var key=UUID.randomUUID();
  communications.save(admin.getId(),key,new RecruitmentCommunicationsService.TemplateWrite("REVIEW_RESULT","TaskLy: {title}","Thông báo: {message}",true,0));
  reviews.notify(app.id(),"Kết quả xét duyệt","Hồ sơ DEMO");
  var messages=reviews.notifications(u.getId());org.junit.jupiter.api.Assertions.assertTrue(messages.stream().allMatch(m->String.valueOf(m.get("title")).startsWith("TaskLy:")));
  var email=db.queryForObject("SELECT id FROM partner_notification_outbox WHERE application_id=? AND channel='EMAIL'",UUID.class,app.id());
  var failed=communications.retry(admin.getId(),email,new RecruitmentCommunicationsService.Retry("FAILURE"));org.junit.jupiter.api.Assertions.assertEquals("FAILED",failed.get("status"));
  var success=communications.retry(admin.getId(),email,new RecruitmentCommunicationsService.Retry("SUCCESS"));org.junit.jupiter.api.Assertions.assertEquals("SIMULATED",success.get("status"));org.junit.jupiter.api.Assertions.assertNull(success.get("delivered_at"));org.junit.jupiter.api.Assertions.assertEquals(2,((Number)success.get("attempts")).intValue());
  mvc.perform(get("/api/v1/admin/recruitment/outbox").with(jwt().jwt(j->j.subject(u.getId().toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_VIEW")))).andExpect(status().isForbidden());
  communications.save(admin.getId(),key,new RecruitmentCommunicationsService.TemplateWrite("REVIEW_RESULT","Nội dung mới","Mới: {message}",true,0));
  org.junit.jupiter.api.Assertions.assertTrue(reviews.notifications(u.getId()).stream().allMatch(m->String.valueOf(m.get("title")).startsWith("TaskLy:")));
 }
 @Test void demoSeedIsRepeatableAndCannotRunInProduction() throws Exception {
  var seed=new RecruitmentDemoSeed(db,users,profiles,roles,passwords,recruitment,exams,uniforms);
  org.springframework.test.util.ReflectionTestUtils.setField(seed,"environment","production");
  org.junit.jupiter.api.Assertions.assertThrows(IllegalStateException.class,()->seed.run(new org.springframework.boot.DefaultApplicationArguments()));
  org.springframework.test.util.ReflectionTestUtils.setField(seed,"environment","test");
  seed.run(new org.springframework.boot.DefaultApplicationArguments());seed.run(new org.springframework.boot.DefaultApplicationArguments());
  org.junit.jupiter.api.Assertions.assertEquals(15,db.queryForObject("SELECT COUNT(*) FROM users WHERE email LIKE 'partner-fixture-%@example.test'",Integer.class));
  org.junit.jupiter.api.Assertions.assertEquals(20,db.queryForObject("SELECT COUNT(*) FROM recruitment_questions WHERE text LIKE 'DEMO — %'",Integer.class));
  org.junit.jupiter.api.Assertions.assertEquals(3,db.queryForObject("SELECT COUNT(*) FROM partner_uniform_packages WHERE name LIKE '%DEMO'",Integer.class));
  var active=db.queryForObject("SELECT user_id FROM partner_applications WHERE status='ACTIVE'",UUID.class);
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->activation.feed(active));
 }
 @Test void agreementsPersistBeforeTrainingAndReopeningReturnsAcceptedVersions() throws Exception {
  var user=user(true);var app=recruitment.current(user.getId());
  var result=reviews.acceptAll(user.getId());entityManager.flush();entityManager.clear();
  org.junit.jupiter.api.Assertions.assertTrue(result.eligibility().get("agreements_current"));
  org.junit.jupiter.api.Assertions.assertFalse(result.eligibility().get("training_complete"));
  org.junit.jupiter.api.Assertions.assertTrue(reviews.agreements(user.getId()).stream().allMatch(RecruitmentReviewService.Agreement::accepted));
  int count=db.queryForObject("SELECT COUNT(*) FROM user_consents WHERE user_id=?",Integer.class,user.getId());
  reviews.acceptAll(user.getId());
  org.junit.jupiter.api.Assertions.assertEquals(count,db.queryForObject("SELECT COUNT(*) FROM user_consents WHERE user_id=?",Integer.class,user.getId()));
  org.junit.jupiter.api.Assertions.assertTrue(recruitment.current(user.getId()).eligibility().get("agreements_current"));
 }
 @Test void recruitmentAreasRemainEditableUntilProfileSubmission() {
  var u=user(true);var app=recruitment.current(u.getId());
  var area=UUID.randomUUID();
  recruitment.saveArea(u.getId(),area,new RecruitmentDtos.AreaWrite("City","Area",true,10,List.of(),0));
  db.update("UPDATE partner_applications SET status='TRAINING_REQUIRED' WHERE id=?",app.id());
  var draft=new RecruitmentDtos.Registration(app.version(),"Partner","0901234567",LocalDate.of(1995,4,12),List.of(area),List.of(),"","","");
  var saved=recruitment.save(u.getId(),draft);
  org.junit.jupiter.api.Assertions.assertEquals(List.of(area),recruitment.current(u.getId()).areaIds());
  db.update("UPDATE partner_applications SET first_submitted_at=? WHERE id=?",java.sql.Timestamp.from(Instant.now()),app.id());
  var changed=new RecruitmentDtos.Registration(saved.version(),"Partner","0901234567",LocalDate.of(1995,4,12),List.of(),List.of(),"","","");
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.save(u.getId(),changed));
  org.junit.jupiter.api.Assertions.assertEquals(List.of(area),recruitment.current(u.getId()).areaIds());
 }
 @Test void configuredCorrectAnswerThresholdPersistsAndIsSnapshotted() {
  db.update("UPDATE recruitment_questions SET active=false");
  var applicant=user(true);var admin=user(true);var app=recruitment.current(applicant.getId());
  db.update("UPDATE partner_applications SET status='EXAM_REQUIRED' WHERE id=?",app.id());
  for(int i=0;i<20;i++)exams.save(admin.getId(),UUID.randomUUID(),new RecruitmentExamService.QuestionWrite("Knowledge "+i,List.of("Correct","Wrong 1","Wrong 2","Wrong 3"),0,"Safety",1,true,0));
  var cfg=exams.config();exams.saveConfig(admin.getId(),new RecruitmentExamService.ConfigWrite(25,12,2,((Number)cfg.get("version")).longValue()));
  org.junit.jupiter.api.Assertions.assertEquals(12,((Number)exams.partnerConfig(applicant.getId()).get("pass_mark")).intValue());
  var attempt=exams.start(applicant.getId());
  cfg=exams.config();exams.saveConfig(admin.getId(),new RecruitmentExamService.ConfigWrite(30,15,2,((Number)cfg.get("version")).longValue()));
  var answers=new HashMap<String,Integer>();
  for(int i=0;i<attempt.questions().size();i++){
    var q=attempt.questions().get(i);int correct=q.options().indexOf("Correct");
    answers.put(q.id().toString(),i<12?correct:(correct+1)%4);
  }
  var result=exams.submit(applicant.getId(),attempt.id(),new RecruitmentExamService.AnswerWrite(answers));
  org.junit.jupiter.api.Assertions.assertEquals(12,result.score());
  org.junit.jupiter.api.Assertions.assertEquals(12,result.passMark());
  org.junit.jupiter.api.Assertions.assertEquals("PASSED",result.status());
  org.junit.jupiter.api.Assertions.assertEquals(15,((Number)exams.partnerConfig(applicant.getId()).get("pass_mark")).intValue());
 }
 @Test void knowledgeExamCanStartBeforeRegistrationSubmission() {
  var u=user(true);var app=recruitment.current(u.getId());
  org.junit.jupiter.api.Assertions.assertFalse(app.eligibility().get("registration_submitted"));
  var attempt=exams.start(u.getId());
  org.junit.jupiter.api.Assertions.assertEquals(20,attempt.questions().size());
  org.junit.jupiter.api.Assertions.assertEquals("IN_PROGRESS",attempt.status());
 }
 @Test void optionalRetakePreservesPassedEligibilityAndLaterStage() {
  var u=user(true);var app=recruitment.current(u.getId());
  db.update("UPDATE partner_applications SET exam_passed=true,status='PRELIMINARY_REVIEW' WHERE id=?",app.id());
  var attempt=exams.start(u.getId());
  org.junit.jupiter.api.Assertions.assertEquals("PRELIMINARY_REVIEW",recruitment.current(u.getId()).status());
  exams.submit(u.getId(),attempt.id(),new RecruitmentExamService.AnswerWrite(Map.of()));
  org.junit.jupiter.api.Assertions.assertTrue(recruitment.current(u.getId()).eligibility().get("exam_passed"));
  org.junit.jupiter.api.Assertions.assertEquals("PRELIMINARY_REVIEW",recruitment.current(u.getId()).status());
 }
 @Test void knowledgeAssessmentReplacesVideoCompletionRequirement() {
  var u=user(true);var app=recruitment.current(u.getId());
  org.junit.jupiter.api.Assertions.assertFalse(reviews.trainingReady(u.getId()));
  db.update("UPDATE partner_applications SET exam_passed=true,training_complete=false WHERE id=?",app.id());
  org.junit.jupiter.api.Assertions.assertTrue(reviews.trainingReady(u.getId()));
 }
 @Test void oldRegistrationAuditDoesNotConfirmCurrentWizard() {
  var u=user(true);var app=recruitment.current(u.getId());
  recruitment.audit(u.getId(),app.id(),"REGISTRATION_SUBMITTED","REGISTERED","EXAM_REQUIRED","");
  org.junit.jupiter.api.Assertions.assertFalse(recruitment.current(u.getId()).eligibility().get("registration_submitted"));
  db.update("UPDATE partner_applications SET registration_confirmed_at=? WHERE id=?",java.sql.Timestamp.from(Instant.now()),app.id());
  org.junit.jupiter.api.Assertions.assertTrue(recruitment.current(u.getId()).eligibility().get("registration_submitted"));
 }
 @Test void personalDetailsPersistWithoutAreasIdentityOrTraining() throws Exception {
  var u=user(true);var app=recruitment.current(u.getId());
  var request=new LinkedHashMap<String,Object>();
  request.put("version",app.version());request.put("fullName","Tên cá nhân đã lưu");request.put("contactPhone","0901234567");request.put("dateOfBirth","1995-04-12");
  request.put("areaIds",List.of());request.put("serviceIds",List.of());request.put("experience","");request.put("transport","");request.put("referral","");
  call(u.getId(),"PUT","/api/v1/partner/onboarding",request);
  entityManager.flush();entityManager.clear();
  org.junit.jupiter.api.Assertions.assertEquals("Tên cá nhân đã lưu",db.queryForObject("SELECT full_name FROM partner_applications WHERE id=?",String.class,app.id()));
  org.junit.jupiter.api.Assertions.assertEquals(LocalDate.of(1995,4,12),db.queryForObject("SELECT date_of_birth FROM partner_applications WHERE id=?",LocalDate.class,app.id()));
  mvc.perform(get("/api/v1/partner/onboarding").with(jwt().jwt(j->j.subject(u.getId().toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data.fullName").value("Tên cá nhân đã lưu")).andExpect(jsonPath("$.data.contactPhone").value("0901234567")).andExpect(jsonPath("$.data.dateOfBirth").value("1995-04-12"));
  db.update("UPDATE partner_applications SET status='TRAINING_REQUIRED' WHERE id=?",app.id());
  request.put("version",recruitment.current(u.getId()).version());request.put("fullName","Tên cập nhật khi học");
  call(u.getId(),"PUT","/api/v1/partner/onboarding",request);
  org.junit.jupiter.api.Assertions.assertEquals("Tên cập nhật khi học",recruitment.current(u.getId()).fullName());
 }
 @Test void registrationPrefillsAccountDetailsAndPreservesApplicantEdits() throws Exception {
  var u=user(true);db.update("UPDATE users SET phone='0901234567' WHERE id=?",u.getId());
  var a=recruitment.current(u.getId());
  org.junit.jupiter.api.Assertions.assertEquals("Ứng viên mẫu",a.fullName());
  org.junit.jupiter.api.Assertions.assertEquals("0901234567",a.contactPhone());
  org.junit.jupiter.api.Assertions.assertEquals("0901234567",db.queryForObject("SELECT contact_phone FROM partner_applications WHERE id=?",String.class,a.id()));
  db.update("UPDATE partner_applications SET full_name='',contact_phone=NULL WHERE id=?",a.id());
  var auth=jwt().jwt(j->j.subject(u.getId().toString()));
  mvc.perform(get("/api/v1/partner/onboarding").with(auth)).andExpect(status().isOk()).andExpect(jsonPath("$.data.fullName").value("Ứng viên mẫu")).andExpect(jsonPath("$.data.contactPhone").value("0901234567"));
  db.update("UPDATE partner_applications SET full_name='Tên trong hồ sơ',contact_phone='0907654321' WHERE id=?",a.id());
  var edited=recruitment.current(u.getId());
  org.junit.jupiter.api.Assertions.assertEquals("Tên trong hồ sơ",edited.fullName());
  org.junit.jupiter.api.Assertions.assertEquals("0907654321",edited.contactPhone());
 }
 @Test void accountWithoutNameAndPhoneLeavesRegistrationEmpty() {
  var u=user(true);db.update("UPDATE user_profiles SET full_name='' WHERE user_id=?",u.getId());
  var a=recruitment.current(u.getId());
  org.junit.jupiter.api.Assertions.assertEquals("",a.fullName());
  org.junit.jupiter.api.Assertions.assertEquals("",a.contactPhone());
 }
 @Test void partnerOnlySeesOpenAdminAreasAndCannotSelectClosedAreas() throws Exception {
  var u=user(true);var admin=user(true);var open=UUID.randomUUID();var closed=UUID.randomUUID();
  call(admin.getId(),"PUT","/api/v1/admin/recruitment/areas/"+open,Map.of("city","Hà Nội","name","Khu vực mở","recruiting",true,"capacity",5,"version",0,"serviceIds",List.of()),"RECRUITMENT_CONFIG");
  call(admin.getId(),"PUT","/api/v1/admin/recruitment/areas/"+closed,Map.of("city","Hà Nội","name","Khu vực đóng","recruiting",false,"capacity",5,"version",0,"serviceIds",List.of()),"RECRUITMENT_CONFIG");
  var visible=json.readTree(call(u.getId(),"GET","/api/v1/partner/recruitment-areas",null)).get("data");
  org.junit.jupiter.api.Assertions.assertTrue(visible.toString().contains(open.toString()));
  org.junit.jupiter.api.Assertions.assertFalse(visible.toString().contains(closed.toString()));
  org.junit.jupiter.api.Assertions.assertTrue(recruitment.areas().stream().anyMatch(a->a.id().equals(closed)));
  var a=recruitment.current(u.getId());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.save(u.getId(),new RecruitmentDtos.Registration(a.version(),"Ứng viên","",null,List.of(closed),List.of(),"","","")));
 }
 @Test void savingRegistrationUpdatesAccountNameWithoutErasingItForEmptyDraft() throws Exception {
  var u=user(true);var other=user(true);var a=recruitment.current(u.getId());
  profiles.findById(u.getId()).orElseThrow().update("Tên cũ","en",Instant.now());
  var saved=recruitment.save(u.getId(),new RecruitmentDtos.Registration(a.version(),"  Nguyễn Văn Minh  ","",null,List.of(),List.of(),"","",""));
  mvc.perform(get("/api/v1/users/me").with(jwt().jwt(j->j.subject(u.getId().toString()))))
   .andExpect(status().isOk()).andExpect(jsonPath("$.data.fullName").value("Nguyễn Văn Minh"))
   .andExpect(jsonPath("$.data.language").value("en"));
  org.junit.jupiter.api.Assertions.assertEquals("Ứng viên mẫu",userService.me(other.getId()).fullName());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.save(u.getId(),new RecruitmentDtos.Registration(a.version(),"Tên không được lưu","",null,List.of(),List.of(),"","","")));
  org.junit.jupiter.api.Assertions.assertEquals("Nguyễn Văn Minh",userService.me(u.getId()).fullName());
  recruitment.save(u.getId(),new RecruitmentDtos.Registration(saved.version(),"   ","",null,List.of(),List.of(),"","",""));
  org.junit.jupiter.api.Assertions.assertEquals("Nguyễn Văn Minh",userService.me(u.getId()).fullName());
 }
 UserAccount user(boolean verified) {var u=new UserAccount(UUID.randomUUID()+"@test.example",null,"hash",roles.findByKey("CUSTOMER").orElseThrow(),Instant.now());if(verified)u.verifyEmail(Instant.now());u=users.saveAndFlush(u);profiles.saveAndFlush(new com.taskly.user.entity.UserProfile(u,"Ứng viên mẫu",Instant.now()));return u;}
 void acceptedTerms(UUID user,UUID admin){db.update("INSERT INTO identity_verifications(id,user_id,status,legal_name,document_type,document_number_masked,created_at,updated_at) VALUES(?,?,'APPROVED','Fixture DEMO','DEMO','NO REAL ID',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",UUID.randomUUID(),user);for(var type:List.of("PARTNER_CONDUCT","PARTNER_SAFETY","PARTNER_COOPERATION","PARTNER_PRIVACY","PARTNER_UNIFORM")){var id=UUID.randomUUID();reviews.saveAgreement(admin,id,new RecruitmentReviewService.AgreementWrite(type,"demo-"+UUID.randomUUID().toString().substring(0,8),"https://example.test/terms",Instant.now().minusSeconds(60),true));db.update("INSERT INTO user_consents(id,user_id,terms_version_id,accepted_at) VALUES(?,?,?,CURRENT_TIMESTAMP)",UUID.randomUUID(),user,id);}}
 String call(UUID user,String method,String path,Object body,String... permissions) throws Exception {
  var request=switch(method) {case "PUT"->put(path);case "POST"->post(path);default->get(path);};
  request.with(jwt().jwt(j->j.subject(user.toString())).authorities(Arrays.stream(permissions).map(SimpleGrantedAuthority::new).toArray(SimpleGrantedAuthority[]::new)));
  if(body!=null)request.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
  return mvc.perform(request).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
 }
 @Test void draftSubmitAdminQueueAndReloadShareDatabaseWithIdempotency() throws Exception {
  var u=user(true); var admin=user(true);var now=Instant.now();
  var cat=categories.saveAndFlush(new ServiceCategory("r-"+UUID.randomUUID(),"Nhà cửa","",0,now));
  var svc=services.saveAndFlush(new CatalogueService(cat,"r-"+UUID.randomUUID(),"Dọn nhà","Mô tả","",0,100,"VND",60,0,now));
  db.update("UPDATE services SET active=true WHERE id=?",svc.getId());
  var area=UUID.randomUUID();
  call(admin.getId(),"PUT","/api/v1/admin/recruitment/areas/"+area,Map.of("city","Thành phố mẫu","name","Vùng thử nghiệm","recruiting",true,"capacity",10,"version",0,"serviceIds",List.of(svc.getId())),"RECRUITMENT_CONFIG");
  call(u.getId(),"GET","/api/v1/partner/onboarding",null);
  var draft=new LinkedHashMap<String,Object>();
  draft.put("version",0);draft.put("fullName","Ứng viên hư cấu");draft.put("contactPhone","0900000001");draft.put("dateOfBirth","1995-01-01");draft.put("areaIds",List.of(area));draft.put("serviceIds",List.of(svc.getId()));draft.put("experience","");draft.put("transport","");draft.put("referral","");
  call(u.getId(),"PUT","/api/v1/partner/onboarding",draft);
  var body=Map.of("version",1,"requestId","submit-once");
  var result=json.readTree(call(u.getId(),"POST","/api/v1/partner/onboarding/submit",body)).get("data");
  org.junit.jupiter.api.Assertions.assertEquals("EXAM_REQUIRED",result.get("status").asText());
  call(u.getId(),"POST","/api/v1/partner/onboarding/submit",body);
  mvc.perform(get("/api/v1/partner/onboarding").with(jwt().jwt(j->j.subject(u.getId().toString())))).andExpect(jsonPath("$.data.version").value(2)).andExpect(jsonPath("$.data.areaIds[0]").value(area.toString()));
  var queue=json.readTree(call(admin.getId(),"GET","/api/v1/admin/recruitment/applications",null,"RECRUITMENT_VIEW")).get("data");
  org.junit.jupiter.api.Assertions.assertEquals("••••0001",queue.get(0).get("contactPhone").asText());
  org.junit.jupiter.api.Assertions.assertFalse(queue.get(0).hasNonNull("dateOfBirth"));
  org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM recruitment_requests WHERE actor_id=?",Integer.class,u.getId()));
 }
 @Test void rejectsUnverifiedAndUnauthorizedAndIncomplete() throws Exception {
  var u=user(false);
  mvc.perform(get("/api/v1/partner/onboarding").with(jwt().jwt(j->j.subject(u.getId().toString())))).andExpect(status().isForbidden());
  mvc.perform(get("/api/v1/admin/recruitment/applications").with(jwt())).andExpect(status().isForbidden());
  var verified=user(true);call(verified.getId(),"GET","/api/v1/partner/onboarding",null);
  mvc.perform(post("/api/v1/partner/onboarding/submit").with(jwt().jwt(j->j.subject(verified.getId().toString()))).contentType(MediaType.APPLICATION_JSON).content("{\"version\":0,\"requestId\":\"incomplete\"}")).andExpect(status().isUnprocessableEntity());
 }
 @Test void serverExamSnapshotsTwentyQuestionsScoresOnceAndNeverLeaksAnswers() throws Exception {
  var applicant=user(true);var trainer=user(true);
  call(applicant.getId(),"GET","/api/v1/partner/onboarding",null);
  db.update("UPDATE partner_applications SET status='EXAM_REQUIRED' WHERE user_id=?",applicant.getId());
  for(int i=0;i<20;i++)exams.save(trainer.getId(),UUID.randomUUID(),new RecruitmentExamService.QuestionWrite("Câu mẫu "+i,List.of("An toàn","Sai một","Sai hai","Sai ba"),0,"an toàn",1,true,0));
  var started=json.readTree(call(applicant.getId(),"POST","/api/v1/partner/exam/attempts",null)).get("data");
  org.junit.jupiter.api.Assertions.assertEquals(1,exams.partnerConfig(applicant.getId()).get("remaining_attempts"));
  org.junit.jupiter.api.Assertions.assertEquals(20,started.get("questions").size());
  org.junit.jupiter.api.Assertions.assertFalse(started.toString().contains("correctOption"));
  var id=started.get("id").asText();var answers=new HashMap<String,Integer>();
  for(var q:started.get("questions")){org.junit.jupiter.api.Assertions.assertEquals(4,q.get("options").size());for(int i=0;i<4;i++)if(q.get("options").get(i).asText().equals("An toàn"))answers.put(q.get("id").asText(),i);}
  // Editing the live bank cannot alter the saved question snapshot.
  var q=exams.questions().getFirst();exams.save(trainer.getId(),q.id(),new RecruitmentExamService.QuestionWrite(q.text(),q.options(),1,q.category(),1,true,q.version()));
  for(int i=0;i<2;i++){var result=json.readTree(call(applicant.getId(),"POST","/api/v1/partner/exam/attempts/"+id+"/submit",Map.of("answers",answers))).get("data");org.junit.jupiter.api.Assertions.assertEquals(20,result.get("score").asInt());org.junit.jupiter.api.Assertions.assertEquals("PASSED",result.get("status").asText());}
  mvc.perform(get("/api/v1/partner/onboarding").with(jwt().jwt(j->j.subject(applicant.getId().toString())))).andExpect(jsonPath("$.data.status").value("AGREEMENT_REQUIRED"));
  var stranger=user(true);
  mvc.perform(post("/api/v1/partner/exam/attempts/"+id+"/submit").with(jwt().jwt(j->j.subject(stranger.getId().toString()))).contentType(MediaType.APPLICATION_JSON).content("{\"answers\":{}}")).andExpect(status().isNotFound());
 }
 @Test void failedExamReportsReviewTopicsAndServerEnforcesDailyLimit() throws Exception {
  var applicant=user(true);var trainer=user(true);var app=recruitment.current(applicant.getId());
  db.update("UPDATE partner_applications SET status='EXAM_REQUIRED' WHERE id=?",app.id());
  for(int i=0;i<20;i++)exams.save(trainer.getId(),UUID.randomUUID(),new RecruitmentExamService.QuestionWrite("Câu DEMO "+i,List.of("Đúng","Sai 1","Sai 2","Sai 3"),0,"An toàn",1,true,0));
  for(int i=0;i<2;i++){var attempt=exams.start(applicant.getId());exams.submit(applicant.getId(),attempt.id(),new RecruitmentExamService.AnswerWrite(Map.of()));}
  var config=exams.partnerConfig(applicant.getId());org.junit.jupiter.api.Assertions.assertEquals(0,config.get("remaining_attempts"));
  org.junit.jupiter.api.Assertions.assertEquals(Set.of("An toàn"),config.get("review_topics"));
  org.junit.jupiter.api.Assertions.assertFalse(json.writeValueAsString(config).contains("correctOption"));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->exams.start(applicant.getId()));
 }
 @Test void academyRequiresContinuousWatchAndQuizAcrossEveryRequiredLesson() throws Exception {
  var u=user(true);var trainer=user(true);var app=json.readTree(call(u.getId(),"GET","/api/v1/partner/onboarding",null)).get("data");
  var appId=UUID.fromString(app.get("id").asText());db.update("UPDATE partner_applications SET exam_passed=true,status='TRAINING_REQUIRED' WHERE id=?",appId);
  var first=UUID.randomUUID();var second=UUID.randomUUID();
  for(var id:List.of(first,second))training.save(trainer.getId(),id,new RecruitmentTrainingService.LessonWrite("Video mẫu","https://example.test/fictional.mp4",10,1,"An toàn?",List.of("Có","Không","Bỏ qua","Không rõ"),0,true,true,true,id.equals(first)?0:1,0));
  training.heartbeat(u.getId(),first,new RecruitmentTrainingService.Heartbeat(0));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->training.complete(u.getId(),first,new RecruitmentTrainingService.Quiz(0)));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->training.heartbeat(u.getId(),first,new RecruitmentTrainingService.Heartbeat(10)));
  org.junit.jupiter.api.Assertions.assertEquals("LOCKED",training.progress(u.getId()).get(1).status());
  db.update("UPDATE partner_learning_progress SET last_heartbeat_at=? WHERE application_id=? AND lesson_id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(11)),appId,first);
  training.heartbeat(u.getId(),first,new RecruitmentTrainingService.Heartbeat(10));training.complete(u.getId(),first,new RecruitmentTrainingService.Quiz(0));
  org.junit.jupiter.api.Assertions.assertEquals("TRAINING_REQUIRED",db.queryForObject("SELECT status FROM partner_applications WHERE id=?",String.class,appId));
  training.heartbeat(u.getId(),second,new RecruitmentTrainingService.Heartbeat(0));
  db.update("UPDATE partner_learning_progress SET last_heartbeat_at=? WHERE application_id=? AND lesson_id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(11)),appId,second);
  training.heartbeat(u.getId(),second,new RecruitmentTrainingService.Heartbeat(10));training.complete(u.getId(),second,new RecruitmentTrainingService.Quiz(0));
  org.junit.jupiter.api.Assertions.assertEquals("AGREEMENT_REQUIRED",db.queryForObject("SELECT status FROM partner_applications WHERE id=?",String.class,appId));
 }
 @Test void agreementsAreVersionedAndReviewChangesPreserveExamTraining() throws Exception {
  var u=user(true);var admin=user(true);var appId=UUID.fromString(json.readTree(call(u.getId(),"GET","/api/v1/partner/onboarding",null)).get("data").get("id").asText());
  db.update("UPDATE partner_applications SET exam_passed=true,training_complete=true,status='AGREEMENT_REQUIRED' WHERE id=?",appId);
  for(var type:List.of("PARTNER_CONDUCT","PARTNER_SAFETY","PARTNER_COOPERATION","PARTNER_PRIVACY","PARTNER_UNIFORM")){var id=UUID.randomUUID();reviews.saveAgreement(admin.getId(),id,new RecruitmentReviewService.AgreementWrite(type,"demo-1","https://example.test/terms",Instant.now().minusSeconds(60),true));reviews.accept(u.getId(),id);}
  org.junit.jupiter.api.Assertions.assertEquals("PROFILE_INCOMPLETE",db.queryForObject("SELECT status FROM partner_applications WHERE id=?",String.class,appId));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->reviews.submitProfile(u.getId()));
  db.update("UPDATE partner_applications SET status='PRELIMINARY_REVIEW' WHERE id=?",appId);
  var version=db.queryForObject("SELECT version FROM partner_applications WHERE id=?",Long.class,appId);
  var decision=new RecruitmentReviewService.Decision(version,"changes-once","REQUEST_CHANGES","Cần bổ sung hồ sơ",List.of("portrait"));
  reviews.preliminary(admin.getId(),appId,decision);reviews.preliminary(admin.getId(),appId,decision);
  org.junit.jupiter.api.Assertions.assertTrue(db.queryForObject("SELECT exam_passed AND training_complete FROM partner_applications WHERE id=?",Boolean.class,appId));
  org.junit.jupiter.api.Assertions.assertEquals(2,reviews.notifications(u.getId()).size());
  mvc.perform(post("/api/v1/admin/recruitment/applications/"+appId+"/preliminary-decision").with(jwt().jwt(j->j.subject(admin.getId().toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_FINANCE"))).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(decision))).andExpect(status().isForbidden());
 }
 @Test void approvedPartnersCanUpdateWorkAreasWithoutChangingOtherProfileData() throws Exception {
  var u=user(true);var other=user(true);var admin=user(true);
  var app=recruitment.current(u.getId());var otherApp=recruitment.current(other.getId());
  var first=UUID.randomUUID();var second=UUID.randomUUID();
  recruitment.saveArea(admin.getId(),first,new RecruitmentDtos.AreaWrite("TP. Hồ Chí Minh","Quận 1",true,10,List.of(),0));
  recruitment.saveArea(admin.getId(),second,new RecruitmentDtos.AreaWrite("Hà Nội","Hà Nội",true,10,List.of(),0));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.saveWorkAreas(u.getId(),new RecruitmentService.WorkAreasWrite(app.version(),List.of(first))));
  db.update("UPDATE partner_applications SET status='ACTIVE' WHERE id=?",app.id());
  var saved=recruitment.saveWorkAreas(u.getId(),new RecruitmentService.WorkAreasWrite(app.version(),List.of(first,second)));
  org.junit.jupiter.api.Assertions.assertEquals(Set.of(first,second),new java.util.HashSet<>(saved.areaIds()));
  org.junit.jupiter.api.Assertions.assertEquals("TP. Hồ Chí Minh",recruitment.areas().stream().filter(area->area.id().equals(first)).findFirst().orElseThrow().name());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.saveArea(admin.getId(),UUID.randomUUID(),new RecruitmentDtos.AreaWrite("TP. Hồ Chí Minh","Quận 7",true,10,List.of(),0)));
  org.junit.jupiter.api.Assertions.assertEquals("ACTIVE",recruitment.current(u.getId()).status());
  org.junit.jupiter.api.Assertions.assertTrue(recruitment.current(other.getId()).areaIds().isEmpty());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.saveWorkAreas(u.getId(),new RecruitmentService.WorkAreasWrite(app.version(),List.of(first))));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.saveWorkAreas(u.getId(),new RecruitmentService.WorkAreasWrite(saved.version(),List.of(UUID.randomUUID()))));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.saveWorkAreas(u.getId(),new RecruitmentService.WorkAreasWrite(saved.version(),List.of())));
  var updated=recruitment.saveWorkAreas(u.getId(),new RecruitmentService.WorkAreasWrite(saved.version(),List.of(second)));
  org.junit.jupiter.api.Assertions.assertEquals(List.of(second),updated.areaIds());
  var partner=jwt().jwt(j->j.subject(u.getId().toString())).authorities(new SimpleGrantedAuthority("ROLE_TASKER"));
  mvc.perform(get("/api/v1/partner/work-areas").with(partner)).andExpect(status().isOk()).andExpect(jsonPath("$.data.areaIds[0]").value(second.toString()));
 }
 @Test void closedWorkAreasBlockCustomersAndNotifyOnlyAffectedPartners() {
  var u=user(true);var other=user(true);var admin=user(true);var app=recruitment.current(u.getId());var otherApp=recruitment.current(other.getId());
  db.update("UPDATE partner_applications SET status='ACTIVE' WHERE id=?",app.id());
  var id=UUID.randomUUID();recruitment.saveArea(admin.getId(),id,new RecruitmentDtos.AreaWrite("Cần Thơ","Cần Thơ",true,10,List.of(),0));
  var saved=recruitment.saveWorkAreas(u.getId(),new RecruitmentService.WorkAreasWrite(app.version(),List.of(id)));
  RecruitmentService.requireOpenCity(db,"Cần Thơ");
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->RecruitmentService.requireOpenCity(db,"Khu vực chưa tạo"));
  recruitment.saveArea(admin.getId(),id,new RecruitmentDtos.AreaWrite("Cần Thơ","Cần Thơ",false,10,List.of(),0));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->RecruitmentService.requireOpenCity(db,"Cần Thơ"));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->recruitment.saveWorkAreas(u.getId(),new RecruitmentService.WorkAreasWrite(saved.version(),List.of(id))));
  org.junit.jupiter.api.Assertions.assertEquals(1,reviews.notifications(u.getId()).size());
  org.junit.jupiter.api.Assertions.assertTrue(reviews.notifications(other.getId()).isEmpty());
  recruitment.deleteArea(admin.getId(),id);
  org.junit.jupiter.api.Assertions.assertEquals(2,reviews.notifications(u.getId()).size());
  org.junit.jupiter.api.Assertions.assertTrue(recruitment.workAreas(u.getId()).areas().stream().noneMatch(a->a.city().equals("Cần Thơ")));
 }
 @Test void uniformsAllowTwoPendingOrdersAndListBothWithoutDuplicateRetries() throws Exception {
  var u=user(true);var admin=user(true);
  var a=UUID.fromString(json.readTree(call(u.getId(),"GET","/api/v1/partner/onboarding",null)).get("data").get("id").asText());
  db.update("UPDATE partner_applications SET preliminary_approved=true,status='PRELIMINARY_APPROVED' WHERE id=?",a);
  var pack=UUID.randomUUID();
  uniforms.save(admin.getId(),pack,new RecruitmentUniformService.PackageWrite("Gói giới hạn","Đồng phục",100,"Mẫu",true,0,Map.of("M",4)));
  var first=uniforms.order(u.getId(),new RecruitmentUniformService.OrderWrite(pack,"M","AT_OFFICE","first"));
  var second=uniforms.order(u.getId(),new RecruitmentUniformService.OrderWrite(pack,"M","ONLINE","second"));
  uniforms.order(u.getId(),new RecruitmentUniformService.OrderWrite(pack,"M","ONLINE","second"));
  org.junit.jupiter.api.Assertions.assertEquals(2,uniforms.orders(u.getId()).size());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->uniforms.order(u.getId(),new RecruitmentUniformService.OrderWrite(pack,"M","ONLINE","third")));
  org.junit.jupiter.api.Assertions.assertEquals(2,db.queryForObject("SELECT stock FROM partner_uniform_inventory WHERE package_id=? AND size='M'",Integer.class,pack));
  uniforms.sandboxPay(u.getId(),(UUID)first.get("id"),new RecruitmentUniformService.Payment("SUCCESS"));
  uniforms.sandboxPay(u.getId(),(UUID)second.get("id"),new RecruitmentUniformService.Payment("FAILURE"));
  org.junit.jupiter.api.Assertions.assertTrue(recruitment.current(u.getId()).eligibility().get("uniform_resolved"));
  uniforms.cancel(u.getId(),(UUID)second.get("id"));
  uniforms.order(u.getId(),new RecruitmentUniformService.OrderWrite(pack,"M","ONLINE","third"));
  org.junit.jupiter.api.Assertions.assertEquals(3,uniforms.orders(u.getId()).size());
 }
 @Test void uniformsReserveStockAndAllowExplicitSandboxPayment() throws Exception {
  var u=user(true);var admin=user(true);var a=UUID.fromString(json.readTree(call(u.getId(),"GET","/api/v1/partner/onboarding",null)).get("data").get("id").asText());
  var pack=UUID.randomUUID();uniforms.save(admin.getId(),pack,new RecruitmentUniformService.PackageWrite("Gói mẫu","Đồng phục demo",100,"Giá minh họa, không ưu tiên việc",true,0,Map.of("M",1)));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->uniforms.order(u.getId(),new RecruitmentUniformService.OrderWrite(pack,"M","AT_OFFICE","order")));
  db.update("UPDATE partner_applications SET preliminary_approved=true,status='PRELIMINARY_APPROVED' WHERE id=?",a);
  var order=uniforms.order(u.getId(),new RecruitmentUniformService.OrderWrite(pack,"M","AT_OFFICE","order"));var id=(UUID)order.get("id");
  org.junit.jupiter.api.Assertions.assertEquals("PENDING",order.get("payment_status"));
  uniforms.order(u.getId(),new RecruitmentUniformService.OrderWrite(pack,"M","AT_OFFICE","order"));
  org.junit.jupiter.api.Assertions.assertEquals(0,db.queryForObject("SELECT stock FROM partner_uniform_inventory WHERE package_id=? AND size='M'",Integer.class,pack));
  org.junit.jupiter.api.Assertions.assertEquals("PAID",uniforms.sandboxPay(u.getId(),id,new RecruitmentUniformService.Payment("SUCCESS")).get("payment_status"));
  uniforms.confirmOffice(admin.getId(),id);uniforms.confirmOffice(admin.getId(),id);
  org.junit.jupiter.api.Assertions.assertTrue(db.queryForObject("SELECT uniform_resolved FROM partner_applications WHERE id=?",Boolean.class,a));
 }
 @Test void receptionFinalReviewActivationAndSuspensionRespectPrerequisites() throws Exception {
  var u=user(true);var other=user(true);var admin=user(true);var a=UUID.fromString(json.readTree(call(u.getId(),"GET","/api/v1/partner/onboarding",null)).get("data").get("id").asText());
  var b=UUID.fromString(json.readTree(call(other.getId(),"GET","/api/v1/partner/onboarding",null)).get("data").get("id").asText());
  db.update("UPDATE partner_applications SET preliminary_approved=true,uniform_resolved=true,agreements_current=true,status='PRELIMINARY_APPROVED' WHERE id IN (?,?)",a,b);
  acceptedTerms(u.getId(),admin.getId());
  // This focused office fixture already completed the current mandatory Academy version.
  var academy=UUID.randomUUID();training.save(admin.getId(),academy,new RecruitmentTrainingService.LessonWrite("Formation DEMO","https://example.test/fixture.mp4",10,1,"An toàn?",List.of("Có","Không","Bỏ qua","Chưa rõ"),0,true,true,true,0,0));
  db.update("UPDATE partner_applications SET exam_passed=true,training_complete=true WHERE id=?",a);
  db.update("INSERT INTO partner_learning_progress(application_id,lesson_id,lesson_version,position_seconds,watched_seconds,quiz_passed,completed_at,last_heartbeat_at) VALUES(?,?,0,10,10,true,?,?)",a,academy,java.sql.Timestamp.from(Instant.now()),java.sql.Timestamp.from(Instant.now()));
  var slot=UUID.randomUUID();office.saveSlot(admin.getId(),slot,new RecruitmentOfficeService.SlotWrite("Văn phòng mẫu","Địa chỉ hư cấu",Instant.now().plusSeconds(86400),1,true,0));
  var booked=office.book(u.getId(),new RecruitmentOfficeService.AppointmentWrite(slot,"book-once"));var appointment=(UUID)booked.get("id");
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->office.book(other.getId(),new RecruitmentOfficeService.AppointmentWrite(slot,"full")));
  var checklist=UUID.randomUUID();office.saveChecklist(admin.getId(),checklist,new RecruitmentOfficeService.ChecklistWrite("Đối chiếu giấy tờ mẫu",true,true));
  office.checkin(admin.getId(),appointment,new RecruitmentOfficeService.Checkin((String)booked.get("checkin_code")));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->office.receive(admin.getId(),appointment,new RecruitmentOfficeService.Receive(Map.of(checklist,true),false,"Mẫu")));
  office.receive(admin.getId(),appointment,new RecruitmentOfficeService.Receive(Map.of(checklist,true),true,"Đã trả bản chính mẫu"));
  office.receive(admin.getId(),appointment,new RecruitmentOfficeService.Receive(Map.of(checklist,true),true,"Đã trả bản chính mẫu"));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->office.receive(admin.getId(),appointment,new RecruitmentOfficeService.Receive(Map.of(checklist,false),true,"Thay đổi biên nhận")));
  org.junit.jupiter.api.Assertions.assertEquals(1,office.receipts(u.getId()).size());
  org.junit.jupiter.api.Assertions.assertEquals(0,office.receipts(other.getId()).size());
  var version=db.queryForObject("SELECT version FROM partner_applications WHERE id=?",Long.class,a);
  activation.finalDecision(admin.getId(),a,new RecruitmentReviewService.Decision(version,"final-once","APPROVE_FINAL","Hồ sơ mẫu hợp lệ",List.of()));
  mvc.perform(get("/api/v1/partner/jobs").with(jwt().jwt(j->j.subject(u.getId().toString())))).andExpect(status().isForbidden());
  // An APPROVED applicant with missing skills/areas cannot activate.
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->activation.activate(u.getId(),new RecruitmentActivationService.Activation(version+1,Instant.now(),Instant.now().plusSeconds(3600))));
  org.junit.jupiter.api.Assertions.assertNotNull(activation.sla(u.getId()).get("expectedUntil"));
  db.update("UPDATE partner_applications SET status='ACTIVE',skills_configured=true,areas_configured=true,availability_configured=true WHERE id=?",a);
  activation.feed(u.getId());
  activation.finalDecision(admin.getId(),a,new RecruitmentReviewService.Decision(version+1,"suspend","SUSPEND","Tạm ngưng thử nghiệm",List.of()));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->activation.accept(u.getId(),UUID.randomUUID()));
 }
 @Test void missingOfficeDocumentsCanBeSupplementedWithoutResettingQualifications() throws Exception {
  var u=user(true);var staff=user(true);var app=recruitment.current(u.getId());
  db.update("UPDATE partner_applications SET preliminary_approved=true,exam_passed=true,training_complete=true,status='PRELIMINARY_APPROVED' WHERE id=?",app.id());
  var slot=UUID.randomUUID();office.saveSlot(staff.getId(),slot,new RecruitmentOfficeService.SlotWrite("Văn phòng DEMO","Địa chỉ hư cấu",Instant.now().plusSeconds(86400),1,true,0));
  var check=UUID.randomUUID();office.saveChecklist(staff.getId(),check,new RecruitmentOfficeService.ChecklistWrite("Giấy tờ mẫu",true,true));
  for(int i=0;i<2;i++){
   var booking=office.book(u.getId(),new RecruitmentOfficeService.AppointmentWrite(slot,"supplement-"+i));var id=(UUID)booking.get("id");
   office.checkin(staff.getId(),id,new RecruitmentOfficeService.Checkin((String)booking.get("checkin_code")));
   office.receive(staff.getId(),id,new RecruitmentOfficeService.Receive(Map.of(check,i==1),true,"Biên nhận DEMO "+i));
   var current=recruitment.current(u.getId());org.junit.jupiter.api.Assertions.assertEquals(i==0?"ACTION_REQUIRED":"DOCUMENTS_RECEIVED",current.status());
   org.junit.jupiter.api.Assertions.assertTrue(current.eligibility().get("exam_passed"));org.junit.jupiter.api.Assertions.assertTrue(current.eligibility().get("training_complete"));
   if(i==0)org.junit.jupiter.api.Assertions.assertNull(current.documentsReceivedAt());else org.junit.jupiter.api.Assertions.assertNotNull(current.documentsReceivedAt());
  }
  org.junit.jupiter.api.Assertions.assertEquals(2,office.receipts(u.getId()).size());
  db.update("UPDATE partner_applications SET status='ACTIVE' WHERE id=?",app.id());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->office.book(u.getId(),new RecruitmentOfficeService.AppointmentWrite(slot,"no-rewind")));
 }
 @Test void appealReopensReviewWithoutGrantingJobAccess() throws Exception {
  var u=user(true);var admin=user(true);var app=recruitment.current(u.getId());
  db.update("UPDATE partner_applications SET status='REJECTED' WHERE id=?",app.id());
  activation.appeal(u.getId(),new RecruitmentActivationService.Appeal("Đề nghị xem xét hồ sơ hư cấu"));
  var id=db.queryForObject("SELECT id FROM partner_appeals WHERE application_id=?",UUID.class,app.id());
  mvc.perform(post("/api/v1/admin/recruitment/appeals/"+id+"/resolve").with(jwt().jwt(j->j.subject(u.getId().toString()))).contentType(MediaType.APPLICATION_JSON).content("{\"action\":\"REOPEN\",\"reason\":\"Mẫu\"}")).andExpect(status().isForbidden());
  activation.resolveAppeal(admin.getId(),id,new RecruitmentActivationService.AppealDecision("REOPEN","Kiểm tra lại hồ sơ mẫu"));
  org.junit.jupiter.api.Assertions.assertEquals("PRELIMINARY_REVIEW",recruitment.current(u.getId()).status());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->activation.feed(u.getId()));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->activation.resolveAppeal(admin.getId(),id,new RecruitmentActivationService.AppealDecision("REOPEN","Lặp")));
 }
 @Test void databaseFlowFromRegistrationToActiveAndRealTaskAssignment() throws Exception {
  var u=user(true);var admin=user(true);var customer=user(true);var now=Instant.now();
  var cat=categories.saveAndFlush(new ServiceCategory("flow-"+UUID.randomUUID(),"Nhà cửa","",0,now));
  var svc=services.saveAndFlush(new CatalogueService(cat,"flow-"+UUID.randomUUID(),"Dọn nhà","Mô tả","",0,100000,"VND",60,0,now));db.update("UPDATE services SET active=true WHERE id=?",svc.getId());
  var area=UUID.randomUUID();recruitment.saveArea(admin.getId(),area,new RecruitmentDtos.AreaWrite("Thành phố mẫu","Khu mẫu",true,10,List.of(svc.getId()),0));
  var app=recruitment.current(u.getId());app=recruitment.save(u.getId(),new RecruitmentDtos.Registration(app.version(),"Ứng viên mẫu","0900000009",LocalDate.of(1995,1,1),List.of(area),List.of(svc.getId()),"","",""));app=recruitment.submit(u.getId(),new RecruitmentDtos.Submit(app.version(),"full-register"));
  for(int i=0;i<20;i++)exams.save(admin.getId(),UUID.randomUUID(),new RecruitmentExamService.QuestionWrite("Tình huống mẫu "+i,List.of("Đúng","Sai 1","Sai 2","Sai 3"),0,"An toàn",1,true,0));
  var attempt=exams.start(u.getId());var answers=new HashMap<String,Integer>();for(var q:attempt.questions())answers.put(q.id().toString(),q.options().indexOf("Đúng"));exams.submit(u.getId(),attempt.id(),new RecruitmentExamService.AnswerWrite(answers));
  var lesson=UUID.randomUUID();training.save(admin.getId(),lesson,new RecruitmentTrainingService.LessonWrite("Đào tạo DEMO","https://example.test/fictional.mp4",10,1,"An toàn?",List.of("Có","Không","Bỏ qua","Không rõ"),0,true,true,true,0,0));training.heartbeat(u.getId(),lesson,new RecruitmentTrainingService.Heartbeat(0));db.update("UPDATE partner_learning_progress SET last_heartbeat_at=? WHERE application_id=?",java.sql.Timestamp.from(now.minusSeconds(20)),app.id());training.heartbeat(u.getId(),lesson,new RecruitmentTrainingService.Heartbeat(10));training.complete(u.getId(),lesson,new RecruitmentTrainingService.Quiz(0));
  for(var type:List.of("PARTNER_CONDUCT","PARTNER_SAFETY","PARTNER_COOPERATION","PARTNER_PRIVACY","PARTNER_UNIFORM")){var id=UUID.randomUUID();reviews.saveAgreement(admin.getId(),id,new RecruitmentReviewService.AgreementWrite(type,"flow-1","https://example.test/fictional-policy",now.minusSeconds(60),true));reviews.accept(u.getId(),id);}
  reviews.demoIdentity(u.getId());
  db.update("UPDATE partner_applications SET editable_until=? WHERE id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(1)),app.id());
  var kyc=verification.current(u.getId());verification.decide(admin.getId(),kyc.id(),com.taskly.verification.entity.VerificationStatus.APPROVED,"DEMO metadata; no actual identity verified");app=recruitment.current(u.getId());reviews.preliminary(admin.getId(),app.id(),new RecruitmentReviewService.Decision(app.version(),"full-prelim","APPROVE_PRELIMINARY","Hồ sơ mẫu",List.of()));
  var pack=UUID.randomUUID();uniforms.save(admin.getId(),pack,new RecruitmentUniformService.PackageWrite("Cơ bản DEMO","Gói mẫu miễn phí",0,"Mẫu, không thu tiền",true,0,Map.of("M",1)));uniforms.order(u.getId(),new RecruitmentUniformService.OrderWrite(pack,"M","AT_OFFICE","full-uniform"));
  var slot=UUID.randomUUID();office.saveSlot(admin.getId(),slot,new RecruitmentOfficeService.SlotWrite("Văn phòng DEMO","Địa chỉ hư cấu",now.plusSeconds(86400),1,true,0));var booking=office.book(u.getId(),new RecruitmentOfficeService.AppointmentWrite(slot,"full-book"));var appt=(UUID)booking.get("id");office.checkin(admin.getId(),appt,new RecruitmentOfficeService.Checkin((String)booking.get("checkin_code")));var check=UUID.randomUUID();office.saveChecklist(admin.getId(),check,new RecruitmentOfficeService.ChecklistWrite("Đối chiếu tài liệu mẫu",true,true));office.receive(admin.getId(),appt,new RecruitmentOfficeService.Receive(Map.of(check,true),true,"Đã trả bản chính mẫu"));
  app=recruitment.current(u.getId());activation.finalDecision(admin.getId(),app.id(),new RecruitmentReviewService.Decision(app.version(),"full-final","APPROVE_FINAL","Hồ sơ mẫu đầy đủ",List.of()));app=recruitment.current(u.getId());activation.activate(u.getId(),new RecruitmentActivationService.Activation(app.version(),now,now.plusSeconds(604800)));
  var task=new com.taskly.task.entity.CustomerTask(customer,svc,"Việc DEMO","Mô tả","Địa chỉ hư cấu","Thành phố mẫu",null,null,now.plusSeconds(86400),60,100000,"VND","",now);task.post(now);tasks.saveAndFlush(task);
  db.update("INSERT INTO service_pricing_rules(service_id,mode,base_amount,unit_amount,platform_fee_amount,platform_fee_percent,quote_ttl_minutes,enabled,updated_by) VALUES(?,'FIXED',100000,0,0,10,15,true,?)",svc.getId(),admin.getId());
  org.junit.jupiter.api.Assertions.assertEquals(90000L,((Number)activation.feed(u.getId()).getFirst().get("partner_net_amount")).longValue());
  // An expired former availability window must not hide an existing eligible job.
  db.update("UPDATE partner_availability SET starts_at=?,ends_at=? WHERE application_id=?",java.sql.Timestamp.from(now.minusSeconds(172800)),java.sql.Timestamp.from(now.minusSeconds(86400)),app.id());
  org.junit.jupiter.api.Assertions.assertEquals(1,activation.feed(u.getId()).size());activation.accept(u.getId(),task.getId());activation.accept(u.getId(),task.getId());org.junit.jupiter.api.Assertions.assertEquals(u.getId(),db.queryForObject("SELECT tasker_id FROM tasks WHERE id=?",UUID.class,task.getId()));
  org.junit.jupiter.api.Assertions.assertEquals(10000L,db.queryForObject("SELECT platform_fee_snapshot FROM tasks WHERE id=?",Long.class,task.getId()));
  db.update("UPDATE service_pricing_rules SET platform_fee_percent=20 WHERE service_id=?",svc.getId());
  org.junit.jupiter.api.Assertions.assertEquals(10000L,db.queryForObject("SELECT platform_fee_snapshot FROM tasks WHERE id=?",Long.class,task.getId()));
  org.junit.jupiter.api.Assertions.assertEquals("ACTIVE",recruitment.current(u.getId()).status());
  var dossier=json.readTree(call(admin.getId(),"GET","/api/v1/admin/recruitment/applications/"+app.id()+"/dossier",null,"RECRUITMENT_VIEW","KYC_REVIEW")).get("data");
  for(var section:List.of("areas","services","exams","lessons","agreements","identities","uniforms","appointments","receipts","decisions","timeline","availability","identityHistory"))org.junit.jupiter.api.Assertions.assertTrue(dossier.get(section).size()>0,section);
  org.junit.jupiter.api.Assertions.assertEquals(20,dossier.get("exams").get(0).get("score").asInt());
  // A new mandatory version must block job access even if cached eligibility flags say ACTIVE.
  db.update("UPDATE partner_training_lessons SET version=version+1 WHERE id=?",lesson);
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->activation.feed(u.getId()));
  db.update("UPDATE partner_learning_progress SET lesson_version=1 WHERE application_id=? AND lesson_id=?",app.id(),lesson);
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->activation.progressJob(u.getId(),task.getId(),new RecruitmentActivationService.JobStatus("ACCEPTED","COMPLETED","skip-step")));
  String previous="ACCEPTED";for(String next:List.of("TASKER_ON_THE_WAY","ARRIVED","IN_PROGRESS","COMPLETED")){var change=new RecruitmentActivationService.JobStatus(previous,next,"progress-"+next);activation.progressJob(u.getId(),task.getId(),change);activation.progressJob(u.getId(),task.getId(),change);previous=next;}
  org.junit.jupiter.api.Assertions.assertEquals(5,db.queryForObject("SELECT COUNT(*) FROM task_status_history WHERE task_id=?",Integer.class,task.getId()));
  mvc.perform(post("/api/v1/task-activity/"+task.getId()+"/messages").with(jwt().jwt(j->j.subject(u.getId().toString()))).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("text","Tin nhắn DEMO cho khách hàng","requestId",UUID.randomUUID())))).andExpect(status().isOk());
  mvc.perform(get("/api/v1/task-activity/"+task.getId()).with(jwt().jwt(j->j.subject(customer.getId().toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data.messages[0].text").value("Tin nhắn DEMO cho khách hàng"));
  mvc.perform(get("/api/v1/admin/customers").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_SUPER_ADMIN"))))
   .andExpect(status().isOk()).andExpect(jsonPath("$.data[?(@.id == '"+u.getId()+"')].recruitment_status").value("ACTIVE"))
   .andExpect(jsonPath("$.data[?(@.id == '"+u.getId()+"')].accepted_jobs").value(1))
   .andExpect(jsonPath("$.data[?(@.id == '"+u.getId()+"')].completed_jobs").value(1))
   .andExpect(jsonPath("$.data[?(@.id == '"+u.getId()+"')].partner_checks.final_approved").value(true));
  db.update("UPDATE identity_verifications SET status='REJECTED' WHERE user_id=?",u.getId());
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->activation.feed(u.getId()));
 }
}


