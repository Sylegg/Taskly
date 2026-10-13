package com.taskly.milestones;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class MilestoneControllerTest {
 @Autowired MockMvc mvc;
 @Test void superAdminCanCreateAndPublishCustomBonus() throws Exception {
  String body="{\"min_orders\":11,\"orders\":\"11 đơn / ngày\",\"bonus_amount\":50001,\"bonus\":\"+50.001đ\",\"icon\":\"🎯\",\"badge\":\"Test\",\"perk\":\"Test sync\",\"color\":\"#2563EB\",\"bgColor\":\"#EFF6FF\",\"borderColor\":\"#BFDBFE\",\"active\":true,\"display_order\":11}";
  mvc.perform(post("/api/v1/admin/partner-milestones").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_PARTNER"))).contentType("application/json").content(body)).andExpect(status().isForbidden());
  mvc.perform(post("/api/v1/admin/partner-milestones").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_SUPER_ADMIN"))).contentType("application/json").content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.data[?(@.min_orders == 11)].bonus_amount").value(org.hamcrest.Matchers.hasItem(50001)));
  String response=mvc.perform(get("/api/v1/public/partner-milestones")).andExpect(status().isOk()).andExpect(jsonPath("$.data[?(@.min_orders == 11)].bonus_amount").value(org.hamcrest.Matchers.hasItem(50001))).andReturn().getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
  var rows=new tools.jackson.databind.ObjectMapper().readTree(response).get("data");
  for(var row:rows) if(row.get("min_orders").asInt()==11) mvc.perform(delete("/api/v1/admin/partner-milestones").param("id",row.get("id").asText()).with(jwt().authorities(new SimpleGrantedAuthority("ROLE_SUPER_ADMIN")))).andExpect(status().isOk());
 }
 @Test void publishedSeedsAndAdminPublication() throws Exception {
  mvc.perform(get("/api/v1/public/partner-milestones")).andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(3));
  mvc.perform(patch("/api/v1/admin/partner-milestones").with(jwt()).contentType("application/json").content("{\"id\":\"milestone-tier-1\",\"active\":false}")).andExpect(status().isForbidden());
  mvc.perform(patch("/api/v1/admin/partner-milestones").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))).contentType("application/json").content("{\"id\":\"milestone-tier-1\",\"active\":false}")).andExpect(status().isOk());
  mvc.perform(get("/api/v1/public/partner-milestones")).andExpect(jsonPath("$.data.length()").value(2));
  mvc.perform(patch("/api/v1/admin/partner-milestones").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))).contentType("application/json").content("{\"id\":\"milestone-tier-1\",\"active\":true}")).andExpect(status().isOk());
 }
}
