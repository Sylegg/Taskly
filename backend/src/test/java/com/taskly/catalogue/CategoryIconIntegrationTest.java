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
class CategoryIconIntegrationTest {
 @Autowired MockMvc mvc;
 @Autowired org.springframework.cache.CacheManager cache;
 @org.junit.jupiter.api.BeforeEach @org.junit.jupiter.api.AfterEach void clearCache(){for(var name:java.util.List.of("publicCatalogue","publicService")){var item=cache.getCache(name);if(item!=null)item.clear();}}
 private final ObjectMapper json=new ObjectMapper();
 @Test void categoryIconsPersistAndPublishSeparatelyFromServiceIcons() throws Exception {
  var output=new ByteArrayOutputStream();ImageIO.write(new BufferedImage(400,400,BufferedImage.TYPE_INT_RGB),"png",output);
  var image="data:image/png;base64,"+Base64.getEncoder().encodeToString(output.toByteArray());
  var body=json.writeValueAsString(java.util.Map.of("name","Icon category","slug","icon-category-test","description","Test","displayOrder",0,"iconKey","pets","iconDataUrl",image));
  var auth=jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
  var response=mvc.perform(post("/api/v1/admin/service-categories").with(auth).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.data.iconKey").value("pets")).andReturn();
  var category=json.readTree(response.getResponse().getContentAsString()).get("data");
  var id=category.get("id").asText();var url=category.get("iconUrl").asText();
  assertTrue(url.startsWith("/api/v1/public/category-icons/"));
  var bytes=mvc.perform(get(url)).andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray();
  assertEquals(256,ImageIO.read(new ByteArrayInputStream(bytes)).getWidth());
  mvc.perform(post("/api/v1/admin/service-categories/"+id+"/activate").with(auth)).andExpect(status().isOk());
  mvc.perform(get("/api/v1/public/services")).andExpect(status().isOk()).andExpect(jsonPath("$.data.categories[?(@.id == '"+id+"')].iconKey").value(org.hamcrest.Matchers.hasItem("pets")));
  mvc.perform(patch("/api/v1/admin/service-categories/"+id).with(auth).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(java.util.Map.of("name","Edited category","slug","icon-category-test","description","Test","displayOrder",0)))).andExpect(status().isOk()).andExpect(jsonPath("$.data.iconUrl").value(url));
  mvc.perform(patch("/api/v1/admin/service-categories/"+id).with(auth).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(java.util.Map.of("name","Edited category","slug","icon-category-test","description","Test","displayOrder",0,"iconKey","not-a-preset")))).andExpect(status().isUnprocessableEntity());
 }
}
