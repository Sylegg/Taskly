package com.taskly.catalogue;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import java.awt.image.BufferedImage;
import java.io.*;
import java.util.Base64;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;
@ActiveProfiles("test") @SpringBootTest @AutoConfigureMockMvc @Transactional
class HomeBannerIntegrationTest {
 @Autowired MockMvc mvc;
 @Autowired org.springframework.jdbc.core.JdbcTemplate db;
 private final ObjectMapper json=new ObjectMapper();
 @Test void uploadsFullWidthImagePublishesTogglesAndDeletes() throws Exception {
  var output=new ByteArrayOutputStream();ImageIO.write(new BufferedImage(1200,400,BufferedImage.TYPE_INT_RGB),"png",output);
  var image="data:image/png;base64,"+Base64.getEncoder().encodeToString(output.toByteArray());
  var body=json.writeValueAsString(java.util.Map.of("title","Banner test","active",true,"displayOrder",2,"imageDataUrl",image));
  var auth=jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
  var response=mvc.perform(post("/api/v1/admin/banners").with(auth).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andReturn();
  var banner=json.readTree(response.getResponse().getContentAsString()).get("data");
  var id=banner.get("id").asText();var url=banner.get("imageUrl").asText();
  mvc.perform(get("/api/v1/public/banners")).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].id").value(id));
  var bytes=mvc.perform(get(url)).andExpect(status().isOk()).andExpect(content().contentType(MediaType.IMAGE_PNG)).andReturn().getResponse().getContentAsByteArray();
  var decoded=ImageIO.read(new ByteArrayInputStream(bytes));assertEquals(1200,decoded.getWidth());assertEquals(400,decoded.getHeight());
  mvc.perform(patch("/api/v1/admin/banners/"+id).with(auth).contentType(MediaType.APPLICATION_JSON).content("{\"title\":\"Banner test\",\"active\":false,\"displayOrder\":2}")).andExpect(status().isOk());
  mvc.perform(get("/api/v1/public/banners")).andExpect(jsonPath("$.data.length()").value(0));
  mvc.perform(delete("/api/v1/admin/banners/"+id).with(auth)).andExpect(status().isOk());
  mvc.perform(get(url)).andExpect(status().isNotFound());
 }
 @Test void imageOnlyCreationUsesInsertionOrderAndReplacementKeepsPosition() throws Exception {
  var output=new ByteArrayOutputStream();ImageIO.write(new BufferedImage(300,100,BufferedImage.TYPE_INT_RGB),"png",output);
  var image="data:image/png;base64,"+Base64.getEncoder().encodeToString(output.toByteArray());
  var body=json.writeValueAsString(java.util.Map.of("imageDataUrl",image));
  var auth=jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
  var first=json.readTree(mvc.perform(post("/api/v1/admin/banners").with(auth).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.data.active").value(true)).andReturn().getResponse().getContentAsString()).get("data").get("id").asText();
  var second=json.readTree(mvc.perform(post("/api/v1/admin/banners").with(auth).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data").get("id").asText();
  db.update("UPDATE home_banners SET display_order=9999 WHERE id=?",java.util.UUID.fromString(first));
  mvc.perform(get("/api/v1/public/banners")).andExpect(jsonPath("$.data[0].id").value(first)).andExpect(jsonPath("$.data[1].id").value(second));
  mvc.perform(patch("/api/v1/admin/banners/"+first).with(auth).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
  mvc.perform(get("/api/v1/admin/banners").with(auth)).andExpect(jsonPath("$.data[0].id").value(first)).andExpect(jsonPath("$.data[1].id").value(second));
 }
 @Test void rejectsMissingImageAndUnauthorizedWrites() throws Exception {
  var body="{\"title\":\"Test\",\"active\":true,\"displayOrder\":0}";
  mvc.perform(post("/api/v1/admin/banners").with(jwt()).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isForbidden());
  mvc.perform(post("/api/v1/admin/banners").with(jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"))).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isUnprocessableEntity());
 }
}
