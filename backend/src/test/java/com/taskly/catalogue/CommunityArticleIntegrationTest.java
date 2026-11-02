package com.taskly.catalogue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import java.awt.image.BufferedImage;
import java.io.*;
import java.util.*;
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
class CommunityArticleIntegrationTest {
 @Autowired MockMvc mvc; final ObjectMapper json=new ObjectMapper();
 @Autowired org.springframework.jdbc.core.JdbcTemplate db;
 @Test void onlyAdminPublishesAndSocialWritesPersistIdempotently() throws Exception {
  var user=UUID.randomUUID();
  db.update("INSERT INTO users(id,email,password_hash,status,created_at,updated_at) VALUES(?,?,?,'ACTIVE',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",user,user+"@example.test","not-a-login-password");
  db.update("INSERT INTO user_profiles(user_id,full_name,created_at,updated_at) VALUES(?,'Khách thử nghiệm',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",user);
  var customer=jwt().jwt(j->j.subject(user.toString()));
  var staff=jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
  var out=new ByteArrayOutputStream();ImageIO.write(new BufferedImage(800,450,BufferedImage.TYPE_INT_RGB),"png",out);
  var body=json.writeValueAsString(Map.of("title","Câu chuyện mới","content","Cảm nghĩ của tôi","imageDataUrl","data:image/png;base64,"+Base64.getEncoder().encodeToString(out.toByteArray())));
  mvc.perform(post("/api/v1/community/articles").with(customer).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isForbidden());
  var result=mvc.perform(post("/api/v1/admin/articles").with(staff).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andReturn();
  var id=json.readTree(result.getResponse().getContentAsString()).get("data").get("id").asText();
  mvc.perform(get("/api/v1/public/articles/"+id)).andExpect(status().isNotFound());
  var admin=mvc.perform(get("/api/v1/admin/articles").with(staff)).andExpect(jsonPath("$.data[0].submittedByUser").value(false)).andExpect(jsonPath("$.data[0].authorName").value("TaskLy")).andReturn();
  var image=json.readTree(admin.getResponse().getContentAsString()).get("data").get(0).get("imageUrl").asText();
  mvc.perform(get(image)).andExpect(status().isNotFound());
  mvc.perform(get(image).with(staff)).andExpect(status().isOk());
  mvc.perform(patch("/api/v1/admin/articles/"+id).with(customer).contentType(MediaType.APPLICATION_JSON).content("{\"active\":true}")).andExpect(status().isForbidden());
  mvc.perform(patch("/api/v1/admin/articles/"+id).with(staff).contentType(MediaType.APPLICATION_JSON).content("{\"active\":true,\"groupName\":\"Chuyện nhà\",\"featured\":true,\"hashtag\":\"TaskLyNews\"}")).andExpect(status().isOk());
  mvc.perform(get("/api/v1/public/articles/"+id)).andExpect(jsonPath("$.data.groupName").value("Chuyện nhà")).andExpect(jsonPath("$.data.featured").value(true));
  var reaction="{\"kind\":\"LIKE\",\"selected\":true}";
  for(int n=0;n<2;n++)mvc.perform(put("/api/v1/community/articles/"+id+"/reaction").with(customer).contentType(MediaType.APPLICATION_JSON).content(reaction)).andExpect(status().isOk()).andExpect(jsonPath("$.data.likes").value(1));
  mvc.perform(post("/api/v1/community/articles/"+id+"/comments").with(customer).contentType(MediaType.APPLICATION_JSON).content("{\"content\":\"Bài viết hữu ích\"}")).andExpect(status().isOk());
  mvc.perform(get("/api/v1/community/articles/"+id+"/comments").with(customer)).andExpect(jsonPath("$.data[0].content").value("Bài viết hữu ích"));
  mvc.perform(get("/api/v1/community/articles/"+id+"/engagement").with(customer)).andExpect(jsonPath("$.data.liked").value(true)).andExpect(jsonPath("$.data.comments").value(1));
  mvc.perform(post("/api/v1/community/articles/"+id+"/comments").with(customer).contentType(MediaType.APPLICATION_JSON).content("{\"content\":\"   \"}")).andExpect(status().isBadRequest());
  mvc.perform(get("/api/v1/admin/articles").with(staff)).andExpect(jsonPath("$.data[0].likes").value(1)).andExpect(jsonPath("$.data[0].comments").value(1));
  mvc.perform(get("/api/v1/admin/articles/"+id+"/comments")).andExpect(status().isUnauthorized());
  mvc.perform(get("/api/v1/admin/articles/"+id+"/comments").with(customer)).andExpect(status().isForbidden());
  mvc.perform(get("/api/v1/admin/articles/"+id+"/comments").with(staff)).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].authorName").value("Khách thử nghiệm")).andExpect(jsonPath("$.data[0].content").value("Bài viết hữu ích"));
  mvc.perform(patch("/api/v1/admin/articles/"+id).with(staff).contentType(MediaType.APPLICATION_JSON).content("{\"active\":false}")).andExpect(status().isOk());
  mvc.perform(get("/api/v1/admin/articles/"+id+"/comments").with(staff)).andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(1));
  mvc.perform(put("/api/v1/community/articles/"+id+"/reaction").with(customer).contentType(MediaType.APPLICATION_JSON).content(reaction)).andExpect(status().isNotFound());
 }
 @Test void publishesEditsHidesAndDeletesRealArticle() throws Exception {
  var out=new ByteArrayOutputStream();ImageIO.write(new BufferedImage(800,450,BufferedImage.TYPE_INT_RGB),"png",out);
  var body=json.writeValueAsString(Map.of("title","Chuyện nhà","summary","Giới thiệu","content","Nội dung\nĐoạn thứ hai","active",true,"imageDataUrl","data:image/png;base64,"+Base64.getEncoder().encodeToString(out.toByteArray())));
  var auth=jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
  var result=mvc.perform(post("/api/v1/admin/articles").with(auth).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andReturn();
  var a=json.readTree(result.getResponse().getContentAsString()).get("data");var id=a.get("id").asText();var image=a.get("imageUrl").asText();
  mvc.perform(get("/api/v1/public/articles")).andExpect(jsonPath("$.data[0].title").value("Chuyện nhà"));
  mvc.perform(get("/api/v1/public/articles/"+id)).andExpect(jsonPath("$.data.content").value("Nội dung\nĐoạn thứ hai"));
  mvc.perform(get(image)).andExpect(status().isOk()).andExpect(content().contentType(MediaType.IMAGE_PNG));
  mvc.perform(patch("/api/v1/admin/articles/"+id).with(auth).contentType(MediaType.APPLICATION_JSON).content("{\"hashtag\":\"TaskLyNews #hello\"}")).andExpect(status().isOk()).andExpect(jsonPath("$.data.hashtag").value("TaskLyNews #hello"));
  mvc.perform(patch("/api/v1/admin/articles/"+id).with(auth).contentType(MediaType.APPLICATION_JSON).content("{\"hashtag\":\"TaskLyNews hello\"}")).andExpect(status().isBadRequest());
  mvc.perform(patch("/api/v1/admin/articles/"+id).with(auth).contentType(MediaType.APPLICATION_JSON).content("{\"active\":false,\"title\":\"Đã sửa\"}")).andExpect(status().isOk());
  mvc.perform(get("/api/v1/public/articles/"+id)).andExpect(status().isNotFound());
  mvc.perform(get("/api/v1/public/articles")).andExpect(jsonPath("$.data.length()").value(0));
  mvc.perform(get("/api/v1/admin/articles").with(auth)).andExpect(jsonPath("$.data[0].title").value("Đã sửa"));
  mvc.perform(delete("/api/v1/admin/articles/"+id).with(auth)).andExpect(status().isOk());
  mvc.perform(get(image)).andExpect(status().isNotFound());
 }
 @Test void validatesAndProtectsWrites() throws Exception {
  mvc.perform(post("/api/v1/admin/articles").with(jwt()).contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isForbidden());
  mvc.perform(post("/api/v1/admin/articles").with(jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"))).contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isUnprocessableEntity());
 }
}
