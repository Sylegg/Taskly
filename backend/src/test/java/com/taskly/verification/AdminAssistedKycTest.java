package com.taskly.verification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskly.auth.dto.AuthDtos;
import com.taskly.rbac.repository.RoleRepository;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.repository.UserAccountRepository;
import jakarta.persistence.EntityManager;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.nio.file.Path;
import java.time.Instant;
import java.util.UUID;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AdminAssistedKycTest {
    @TempDir static Path privateStorage;
    @Autowired MockMvc mvc;
    @Autowired UserAccountRepository users;
    @Autowired RoleRepository roles;
    @Autowired EntityManager entities;
    @Autowired JdbcTemplate db;

    @DynamicPropertySource
    static void storagePath(DynamicPropertyRegistry registry) {
        registry.add("app.storage.local-directory", () -> privateStorage.toString());
    }

    @Test
    void adminCanSubmitAndApproveBothSidesForAnUnverifiedPartnerWithoutCheckin() throws Exception {
        var partner = newUser();
        partner.recordAppUse(AuthDtos.AppType.PARTNER, Instant.now());
        users.saveAndFlush(partner);
        var admin = users.saveAndFlush(newUser());
        var reviewer = jwt().jwt(token -> token.subject(admin.getId().toString())).authorities(() -> "KYC_REVIEW");
        String route = "/api/v1/admin/verifications/assisted/" + partner.getId();

        var bytes = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(240, 240, BufferedImage.TYPE_INT_RGB), "png", bytes);
        var front = new MockMultipartFile("front", "front.png", "image/png", bytes.toByteArray());
        var back = new MockMultipartFile("back", "back.png", "image/png", bytes.toByteArray());
        var upload = multipart(route + "/submit").file(front).file(back)
                .param("legalName", "Đối tác thử nghiệm").param("documentNumber", "001234567890")
                .param("ownerAuthorized", "true").param("version", "-1");

        mvc.perform(multipart(route + "/submit").file(front).file(back)
                        .param("legalName", "Đối tác thử nghiệm").param("documentNumber", "001234567890")
                        .param("ownerAuthorized", "true")
                        .with(jwt().jwt(token -> token.subject(admin.getId().toString()))))
                .andExpect(status().isForbidden());
        mvc.perform(upload.with(reviewer))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("SUBMITTED"))
                .andExpect(jsonPath("$.data.documents.length()").value(2));
        entities.flush();
        UUID id = db.queryForObject("SELECT id FROM identity_verifications WHERE user_id=?", UUID.class, partner.getId());
        Long version = db.queryForObject("SELECT version FROM identity_verifications WHERE id=?", Long.class, id);

        String approval = route + "/" + id + "/approve";
        mvc.perform(post(approval).param("version", Long.toString(version)).with(reviewer))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"));
        entities.flush();
        assertThat(db.queryForObject("SELECT kyc_status FROM tasker_profiles WHERE user_id=?", String.class, partner.getId()))
                .isEqualTo("APPROVED");
        assertThat(db.queryForObject("SELECT COUNT(*) FROM partner_applications WHERE user_id=?", Integer.class, partner.getId()))
                .isZero();
        assertThat(db.queryForObject("SELECT status FROM users WHERE id=?", String.class, partner.getId()))
                .isEqualTo("PENDING_VERIFICATION");
        mvc.perform(post(approval).param("version", Long.toString(version)).with(reviewer))
                .andExpect(status().isConflict());
    }

    private UserAccount newUser() {
        return new UserAccount(UUID.randomUUID() + "@example.test", null, "hash",
                roles.findByKey("CUSTOMER").orElseThrow(), Instant.now());
    }
}
