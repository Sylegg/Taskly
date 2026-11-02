package com.taskly.catalogue;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasItem;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.taskly.catalogue.entity.CatalogueService;
import com.taskly.catalogue.entity.ServiceCategory;
import com.taskly.catalogue.repository.CatalogueServiceRepository;
import com.taskly.catalogue.repository.ServiceCategoryRepository;
import jakarta.persistence.EntityManager;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.cache.CacheManager;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@ActiveProfiles("test")
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class ServiceIconIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired ServiceCategoryRepository categories;
    @Autowired CatalogueServiceRepository services;
    @Autowired EntityManager entities;
    @Autowired CacheManager cacheManager;
    private final ObjectMapper json = new ObjectMapper();

    @BeforeEach
    @AfterEach
    void clearCatalogueCache() {
        for (String name : List.of("publicCatalogue", "publicService")) {
            var cache = cacheManager.getCache(name);
            if (cache != null) cache.clear();
        }
    }

    @Test
    void presetRoundTripsAndOlderRequestsPreserveThenClearIt() throws Exception {
        UUID categoryId = category();
        String slug = "icon-preset-" + UUID.randomUUID();
        var request = serviceJson(categoryId, slug);
        request.put("iconKey", "cleaning");
        JsonNode created = createService(request);
        UUID id = UUID.fromString(created.path("id").asText());
        assertEquals("cleaning", created.path("iconKey").asText());
        assertFalse(created.hasNonNull("iconUrl"));
        activate(id);

        mvc.perform(get("/api/v1/public/services/{slug}", slug))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.iconKey").value("cleaning"))
                .andExpect(jsonPath("$.data.iconUrl").doesNotExist());
        mvc.perform(get("/api/v1/public/services"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.services[?(@.id == '" + id + "')].iconKey").value(hasItem("cleaning")));

        var olderRequest = serviceJson(categoryId, slug);
        updateService(id, olderRequest).andExpect(jsonPath("$.data.iconKey").value("cleaning"));
        olderRequest.put("iconKey", null);
        olderRequest.put("iconDataUrl", null);
        updateService(id, olderRequest).andExpect(jsonPath("$.data.iconKey").value("cleaning"));

        olderRequest.put("iconKey", "sparkles");
        updateService(id, olderRequest).andExpect(jsonPath("$.data.iconKey").value("sparkles"));
        mvc.perform(get("/api/v1/public/services/{slug}", slug))
                .andExpect(jsonPath("$.data.iconKey").value("sparkles"));
        mvc.perform(get("/api/v1/public/services"))
                .andExpect(jsonPath("$.data.services[?(@.id == '" + id + "')].iconKey").value(hasItem("sparkles")));

        mvc.perform(post("/api/v1/admin/services/{id}/order", id).with(catalogueAdmin())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"displayOrder\":3}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.iconKey").value("sparkles"));
        mvc.perform(post("/api/v1/admin/services/{id}/deactivate", id).with(catalogueAdmin()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.iconKey").value("sparkles"));
        activate(id);

        olderRequest.put("iconKey", "");
        updateService(id, olderRequest).andExpect(jsonPath("$.data.iconKey").doesNotExist());
        mvc.perform(get("/api/v1/public/services/{slug}", slug))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.iconKey").doesNotExist());
        services.flush();
        entities.clear();
        CatalogueService persisted = services.findById(id).orElseThrow();
        assertNull(persisted.getIconKey());
        assertNull(persisted.getIconImage());
    }

    @Test
    void uploadedImagePersistsIsNormalizedAndChangesItsCachedUrlWhenReplacedOrRemoved() throws Exception {
        UUID categoryId = category();
        String slug = "icon-upload-" + UUID.randomUUID();
        var request = serviceJson(categoryId, slug);
        request.put("iconKey", "sofa");
        request.put("iconDataUrl", dataUrl("png", 512, 256, new Color(255, 40, 20, 128)));
        JsonNode created = createService(request);
        UUID id = UUID.fromString(created.path("id").asText());
        String firstUrl = created.path("iconUrl").asText();
        assertTrue(firstUrl.matches("/api/v1/public/service-icons/" + id + "/[a-f0-9]{64}\\.png"));
        assertEquals("sofa", created.path("iconKey").asText());
        assertFalse(created.has("iconDataUrl"));
        assertFalse(created.has("iconImage"));
        assertFalse(created.has("iconImageHash"));

        // Inactive services still need a public image URL for the admin editor preview.
        var firstImage = mvc.perform(get(firstUrl))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_PNG))
                .andExpect(header().string(HttpHeaders.CACHE_CONTROL, containsString("max-age=31536000")))
                .andExpect(header().string(HttpHeaders.CACHE_CONTROL, containsString("public")))
                .andExpect(header().string(HttpHeaders.CACHE_CONTROL, containsString("immutable")))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andReturn().getResponse();
        BufferedImage normalized = ImageIO.read(new ByteArrayInputStream(firstImage.getContentAsByteArray()));
        assertEquals(256, normalized.getWidth());
        assertEquals(128, normalized.getHeight());
        assertEquals(128, new Color(normalized.getRGB(128, 64), true).getAlpha());
        String etag = firstImage.getHeader(HttpHeaders.ETAG);
        assertNotNull(etag);
        mvc.perform(get(firstUrl).header(HttpHeaders.IF_NONE_MATCH, etag))
                .andExpect(status().isNotModified()).andExpect(content().bytes(new byte[0]));
        mvc.perform(get("/api/v1/public/service-icons/{id}/{hash}.png", id, "0".repeat(64)))
                .andExpect(status().isNotFound());

        services.flush();
        entities.clear();
        assertArrayEquals(firstImage.getContentAsByteArray(), services.findById(id).orElseThrow().getIconImage());
        activate(id);
        mvc.perform(get("/api/v1/public/services/{slug}", slug))
                .andExpect(jsonPath("$.data.iconUrl").value(firstUrl))
                .andExpect(jsonPath("$.data.iconDataUrl").doesNotExist())
                .andExpect(jsonPath("$.data.iconImage").doesNotExist());
        mvc.perform(get("/api/v1/public/services"))
                .andExpect(jsonPath("$.data.services[?(@.id == '" + id + "')].iconUrl").value(hasItem(firstUrl)));

        var olderRequest = serviceJson(categoryId, slug);
        updateService(id, olderRequest).andExpect(jsonPath("$.data.iconUrl").value(firstUrl))
                .andExpect(jsonPath("$.data.iconKey").value("sofa"));
        olderRequest.put("iconDataUrl", null);
        olderRequest.put("iconKey", null);
        updateService(id, olderRequest).andExpect(jsonPath("$.data.iconUrl").value(firstUrl));

        olderRequest.put("iconDataUrl", dataUrl("jpeg", 320, 320, Color.BLUE));
        var replaced = updateService(id, olderRequest).andExpect(jsonPath("$.data.iconKey").value("sofa"))
                .andReturn().getResponse();
        String secondUrl = json.readTree(replaced.getContentAsString()).path("data").path("iconUrl").asText();
        assertNotEquals(firstUrl, secondUrl);
        mvc.perform(get(firstUrl)).andExpect(status().isNotFound());
        var secondImage = mvc.perform(get(secondUrl)).andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_PNG)).andReturn().getResponse().getContentAsByteArray();
        assertEquals(256, ImageIO.read(new ByteArrayInputStream(secondImage)).getWidth());
        mvc.perform(get("/api/v1/public/services/{slug}", slug))
                .andExpect(jsonPath("$.data.iconUrl").value(secondUrl));
        mvc.perform(get("/api/v1/public/services"))
                .andExpect(jsonPath("$.data.services[?(@.id == '" + id + "')].iconUrl").value(hasItem(secondUrl)));

        olderRequest.put("iconDataUrl", "");
        updateService(id, olderRequest).andExpect(jsonPath("$.data.iconUrl").doesNotExist())
                .andExpect(jsonPath("$.data.iconKey").value("sofa"));
        mvc.perform(get(secondUrl)).andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/public/services/{slug}", slug))
                .andExpect(jsonPath("$.data.iconUrl").doesNotExist());

        olderRequest.put("iconDataUrl", dataUrl("png", 32, 32, Color.GREEN));
        String deletedUrl = json.readTree(updateService(id, olderRequest).andReturn().getResponse().getContentAsString())
                .path("data").path("iconUrl").asText();
        mvc.perform(delete("/api/v1/admin/services/{id}", id).with(catalogueAdmin())).andExpect(status().isOk());
        mvc.perform(get(deletedUrl)).andExpect(status().isNotFound());
    }

    @Test
    void invalidIconsAreRejectedWithoutOverwritingTheStoredIcon() throws Exception {
        UUID categoryId = category();
        String slug = "icon-invalid-" + UUID.randomUUID();
        var request = serviceJson(categoryId, slug);
        request.put("iconKey", "pets");
        request.put("iconDataUrl", dataUrl("png", 24, 24, Color.ORANGE));
        UUID id = UUID.fromString(createService(request).path("id").asText());
        byte[] original = services.findById(id).orElseThrow().getIconImage();
        String jpeg = dataUrl("jpeg", 12, 12, Color.RED);
        var invalidInputs = List.of(
                new InvalidInput("unknown-icon", null, "SERVICE_ICON_KEY_INVALID"),
                new InvalidInput("x".repeat(41), null, "SERVICE_ICON_KEY_INVALID"),
                new InvalidInput(null, "data:image/svg+xml;base64,PHN2Zz4=", "SERVICE_ICON_FORMAT_INVALID"),
                new InvalidInput(null, "https://example.com/icon.png", "SERVICE_ICON_FORMAT_INVALID"),
                new InvalidInput(null, "data:image/png;base64,!!!", "SERVICE_ICON_DATA_INVALID"),
                new InvalidInput(null, "data:image/png;base64,SGVsbG8=", "SERVICE_ICON_FORMAT_INVALID"),
                new InvalidInput(null, jpeg.replace("image/jpeg", "image/png"), "SERVICE_ICON_FORMAT_INVALID"),
                new InvalidInput(null, "data:image/png;base64,iVBORw0KGgo=", "SERVICE_ICON_DATA_INVALID"),
                new InvalidInput(null, dataUrl("png", 2049, 1, Color.RED), "SERVICE_ICON_DIMENSIONS_INVALID"),
                new InvalidInput(null, "data:image/png;base64," + Base64.getEncoder().encodeToString(new byte[1_048_577]), "SERVICE_ICON_TOO_LARGE"),
                new InvalidInput(null, "data:image/png;base64," + "A".repeat(1_400_001), "SERVICE_ICON_TOO_LARGE"));
        for (var invalid : invalidInputs) {
            var update = serviceJson(categoryId, slug);
            update.put("iconKey", invalid.key());
            update.put("iconDataUrl", invalid.dataUrl());
            mvc.perform(patch("/api/v1/admin/services/{id}", id).with(catalogueAdmin())
                            .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(update)))
                    .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.error.code").value(invalid.code()));
            assertEquals("pets", services.findById(id).orElseThrow().getIconKey());
            assertArrayEquals(original, services.findById(id).orElseThrow().getIconImage());
        }
    }

    @Test
    void iconChangesRequireAuthenticatedCatalogueAdmin() throws Exception {
        UUID categoryId = category();
        String slug = "icon-auth-" + UUID.randomUUID();
        var request = serviceJson(categoryId, slug);
        request.put("iconKey", "grid");
        UUID id = UUID.fromString(createService(request).path("id").asText());
        request.put("iconKey", "shopping");
        request.put("iconDataUrl", dataUrl("png", 16, 16, Color.BLACK));
        String body = json.writeValueAsString(request);
        mvc.perform(patch("/api/v1/admin/services/{id}", id).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isUnauthorized());
        mvc.perform(patch("/api/v1/admin/services/{id}", id).with(jwt())
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/admin/services").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isUnauthorized());
        assertEquals("grid", services.findById(id).orElseThrow().getIconKey());
        assertNull(services.findById(id).orElseThrow().getIconImage());
    }

    @Test
    void popularFlagPersistsAndInvalidatesPublicCatalogueWithoutActivatingServices() throws Exception {
        var request = serviceJson(category(), "popular-" + UUID.randomUUID());
        var created = createService(request);
        UUID id = UUID.fromString(created.path("id").asText());
        assertFalse(created.path("popular").asBoolean());
        mvc.perform(patch("/api/v1/admin/services/{id}/popular", id).with(jwt())
                .contentType(MediaType.APPLICATION_JSON).content("{\"popular\":true}"))
                .andExpect(status().isForbidden());
        mvc.perform(patch("/api/v1/admin/services/{id}/popular", id).with(catalogueAdmin())
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest());
        mvc.perform(patch("/api/v1/admin/services/{id}/popular", id).with(catalogueAdmin())
                .contentType(MediaType.APPLICATION_JSON).content("{\"popular\":true}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.popular").value(true))
                .andExpect(jsonPath("$.data.active").value(false));
        activate(id);
        mvc.perform(get("/api/v1/public/services/{slug}", request.get("slug")))
                .andExpect(jsonPath("$.data.popular").value(true));
        updateService(id, request).andExpect(jsonPath("$.data.popular").value(true));
        mvc.perform(patch("/api/v1/admin/services/{id}/popular", id).with(catalogueAdmin())
                .contentType(MediaType.APPLICATION_JSON).content("{\"popular\":false}"))
                .andExpect(status().isOk());
        entities.flush(); entities.clear();
        assertFalse(services.findById(id).orElseThrow().isPopular());
        mvc.perform(get("/api/v1/public/services/{slug}", request.get("slug")))
                .andExpect(jsonPath("$.data.popular").value(false));
    }

    private UUID category() {
        var category = new ServiceCategory("icon-category-" + UUID.randomUUID(), "Nhà cửa", "", 0, Instant.now());
        category.setActive(true, Instant.now());
        return categories.saveAndFlush(category).getId();
    }

    private JsonNode createService(Map<String, Object> request) throws Exception {
        String body = mvc.perform(post("/api/v1/admin/services").with(catalogueAdmin())
                        .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(request)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        assertFalse(body.contains("data:image"));
        return json.readTree(body).path("data");
    }

    private org.springframework.test.web.servlet.ResultActions updateService(UUID id, Map<String, Object> request) throws Exception {
        return mvc.perform(patch("/api/v1/admin/services/{id}", id).with(catalogueAdmin())
                        .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(request)))
                .andExpect(status().isOk());
    }

    private void activate(UUID id) throws Exception {
        mvc.perform(post("/api/v1/admin/services/{id}/activate", id).with(catalogueAdmin())).andExpect(status().isOk());
    }

    private RequestPostProcessor catalogueAdmin() {
        return jwt().jwt(value -> value.subject(UUID.randomUUID().toString()))
                .authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
    }

    private Map<String, Object> serviceJson(UUID categoryId, String slug) {
        var request = new LinkedHashMap<String, Object>();
        request.put("categoryId", categoryId.toString());
        request.put("slug", slug);
        request.put("name", "Dịch vụ thử biểu tượng");
        request.put("shortDescription", "Mô tả dịch vụ");
        request.put("description", "Dịch vụ có biểu tượng riêng");
        request.put("suggestedPriceMin", 100_000);
        request.put("suggestedPriceMax", 200_000);
        request.put("currency", "VND");
        request.put("estimatedDurationMinutes", 120);
        request.put("displayOrder", 0);
        return request;
    }

    private String dataUrl(String format, int width, int height, Color color) throws Exception {
        var image = new BufferedImage(width, height,
                format.equals("png") ? BufferedImage.TYPE_INT_ARGB : BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = image.createGraphics();
        try {
            graphics.setColor(color);
            graphics.fillRect(0, 0, width, height);
        } finally {
            graphics.dispose();
        }
        var bytes = new ByteArrayOutputStream();
        assertTrue(ImageIO.write(image, format, bytes));
        return "data:image/" + format + ";base64," + Base64.getEncoder().encodeToString(bytes.toByteArray());
    }

    private record InvalidInput(String key, String dataUrl, String code) {}
}
