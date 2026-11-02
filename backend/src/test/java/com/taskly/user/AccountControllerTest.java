package com.taskly.user;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.taskly.rbac.repository.RoleRepository;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.repository.UserAccountRepository;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AccountControllerTest {
    @Autowired MockMvc mvc;
    @Autowired UserAccountRepository users;
    @Autowired RoleRepository roles;
    @Autowired org.springframework.jdbc.core.JdbcTemplate db;
    @Test
    void favoritesAreIdempotentAndPrivateToTheCustomer() throws Exception {
        UUID owner = account(), other = account();
        UserAccount helper = new UserAccount(UUID.randomUUID()+"@example.test", null, "hash",
                roles.findByKey("TASKER").orElseThrow(), Instant.now());
        helper.verifyEmail(Instant.now());
        UUID helperId = users.save(helper).getId();
        db.update("INSERT INTO user_profiles(user_id,full_name,language,created_at,updated_at) VALUES (?,?,'vi',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)", helperId, "Người giúp thử nghiệm");
        String path = "/api/v1/users/me/favorite-helpers/" + helperId;
        for (int i = 0; i < 2; i++)
            mvc.perform(put(path).with(jwt().jwt(j -> j.subject(owner.toString()))))
                    .andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/favorite-helpers").with(jwt().jwt(j -> j.subject(owner.toString()))))
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].id").value(helperId.toString()));
        mvc.perform(delete(path).with(jwt().jwt(j -> j.subject(other.toString()))))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/favorite-helpers").with(jwt().jwt(j -> j.subject(owner.toString()))))
                .andExpect(jsonPath("$.data.length()").value(1));
        mvc.perform(get("/api/v1/users/me/favorite-helpers").with(jwt().jwt(j -> j.subject(other.toString()))))
                .andExpect(jsonPath("$.data").isEmpty());
        mvc.perform(put("/api/v1/users/me/favorite-helpers/" + other).with(jwt().jwt(j -> j.subject(owner.toString()))))
                .andExpect(status().isNotFound());
        mvc.perform(delete(path).with(jwt().jwt(j -> j.subject(owner.toString()))))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/favorite-helpers").with(jwt().jwt(j -> j.subject(owner.toString()))))
                .andExpect(jsonPath("$.data").isEmpty());
    }
    private UUID account() {
        return users.save(new UserAccount(UUID.randomUUID()+"@example.test", null, "hash",
                roles.findByKey("CUSTOMER").orElseThrow(), Instant.now())).getId();
    }
    @Test
    void methodsPersistAndCannotBeDeletedByAnotherAccount() throws Exception {
        UUID owner = account(), other = account();
        mvc.perform(post("/api/v1/users/me/payment-methods").with(jwt().jwt(j -> j.subject(owner.toString())))
                .contentType(MediaType.APPLICATION_JSON).content("{\"kind\":\"CASH\",\"name\":\"Cash\",\"detail\":\"Cash\"}"))
                .andExpect(status().isOk());
        String body = mvc.perform(get("/api/v1/users/me/payment-methods").with(jwt().jwt(j -> j.subject(owner.toString()))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data[0].isDefault").value(true))
                .andReturn().getResponse().getContentAsString();
        String id = new ObjectMapper().readTree(body).get("data").get(0).get("id").asText();
        mvc.perform(delete("/api/v1/users/me/payment-methods/"+id).with(jwt().jwt(j -> j.subject(other.toString()))))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/users/me/payment-methods").with(jwt().jwt(j -> j.subject(other.toString()))))
                .andExpect(jsonPath("$.data").isEmpty());
        mvc.perform(put("/api/v1/users/me/settings").with(jwt().jwt(j -> j.subject(owner.toString())))
                .contentType(MediaType.APPLICATION_JSON).content("{\"notificationsEnabled\":false}"))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me/settings").with(jwt().jwt(j -> j.subject(owner.toString()))))
                .andExpect(jsonPath("$.data.notificationsEnabled").value(false));
        mvc.perform(get("/api/v1/users/me/settings").with(jwt().jwt(j -> j.subject(other.toString()))))
                .andExpect(jsonPath("$.data.notificationsEnabled").value(true));
    }
}
