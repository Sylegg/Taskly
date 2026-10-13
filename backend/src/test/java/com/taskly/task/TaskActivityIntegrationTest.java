package com.taskly.task;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.taskly.catalogue.entity.*;
import com.taskly.catalogue.repository.*;
import com.taskly.rbac.repository.RoleRepository;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.repository.UserAccountRepository;
import com.taskly.task.entity.CustomerTask;
import com.taskly.task.repository.CustomerTaskRepository;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") @Transactional
class TaskActivityIntegrationTest {
 @Autowired MockMvc mvc; @Autowired JdbcTemplate db; @Autowired UserAccountRepository users; @Autowired RoleRepository roles; @Autowired ServiceCategoryRepository categories; @Autowired CatalogueServiceRepository services; @Autowired CustomerTaskRepository tasks;
 UserAccount user(){return users.saveAndFlush(new UserAccount(UUID.randomUUID()+"@test.example",null,"hash",roles.findByKey("CUSTOMER").orElseThrow(),Instant.now()));}
 @Test void adminCanCancelEveryActiveStatusButCustomerCannotUseAdminEndpoint() throws Exception {
  var owner=user();var tasker=user();var now=Instant.now();
  var category=categories.saveAndFlush(new ServiceCategory("cat-"+UUID.randomUUID(),"Category","",0,now));
  var service=services.saveAndFlush(new CatalogueService(category,"svc-"+UUID.randomUUID(),"Service","Description","",100000,200000,"VND",120,0,now));
  for(var state:java.util.List.of("POSTED","MATCHING","ACCEPTED","TASKER_ON_THE_WAY","ARRIVED","IN_PROGRESS","COMPLETED","PAID","DISPUTED")) {
   var task=tasks.saveAndFlush(new CustomerTask(owner,service,"Task","Description","Address","HCM",null,null,now.plusSeconds(3600),120,150000,"VND","",now));
   var id=task.getId();var url="/api/v1/admin/tasks/"+id+"/cancel";
   db.update("UPDATE tasks SET status=?,tasker_id=? WHERE id=?",state,tasker.getId(),id);
   mvc.perform(post(url).with(jwt().jwt(j->j.subject(owner.getId().toString()))).contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"Khách yêu cầu hỗ trợ\"}")).andExpect(status().isForbidden());
   var admin=jwt().authorities(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_ADMIN"));
   for(int retry=0;retry<2;retry++)mvc.perform(post(url).with(admin).contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"Khách yêu cầu hỗ trợ\"}")).andExpect(status().isOk()).andExpect(jsonPath("$.data.status").value("CANCELLED"));
   org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM task_status_history WHERE task_id=? AND actor_role='ADMIN'",Integer.class,id));
  }
 }
 @Test void partnerLimitsTodayAndAllFutureDaysAndWorksOnlyOneTaskAtATime() {
  var owner=user();var partner=user();var zone=java.time.ZoneId.of("Asia/Ho_Chi_Minh");
  var now=Instant.parse("2026-10-13T05:00:00Z");var today=now.atZone(zone).toLocalDate();
  var category=categories.saveAndFlush(new ServiceCategory("cat-"+UUID.randomUUID(),"Category","",0,now));
  var service=services.saveAndFlush(new CatalogueService(category,"svc-"+UUID.randomUUID(),"Service","Description","",100000,200000,"VND",120,0,now));
  var todayIds=new java.util.ArrayList<UUID>();
  for(int i=0;i<3;i++) {
   var time=today.atTime(8+i*4,0).atZone(zone).toInstant();
   var t=tasks.saveAndFlush(new CustomerTask(owner,service,"Task","Description","Address","HCM",null,null,time,120,150000,"VND","",now));
   db.update("UPDATE tasks SET status=?,tasker_id=? WHERE id=?",i==0?"COMPLETED":"ACCEPTED",partner.getId(),t.getId());todayIds.add(t.getId());
  }
  var candidate=UUID.randomUUID();
  org.junit.jupiter.api.Assertions.assertEquals("PARTNER_DAILY_LIMIT",PartnerWorkPolicy.bookingLimit(db,partner.getId(),candidate,now,now).code());
  org.junit.jupiter.api.Assertions.assertNull(PartnerWorkPolicy.bookingLimit(db,partner.getId(),todayIds.get(1),now,now));
  var tomorrow=today.plusDays(1).atTime(8,0).atZone(zone).toInstant();
  org.junit.jupiter.api.Assertions.assertNull(PartnerWorkPolicy.bookingLimit(db,partner.getId(),candidate,tomorrow,now));
  var future=tasks.saveAndFlush(new CustomerTask(owner,service,"Future","Description","Address","HCM",null,null,tomorrow,120,150000,"VND","",now));
  db.update("UPDATE tasks SET status='ACCEPTED',tasker_id=? WHERE id=?",partner.getId(),future.getId());
  org.junit.jupiter.api.Assertions.assertEquals("PARTNER_ADVANCE_LIMIT",PartnerWorkPolicy.bookingLimit(db,partner.getId(),candidate,tomorrow.plusSeconds(86400*5),now).code());
  db.update("UPDATE tasks SET status='CANCELLED' WHERE id=?",future.getId());
  org.junit.jupiter.api.Assertions.assertNull(PartnerWorkPolicy.bookingLimit(db,partner.getId(),candidate,tomorrow,now));
  db.update("UPDATE tasks SET status='IN_PROGRESS' WHERE id=?",todayIds.get(1));
  org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->PartnerWorkPolicy.requireFree(db,partner.getId(),todayIds.get(2)));
  org.junit.jupiter.api.Assertions.assertDoesNotThrow(()->PartnerWorkPolicy.requireFree(db,partner.getId(),todayIds.get(1)));
  db.update("UPDATE tasks SET status='COMPLETED' WHERE id=?",todayIds.get(1));
  org.junit.jupiter.api.Assertions.assertDoesNotThrow(()->PartnerWorkPolicy.requireFree(db,partner.getId(),todayIds.get(2)));
 }
 @Test void lateArrivalReportRequiresOwnerAndThirtyMinutesAndIsSentOnce() throws Exception {
  var owner=user();var tasker=user();var now=Instant.now();
  var category=categories.saveAndFlush(new ServiceCategory("cat-"+UUID.randomUUID(),"Category","",0,now));
  var service=services.saveAndFlush(new CatalogueService(category,"svc-"+UUID.randomUUID(),"Service","Description","",100000,200000,"VND",120,0,now));
  var task=tasks.saveAndFlush(new CustomerTask(owner,service,"Task","Description","Address","HCM",null,null,now.plusSeconds(3600),120,150000,"VND","",now));
  var id=task.getId();var event=UUID.randomUUID();var url="/api/v1/task-activity/"+id+"/arrival-report";
  var auth=jwt().jwt(j->j.subject(owner.getId().toString()));
  db.update("UPDATE tasks SET scheduled_at=? WHERE id=?",java.sql.Timestamp.from(now.minusSeconds(3600)),id);
  db.update("UPDATE tasks SET status='TASKER_ON_THE_WAY',tasker_id=? WHERE id=?",tasker.getId(),id);
  db.update("INSERT INTO task_status_history(id,task_id,to_status,actor_role,occurred_at) VALUES(?,?,'TASKER_ON_THE_WAY','TASKER',?)",event,id,java.sql.Timestamp.from(now.minusSeconds(1790)));
  mvc.perform(get(url).with(auth)).andExpect(status().isOk()).andExpect(jsonPath("$.data.eligible").value(false));
  mvc.perform(post(url).with(auth)).andExpect(status().isConflict());
  db.update("UPDATE task_status_history SET occurred_at=? WHERE id=?",java.sql.Timestamp.from(now.minusSeconds(1801)),event);
  mvc.perform(get(url).with(auth)).andExpect(jsonPath("$.data.eligible").value(true));
  db.update("UPDATE tasks SET scheduled_at=? WHERE id=?",java.sql.Timestamp.from(now.plusSeconds(3600)),id);
  mvc.perform(get(url).with(auth)).andExpect(jsonPath("$.data.eligible").value(false));
  mvc.perform(post(url).with(auth)).andExpect(status().isConflict());
  db.update("UPDATE tasks SET scheduled_at=? WHERE id=?",java.sql.Timestamp.from(now.minusSeconds(60)),id);
  mvc.perform(post(url).with(auth)).andExpect(status().isConflict());
  db.update("UPDATE tasks SET scheduled_at=? WHERE id=?",java.sql.Timestamp.from(now.minusSeconds(3600)),id);
  mvc.perform(post(url).with(jwt().jwt(j->j.subject(tasker.getId().toString())))).andExpect(status().isNotFound());
  db.update("UPDATE tasks SET status='ARRIVED' WHERE id=?",id);
  mvc.perform(post(url).with(auth)).andExpect(status().isConflict());
  db.update("UPDATE tasks SET status='TASKER_ON_THE_WAY' WHERE id=?",id);
  for(int i=0;i<2;i++)mvc.perform(post(url).with(auth)).andExpect(status().isOk()).andExpect(jsonPath("$.data.reported").value(true));
  org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM task_arrival_reports WHERE task_id=?",Integer.class,id));
  org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM customer_support_messages WHERE task_id=? AND user_id=?",Integer.class,id,owner.getId()));
  org.junit.jupiter.api.Assertions.assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM support_messages WHERE user_id=?",Integer.class,owner.getId()));
  var staff=jwt().authorities(new org.springframework.security.core.authority.SimpleGrantedAuthority("RECRUITMENT_VIEW"));
  mvc.perform(get("/api/v1/admin/support/customer/"+owner.getId()+"/messages").with(staff)).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].task_id").value(id.toString()));
 }
 @Test void unassignedTaskCanBeReportedAfterThirtyMinutes() throws Exception {
  var owner=user();var now=Instant.now();
  var category=categories.saveAndFlush(new ServiceCategory("cat-"+UUID.randomUUID(),"Category","",0,now));
  var service=services.saveAndFlush(new CatalogueService(category,"svc-"+UUID.randomUUID(),"Service","Description","",100000,200000,"VND",120,0,now));
  var task=tasks.saveAndFlush(new CustomerTask(owner,service,"Task","Description","Address","HCM",null,null,now.plusSeconds(86400),120,150000,"VND","",now));
  var id=task.getId();var url="/api/v1/task-activity/"+id+"/arrival-report";var auth=jwt().jwt(j->j.subject(owner.getId().toString()));
  db.update("UPDATE tasks SET status='POSTED' WHERE id=?",id);
  mvc.perform(get(url).with(auth)).andExpect(status().isOk()).andExpect(jsonPath("$.data.visible").value(false)).andExpect(jsonPath("$.data.reportType").value("NO_TASKER")).andExpect(jsonPath("$.data.eligible").value(false));
  mvc.perform(post(url).with(auth)).andExpect(status().isConflict());
  db.update("UPDATE tasks SET created_at=? WHERE id=?",java.sql.Timestamp.from(now.minusSeconds(1801)),id);
  mvc.perform(get(url).with(auth)).andExpect(jsonPath("$.data.eligible").value(false));
  db.update("UPDATE tasks SET scheduled_at=? WHERE id=?",java.sql.Timestamp.from(now.minusSeconds(600)),id);
  mvc.perform(get(url).with(auth)).andExpect(jsonPath("$.data.visible").value(true)).andExpect(jsonPath("$.data.eligible").value(false));
  mvc.perform(post(url).with(auth)).andExpect(status().isConflict());
  db.update("UPDATE tasks SET scheduled_at=? WHERE id=?",java.sql.Timestamp.from(now.minusSeconds(1801)),id);
  mvc.perform(get(url).with(auth)).andExpect(jsonPath("$.data.eligible").value(true));
  for(int i=0;i<2;i++)mvc.perform(post(url).with(auth)).andExpect(status().isOk()).andExpect(jsonPath("$.data.reported").value(true));
  org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM task_arrival_reports WHERE task_id=? AND report_type='NO_TASKER'",Integer.class,id));
  org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM customer_support_messages WHERE task_id=?",Integer.class,id));
  db.update("UPDATE tasks SET status='CANCELLED' WHERE id=?",id);
  mvc.perform(get(url).with(auth)).andExpect(jsonPath("$.data.visible").value(false));
  mvc.perform(post(url).with(auth)).andExpect(status().isConflict());
 }
 @Test void supportTaskSelectionIsScopedToCustomerAndAssignedPartner() throws Exception {
  var owner=user();var partner=user();var now=Instant.now();
  var category=categories.saveAndFlush(new ServiceCategory("cat-"+UUID.randomUUID(),"Category","",0,now));
  var service=services.saveAndFlush(new CatalogueService(category,"svc-"+UUID.randomUUID(),"Service","Description","",100000,200000,"VND",120,0,now));
  var task=tasks.saveAndFlush(new CustomerTask(owner,service,"Task","Description","Address","HCM",null,null,now.plusSeconds(86400),120,150000,"VND","",now));
  var id=task.getId();db.update("UPDATE tasks SET status='ACCEPTED',tasker_id=? WHERE id=?",partner.getId(),id);
  var customerAuth=jwt().jwt(j->j.subject(owner.getId().toString())).authorities(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_CUSTOMER"));
  var partnerAuth=jwt().jwt(j->j.subject(partner.getId().toString())).authorities(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_CUSTOMER"));
  mvc.perform(get("/api/v1/customer/support/tasks").with(customerAuth)).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].id").value(id.toString()));
  mvc.perform(get("/api/v1/support/tasks").with(customerAuth)).andExpect(jsonPath("$.data.length()").value(0));
  mvc.perform(get("/api/v1/support/tasks").with(partnerAuth)).andExpect(jsonPath("$.data[0].id").value(id.toString()));
  mvc.perform(get("/api/v1/customer/support/tasks").with(partnerAuth)).andExpect(jsonPath("$.data.length()").value(0));
  var body="{\"requestId\":\""+UUID.randomUUID()+"\",\"text\":\"Help with this order\",\"taskId\":\""+id+"\"}";
  mvc.perform(post("/api/v1/customer/support/messages").with(customerAuth).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
  mvc.perform(post("/api/v1/support/messages").with(partnerAuth).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
  mvc.perform(post("/api/v1/support/messages").with(customerAuth).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isNotFound());
  mvc.perform(post("/api/v1/customer/support/messages").with(partnerAuth).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isNotFound());
  mvc.perform(get("/api/v1/support/messages").with(partnerAuth)).andExpect(jsonPath("$.data[0].task_id").value(id.toString()));
  mvc.perform(get("/api/v1/customer/support/messages").with(customerAuth)).andExpect(jsonPath("$.data[0].task_id").value(id.toString()));
  for(var ended:java.util.List.of("COMPLETED","PAID","CANCELLED","REFUNDED","EXPIRED")) {
   db.update("UPDATE tasks SET status=? WHERE id=?",ended,id);
   mvc.perform(get("/api/v1/customer/support/tasks").with(customerAuth)).andExpect(jsonPath("$.data.length()").value(0));
   mvc.perform(get("/api/v1/support/tasks").with(partnerAuth)).andExpect(jsonPath("$.data.length()").value(0));
  }
 }
 @Test void adminTasksReadDatabaseAndEnforceRoles() throws Exception {
  var now=Instant.now(); var owner=user();
  var category=categories.saveAndFlush(new ServiceCategory("cat-"+UUID.randomUUID(),"Category","",0,now));
  var service=services.saveAndFlush(new CatalogueService(category,"svc-"+UUID.randomUUID(),"Real service","Description","",100000,200000,"VND",120,0,now));
  var task=tasks.saveAndFlush(new CustomerTask(owner,service,"Real task","Description","Real address","HCM",null,null,now.plusSeconds(86400),120,150000,"VND","",now));
  db.update("UPDATE tasks SET status='POSTED',recipient_name_snapshot=?,recipient_phone_snapshot=?,building_type_snapshot=?,building_description_snapshot=?,ward_snapshot=?,district_snapshot=?,address_notes_snapshot=? WHERE id=?","vu","0909098678","Nhà riêng","Tầng 2","Phường 1","Quận 1","Gọi trước khi đến",task.getId());
  mvc.perform(get("/api/v1/task-activity/"+task.getId()).with(jwt().jwt(j->j.subject(owner.getId().toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data.addressDetails.recipientName").value("vu")).andExpect(jsonPath("$.data.addressDetails.recipientPhone").value("0909098678")).andExpect(jsonPath("$.data.addressDetails.buildingType").value("Nhà riêng")).andExpect(jsonPath("$.data.addressDetails.buildingDescription").value("Tầng 2")).andExpect(jsonPath("$.data.addressDetails.ward").value("Phường 1")).andExpect(jsonPath("$.data.addressDetails.notes").value("Gọi trước khi đến"));
  var admin=jwt().authorities(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_ADMIN"));
  mvc.perform(get("/api/v1/admin/tasks")).andExpect(status().isUnauthorized());
  mvc.perform(get("/api/v1/admin/tasks").with(jwt().authorities(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_CUSTOMER")))) .andExpect(status().isForbidden());
  mvc.perform(get("/api/v1/admin/tasks").with(admin)).andExpect(status().isOk()).andExpect(jsonPath("$.data[?(@.id == '"+task.getId()+"')].service").value("Real service"));
  db.update("INSERT INTO task_status_history(id,task_id,to_status,actor_role,occurred_at) VALUES(?,?,'POSTED','CUSTOMER',CURRENT_TIMESTAMP)",UUID.randomUUID(),task.getId());
  mvc.perform(get("/api/v1/admin/tasks/"+task.getId()+"/history").with(admin)).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].status").value("POSTED"));
  mvc.perform(get("/api/v1/admin/tasks/"+UUID.randomUUID()+"/history").with(admin)).andExpect(status().isNotFound());
 }
 @Test void chatIsScopedToAssignedParticipantsAndRetriesDoNotDuplicate()throws Exception {
  var owner=user();var tasker=user();var stranger=user();var now=Instant.now();
  var category=categories.saveAndFlush(new ServiceCategory("cat-"+UUID.randomUUID(),"Nhà cửa","",0,now));
  var service=services.saveAndFlush(new CatalogueService(category,"svc-"+UUID.randomUUID(),"Dịch vụ","Mô tả","",100000,200000,"VND",120,0,now));
  var task=new CustomerTask(owner,service,"Dọn nhà","Mô tả","Địa chỉ","HCM",null,null,now.plusSeconds(86400),120,100000,"VND","",now);task.post(now);tasks.saveAndFlush(task);var id=task.getId();
  var auth=jwt().jwt(j->j.subject(owner.getId().toString()));
  var other=jwt().jwt(j->j.subject(stranger.getId().toString()));
  var message="{\"text\":\"Xin chào\",\"requestId\":\""+UUID.randomUUID()+"\"}";
  mvc.perform(get("/api/v1/task-activity").with(auth)).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].id").value(id.toString()));
  mvc.perform(post("/api/v1/task-activity/"+id+"/messages").with(auth).contentType(MediaType.APPLICATION_JSON).content(message)).andExpect(status().isUnprocessableEntity());
  db.update("UPDATE tasks SET tasker_id=?,status='ACCEPTED' WHERE id=?",tasker.getId(),id);
  db.update("INSERT INTO service_pricing_rules(service_id,mode,base_amount,unit_amount,platform_fee_amount,platform_fee_percent,quote_ttl_minutes,enabled,updated_by) VALUES(?,'FIXED',100000,0,0,10,15,true,?)",service.getId(),owner.getId());
  db.update("UPDATE tasks SET platform_fee_snapshot=(SELECT "+PartnerEarnings.FEE_SQL+" FROM tasks t LEFT JOIN service_pricing_rules r ON r.service_id=t.service_id WHERE t.id=tasks.id) WHERE id=?",id);
  db.update("UPDATE service_pricing_rules SET platform_fee_percent=20 WHERE service_id=?",service.getId());
  mvc.perform(get("/api/v1/task-activity").with(jwt().jwt(j->j.subject(tasker.getId().toString()))))
    .andExpect(jsonPath("$.data[0].budgetAmount").value(100000))
    .andExpect(jsonPath("$.data[0].partnerNetAmount").value(90000));
  db.update("INSERT INTO task_status_history(id,task_id,to_status,actor_role,occurred_at) VALUES(?,?,'ACCEPTED','TASKER',CURRENT_TIMESTAMP)",UUID.randomUUID(),id);
  for(int i=0;i<2;i++)mvc.perform(post("/api/v1/task-activity/"+id+"/messages").with(auth).contentType(MediaType.APPLICATION_JSON).content(message)).andExpect(status().isOk());
  String png="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
  var imageMsg="{\"text\":\"Ảnh kiểm tra\",\"requestId\":\""+UUID.randomUUID()+"\",\"imageData\":\""+png+"\"}";
  mvc.perform(post("/api/v1/task-activity/"+id+"/messages").with(auth).contentType(MediaType.APPLICATION_JSON).content(imageMsg)).andExpect(status().isOk());
  mvc.perform(get("/api/v1/task-activity/"+id).with(auth)).andExpect(jsonPath("$.data.messages.length()").value(2)).andExpect(jsonPath("$.data.messages[0].mine").value(true)).andExpect(jsonPath("$.data.messages[?(@.text == 'Ảnh kiểm tra')].imageData").value(png)).andExpect(jsonPath("$.data.events[0].status").value("ACCEPTED"));
  mvc.perform(get("/api/v1/task-activity/"+id).with(jwt().jwt(j->j.subject(tasker.getId().toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data.messages[0].mine").value(false));
  var admin=jwt().authorities(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_ADMIN"));
  mvc.perform(get("/api/v1/admin/tasks/"+id+"/messages").with(admin))
   .andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(2))
   .andExpect(jsonPath("$.data[0].sender_portal").value("CUSTOMER"));
  mvc.perform(get("/api/v1/admin/tasks/"+id+"/messages").with(auth)).andExpect(status().isForbidden());
  mvc.perform(get("/api/v1/admin/tasks/"+UUID.randomUUID()+"/messages").with(admin)).andExpect(status().isNotFound());
  // The same account can chat from two apps without merging sender identities.
  db.update("UPDATE tasks SET tasker_id=? WHERE id=?",owner.getId(),id);
  var customerMessage=UUID.randomUUID();var partnerMessage=UUID.randomUUID();
  mvc.perform(post("/api/v1/task-activity/"+id+"/messages?partner=false").with(auth).contentType(MediaType.APPLICATION_JSON).content("{\"text\":\"Customer\",\"requestId\":\""+customerMessage+"\"}")).andExpect(status().isOk());
  mvc.perform(post("/api/v1/task-activity/"+id+"/messages?partner=true").with(auth).contentType(MediaType.APPLICATION_JSON).content("{\"text\":\"Partner\",\"requestId\":\""+partnerMessage+"\"}")).andExpect(status().isOk());
  mvc.perform(get("/api/v1/task-activity/"+id+"?partner=false").with(auth))
   .andExpect(jsonPath("$.data.messages[?(@.id == '"+customerMessage+"')].mine").value(true))
   .andExpect(jsonPath("$.data.messages[?(@.id == '"+partnerMessage+"')].mine").value(false));
  mvc.perform(get("/api/v1/task-activity/"+id+"?partner=true").with(auth))
   .andExpect(jsonPath("$.data.messages[?(@.id == '"+customerMessage+"')].mine").value(false))
   .andExpect(jsonPath("$.data.messages[?(@.id == '"+partnerMessage+"')].mine").value(true));
  mvc.perform(get("/api/v1/task-activity/"+id).with(other)).andExpect(status().isNotFound());
  mvc.perform(post("/api/v1/task-activity/"+id+"/messages").with(other).contentType(MediaType.APPLICATION_JSON).content(message)).andExpect(status().isNotFound());
 }
 @Test void customerCapacityBlocksAtThreeAndReopensOnCompletionOrCancellation() throws Exception {
  var owner=user();var now=Instant.now();
  var category=categories.saveAndFlush(new ServiceCategory("cap-"+UUID.randomUUID(),"Nhà cửa","",0,now));
  var service=services.saveAndFlush(new CatalogueService(category,"cap-"+UUID.randomUUID(),"Dịch vụ","Mô tả","",100000,200000,"VND",120,0,now));
  var auth=jwt().jwt(j->j.subject(owner.getId().toString())).authorities(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_CUSTOMER"));
  UUID first=null;
  for(int i=0;i<3;i++) {
   var task=new CustomerTask(owner,service,"Dọn nhà","Mô tả","Địa chỉ","HCM",null,null,now.plusSeconds(86400),120,100000,"VND","",now);
   task.post(now);tasks.saveAndFlush(task);if(first==null)first=task.getId();
  }
  mvc.perform(get("/api/v1/users/me/booking-capacity").with(auth)).andExpect(status().isOk()).andExpect(jsonPath("$.data.canCreate").value(false)).andExpect(jsonPath("$.data.activeOrders").value(3));
  String draft="{\"serviceId\":\""+service.getId()+"\",\"schemaKey\":\"any\",\"schemaVersion\":1,\"details\":{},\"duration\":1}";
  mvc.perform(put("/api/v1/users/me/booking-draft").with(auth).contentType(MediaType.APPLICATION_JSON).content(draft)).andExpect(status().isConflict());
  for(var status:java.util.List.of("COMPLETED","CANCELLED")) {
   db.update("UPDATE tasks SET status=? WHERE id=?",status,first);
   mvc.perform(get("/api/v1/users/me/booking-capacity").with(auth)).andExpect(status().isOk()).andExpect(jsonPath("$.data.canCreate").value(true)).andExpect(jsonPath("$.data.activeOrders").value(2));
  }
 }

}
