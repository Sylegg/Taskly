package com.taskly.common.system;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@ActiveProfiles("test")
@SpringBootTest
@AutoConfigureMockMvc
class SystemInfoControllerTest {
    @Autowired
    MockMvc mvc;

    @Test
    void publicSystemInfoUsesEnvelopeAndCorrelationId() throws Exception {
        mvc.perform(get("/api/v1/system/info").header("X-Request-ID", "test-request-1"))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Request-ID", "test-request-1"))
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.name").value("TaskLy API"))
                .andExpect(jsonPath("$.data.environment").value("test"));
    }

    @Test
    void protectedUnknownApiIsNotPublic() throws Exception {
        mvc.perform(get("/api/v1/private-placeholder"))
                .andExpect(status().isUnauthorized());
    }
}
