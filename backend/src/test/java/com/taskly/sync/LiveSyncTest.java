package com.taskly.sync;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class LiveSyncTest {
    @Autowired LiveSync sync;
    @Autowired LiveSyncFilter filter;
    @Autowired MockMvc mvc;
    @Test void authenticatedClientsReceiveOnlyRevision() throws Exception {
        mvc.perform(get("/api/v1/live-sync")).andExpect(status().isUnauthorized());
        var pending=mvc.perform(get("/api/v1/live-sync").with(jwt())).andExpect(request().asyncStarted()).andReturn();
        mvc.perform(asyncDispatch(pending)).andExpect(status().isOk())
            .andExpect(jsonPath("$.data.revision").isNumber());
    }
    @Test void successfulWritesWakeWaitersAndFailuresDoNot() throws Exception {
        long before=sync.revision();
        var waiter=sync.waitFor(before);
        assertFalse(waiter.hasResult());
        var request=new MockHttpServletRequest("PATCH","/api/v1/admin/services/test/pricing");
        filter.doFilter(request,new MockHttpServletResponse(),(req,res)->{});
        assertTrue(waiter.hasResult());
        assertEquals(before+1,sync.revision());
        var failed=new MockHttpServletResponse();
        filter.doFilter(new MockHttpServletRequest("PATCH","/api/v1/admin/services/test/pricing"),failed,(req,res)->((jakarta.servlet.http.HttpServletResponse)res).setStatus(422));
        assertEquals(before+1,sync.revision());
        filter.doFilter(new MockHttpServletRequest("GET","/api/v1/public/services"),new MockHttpServletResponse(),(req,res)->{});
        assertEquals(before+1,sync.revision());
    }
}
