package com.taskly.catalogue;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.taskly.catalogue.repository.CatalogueServiceRepository;
import com.taskly.catalogue.repository.ServiceCategoryRepository;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@ActiveProfiles("test")
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class CatalogueIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired ServiceCategoryRepository categories;
    @Autowired CatalogueServiceRepository services;

    @Test
    void publicOnlySeesActivatedCatalogueAndAdminRequiresPermission() throws Exception {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        String categorySlug = "cleaning-" + suffix;
        String serviceSlug = "home-cleaning-" + suffix;

        mvc.perform(get("/api/v1/public/services"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.services").isArray());

        mvc.perform(post("/api/v1/admin/service-categories")
                        .with(jwt().jwt(value -> value.subject(UUID.randomUUID().toString())))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(categoryJson(categorySlug)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));

        mvc.perform(post("/api/v1/admin/service-categories")
                        .with(catalogueAdmin()).contentType(MediaType.APPLICATION_JSON)
                        .content(categoryJson(categorySlug)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.active").value(false));
        UUID categoryId = categories.findBySlugAndDeletedAtIsNull(categorySlug).orElseThrow().getId();

        mvc.perform(post("/api/v1/admin/services")
                        .with(catalogueAdmin()).contentType(MediaType.APPLICATION_JSON)
                        .content(serviceJson(categoryId, serviceSlug, 200_000, 100_000)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("PRICE_RANGE_INVALID"));

        mvc.perform(post("/api/v1/admin/services")
                        .with(catalogueAdmin()).contentType(MediaType.APPLICATION_JSON)
                        .content(serviceJson(categoryId, serviceSlug, 100_000, 200_000)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.active").value(false));
        UUID serviceId = services.findByDeletedAtIsNullOrderByDisplayOrderAscNameAsc().stream()
                .filter(value -> value.getSlug().equals(serviceSlug)).findFirst().orElseThrow().getId();

        mvc.perform(get("/api/v1/public/services/{slug}", serviceSlug))
                .andExpect(status().isNotFound());

        mvc.perform(post("/api/v1/admin/service-categories/{id}/activate", categoryId).with(catalogueAdmin()))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/admin/services/{id}/activate", serviceId).with(catalogueAdmin()))
                .andExpect(status().isOk());

        mvc.perform(get("/api/v1/public/services/{slug}", serviceSlug))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.slug").value(serviceSlug))
                .andExpect(jsonPath("$.data.suggestedPriceMin").value(100000));
        mvc.perform(get("/api/v1/public/services"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.services[?(@.slug == '" + serviceSlug + "')]").exists());

        mvc.perform(post("/api/v1/admin/services/{id}/deactivate", serviceId).with(catalogueAdmin()))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/public/services/{slug}", serviceSlug))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/public/services"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.services[?(@.slug == '" + serviceSlug + "')]").isEmpty());
    }

    private org.springframework.test.web.servlet.request.RequestPostProcessor catalogueAdmin() {
        return jwt().jwt(value -> value.subject(UUID.randomUUID().toString()))
                .authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
    }

    private String categoryJson(String slug) {
        return "{\"slug\":\"" + slug + "\",\"name\":\"Dọn dẹp\",\"description\":\"Dịch vụ nhà cửa\",\"displayOrder\":1}";
    }

    private String serviceJson(UUID categoryId, String slug, long min, long max) {
        return "{\"categoryId\":\"" + categoryId + "\",\"slug\":\"" + slug
                + "\",\"name\":\"Dọn nhà\",\"shortDescription\":\"Dọn dẹp theo giờ\","
                + "\"description\":\"Dịch vụ dọn nhà\",\"suggestedPriceMin\":" + min
                + ",\"suggestedPriceMax\":" + max + ",\"currency\":\"VND\","
                + "\"estimatedDurationMinutes\":120,\"displayOrder\":1}";
    }
}
