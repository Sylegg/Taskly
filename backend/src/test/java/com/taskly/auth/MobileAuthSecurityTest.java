package com.taskly.auth;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.ObjectMapper;

@ActiveProfiles("test")
@SpringBootTest
@AutoConfigureMockMvc
class MobileAuthSecurityTest {
    @Autowired MockMvc mvc;
    @Autowired UserAccountRepository users;
    @Autowired UserProfileRepository profiles;
    @Autowired RoleRepository roles;
    @Autowired PasswordEncoder passwords;
    @MockitoBean OtpService otp;
    @MockitoBean OtpMailSender mail;
    private final ObjectMapper json = new ObjectMapper();

    @Test
    void sharedAccountTracksBothAppsWithoutGrantingTaskerPermissions() throws Exception {
        String phone = "07" + String.format("%08d", Math.abs(UUID.randomUUID().getLeastSignificantBits() % 100000000));
        UserAccount user = new UserAccount(UUID.randomUUID() + "@example.test", phone,
                passwords.encode("Shared-password-2026"), roles.findByKey("CUSTOMER").orElseThrow(), Instant.now());
        user.verifyEmail(Instant.now());
        user = users.save(user);
        profiles.save(new UserProfile(user, "Shared account", Instant.now()));
        for (String app : new String[]{"CUSTOMER", "PARTNER"}) {
            mvc.perform(post("/api/v1/auth/mobile/login-phone").contentType(MediaType.APPLICATION_JSON)
                    .content(json.writeValueAsString(java.util.Map.of("phone", phone, "password", "Shared-password-2026", "appType", app))))
                    .andExpect(status().isOk()).andExpect(jsonPath("$.data.user.id").value(user.getId().toString()));
        }
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/v1/admin/customers")
                .with(org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt()
                        .authorities(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_ADMIN"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[?(@.id == '" + user.getId() + "')].customer_app").value(true))
                .andExpect(jsonPath("$.data[?(@.id == '" + user.getId() + "')].partner_app").value(true));
        org.junit.jupiter.api.Assertions.assertEquals(1, users.findById(user.getId()).orElseThrow().getRoles().size());
    }

    @Test
    void phoneLoginIssuesTokensAndRejectsInvalidCredentials() throws Exception {
        String email = "phone-login-" + UUID.randomUUID() + "@example.test";
        String phone = "06" + String.format("%08d", Math.abs(UUID.randomUUID().getLeastSignificantBits() % 100000000));
        String password = "Phone-password-2026";
        UserAccount user = new UserAccount(email, phone, passwords.encode(password),
                roles.findByKey("CUSTOMER").orElseThrow(), Instant.now());
        user = users.save(user);
        profiles.save(new UserProfile(user, "Phone login test", Instant.now()));
        mvc.perform(post("/api/v1/auth/mobile/login-phone").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("phone", phone, "password", password))))
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.error.code").value("EMAIL_VERIFICATION_REQUIRED"));
        user.verifyEmail(Instant.now());
        users.save(user);
        mvc.perform(post("/api/v1/auth/mobile/login-phone").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("phone", phone, "password", password))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.accessToken").isString())
                .andExpect(jsonPath("$.data.refreshToken").isString());
        for (String candidate : new String[]{phone, "0000000000"}) {
            mvc.perform(post("/api/v1/auth/mobile/login-phone").contentType(MediaType.APPLICATION_JSON)
                            .content(json.writeValueAsString(java.util.Map.of("phone", candidate, "password", "incorrect"))))
                    .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
        }
        mvc.perform(post("/api/v1/auth/mobile/login-phone").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phone\":\"bad\",\"password\":\"incorrect\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void registrationPersistsProfileAndRoleGrant() throws Exception {
        String email = "register-" + UUID.randomUUID() + "@example.test";
        String phone = "08" + String.format("%08d", Math.abs(UUID.randomUUID().getLeastSignificantBits() % 100000000));
        org.mockito.Mockito.when(otp.create("register", email)).thenReturn("123456");
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("email", email, "phone", phone,
                                "fullName", "Registration test", "password", "Registration-password-2026"))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.status").value("PENDING_VERIFICATION"));
        UserAccount registered = users.findByEmailIgnoreCase(email).orElseThrow();
        org.junit.jupiter.api.Assertions.assertTrue(profiles.findById(registered.getId()).isPresent());
        org.junit.jupiter.api.Assertions.assertTrue(registered.getRoles().stream().anyMatch(role -> role.getKey().equals("CUSTOMER")));
        org.mockito.Mockito.verify(mail).sendVerification(email, "123456");
        long accountCount = users.count();
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("email", email, "phone", phone,
                                "fullName", "Changed name", "password", "Registration-password-2026"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.userId").value(registered.getId().toString()))
                .andExpect(jsonPath("$.data.status").value("PENDING_VERIFICATION"));
        org.mockito.Mockito.verify(mail, org.mockito.Mockito.times(2)).sendVerification(email, "123456");
        org.junit.jupiter.api.Assertions.assertEquals(accountCount, users.count());
        org.junit.jupiter.api.Assertions.assertEquals("Registration test",
                profiles.findById(registered.getId()).orElseThrow().getFullName());
        for (String conflictingEmail : java.util.List.of(email, "different-" + email)) {
            mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                            .content(json.writeValueAsString(java.util.Map.of("email", conflictingEmail, "phone", phone,
                                    "fullName", "Registration test", "password", "Wrong-password-2026"))))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.error.code").value("ACCOUNT_ALREADY_EXISTS"));
        }
        org.mockito.Mockito.verify(mail, org.mockito.Mockito.times(2)).sendVerification(email, "123456");
        String loginBody = json.writeValueAsString(java.util.Map.of("email", email,
                "password", "Registration-password-2026"));
        mvc.perform(post("/api/v1/auth/mobile/login").contentType(MediaType.APPLICATION_JSON).content(loginBody))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("EMAIL_VERIFICATION_REQUIRED"));
        mvc.perform(post("/api/v1/auth/verify-otp").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("email", email, "code", "123456"))))
                .andExpect(status().isOk());
        org.mockito.Mockito.verify(otp).verify("register", email, "123456");
        mvc.perform(post("/api/v1/auth/mobile/login").contentType(MediaType.APPLICATION_JSON).content(loginBody))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.accessToken").isString());
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("email", email, "phone", phone,
                                "fullName", "Registration test", "password", "Registration-password-2026"))))
                .andExpect(status().isConflict());
    }

    @Test
    void registrationMailFailureAllowsRetryWithoutCreatingAnAccount() throws Exception {
        String email = "mail-failure-" + UUID.randomUUID() + "@example.test";
        String phone = "08" + String.format("%08d", Math.abs(UUID.randomUUID().getLeastSignificantBits() % 100000000));
        org.mockito.Mockito.when(otp.create("register", email)).thenReturn("123456");
        org.mockito.Mockito.doThrow(new com.taskly.common.exception.DomainException(
                "EMAIL_DELIVERY_FAILED", "Email unavailable", org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE))
                .when(mail).sendVerification(email, "123456");
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("email", email, "phone", phone,
                                "fullName", "Mail failure test", "password", "Registration-password-2026"))))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error.code").value("EMAIL_DELIVERY_FAILED"));
        org.mockito.Mockito.verify(otp).cancel("register", email);
        org.junit.jupiter.api.Assertions.assertFalse(users.existsByEmailIgnoreCase(email));
    }

    @Test
    void refreshRequiresExplicitCredentialAndDoesNotConsumeCookies() throws Exception {
        mvc.perform(post("/api/v1/auth/mobile/logout-all"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/mobile/logout-all")
                        .with(org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt()
                                .jwt(value -> value.subject(UUID.randomUUID().toString()))))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/auth/mobile/refresh").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/auth/refresh"))
                .andExpect(status().isForbidden());
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete(
                        "/api/v1/auth/mobile/sessions/" + UUID.randomUUID()))
                .andExpect(status().isUnauthorized());
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete(
                        "/api/v1/auth/mobile/sessions/" + UUID.randomUUID())
                        .with(org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt()
                                .jwt(value -> value.subject(UUID.randomUUID().toString()))))
                .andExpect(status().isNotFound());
    }

    @Test
    void failedLoginAttemptsPersistAndActivateCooldown() throws Exception {
        String email = "cooldown-" + UUID.randomUUID() + "@example.test";
        String password = "Cooldown-password-2026";
        UserAccount user = new UserAccount(email, "07" + String.format("%08d", Math.abs(UUID.randomUUID().getLeastSignificantBits() % 100000000)),
                passwords.encode(password), roles.findByKey("CUSTOMER").orElseThrow(), Instant.now());
        user.verifyEmail(Instant.now());
        user = users.save(user);
        profiles.save(new UserProfile(user, "Cooldown test", Instant.now()));
        for (int attempt = 0; attempt < 5; attempt++) {
            mvc.perform(post("/api/v1/auth/mobile/login").contentType(MediaType.APPLICATION_JSON)
                            .content(json.writeValueAsString(java.util.Map.of("email", email, "password", "wrong-password"))))
                    .andExpect(status().isUnauthorized());
        }
        mvc.perform(post("/api/v1/auth/mobile/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("email", email, "password", password))))
                .andExpect(status().isTooManyRequests()).andExpect(jsonPath("$.error.code").value("LOGIN_COOLDOWN"));
    }

    @Test
    void mobileRotationReplayRevokesReplacementAndLogoutRevokesCredential() throws Exception {
        String email = "native-" + UUID.randomUUID() + "@example.test";
        String password = "Mobile-test-password-2026";
        UserAccount user = new UserAccount(email, "09" + String.format("%08d", Math.abs(UUID.randomUUID().getLeastSignificantBits() % 100000000)),
                passwords.encode(password), roles.findByKey("CUSTOMER").orElseThrow(), Instant.now());
        user.verifyEmail(Instant.now());
        users.save(user);
        profiles.save(new UserProfile(user, "Mobile test", Instant.now()));
        String response = mvc.perform(post("/api/v1/auth/mobile/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("email", email, "password", password, "deviceName", "Android test"))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.refreshToken").isString())
                .andExpect(header().doesNotExist("Set-Cookie")).andReturn().getResponse().getContentAsString();
        String original = json.readTree(response).path("data").path("refreshToken").asText();
        String rotated = mvc.perform(post("/api/v1/auth/mobile/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("refreshToken", original))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String replacement = json.readTree(rotated).path("data").path("refreshToken").asText();
        mvc.perform(post("/api/v1/auth/mobile/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("refreshToken", original))))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/mobile/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("refreshToken", replacement))))
                .andExpect(status().isUnauthorized());
        String nextLogin = mvc.perform(post("/api/v1/auth/mobile/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("email", email, "password", password))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String credential = json.readTree(nextLogin).path("data").path("refreshToken").asText();
        mvc.perform(post("/api/v1/auth/mobile/logout").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("refreshToken", credential))))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/auth/mobile/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(java.util.Map.of("refreshToken", credential))))
                .andExpect(status().isUnauthorized());
    }
}
