package com.taskly.user;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.taskly.rbac.repository.RoleRepository;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.entity.UserProfile;
import com.taskly.user.repository.UserAccountRepository;
import com.taskly.user.repository.UserProfileRepository;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminCustomerControllerTest {
    @Autowired MockMvc mvc;
    @Autowired UserAccountRepository users;
    @Autowired UserProfileRepository profiles;
    @Autowired RoleRepository roles;
    @Autowired org.springframework.jdbc.core.JdbcTemplate db;
    private UUID customer() {
        UserAccount user = new UserAccount(UUID.randomUUID()+"@example.test", null, "hash",
                roles.findByKey("CUSTOMER").orElseThrow(), Instant.now());
        user.verifyEmail(Instant.now()); user = users.save(user);
        profiles.save(new UserProfile(user, "Customer API test", Instant.now()));
        return user.getId();
    }
    @Test void customerDetailsUseRealOrdersWithoutPartnerData() throws Exception {
        UUID id=customer(),category=UUID.randomUUID(),service=UUID.randomUUID();
        db.update("INSERT INTO service_categories(id,slug,name,created_at,updated_at) VALUES(?,?,'Test',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",category,category.toString());
        db.update("INSERT INTO services(id,category_id,slug,name,short_description,suggested_price_min,suggested_price_max,currency,created_at,updated_at) VALUES(?,?,?,'Test','Test',0,0,'VND',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",service,category,service.toString());
        for(String state:java.util.List.of("DRAFT","POSTED","COMPLETED")) {
            db.update("INSERT INTO tasks(id,customer_id,service_id,status,service_slug_snapshot,service_name_snapshot,category_slug_snapshot,category_name_snapshot,suggested_price_min_snapshot,suggested_price_max_snapshot,title,description,address_line_snapshot,city_snapshot,scheduled_at,estimated_duration_minutes,budget_amount,currency,created_at,updated_at) SELECT ?,?,id,?,slug,name,'test','Test',0,0,'Test','Test','123 Nguyen Trai','TP. Hồ Chí Minh',CURRENT_TIMESTAMP,60,100000,'VND',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP FROM services LIMIT 1",UUID.randomUUID(),id,state);
        }
        mvc.perform(get("/api/v1/admin/customers/"+id+"/customer-details").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))).andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/admin/customers/"+id+"/customer-details").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_ADMIN")))).andExpect(status().isOk()).andExpect(jsonPath("$.data.orders.length()").value(2)).andExpect(jsonPath("$.data.orders[0].total").value(100000)).andExpect(jsonPath("$.data.bank").doesNotExist()).andExpect(jsonPath("$.data.dossier").doesNotExist());
    }
    @Test void batchEditsRollbackIfAnySectionIsInvalid() throws Exception {
        UUID id=customer(),actor=UUID.randomUUID();
        String bank="{\"section\":\"bank\",\"values\":{\"bank_name\":\"VCB\",\"account_name\":\"TEST\",\"account_number\":\"0123456789\"}}";
        mvc.perform(patch("/api/v1/admin/customers/"+id+"/details/batch").with(jwt().jwt(j->j.subject(actor.toString())).authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))).contentType(MediaType.APPLICATION_JSON).content("{\"edits\":["+bank+",{\"section\":\"decisions\",\"values\":{}}]}" )).andExpect(status().isBadRequest());
        org.junit.jupiter.api.Assertions.assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM partner_bank_accounts WHERE user_id=?",Integer.class,id));
        org.junit.jupiter.api.Assertions.assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM audit_logs WHERE actor_id=? AND entity_id=?",Integer.class,actor,id));
        mvc.perform(patch("/api/v1/admin/customers/"+id+"/details/batch").with(jwt().jwt(j->j.subject(actor.toString())).authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))).contentType(MediaType.APPLICATION_JSON).content("{\"edits\":["+bank+"]}" )).andExpect(status().isOk()).andExpect(jsonPath("$.data.bank[0].account_number").value("0123456789"));
    }
    @Test void adminEditsBankWithAuditAndCannotRewriteDecisions() throws Exception {
        UUID id=customer(),actor=UUID.randomUUID();
        String body="{\"section\":\"bank\",\"values\":{\"bank_name\":\"VCB\",\"account_name\":\"PARTNER TEST\",\"account_number\":\"0123456789\"}}";
        mvc.perform(patch("/api/v1/admin/customers/"+id+"/details").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"))).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isForbidden());
        mvc.perform(patch("/api/v1/admin/customers/"+id+"/details").with(jwt().jwt(j->j.subject(actor.toString())).authorities(new SimpleGrantedAuthority("ROLE_SUPER_ADMIN"))).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.data.bank[0].account_number").value("0123456789"));
        org.junit.jupiter.api.Assertions.assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM audit_logs WHERE actor_id=? AND entity_id=? AND action='EDIT_PARTNER_BANK'",Integer.class,actor,id));
        mvc.perform(patch("/api/v1/admin/customers/"+id+"/details").with(jwt().jwt(j->j.subject(actor.toString())).authorities(new SimpleGrantedAuthority("ROLE_SUPER_ADMIN"))).contentType(MediaType.APPLICATION_JSON).content("{\"section\":\"decisions\",\"values\":{}}" )).andExpect(status().isBadRequest());
    }
    @Test void adminDetailsIncludeBankAndRejectCustomer() throws Exception {
        UUID id=customer();
        db.update("INSERT INTO partner_bank_accounts(user_id,bank_name,account_name,account_number) VALUES(?,?,?,?)",id,"VCB","CUSTOMER API TEST","0123456789");
        mvc.perform(get("/api/v1/admin/customers/"+id+"/details").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))).andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/admin/customers/"+id+"/details").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_SUPER_ADMIN")))).andExpect(status().isOk()).andExpect(jsonPath("$.data.bank[0].account_number").value("0123456789")).andExpect(jsonPath("$.data.profile.full_name").value("Customer API test")).andExpect(jsonPath("$.data.performance.accepted_jobs").value(0)).andExpect(jsonPath("$.data.performance.completed_jobs").value(0));
    }
    @Test
    void rejectsAnonymousAndCustomerTokens() throws Exception {
        mvc.perform(get("/api/v1/admin/customers")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/admin/customers").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER"))))
            .andExpect(status().isForbidden());
        UUID id = customer();
        mvc.perform(patch("/api/v1/admin/customers/"+id).with(jwt().authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))
            .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Changed\",\"phone\":\"0900000111\"}"))
            .andExpect(status().isForbidden());
        mvc.perform(patch("/api/v1/admin/customers/"+id+"/status").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_CUSTOMER")))
            .contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"SUSPENDED\"}"))
            .andExpect(status().isForbidden());
    }
    @Test
    void adminReadsActualCustomersAndUpdatesDatabase() throws Exception {
        UUID id = customer();
        var admin = jwt().authorities(new SimpleGrantedAuthority("ROLE_SUPER_ADMIN"));
        mvc.perform(get("/api/v1/admin/customers").with(admin)).andExpect(status().isOk())
            .andExpect(jsonPath("$.data[?(@.id == '"+id+"')].name").value("Customer API test"));
        mvc.perform(patch("/api/v1/admin/customers/"+id).with(admin).contentType(MediaType.APPLICATION_JSON)
            .content("{\"name\":\"Updated customer\",\"phone\":\"0900000222\"}"))
            .andExpect(status().isOk());
        mvc.perform(get("/api/v1/admin/customers").with(admin))
            .andExpect(jsonPath("$.data[?(@.id == '"+id+"')].name").value("Updated customer"));
        mvc.perform(patch("/api/v1/admin/customers/"+id+"/status").with(admin).contentType(MediaType.APPLICATION_JSON)
            .content("{\"status\":\"SUSPENDED\"}")).andExpect(status().isOk());
        mvc.perform(get("/api/v1/admin/customers").with(admin))
            .andExpect(jsonPath("$.data[?(@.id == '"+id+"')].status").value("SUSPENDED"));
        mvc.perform(patch("/api/v1/admin/customers/"+id+"/status").with(admin).contentType(MediaType.APPLICATION_JSON)
            .content("{\"status\":\"ACTIVE\"}")).andExpect(status().isOk());
        mvc.perform(patch("/api/v1/admin/customers/"+id+"/status").with(admin).contentType(MediaType.APPLICATION_JSON)
            .content("{\"status\":\"SUPER_ADMIN\"}")).andExpect(status().isBadRequest());
    }
    @Test
    @org.springframework.transaction.annotation.Transactional
    void partnerAccountIncludesEveryReviewStepAndLatestIdentityStatus() throws Exception {
        UUID user = customer(), application = UUID.randomUUID();
        users.flush(); profiles.flush();
        db.update("UPDATE users SET used_partner=true WHERE id=?", user);
        db.update("INSERT INTO partner_applications(id,user_id,status,exam_passed,training_complete,reason,created_at,updated_at) VALUES(?,?,'ACTION_REQUIRED',true,false,'Bổ sung hồ sơ',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",application,user);
        db.update("INSERT INTO identity_verifications(id,user_id,status,created_at,updated_at) VALUES(?,?,'UNDER_REVIEW',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",UUID.randomUUID(),user);
        String target="$.data[?(@.id == '"+user+"')]";
        mvc.perform(get("/api/v1/admin/customers").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_SUPER_ADMIN"))))
          .andExpect(status().isOk()).andExpect(jsonPath(target+".partner_app").value(true))
          .andExpect(jsonPath(target+".recruitment_status").value("ACTION_REQUIRED"))
          .andExpect(jsonPath(target+".kyc").value("UNDER_REVIEW"))
          .andExpect(jsonPath(target+".partner_checks.exam_passed").value(true))
          .andExpect(jsonPath(target+".partner_checks.training_complete").value(false))
          .andExpect(jsonPath(target+".partner_checks.final_approved").value(false))
          .andExpect(jsonPath(target+".review_reason").value("Bổ sung hồ sơ"));
    }

}
