package com.taskly.catalogue;
import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.transaction.annotation.Transactional;

@RestController @RequestMapping("/api/v1")
public class CommunityArticleController {
 private final JdbcTemplate db; private final ServiceIconProcessor images;
 public CommunityArticleController(JdbcTemplate db, ServiceIconProcessor images){this.db=db;this.images=images;}
 public record Article(UUID id,String title,String summary,String content,String imageUrl,boolean active,Instant createdAt,String authorName,String hashtag,String groupName,boolean featured,boolean submittedByUser,long likes,long comments){}
 public record Write(@Size(max=160) String title,@Size(max=500) String summary,@Size(max=50000) String content,Boolean active,@Size(max=7000000) String imageDataUrl,@Size(max=100) String authorName,@Size(max=500) @Pattern(regexp="(?:[\\p{L}\\p{N}_]{1,60}( #[\\p{L}\\p{N}_]{1,60})*)?") String hashtag,@Size(max=100) String groupName,Boolean featured){}
 private List<Article> list(boolean published){return db.query("SELECT a.*,(SELECT count(*) FROM community_reactions r WHERE r.article_id=a.id AND r.kind='LIKE') AS likes,(SELECT count(*) FROM community_comments c WHERE c.article_id=a.id) AS comments FROM community_articles a "+(published?"WHERE active=true ":"")+"ORDER BY created_at DESC,id",(r,n)->new Article(r.getObject("id",UUID.class),r.getString("title"),r.getString("summary"),r.getString("content"),"/api/v1/public/article-images/"+r.getString("id")+"/"+r.getString("image_hash")+".png",r.getBoolean("active"),r.getTimestamp("created_at").toInstant(),r.getString("author_name"),r.getString("hashtag"),r.getString("group_name"),r.getBoolean("featured"),r.getObject("submitted_by")!=null,r.getLong("likes"),r.getLong("comments")));}
 @GetMapping("/public/articles") public ApiResponse<List<Article>> published(){return ApiResponse.success(list(true));}
 @GetMapping("/public/articles/{id}") public ApiResponse<Article> publishedArticle(@PathVariable UUID id){return ApiResponse.success(list(true).stream().filter(a->a.id().equals(id)).findFirst().orElseThrow(this::missing));}
 @GetMapping("/admin/articles") @PreAuthorize("hasAuthority('SERVICE_MANAGE')") public ApiResponse<List<Article>> admin(){return ApiResponse.success(list(false));}
 @GetMapping("/admin/articles/{id}/comments") @PreAuthorize("hasAuthority('SERVICE_MANAGE')")
 public ApiResponse<List<java.util.Map<String,Object>>> comments(@PathVariable UUID id){
  if(db.queryForObject("SELECT count(*) FROM community_articles WHERE id=?",Integer.class,id)==0)throw missing();
  return ApiResponse.success(db.query("SELECT c.id,c.content,c.created_at,COALESCE(p.full_name,'Khách hàng') AS author_name FROM community_comments c LEFT JOIN user_profiles p ON p.user_id=c.user_id WHERE c.article_id=? ORDER BY c.created_at DESC,c.id",(r,n)->java.util.Map.<String,Object>of("id",r.getString("id"),"content",r.getString("content"),"authorName",r.getString("author_name"),"createdAt",r.getTimestamp("created_at").toInstant().toString()),id));
 }
 @PostMapping("/admin/articles") @PreAuthorize("hasAuthority('SERVICE_MANAGE')") @Transactional
 public ApiResponse<Article> create(@Valid @RequestBody Write w){
  required(w.title(),"Tiêu đề"); required(w.content(),"Nội dung"); required(w.imageDataUrl(),"Ảnh bìa");
  var image=images.normalizeBanner(w.imageDataUrl()); var id=UUID.randomUUID();
  db.update("INSERT INTO community_articles(id,title,summary,content,image_data,image_hash,active) VALUES(?,?,?,?,?,?,?)",id,w.title().trim(),w.summary()==null?"":w.summary().trim(),w.content().trim(),image.pngBytes(),image.hash(),Boolean.TRUE.equals(w.active()));
  metadata(id,w,find(id));
  return ApiResponse.success(find(id));
 }
 @PatchMapping("/admin/articles/{id}") @PreAuthorize("hasAuthority('SERVICE_MANAGE')") @Transactional
 public ApiResponse<Article> update(@PathVariable UUID id,@Valid @RequestBody Write w){
  var current=find(id); var title=w.title()==null?current.title():w.title().trim();var content=w.content()==null?current.content():w.content().trim();required(title,"Tiêu đề");required(content,"Nội dung");
  db.update("UPDATE community_articles SET title=?,summary=?,content=?,active=?,updated_at=CURRENT_TIMESTAMP WHERE id=?",title,w.summary()==null?current.summary():w.summary().trim(),content,w.active()==null?current.active():w.active(),id);
  if(w.imageDataUrl()!=null){var image=images.normalizeBanner(w.imageDataUrl());db.update("UPDATE community_articles SET image_data=?,image_hash=? WHERE id=?",image.pngBytes(),image.hash(),id);}
  metadata(id,w,current);
  return ApiResponse.success(find(id));
 }
 @DeleteMapping("/admin/articles/{id}") @PreAuthorize("hasAuthority('SERVICE_MANAGE')") public ApiResponse<Void> delete(@PathVariable UUID id){if(db.update("DELETE FROM community_articles WHERE id=?",id)==0)throw missing();return ApiResponse.success(null);}
 private Article find(UUID id){return list(false).stream().filter(a->a.id().equals(id)).findFirst().orElseThrow(this::missing);}
 private void metadata(UUID id,Write w,Article current){
  String author=w.authorName()==null?current.authorName():w.authorName().trim();required(author,"Tên người đăng");
  db.update("UPDATE community_articles SET author_name=?,hashtag=?,group_name=?,featured=? WHERE id=?",author,w.hashtag()==null?current.hashtag():w.hashtag(),w.groupName()==null?current.groupName():w.groupName().trim(),w.featured()==null?current.featured():w.featured(),id);
 }
 private void required(String text,String label){if(text==null||text.isBlank())throw new DomainException("ARTICLE_REQUIRED",label+" không được để trống.",HttpStatus.UNPROCESSABLE_ENTITY);}
 private DomainException missing(){return new DomainException("ARTICLE_NOT_FOUND","Bài viết không tồn tại hoặc đã được ẩn.",HttpStatus.NOT_FOUND);}
 @GetMapping(value="/public/article-images/{id}/{hash}.png",produces=MediaType.IMAGE_PNG_VALUE)
 public ResponseEntity<byte[]> image(@PathVariable UUID id,@PathVariable String hash,org.springframework.security.core.Authentication auth){boolean staff=auth!=null&&auth.getAuthorities().stream().anyMatch(a->a.getAuthority().equals("SERVICE_MANAGE"));var bytes=db.query("SELECT image_data FROM community_articles WHERE id=? AND image_hash=?"+(staff?"":" AND active=true"),(r,n)->r.getBytes(1),id,hash);if(bytes.isEmpty())throw missing();return ResponseEntity.ok().contentType(MediaType.IMAGE_PNG).cacheControl(CacheControl.noStore()).header("X-Content-Type-Options","nosniff").body(bytes.getFirst());}
}
