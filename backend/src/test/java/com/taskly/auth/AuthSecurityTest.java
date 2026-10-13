package com.taskly.auth;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@ActiveProfiles("test")
@SpringBootTest
@AutoConfigureMockMvc
class AuthSecurityTest {
    @Autowired
    MockMvc mvc;

    @Test
    void loginIsPublicButStillValidated() throws Exception {
        mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));
    }

    @Test
    void refreshCookieMutationRequiresCsrf() throws Exception {
        mvc.perform(post("/api/v1/auth/refresh"))
                .andExpect(status().isForbidden());
    }

    @Test
    void profileRequiresAuthentication() throws Exception {
        mvc.perform(get("/api/v1/users/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHENTICATED"));
    }

    @Test
    void authenticatedPrincipalCannotReadAnotherUserByProvidingAnId() throws Exception {
        UUID principalId = UUID.randomUUID();
        mvc.perform(get("/api/v1/users/me")
                        .with(jwt().jwt(value -> value.subject(principalId.toString()))))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("USER_NOT_FOUND"));
    }

    @Test
    void kycRequiresAuthentication() throws Exception {
        mvc.perform(get("/api/v1/verifications/me"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void adminKycRequiresExplicitReviewPermission() throws Exception {
        mvc.perform(get("/api/v1/admin/verifications")
                        .with(jwt().jwt(value -> value.subject(UUID.randomUUID().toString()))))
                .andExpect(status().isForbidden());
    }

    @Test
    void adminKycPermissionReachesApplicationLayer() throws Exception {
        mvc.perform(get("/api/v1/admin/verifications")
                        .with(jwt().jwt(value -> value.subject(UUID.randomUUID().toString()))
                                .authorities(() -> "KYC_REVIEW")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items").isArray());
    }
}
