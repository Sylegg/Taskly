package com.taskly.catalogue;

import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/v1/community")
public class CommunitySocialController {
 private final JdbcTemplate db;
 public CommunitySocialController(JdbcTemplate db){this.db=db;}
 public record Comment(@NotBlank @Size(max=2000) String content){}
 public record Reaction(@Pattern(regexp="LIKE|REPOST") @NotNull String kind,boolean selected){}
 private void visible(UUID id){if(db.queryForObject("SELECT count(*) FROM community_articles WHERE id=? AND active=true",Integer.class,id)==0)throw new DomainException("ARTICLE_NOT_FOUND","Bài viết không tồn tại hoặc đã được ẩn.",HttpStatus.NOT_FOUND);}
 private void lock(UUID id){visible(id);db.queryForObject("SELECT id FROM community_articles WHERE id=? FOR UPDATE",UUID.class,id);visible(id);}
 private Map<String,Object> stats(UUID id,UUID user){return Map.of("likes",count(id,"LIKE"),"reposts",count(id,"REPOST"),"comments",db.queryForObject("SELECT count(*) FROM community_comments WHERE article_id=?",Integer.class,id),"liked",selected(id,user,"LIKE"),"reposted",selected(id,user,"REPOST"));}
 private int count(UUID id,String kind){return db.queryForObject("SELECT count(*) FROM community_reactions WHERE article_id=? AND kind=?",Integer.class,id,kind);}
 private boolean selected(UUID id,UUID user,String kind){return db.queryForObject("SELECT count(*) FROM community_reactions WHERE article_id=? AND user_id=? AND kind=?",Integer.class,id,user,kind)>0;}
 @GetMapping("/articles/{id}/engagement") public ApiResponse<Map<String,Object>> engagement(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){visible(id);return ApiResponse.success(stats(id,UUID.fromString(jwt.getSubject())));}
 @PutMapping("/articles/{id}/reaction") @Transactional public ApiResponse<Map<String,Object>> react(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Reaction body){lock(id);var user=UUID.fromString(jwt.getSubject());if(body.selected()&&!selected(id,user,body.kind()))db.update("INSERT INTO community_reactions(article_id,user_id,kind) VALUES(?,?,?)",id,user,body.kind());if(!body.selected())db.update("DELETE FROM community_reactions WHERE article_id=? AND user_id=? AND kind=?",id,user,body.kind());return ApiResponse.success(stats(id,user));}
 @GetMapping("/articles/{id}/comments") public ApiResponse<List<Map<String,Object>>> comments(@PathVariable UUID id){visible(id);return ApiResponse.success(db.query("SELECT c.*,u.full_name FROM community_comments c JOIN user_profiles u ON u.user_id=c.user_id WHERE c.article_id=? ORDER BY c.created_at,c.id",(r,n)->Map.<String,Object>of("id",r.getString("id"),"authorName",r.getString("full_name"),"content",r.getString("content"),"createdAt",r.getTimestamp("created_at").toInstant().toString()),id));}
 @PostMapping("/articles/{id}/comments") @Transactional public ApiResponse<Void> comment(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Comment body){lock(id);db.update("INSERT INTO community_comments(id,article_id,user_id,content) VALUES(?,?,?,?)",UUID.randomUUID(),id,UUID.fromString(jwt.getSubject()),body.content().trim());return ApiResponse.success(null);}
 @PostMapping("/articles") public ApiResponse<Void> submit(){throw new DomainException("COMMUNITY_ADMIN_ONLY","Chỉ Admin được đăng bài Cộng đồng.",HttpStatus.FORBIDDEN);}
}
