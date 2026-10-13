package com.taskly.catalogue;
import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import java.util.*;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;

@RestController @RequestMapping("/api/v1")
public class CommunityVideoController {
 private final JdbcTemplate db;
 public CommunityVideoController(JdbcTemplate db){this.db=db;}
 private List<Map<String,Object>> list(boolean published){return db.query("SELECT v.id,v.caption,v.hashtag,v.active,v.created_at,(SELECT count(*) FROM community_video_likes l WHERE l.video_id=v.id) AS likes,(SELECT count(*) FROM community_video_views w WHERE w.video_id=v.id) AS views FROM community_videos v "+(published?"WHERE v.active=true ":"")+"ORDER BY v.created_at DESC,v.id",(r,n)->Map.of("id",r.getString("id"),"caption",r.getString("caption"),"hashtag",r.getString("hashtag"),"active",r.getBoolean("active"),"createdAt",r.getTimestamp("created_at").toInstant().toString(),"videoUrl","/api/v1/public/community-videos/"+r.getString("id")+"/video.mp4","likes",r.getLong("likes"),"views",r.getLong("views")));}
 @GetMapping("/public/community-videos") public ApiResponse<List<Map<String,Object>>> published(){return ApiResponse.success(list(true));}
 @GetMapping("/admin/community-videos") @PreAuthorize("hasAuthority('SERVICE_MANAGE')") public ApiResponse<List<Map<String,Object>>> admin(){return ApiResponse.success(list(false));}
 @PostMapping(value="/admin/community-videos",consumes=MediaType.MULTIPART_FORM_DATA_VALUE) @PreAuthorize("hasAuthority('SERVICE_MANAGE')")
 public ApiResponse<Void> create(@RequestParam String caption,@RequestParam String hashtag,@RequestParam MultipartFile video) throws java.io.IOException {
  if(caption.isBlank()||caption.length()>2000||hashtag.length()>500||!hashtag.matches("#[\\p{L}\\p{N}_]{1,60}( #[\\p{L}\\p{N}_]{1,60})*"))throw new DomainException("VIDEO_FIELDS","Nhập nội dung và hashtag hợp lệ.",HttpStatus.BAD_REQUEST);
  if(video.isEmpty()||video.getSize()>100L*1024*1024||!"video/mp4".equals(video.getContentType()))throw new DomainException("VIDEO_FORMAT","Chọn video MP4 tối đa 100 MB.",HttpStatus.BAD_REQUEST);
  byte[] data=video.getBytes();if(data.length<12||data[4]!='f'||data[5]!='t'||data[6]!='y'||data[7]!='p')throw new DomainException("VIDEO_FORMAT","Tệp không đúng định dạng MP4.",HttpStatus.BAD_REQUEST);
  db.update("INSERT INTO community_videos(id,caption,hashtag,video_data) VALUES(?,?,?,?)",UUID.randomUUID(),caption.trim(),hashtag,data);return ApiResponse.success(null);
 }
 @PatchMapping("/admin/community-videos/{id}") @PreAuthorize("hasAuthority('SERVICE_MANAGE')") public ApiResponse<Void> visibility(@PathVariable UUID id,@RequestBody Map<String,Boolean> body){if(body.get("active")==null)throw new DomainException("VIDEO_FIELDS","Thiếu trạng thái hiển thị.",HttpStatus.BAD_REQUEST);if(db.update("UPDATE community_videos SET active=? WHERE id=?",body.get("active"),id)==0)throw missing();return ApiResponse.success(null);}
 @DeleteMapping("/admin/community-videos/{id}") @PreAuthorize("hasAuthority('SERVICE_MANAGE')") public ApiResponse<Void> delete(@PathVariable UUID id){if(db.update("DELETE FROM community_videos WHERE id=?",id)==0)throw missing();return ApiResponse.success(null);}
 @GetMapping("/public/community-videos/{id}/video.mp4")
 public ResponseEntity<ByteArrayResource> video(@PathVariable UUID id,
   @RequestHeader(value="Range",required=false) String rangeHeader,
   org.springframework.security.core.Authentication auth) {
  boolean staff=auth!=null&&auth.getAuthorities().stream().anyMatch(a->a.getAuthority().equals("SERVICE_MANAGE"));
  String visibility=staff?"":" AND active=true";
  var sizes=db.queryForList("SELECT OCTET_LENGTH(video_data) FROM community_videos WHERE id=?"+visibility,Long.class,id);
  if(sizes.isEmpty())throw missing();
  long size=sizes.getFirst(),start=0,end=size-1;
  boolean partial=false;
  if(rangeHeader!=null) {
   try {
    var ranges=HttpRange.parseRanges(rangeHeader);
    // Slice single ranges here; Spring handles multipart ranges on the full resource.
    if(ranges.size()==1) {
     start=ranges.getFirst().getRangeStart(size);end=ranges.getFirst().getRangeEnd(size);
     if(start<0||start>=size||end<start)throw new IllegalArgumentException("Invalid range");
     partial=true;
    }
   } catch(IllegalArgumentException e) {
    return ResponseEntity.status(HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
     .header("Content-Range","bytes */"+size).cacheControl(CacheControl.noStore()).build();
   }
  }
  // Slice in the database so seeking does not transfer the whole MP4 into the JVM.
  var data=db.query("SELECT SUBSTRING(video_data,?,?) FROM community_videos WHERE id=?"+visibility,
   (r,n)->r.getBytes(1),Math.toIntExact(start+1),Math.toIntExact(end-start+1),id);
  if(data.isEmpty())throw missing();
  var response=ResponseEntity.status(partial?HttpStatus.PARTIAL_CONTENT:HttpStatus.OK)
   .contentType(MediaType.valueOf("video/mp4")).cacheControl(CacheControl.noStore())
   .header("Accept-Ranges","bytes").header("X-Content-Type-Options","nosniff")
   .contentLength(data.getFirst().length);
  if(partial)response.header("Content-Range","bytes "+start+"-"+end+"/"+size);
  return response.body(new ByteArrayResource(data.getFirst()));
 }
 private DomainException missing(){return new DomainException("VIDEO_NOT_FOUND","Video không tồn tại hoặc đã ẩn.",HttpStatus.NOT_FOUND);}
 private void visible(UUID id){if(db.queryForObject("SELECT count(*) FROM community_videos WHERE id=? AND active=true",Integer.class,id)==0)throw missing();}
 @PostMapping("/community/videos/{id}/view") @Transactional public ApiResponse<Void> view(@PathVariable UUID id,@AuthenticationPrincipal Jwt jwt){visible(id);db.queryForObject("SELECT id FROM community_videos WHERE id=? FOR UPDATE",UUID.class,id);visible(id);var user=UUID.fromString(jwt.getSubject());if(db.queryForObject("SELECT count(*) FROM community_video_views WHERE video_id=? AND user_id=?",Integer.class,id,user)==0)db.update("INSERT INTO community_video_views(video_id,user_id) VALUES(?,?)",id,user);return ApiResponse.success(null);}
 private Map<String,Object> likes(UUID id,UUID user){return Map.of("likes",db.queryForObject("SELECT count(*) FROM community_video_likes WHERE video_id=?",Integer.class,id),"liked",db.queryForObject("SELECT count(*) FROM community_video_likes WHERE video_id=? AND user_id=?",Integer.class,id,user)>0);}
 @GetMapping("/community/videos/{id}/likes") public ApiResponse<Map<String,Object>> likes(@PathVariable UUID id,@AuthenticationPrincipal Jwt jwt){visible(id);return ApiResponse.success(likes(id,UUID.fromString(jwt.getSubject())));}
 @PutMapping("/community/videos/{id}/likes") @Transactional public ApiResponse<Map<String,Object>> like(@PathVariable UUID id,@AuthenticationPrincipal Jwt jwt,@RequestBody Map<String,Boolean> body){visible(id);db.queryForObject("SELECT id FROM community_videos WHERE id=? FOR UPDATE",UUID.class,id);visible(id);var user=UUID.fromString(jwt.getSubject());if(body.get("liked")==null)throw new DomainException("LIKE_INVALID","Thiếu trạng thái thích.",HttpStatus.BAD_REQUEST);db.update("DELETE FROM community_video_likes WHERE video_id=? AND user_id=?",id,user);if(body.get("liked"))db.update("INSERT INTO community_video_likes(video_id,user_id) VALUES(?,?)",id,user);return ApiResponse.success(likes(id,user));}
}
