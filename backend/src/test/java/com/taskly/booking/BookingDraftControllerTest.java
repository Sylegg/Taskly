package com.taskly.booking;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.taskly.catalogue.entity.CatalogueService;
import com.taskly.catalogue.entity.ServiceCategory;
import com.taskly.catalogue.repository.CatalogueServiceRepository;
import com.taskly.catalogue.repository.ServiceCategoryRepository;
import com.taskly.rbac.repository.RoleRepository;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.repository.UserAccountRepository;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import tools.jackson.databind.ObjectMapper;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") @Transactional
class BookingDraftControllerTest {
    @Autowired BookingCheckout checkout;
    @ParameterizedTest @ValueSource(strings={"BANK","CASH"})
    void checkoutPostsOnceAndCancelRefundsOnlyPaidOrders(String method) throws Exception {
        UUID owner=account(),other=account();var svc=service("clean");
        String payload=scheduledDraft(owner,svc.getId(),"clean",completeDetails(categorySchemas.require("clean",1,"clean")));
        db.update("UPDATE addresses SET recipient_name='Test',recipient_phone='0909000000',building_type='Nhà riêng',building_description='Tầng 1' WHERE user_id=?",owner);
        db.update("INSERT INTO service_pricing_rules(service_id,mode,base_amount,unit_amount,platform_fee_amount,quote_ttl_minutes,enabled,updated_by) VALUES(?,'FIXED',100000,0,0,15,true,?)",svc.getId(),owner);
        var customer=jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"));
        String quoteResponse=mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        UUID quoteId=UUID.fromString(new ObjectMapper().readTree(quoteResponse).get("data").get("id").asText());
        db.update("INSERT INTO customer_pending_bookings(id,customer_id,payload) VALUES(?,?,?)","booking-existing",owner,payload);
        var created=checkout.checkout(owner,quoteId,method);UUID task=(UUID)created.get("id");
        org.junit.jupiter.api.Assertions.assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM customer_pending_bookings WHERE customer_id=?",Integer.class,owner));
        org.junit.jupiter.api.Assertions.assertEquals(task,checkout.checkout(owner,quoteId,method).get("id"));
        org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM tasks WHERE customer_id=?",Integer.class,owner));
        org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->checkout.checkout(other,quoteId,method));
        org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->checkout.cancel(other,task));
        db.update("UPDATE task_booking_payments SET tasker_viewed_at=CURRENT_TIMESTAMP WHERE task_id=?",task);
        org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->checkout.cancel(owner,task));
        db.update("UPDATE task_booking_payments SET tasker_viewed_at=NULL WHERE task_id=?",task);
        checkout.cancel(owner,task);checkout.cancel(owner,task);checkout.expireUnmatched();
        org.junit.jupiter.api.Assertions.assertEquals(method.equals("BANK")?1:0,db.queryForObject("SELECT COUNT(*) FROM customer_refund_credits WHERE task_id=?",Integer.class,task));
        org.junit.jupiter.api.Assertions.assertEquals(2,db.queryForObject("SELECT COUNT(*) FROM customer_booking_notifications WHERE task_id=?",Integer.class,task));
        org.junit.jupiter.api.Assertions.assertEquals(method.equals("BANK")?"REFUNDED":"CANCELLED",db.queryForObject("SELECT status FROM tasks WHERE id=?",String.class,task));
        mvc.perform(get("/api/v1/users/me/booking-notifications").with(customer)).andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(2));
        mvc.perform(get("/api/v1/users/me/refund-balance").with(customer)).andExpect(status().isOk()).andExpect(jsonPath("$.data.amount").value(method.equals("BANK")?100000:0));
        mvc.perform(get("/api/v1/task-activity/"+task).with(customer)).andExpect(status().isOk()).andExpect(jsonPath("$.data.payment.method").value(method));

    }
    @Test void unmatchedBankOrderExpiresOnceAndCashNeedsAssignedPartner() throws Exception {
        UUID owner=account(),partner=account();var svc=service("clean");
        String payload=scheduledDraft(owner,svc.getId(),"clean",completeDetails(categorySchemas.require("clean",1,"clean")));
        db.update("UPDATE addresses SET recipient_name='Test',recipient_phone='0909000000',building_type='Nhà riêng',building_description='Tầng 1' WHERE user_id=?",owner);
        db.update("INSERT INTO service_pricing_rules(service_id,mode,base_amount,unit_amount,platform_fee_amount,quote_ttl_minutes,enabled,updated_by) VALUES(?,'FIXED',100000,0,0,15,true,?)",svc.getId(),owner);
        var customer=jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"));
        java.util.function.Supplier<UUID> quote=()->{try {var body=mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();return UUID.fromString(new ObjectMapper().readTree(body).get("data").get("id").asText());}catch(Exception e){throw new RuntimeException(e);}};
        UUID bank=(UUID)checkout.checkout(owner,quote.get(),"BANK").get("id");
        db.update("UPDATE task_booking_payments SET match_deadline=? WHERE task_id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(1)),bank);
        checkout.expireUnmatched();checkout.expireUnmatched();
        org.junit.jupiter.api.Assertions.assertEquals(100000L,db.queryForObject("SELECT amount FROM customer_refund_credits WHERE task_id=?",Long.class,bank));
        UUID assigned=(UUID)checkout.checkout(owner,quote.get(),"BANK").get("id");
        db.update("UPDATE tasks SET tasker_id=?,status='ACCEPTED' WHERE id=?",partner,assigned);
        db.update("UPDATE task_booking_payments SET match_deadline=? WHERE task_id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(1)),assigned);
        checkout.expireUnmatched();
        org.junit.jupiter.api.Assertions.assertEquals("ACCEPTED",db.queryForObject("SELECT status FROM tasks WHERE id=?",String.class,assigned));
        UUID cash=(UUID)checkout.checkout(owner,quote.get(),"CASH").get("id");
        org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->checkout.cashReceived(partner,cash));
        db.update("UPDATE tasks SET tasker_id=?,status='COMPLETED' WHERE id=?",partner,cash);
        org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->checkout.cashReceived(owner,cash));
        checkout.cashReceived(partner,cash);checkout.cashReceived(partner,cash);
        org.junit.jupiter.api.Assertions.assertEquals("PAID",db.queryForObject("SELECT status FROM tasks WHERE id=?",String.class,cash));
        org.junit.jupiter.api.Assertions.assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM customer_refund_credits WHERE task_id=?",Integer.class,cash));
    }
    @Autowired CategoryBookingSchemas categorySchemas;
    @org.junit.jupiter.api.BeforeEach void openBookingArea() {
        db.update("INSERT INTO recruitment_areas(id,city,name,recruiting,capacity,version,updated_at) VALUES(?,?,?,true,100,0,CURRENT_TIMESTAMP)",UUID.randomUUID(),"Hồ Chí Minh","Hồ Chí Minh");
    }
    @Test void supportMessagesPersistAndArePrivate() throws Exception {
        var owner=account(); var other=account(); users.flush(); var requestId=UUID.randomUUID();
        var body="{\"requestId\":\""+requestId+"\",\"text\":\"Need help\"}";
        for(int i=0;i<2;i++) mvc.perform(post("/api/v1/support/messages").with(jwt().jwt(j->j.subject(owner.toString()))).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/support/messages").with(jwt().jwt(j->j.subject(owner.toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(1)).andExpect(jsonPath("$.data[0].content").value("Need help"));
        mvc.perform(get("/api/v1/support/messages").with(jwt().jwt(j->j.subject(other.toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(0));
        org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM support_messages WHERE user_id=?",Integer.class,owner));
        mvc.perform(get("/api/v1/admin/support/conversations").with(jwt().jwt(j->j.subject(other.toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_VIEW")))).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].unread_count").value(1));
        var readBody="{\"messageIds\":[\""+requestId+"\"]}";
        mvc.perform(post("/api/v1/admin/support/"+owner+"/read").with(jwt().jwt(j->j.subject(other.toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_VIEW"))).contentType(MediaType.APPLICATION_JSON).content(readBody)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/admin/support/conversations").with(jwt().jwt(j->j.subject(other.toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_VIEW")))).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].unread_count").value(0));
        mvc.perform(get("/api/v1/admin/support/conversations").with(jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_VIEW")))).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].unread_count").value(1));
    }

    @Test void customerAndPartnerSupportStaySeparateForTheSameAccount() throws Exception {
        var owner=account(); var admin=account(); users.flush();
        var customer=jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"));
        var staff=jwt().jwt(j->j.subject(admin.toString())).authorities(new SimpleGrantedAuthority("RECRUITMENT_VIEW"),new SimpleGrantedAuthority("RECRUITMENT_PRELIMINARY"));
        var id=UUID.randomUUID();
        var body="{\"requestId\":\""+id+"\",\"text\":\"Customer help\"}";
        for(int i=0;i<2;i++) mvc.perform(post("/api/v1/customer/support/messages").with(customer).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/support/messages").with(customer)).andExpect(jsonPath("$.data.length()").value(0));
        mvc.perform(post("/api/v1/support/messages").with(customer).contentType(MediaType.APPLICATION_JSON).content(body.replace("Customer help","Partner help"))).andExpect(status().isOk());
        mvc.perform(get("/api/v1/customer/support/messages").with(customer)).andExpect(jsonPath("$.data.length()").value(1)).andExpect(jsonPath("$.data[0].content").value("Customer help"));
        mvc.perform(get("/api/v1/customer/support/messages").with(jwt().jwt(j->j.subject(admin.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))).andExpect(jsonPath("$.data.length()").value(0));
        mvc.perform(post("/api/v1/admin/support/customer/"+owner+"/read").with(staff).contentType(MediaType.APPLICATION_JSON).content("{\"messageIds\":[\""+id+"\"]}")).andExpect(status().isOk());
        mvc.perform(get("/api/v1/admin/support/customer/conversations").with(staff)).andExpect(jsonPath("$.data[0].unread_count").value(0));
        mvc.perform(get("/api/v1/admin/support/conversations").with(staff)).andExpect(jsonPath("$.data[0].unread_count").value(1));
        mvc.perform(post("/api/v1/admin/support/customer/"+owner+"/messages").with(staff).contentType(MediaType.APPLICATION_JSON).content("{\"requestId\":\""+UUID.randomUUID()+"\",\"text\":\"Customer reply\"}")).andExpect(status().isOk());
        mvc.perform(get("/api/v1/customer/support/messages").with(customer)).andExpect(jsonPath("$.data.length()").value(2));
        mvc.perform(get("/api/v1/support/messages").with(customer)).andExpect(jsonPath("$.data.length()").value(1)).andExpect(jsonPath("$.data[0].content").value("Partner help"));
    }

    @Test void addressDetailsPersistOnCreateUpdateAndReload() throws Exception {
        var owner = account();
        var body = "{\"label\":\"Home\",\"addressLine\":\"123 Street\",\"city\":\"HCM\",\"recipientName\":\"Customer\",\"recipientPhone\":\"0901234567\",\"buildingType\":\"Apartment\",\"buildingDescription\":\"Floor 5\",\"notes\":\"Ring bell\",\"defaultAddress\":true}";
        var result = mvc.perform(post("/api/v1/users/me/addresses").with(jwt().jwt(j -> j.subject(owner.toString()))).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andReturn();
        var id = new ObjectMapper().readTree(result.getResponse().getContentAsString()).get("data").get("id").asText();
        mvc.perform(put("/api/v1/users/me/addresses/"+id).with(jwt().jwt(j -> j.subject(owner.toString()))).contentType(MediaType.APPLICATION_JSON).content(body.replace("Floor 5", "Floor 6"))).andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/addresses").with(jwt().jwt(j -> j.subject(owner.toString())))).andExpect(status().isOk())
            .andExpect(jsonPath("$.data[0].buildingType").value("Apartment"))
            .andExpect(jsonPath("$.data[0].buildingDescription").value("Floor 6"))
            .andExpect(jsonPath("$.data[0].notes").value("Ring bell"))
            .andExpect(jsonPath("$.data[0].recipientName").value("Customer"))
            .andExpect(jsonPath("$.data[0].recipientPhone").value("0901234567"));
        org.junit.jupiter.api.Assertions.assertEquals("Floor 6", db.queryForObject("SELECT building_description FROM addresses WHERE id=?", String.class, UUID.fromString(id)));
    }

    @Test void serviceNumberFieldsPersistAndRejectNonNumericInput() throws Exception {
        var service=service("custom-"+UUID.randomUUID());
        mvc.perform(put("/api/v1/admin/services/"+service.getId()+"/booking-fields").with(jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"))).contentType(MediaType.APPLICATION_JSON)
            .content("[{\"key\":\"count\",\"label\":\"Số món\",\"type\":\"number\",\"required\":true,\"options\":[]}]"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data[0].minimum").value(1));
        var schema=categorySchemas.all().stream().filter(s->s.serviceSlugs().contains(service.getSlug())).findFirst().orElseThrow();
        BookingSchemas.validatePartial(schema,Map.of("count",3));
        org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->BookingSchemas.validatePartial(schema,Map.of("count","abc")));
        org.junit.jupiter.api.Assertions.assertThrows(com.taskly.common.exception.DomainException.class,()->BookingSchemas.validatePartial(schema,Map.of("count",0)));
    }
    @Test void categoryCreationSavesQuantityFieldsInTheSameRequest() throws Exception {
        String slug="category-"+UUID.randomUUID();
        mvc.perform(post("/api/v1/admin/service-categories").with(jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"))).contentType(MediaType.APPLICATION_JSON)
            .content("{\"slug\":\""+slug+"\",\"name\":\"Danh mục mới\",\"description\":\"\",\"displayOrder\":0,\"quantityFields\":[{\"key\":\"area\",\"label\":\"Diện tích\",\"minimum\":1},{\"key\":\"rooms\",\"label\":\"Số phòng\",\"minimum\":0}]}"))
            .andExpect(status().isOk());
        var id=db.queryForObject("SELECT id FROM service_categories WHERE slug=?",UUID.class,slug);
        org.junit.jupiter.api.Assertions.assertEquals(2,categorySchemas.fields(id).size());
        org.junit.jupiter.api.Assertions.assertEquals("area",categorySchemas.fields(id).getFirst().key());
    }
    @Test void serviceRequirementsAreEditableAndKeepInheritedQuantityFields() throws Exception {
        var service=service("ac");var endpoint="/api/v1/admin/services/"+service.getId()+"/booking-fields";
        var admin=jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
        mvc.perform(put(endpoint).with(admin).contentType(MediaType.APPLICATION_JSON).content("[{\"key\":\"access\",\"label\":\"Hướng dẫn tiếp cận\",\"type\":\"text\",\"required\":false,\"options\":[]},{\"key\":\"supplies\",\"label\":\"Dụng cụ\",\"type\":\"choice\",\"required\":true,\"options\":[\"Có sẵn\",\"Mang theo\"]}]"))
            .andExpect(status().isOk());
        var schema=categorySchemas.all().stream().filter(s->s.serviceSlugs().contains("ac")).findFirst().orElseThrow();
        org.junit.jupiter.api.Assertions.assertTrue(schema.fields().stream().anyMatch(f->f.key().equals("units")&&f.type().equals("number")));
        org.junit.jupiter.api.Assertions.assertTrue(schema.fields().stream().anyMatch(f->f.key().equals("supplies")&&f.required()));
        org.junit.jupiter.api.Assertions.assertFalse(schema.fields().stream().anyMatch(f->f.key().equals("type")));
        mvc.perform(put(endpoint).with(admin).contentType(MediaType.APPLICATION_JSON).content("[{\"key\":\"units\",\"label\":\"Trùng trường số\",\"type\":\"text\",\"required\":true,\"options\":[]}]"))
            .andExpect(status().isUnprocessableEntity());
    }
    @Test void categoryQuantityFieldsPersistAndApplyToEveryServiceInCategory() throws Exception {
        var first=service("custom-"+UUID.randomUUID());
        var category=first.getCategory();
        var second=new CatalogueService(category,"custom-"+UUID.randomUUID(),"Dịch vụ thứ hai","Mô tả","",0,0,"VND",60,0,Instant.now());
        services.saveAndFlush(second);
        var endpoint="/api/v1/admin/service-categories/"+category.getId()+"/quantity-fields";
        var authority=new SimpleGrantedAuthority("SERVICE_MANAGE");
        mvc.perform(put(endpoint).with(jwt().authorities(authority)).contentType(MediaType.APPLICATION_JSON).content("{\"fields\":[{\"key\":\"units\",\"label\":\"Số thiết bị\",\"minimum\":1}]}"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data[0].key").value("units"));
        for(var slug:java.util.List.of(first.getSlug(),second.getSlug())) {
            var schema=categorySchemas.all().stream().filter(s->s.serviceSlugs().contains(slug)).findFirst().orElseThrow();
            org.junit.jupiter.api.Assertions.assertEquals("Số thiết bị",schema.fields().getFirst().label());
            org.junit.jupiter.api.Assertions.assertEquals(2,schema.version());
        }
        mvc.perform(put(endpoint).with(jwt().authorities(authority)).contentType(MediaType.APPLICATION_JSON).content("{\"fields\":[{\"key\":\"units\",\"label\":\"A\",\"minimum\":1},{\"key\":\"units\",\"label\":\"B\",\"minimum\":1}]}"))
            .andExpect(status().isUnprocessableEntity());
        UUID actor=account();users.flush();
        db.update("INSERT INTO service_pricing_rules(service_id,mode,quantity_field,base_amount,unit_amount,platform_fee_amount,quote_ttl_minutes,enabled,version,updated_by) VALUES(?,'FIELD','units',0,150000,10000,15,true,0,?)",first.getId(),actor);
        mvc.perform(put(endpoint).with(jwt().authorities(authority)).contentType(MediaType.APPLICATION_JSON).content("{\"fields\":[{\"key\":\"items\",\"label\":\"Số món\",\"minimum\":1}]}"))
            .andExpect(status().isOk());
        org.junit.jupiter.api.Assertions.assertFalse(db.queryForObject("SELECT enabled FROM service_pricing_rules WHERE service_id=?",Boolean.class,first.getId()));
        org.junit.jupiter.api.Assertions.assertEquals("items",categorySchemas.fields(category.getId()).getFirst().key());
    }
    @Autowired MockMvc mvc;
    @Autowired UserAccountRepository users;
    @Autowired RoleRepository roles;
    @Autowired ServiceCategoryRepository categories;
    @Autowired CatalogueServiceRepository services;
    @Autowired JdbcTemplate db;
    UUID account() { return users.save(new UserAccount(UUID.randomUUID()+"@test.example", null, "hash",
        roles.findByKey("CUSTOMER").orElseThrow(), Instant.now())).getId(); }
    CatalogueService service(String slug) {
        var now = Instant.now();
        var category = new ServiceCategory("category-"+UUID.randomUUID(), "Nhà cửa", "", 0, now);
        category.setActive(true, now); categories.saveAndFlush(category);
        var service = new CatalogueService(category, slug, "Dịch vụ", "Mô tả", "", 100000, 200000, "VND", 120, 0, now);
        service.setActive(true, now); return services.saveAndFlush(service);
    }
    String draft(UUID service, String key, String details) {
        return "{\"serviceId\":\""+service+"\",\"schemaKey\":\""+key+"\",\"schemaVersion\":1,\"details\":"+details+",\"addressId\":\"\",\"duration\":2,\"description\":\"\",\"notes\":\"\"}";
    }
    Map<String, Object> completeDetails(BookingSchemas.Schema schema) {
        Map<String, Object> details = new LinkedHashMap<>();
        for (var field : schema.fields()) {
            details.put(field.key(), switch (field.type()) {
                case "number" -> 2;
                case "choice" -> field.options().getFirst();
                default -> field.key() + " - Thông tin hợp lệ";
            });
        }
        return details;
    }
    String scheduledDraft(UUID owner, UUID service, String key, Map<String, Object> details) {
        UUID address = UUID.randomUUID();
        db.update("INSERT INTO addresses(id,user_id,label,address_line,city,is_default,version,created_at,updated_at) VALUES (?,?,?,?,?,FALSE,0,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)", address, owner, "Nhà", "123 Nguyễn Huệ", "Hồ Chí Minh");
        return draft(service, key, new ObjectMapper().writeValueAsString(details))
            .replace("\"addressId\":\"\"", "\"addressId\":\"" + address + "\"")
            .replace("\"duration\":2", "\"scheduledAt\":\"" + Instant.now().plusSeconds(86400) + "\",\"duration\":2");
    }
    @Test void pendingBookingsAreSeparatePrivateAndLimitedToThree() throws Exception {
        UUID owner=account(),other=account(); var service=service("clean"); users.flush();
        var customer=jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"));
        String body=draft(service.getId(),"clean","{}");
        for(int i=1;i<=3;i++) mvc.perform(put("/api/v1/users/me/pending-bookings/"+owner+"-"+i).with(customer).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
        mvc.perform(put("/api/v1/users/me/pending-bookings/"+owner+"-4").with(customer).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isConflict()).andExpect(jsonPath("$.error.code").value("BOOKING_LIMIT"));
        mvc.perform(put("/api/v1/users/me/pending-bookings/"+owner+"-1").with(customer).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/pending-bookings").with(customer)).andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(3));
        mvc.perform(get("/api/v1/admin/tasks").with(jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data[?(@.customer_id == '"+owner+"')].status").value(org.hamcrest.Matchers.everyItem(org.hamcrest.Matchers.is("INCOMPLETE"))));
        mvc.perform(get("/api/v1/admin/tasks").with(customer)).andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/users/me/pending-bookings").with(jwt().jwt(j->j.subject(other.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))).andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(0));
        mvc.perform(delete("/api/v1/users/me/pending-bookings/"+owner+"-1").with(customer)).andExpect(status().isOk());
        mvc.perform(put("/api/v1/users/me/pending-bookings/"+owner+"-4").with(customer).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
    }
    @Test void percentFeeUsesServiceSubtotalAndRoundsToDong() throws Exception {
        UUID owner=account();var service=service("clean");users.flush();
        var schema=categorySchemas.require("clean",1,service.getSlug());
        Map<String,Object> details=new LinkedHashMap<>();
        for(var field:schema.fields()) if(field.required()) details.put(field.key(), field.type().equals("number")?2:field.type().equals("choice")?field.options().getFirst():"Test");
        String payload=scheduledDraft(owner,service.getId(),"clean",details);
        var admin=jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
        var customer=jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"));
        String rule="{\"mode\":\"HOURLY\",\"baseAmount\":1,\"unitAmount\":50000,\"platformFeeAmount\":0,\"platformFeePercent\":12.5,\"quoteTtlMinutes\":5,\"enabled\":true}";
        mvc.perform(put("/api/v1/admin/services/"+service.getId()+"/pricing").with(admin).contentType(MediaType.APPLICATION_JSON).content(rule)).andExpect(status().isOk());
        mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isOk()).andExpect(jsonPath("$.data.subtotal").value(100001)).andExpect(jsonPath("$.data.platformFee").value(12500)).andExpect(jsonPath("$.data.total").value(100001));
        mvc.perform(put("/api/v1/admin/services/"+service.getId()+"/pricing").with(admin).contentType(MediaType.APPLICATION_JSON).content(rule.replace("12.5","101"))).andExpect(status().isBadRequest());
    }
    @Test void publicServicePriceTracksAdminUpdatesIncludingCachedReads() throws Exception {
        UUID owner=account();var service=service("sync-"+UUID.randomUUID());users.flush();
        var admin=jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
        String endpoint="/api/v1/admin/services/"+service.getId()+"/pricing";
        String rule="{\"mode\":\"HOURLY\",\"baseAmount\":0,\"unitAmount\":12000,\"platformFeeAmount\":0,\"platformFeePercent\":10,\"quoteTtlMinutes\":15,\"enabled\":true}";
        mvc.perform(get("/api/v1/public/services/"+service.getSlug())).andExpect(status().isOk());
        mvc.perform(put(endpoint).with(admin).contentType(MediaType.APPLICATION_JSON).content(rule)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/public/services/"+service.getSlug())).andExpect(status().isOk()).andExpect(jsonPath("$.data.pricing.unitAmount").value(12000));
        mvc.perform(put(endpoint).with(admin).contentType(MediaType.APPLICATION_JSON).content(rule.replace("12000","15000"))).andExpect(status().isOk());
        mvc.perform(get("/api/v1/public/services/"+service.getSlug())).andExpect(status().isOk()).andExpect(jsonPath("$.data.pricing.unitAmount").value(15000));
    }
    @Test void supportImagesPersistAndAreVisibleToSupportOnly() throws Exception {
        UUID owner=account(),other=account(),id=UUID.randomUUID();users.flush();
        var image=new java.awt.image.BufferedImage(2,2,java.awt.image.BufferedImage.TYPE_INT_RGB);
        var output=new java.io.ByteArrayOutputStream();javax.imageio.ImageIO.write(image,"png",output);
        String data="data:image/png;base64,"+java.util.Base64.getEncoder().encodeToString(output.toByteArray());
        String body=new ObjectMapper().writeValueAsString(Map.of("requestId",id,"text","[Báo cáo sự cố] Test","imageData",data));
        var user=jwt().jwt(j->j.subject(owner.toString()));
        mvc.perform(post("/api/v1/support/messages").with(user).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/support/messages").with(user)).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].image_data").value(data));
        mvc.perform(get("/api/v1/support/messages").with(jwt().jwt(j->j.subject(other.toString())))).andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(0));
        mvc.perform(get("/api/v1/admin/support/"+owner+"/messages").with(jwt().authorities(new SimpleGrantedAuthority("RECRUITMENT_VIEW")))).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].image_data").value(data));
        mvc.perform(post("/api/v1/support/messages").with(user).contentType(MediaType.APPLICATION_JSON).content(body.replace(data,"data:image/png;base64,YmFk"))).andExpect(status().isBadRequest());
    }
    @Test void schemasArePublicAndDraftRequiresAuthentication() throws Exception {
        mvc.perform(get("/api/v1/public/booking-schemas")).andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(categorySchemas.all().size()));
        mvc.perform(get("/api/v1/users/me/booking-draft")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/users/me/booking-draft").with(jwt())).andExpect(status().isForbidden());
    }
    @ParameterizedTest @ValueSource(strings={"clean","deep","repair","move","ac","shop","pets","it","upholstery","laundry","ironing","packing"})
    void eachSchemaPersistsAndRejectsInvalidFields(String key) throws Exception {
        UUID owner = account(), other = account(); var service = service(key);
        var schema = categorySchemas.require(key,1,service.getSlug());
        var field = schema.fields().getFirst();
        String value = new ObjectMapper().writeValueAsString(completeDetails(schema).get(field.key()));
        String valid = "{\""+field.key()+"\":"+value+"}";
        mvc.perform(put("/api/v1/users/me/booking-draft").with(jwt().jwt(j -> j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))
            .contentType(MediaType.APPLICATION_JSON).content(draft(service.getId(), key, valid))).andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/booking-draft").with(jwt().jwt(j -> j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"))))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.schemaKey").value(key));
        mvc.perform(get("/api/v1/users/me/booking-draft").with(jwt().jwt(j -> j.subject(other.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"))))
            .andExpect(jsonPath("$.data").doesNotExist());
        mvc.perform(put("/api/v1/users/me/booking-draft").with(jwt().jwt(j -> j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))
            .contentType(MediaType.APPLICATION_JSON).content(draft(service.getId(), key, "{\"unknown\":\"bad\"}")))
            .andExpect(status().isUnprocessableEntity());
        mvc.perform(delete("/api/v1/users/me/booking-draft").with(jwt().jwt(j -> j.subject(other.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))).andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/booking-draft").with(jwt().jwt(j -> j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))).andExpect(jsonPath("$.data.schemaKey").value(key));
        service.setActive(false, Instant.now()); services.saveAndFlush(service);
        mvc.perform(put("/api/v1/users/me/booking-draft").with(jwt().jwt(j -> j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))
            .contentType(MediaType.APPLICATION_JSON).content(draft(service.getId(), key, valid))).andExpect(status().isUnprocessableEntity());
    }
    @ParameterizedTest
    @CsvSource({
        "home-cleaning,clean,HOURLY,",
        "deep-cleaning,deep,FIELD,area",
        "sofa-cleaning,upholstery,FIELD,items",
        "mattress-cleaning,upholstery,FIELD,items",
        "air-conditioning,ac,FIELD,units",
        "aircon-repair,repair,FIXED,",
        "washing-machine-repair,repair,FIXED,",
        "refrigerator-repair,repair,FIXED,",
        "assembly,repair,HOURLY,",
        "furniture-disassembly,repair,HOURLY,",
        "moving,move,HOURLY,",
        "packing,packing,HOURLY,",
        "shopping,shop,FIXED,",
        "grocery-delivery,shop,FIXED,",
        "pet-care,pets,FIELD,count",
        "dog-walking,pets,FIELD,count",
        "it-support,it,HOURLY,",
        "wifi-setup,it,FIXED,",
        "laundry,laundry,FIELD,weightKg",
        "ironing,ironing,FIELD,items"
    })
    void catalogueServicesCanSaveDraftsAndReceiveQuotes(String slug, String key, String mode, String quantityField) throws Exception {
        UUID owner = account();
        var service = service(slug);
        var schema = categorySchemas.require(key, 1, slug);
        String payload = scheduledDraft(owner, service.getId(), key, completeDetails(schema));
        var customer = jwt().jwt(j -> j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"));
        var admin = jwt().jwt(j -> j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
        Map<String, Object> rule = new LinkedHashMap<>();
        rule.put("mode", mode);
        rule.put("quantityField", quantityField);
        rule.put("baseAmount", 10000);
        rule.put("unitAmount", mode.equals("FIXED") ? 0 : 50000);
        rule.put("platformFeeAmount", 5000);
        rule.put("quoteTtlMinutes", 5);
        rule.put("enabled", true);
        mvc.perform(put("/api/v1/admin/services/" + service.getId() + "/pricing").with(admin)
            .contentType(MediaType.APPLICATION_JSON).content(new ObjectMapper().writeValueAsString(rule)))
            .andExpect(status().isOk());
        mvc.perform(put("/api/v1/users/me/booking-draft").with(customer)
            .contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/booking-draft").with(customer))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.serviceId").value(service.getId().toString()))
            .andExpect(jsonPath("$.data.schemaKey").value(key));
        mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer)
            .contentType(MediaType.APPLICATION_JSON).content(payload))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(mode.equals("FIXED") ? 10000 : 110000))
            .andExpect(jsonPath("$.data.currency").value("VND"));
        db.update("UPDATE recruitment_areas SET recruiting=false WHERE city='Hồ Chí Minh'");
        mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload))
            .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.error.code").value("AREA_MAINTENANCE"));
        db.update("DELETE FROM recruitment_areas WHERE city='Hồ Chí Minh'");
        mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload))
            .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.error.code").value("AREA_MAINTENANCE"));
        mvc.perform(put("/api/v1/users/me/booking-draft").with(customer)
            .contentType(MediaType.APPLICATION_JSON).content(payload.replace("\"schemaVersion\":1", "\"schemaVersion\":2")))
            .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.error.code").value("INVALID_BOOKING_DETAILS"));
    }
    @ParameterizedTest
    @CsvSource({"sofa-cleaning,upholstery,items,material", "mattress-cleaning,upholstery,items,material", "laundry,laundry,weightKg,treatment", "ironing,ironing,items,clothing", "packing,packing,boxes,contents"})
    void newServiceFormsRejectInvalidQuantitiesAndRequireDetailsForQuotes(String slug, String key, String quantityField, String requiredField) throws Exception {
        UUID owner = account();
        var service = service(slug);
        var schema = categorySchemas.require(key, 1, slug);
        var customer = jwt().jwt(j -> j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"));
        for (String value : new String[]{"0", "-1", "1.5", "100000001", "nhiều"}) {
            String invalid = new ObjectMapper().writeValueAsString(Map.of(quantityField, value));
            mvc.perform(put("/api/v1/users/me/booking-draft").with(customer)
                .contentType(MediaType.APPLICATION_JSON).content(draft(service.getId(), key, invalid)))
                .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.error.code").value("INVALID_BOOKING_DETAILS"));
        }
        var wrongType = completeDetails(schema);
        wrongType.put(requiredField, 42);
        mvc.perform(put("/api/v1/users/me/booking-draft").with(customer)
            .contentType(MediaType.APPLICATION_JSON).content(draft(service.getId(), key, new ObjectMapper().writeValueAsString(wrongType))))
            .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.error.code").value("INVALID_BOOKING_DETAILS"));
        var incomplete = completeDetails(schema);
        incomplete.remove(requiredField);
        String payload = scheduledDraft(owner, service.getId(), key, incomplete);
        mvc.perform(put("/api/v1/users/me/booking-draft").with(customer)
            .contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isOk());
        mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer)
            .contentType(MediaType.APPLICATION_JSON).content(payload))
            .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.error.code").value("INCOMPLETE_BOOKING"));
        if (key.equals("laundry")) {
            mvc.perform(put("/api/v1/users/me/booking-draft").with(customer)
                .contentType(MediaType.APPLICATION_JSON).content(draft(service.getId(), key, "{\"treatment\":\"Không hợp lệ\"}")))
                .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.error.code").value("INVALID_BOOKING_DETAILS"));
        }
    }
    @Test void negativeQuantityAndForeignAddressAreRejected() throws Exception {
        UUID owner = account(); var service = service("clean");
        mvc.perform(put("/api/v1/users/me/booking-draft").with(jwt().jwt(j -> j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))
            .contentType(MediaType.APPLICATION_JSON).content(draft(service.getId(), "clean", "{\"area\":\"-1\"}")))
            .andExpect(status().isUnprocessableEntity());
        String foreign = draft(service.getId(), "clean", "{}").replace("\"addressId\":\"\"", "\"addressId\":\""+UUID.randomUUID()+"\"");
        mvc.perform(put("/api/v1/users/me/booking-draft").with(jwt().jwt(j -> j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))
            .contentType(MediaType.APPLICATION_JSON).content(foreign)).andExpect(status().isNotFound());
    }
    @Test void quoteIncludesEverySelectedServiceAndRejectsChangedAdditionalPricing() throws Exception {
        UUID owner=account();users.flush();
        var first=service("clean");var second=service("ac");var third=service("fixed-"+UUID.randomUUID());
        var details=completeDetails(categorySchemas.require("clean",1,"clean"));
        completeDetails(categorySchemas.require("ac",1,"ac")).forEach((key,value)->details.put(second.getId()+"_"+key,value));
        details.put("selectedServiceIds",java.util.List.of(first.getId().toString(),second.getId().toString(),third.getId().toString()));
        String payload=scheduledDraft(owner,first.getId(),"clean",details);
        db.update("INSERT INTO service_pricing_rules(service_id,mode,base_amount,unit_amount,platform_fee_amount,platform_fee_percent,quote_ttl_minutes,enabled,version,updated_by) VALUES(?,'HOURLY',0,50000,0,10,15,true,1,?)",first.getId(),owner);
        db.update("INSERT INTO service_pricing_rules(service_id,mode,quantity_field,base_amount,unit_amount,platform_fee_amount,platform_fee_percent,quote_ttl_minutes,enabled,version,updated_by) VALUES(?,'FIELD','units',0,30000,0,10,5,true,1,?)",second.getId(),owner);
        db.update("INSERT INTO service_pricing_rules(service_id,mode,base_amount,unit_amount,platform_fee_amount,platform_fee_percent,quote_ttl_minutes,enabled,version,updated_by) VALUES(?,'FIXED',40000,0,0,10,10,true,1,?)",third.getId(),owner);
        var customer=jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"));
        payload=payload.replace("\"details\":{", "\"details\":{\"quoteSessionId\":\""+UUID.randomUUID()+"\",");
        var initial=new ObjectMapper().readTree(payload);
        ((tools.jackson.databind.node.ObjectNode)initial.get("details")).putArray("selectedServiceIds").add(first.getId().toString());
        mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(initial.toString())).andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(100000));
        db.update("UPDATE service_pricing_rules SET unit_amount=90000,version=version+1 WHERE service_id=?",first.getId());
        String pendingId=owner+"-quote";
        var admin=jwt().authorities(new SimpleGrantedAuthority("ROLE_ADMIN"));
        mvc.perform(put("/api/v1/users/me/pending-bookings/"+pendingId).with(customer).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isOk());
        String row="$.data[?(@.id == '"+pendingId+"')]";
        mvc.perform(get("/api/v1/admin/tasks").with(admin)).andExpect(status().isOk()).andExpect(jsonPath(row+".total").isEmpty());
        String body=mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.items.length()").value(3))
            .andExpect(jsonPath("$.data.items[0].mode").value("HOURLY"))
            .andExpect(jsonPath("$.data.items[1].quantity").value(2))
            .andExpect(jsonPath("$.data.items[1].subtotal").value(60000))
            .andExpect(jsonPath("$.data.items[2].subtotal").value(40000))
            .andExpect(jsonPath("$.data.subtotal").value(200000))
            .andExpect(jsonPath("$.data.platformFee").value(20000))
            .andExpect(jsonPath("$.data.total").value(200000)).andReturn().getResponse().getContentAsString();
        mvc.perform(get("/api/v1/admin/tasks").with(admin)).andExpect(status().isOk()).andExpect(jsonPath(row+".total").value(org.hamcrest.Matchers.contains(200000)));
        mvc.perform(put("/api/v1/users/me/pending-bookings/"+pendingId).with(customer).contentType(MediaType.APPLICATION_JSON).content(payload.replace("\"duration\":2","\"duration\":3"))).andExpect(status().isOk());
        mvc.perform(get("/api/v1/admin/tasks").with(admin)).andExpect(status().isOk()).andExpect(jsonPath(row+".total").isEmpty());
        String id=new ObjectMapper().readTree(body).get("data").get("id").asText();
        mvc.perform(get("/api/v1/users/me/booking-quotes/"+id).with(customer)).andExpect(status().isOk()).andExpect(jsonPath("$.data.items.length()").value(3));
        db.update("UPDATE service_pricing_rules SET version=version+1 WHERE service_id=?",second.getId());
        mvc.perform(get("/api/v1/users/me/booking-quotes/"+id).with(customer)).andExpect(status().isOk());
        db.update("UPDATE service_pricing_rules SET enabled=false WHERE service_id=?",second.getId());
        mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.error.code").value("PRICING_UNAVAILABLE"));
        org.junit.jupiter.api.Assertions.assertEquals(2,db.queryForObject("SELECT count(*) FROM customer_price_quotes WHERE customer_id=?",Integer.class,owner));
    }
    @Test void adminPricesAreVersionedAndQuotesCannotBeUsedByAnotherCustomer() throws Exception {
        UUID owner=account(), other=account(), address=UUID.randomUUID(); var service=service("clean");
        db.update("INSERT INTO addresses(id,user_id,label,address_line,city,is_default,version,created_at,updated_at) VALUES (?,?,?,?,?,FALSE,0,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)", address,owner,"Nhà","123 Nguyễn Huệ","Hồ Chí Minh");
        String payload=draft(service.getId(),"clean","{\"area\":\"65\",\"rooms\":\"2\",\"bathrooms\":\"1\",\"supplies\":\"Nhà đã có\"}")
            .replace("\"addressId\":\"\"","\"addressId\":\""+address+"\"")
            .replace("\"duration\":2","\"scheduledAt\":\""+Instant.now().plusSeconds(86400)+"\",\"duration\":2");
        payload=payload.replace("\"details\":{", "\"details\":{\"quoteSessionId\":\""+UUID.randomUUID()+"\",");
        var customer=jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"));
        var admin=jwt().jwt(j->j.subject(owner.toString())).authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
        mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload))
            .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.error.code").value("PRICING_UNAVAILABLE"));
        String rule="{\"mode\":\"HOURLY\",\"baseAmount\":10000,\"unitAmount\":50000,\"platformFeeAmount\":5000,\"quoteTtlMinutes\":5,\"enabled\":true}";
        mvc.perform(put("/api/v1/admin/services/"+service.getId()+"/pricing").with(customer).contentType(MediaType.APPLICATION_JSON).content(rule)).andExpect(status().isForbidden());
        mvc.perform(put("/api/v1/admin/services/"+service.getId()+"/pricing").with(admin).contentType(MediaType.APPLICATION_JSON).content(rule)).andExpect(status().isOk());
        String body=mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(110000)).andExpect(jsonPath("$.data.ruleVersion").value(1)).andReturn().getResponse().getContentAsString();
        String id=new ObjectMapper().readTree(body).get("data").get("id").asText();
        mvc.perform(get("/api/v1/users/me/booking-quotes/"+id).with(jwt().jwt(j->j.subject(other.toString())).authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"))))
            .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/users/me/booking-quotes/"+id).with(customer)).andExpect(status().isOk());
        mvc.perform(put("/api/v1/admin/services/"+service.getId()+"/pricing").with(admin).contentType(MediaType.APPLICATION_JSON).content(rule.replace("50000","60000"))).andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/booking-quotes/"+id).with(customer)).andExpect(status().isOk());
        mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(110000));

        db.update("UPDATE customer_price_quotes SET expires_at=? WHERE id=?", java.sql.Timestamp.from(Instant.now().minusSeconds(1)),UUID.fromString(id));
        mvc.perform(get("/api/v1/users/me/booking-quotes/"+id).with(customer)).andExpect(status().isConflict()).andExpect(jsonPath("$.error.code").value("QUOTE_EXPIRED"));
        mvc.perform(post("/api/v1/users/me/booking-quotes").with(customer).contentType(MediaType.APPLICATION_JSON).content(payload.replace("\"65\"","\"0\""))).andExpect(status().isUnprocessableEntity());
    }
}

