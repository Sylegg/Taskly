package com.taskly.catalogue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;
@ActiveProfiles("test") @SpringBootTest @AutoConfigureMockMvc @Transactional
class CommunityVideoIntegrationTest {
 @Autowired MockMvc mvc;
 @Autowired org.springframework.jdbc.core.JdbcTemplate db;
 @Test void acceptsLongVideoUpTo100MbAndRejectsOversize() throws Exception {
  byte[] bytes=new byte[100];var buffer=java.nio.ByteBuffer.wrap(bytes);buffer.putInt(0,16);bytes[4]='f';bytes[5]='t';bytes[6]='y';bytes[7]='p';buffer.putInt(16,84);bytes[20]='m';bytes[21]='o';bytes[22]='o';bytes[23]='v';buffer.putInt(24,76);bytes[28]='m';bytes[29]='v';bytes[30]='h';bytes[31]='d';buffer.putInt(44,1000);buffer.putInt(48,3600000);
  var admin=jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
  var limitFile=new MockMultipartFile("video","long.mp4","video/mp4",bytes){@Override public long getSize(){return 100L*1024*1024;}};
  mvc.perform(multipart("/api/v1/admin/community-videos").file(limitFile).param("caption","Video dài").param("hashtag","#hello").with(admin)).andExpect(status().isOk());
  var oversizeFile=new MockMultipartFile("video","large.mp4","video/mp4",bytes){@Override public long getSize(){return 100L*1024*1024+1;}};
  mvc.perform(multipart("/api/v1/admin/community-videos").file(oversizeFile).param("caption","Quá dung lượng").param("hashtag","#hello").with(admin)).andExpect(status().isBadRequest());
 }
 @Test void adminUploadsAndHidesVideoWithRangePlayback() throws Exception {
  byte[] bytes=new byte[100];var buffer=java.nio.ByteBuffer.wrap(bytes);buffer.putInt(0,16);bytes[4]='f';bytes[5]='t';bytes[6]='y';bytes[7]='p';buffer.putInt(16,84);bytes[20]='m';bytes[21]='o';bytes[22]='o';bytes[23]='v';buffer.putInt(24,76);bytes[28]='m';bytes[29]='v';bytes[30]='h';bytes[31]='d';buffer.putInt(44,1000);buffer.putInt(48,15000);
  var file=new MockMultipartFile("video","test.mp4","video/mp4",bytes);
  var admin=jwt().authorities(new SimpleGrantedAuthority("SERVICE_MANAGE"));
  mvc.perform(multipart("/api/v1/admin/community-videos").file(file).param("caption","Video thử nghiệm").param("hashtag","#TaskLyNews #hello").with(jwt())).andExpect(status().isForbidden());
  mvc.perform(multipart("/api/v1/admin/community-videos").file(file).param("caption","Video thử nghiệm").param("hashtag","#TaskLyNews #hello").with(admin)).andExpect(status().isOk());
  var result=mvc.perform(get("/api/v1/public/community-videos")).andExpect(jsonPath("$.data[0].caption").value("Video thử nghiệm")).andReturn();
  var item=new ObjectMapper().readTree(result.getResponse().getContentAsString()).get("data").get(0);
  var id=item.get("id").asText();var url=item.get("videoUrl").asText();
  var user=java.util.UUID.randomUUID();db.update("INSERT INTO users(id,email,password_hash,status,created_at,updated_at) VALUES(?,?,?,'ACTIVE',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",user,user+"@example.test","not-a-password");
  var customer=jwt().jwt(j->j.subject(user.toString()));
  for(int i=0;i<2;i++)mvc.perform(put("/api/v1/community/videos/"+id+"/likes").with(customer).contentType("application/json").content("{\"liked\":true}")).andExpect(status().isOk()).andExpect(jsonPath("$.data.likes").value(1));
  mvc.perform(get("/api/v1/community/videos/"+id+"/likes").with(customer)).andExpect(jsonPath("$.data.liked").value(true));
  for(int i=0;i<2;i++)mvc.perform(post("/api/v1/community/videos/"+id+"/view").with(customer)).andExpect(status().isOk());
  mvc.perform(get("/api/v1/admin/community-videos").with(admin)).andExpect(jsonPath("$.data[0].views").value(1)).andExpect(jsonPath("$.data[0].likes").value(1));
  mvc.perform(put("/api/v1/community/videos/"+id+"/likes").with(customer).contentType("application/json").content("{\"liked\":false}")).andExpect(jsonPath("$.data.likes").value(0));
  mvc.perform(get(url)).andExpect(status().isOk()).andExpect(content().bytes(bytes));
  mvc.perform(get(url).header("Range","bytes=0-9")).andExpect(status().isPartialContent()).andExpect(header().string("Content-Range","bytes 0-9/100"))
   .andExpect(header().string("Content-Length","10")).andExpect(content().bytes(java.util.Arrays.copyOfRange(bytes,0,10)));
  mvc.perform(get(url).header("Range","bytes=90-")).andExpect(status().isPartialContent()).andExpect(content().bytes(java.util.Arrays.copyOfRange(bytes,90,100)));
  mvc.perform(get(url).header("Range","bytes=-10")).andExpect(status().isPartialContent()).andExpect(content().bytes(java.util.Arrays.copyOfRange(bytes,90,100)));
  mvc.perform(get(url).header("Range","bytes=100-110")).andExpect(status().isRequestedRangeNotSatisfiable()).andExpect(header().string("Content-Range","bytes */100"));
  mvc.perform(get(url).header("Range","invalid")).andExpect(status().isRequestedRangeNotSatisfiable());
  mvc.perform(patch("/api/v1/admin/community-videos/"+id).with(admin).contentType("application/json").content("{\"active\":false}")).andExpect(status().isOk());
  mvc.perform(get(url)).andExpect(status().isNotFound());
  mvc.perform(get(url).header("Range","bytes=0-9")).andExpect(status().isNotFound());
  mvc.perform(get("/api/v1/public/community-videos")).andExpect(jsonPath("$.data.length()").value(0));
  mvc.perform(delete("/api/v1/admin/community-videos/"+id).with(admin)).andExpect(status().isOk());
 }
}
