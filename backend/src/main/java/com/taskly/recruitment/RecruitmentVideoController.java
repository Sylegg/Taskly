package com.taskly.recruitment;

import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import java.util.*;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.transaction.annotation.Transactional;

@RestController @RequestMapping("/api/v1")
public class RecruitmentVideoController {
 private final JdbcTemplate db;
 private final RecruitmentTrainingService training;
 public RecruitmentVideoController(JdbcTemplate db,RecruitmentTrainingService training){this.db=db;this.training=training;}
 public static String videoUrl(UUID id){return "/api/v1/partner/training/videos/"+id;}
 @PostMapping(value="/admin/recruitment/training-videos",consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
 @PreAuthorize("hasAuthority('RECRUITMENT_TRAINING')") @Transactional
 public ApiResponse<Map<String,Object>> upload(@AuthenticationPrincipal Jwt jwt,@RequestParam MultipartFile video) throws java.io.IOException {
  if(video.isEmpty()||video.getSize()>100L*1024*1024||!"video/mp4".equals(video.getContentType()))throw RecruitmentService.invalid("Chọn video MP4 tối đa 100 MB.");
  var data=video.getBytes();
  if(data.length<12||data[4]!='f'||data[5]!='t'||data[6]!='y'||data[7]!='p')throw RecruitmentService.invalid("Tệp không đúng định dạng MP4.");
  var id=UUID.randomUUID();var actor=UUID.fromString(jwt.getSubject());
  db.update("INSERT INTO partner_training_videos(id,uploaded_by,video_data) VALUES(?,?,?)",id,actor,data);
  db.update("INSERT INTO recruitment_audit(id,actor_id,action,reason,created_at) VALUES(?,?,'TRAINING_VIDEO_UPLOADED',?,CURRENT_TIMESTAMP)",UUID.randomUUID(),actor,"Video Academy "+id);
  return ApiResponse.success(Map.of("id",id,"videoUrl",videoUrl(id),"sizeBytes",data.length));
 }
 @GetMapping("/admin/recruitment/training-videos/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_TRAINING')")
 public ResponseEntity<ByteArrayResource> adminVideo(@PathVariable UUID id,@RequestHeader(value="Range",required=false) String range){return stream(id,range);}
 @GetMapping("/partner/training/videos/{id}")
 public ResponseEntity<ByteArrayResource> partnerVideo(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@RequestHeader(value="Range",required=false) String range){
  boolean visible=training.progress(UUID.fromString(jwt.getSubject())).stream().anyMatch(p->p.lesson().videoUrl().equals(videoUrl(id))&&!p.status().equals("LOCKED"));
  if(!visible)throw missing();
  return stream(id,range);
 }
 private ResponseEntity<ByteArrayResource> stream(UUID id,String range){
  var sizes=db.queryForList("SELECT OCTET_LENGTH(video_data) FROM partner_training_videos WHERE id=?",Long.class,id);
  if(sizes.isEmpty())throw missing();
  long size=sizes.getFirst(),start=0,end=size-1;boolean partial=range!=null;
  if(partial){try{
   var ranges=HttpRange.parseRanges(range);if(ranges.size()!=1)throw new IllegalArgumentException();
   start=ranges.getFirst().getRangeStart(size);end=ranges.getFirst().getRangeEnd(size);
   if(start<0||start>=size||end<start)throw new IllegalArgumentException();
  }catch(IllegalArgumentException e){return ResponseEntity.status(416).header("Content-Range","bytes */"+size).build();}}
  var bytes=db.queryForObject("SELECT SUBSTRING(video_data,?,?) FROM partner_training_videos WHERE id=?",byte[].class,Math.toIntExact(start+1),Math.toIntExact(end-start+1),id);
  var response=ResponseEntity.status(partial?206:200).contentType(MediaType.valueOf("video/mp4"))
    .header("Accept-Ranges","bytes").header("X-Content-Type-Options","nosniff").cacheControl(CacheControl.noStore()).contentLength(bytes.length);
  if(partial)response.header("Content-Range","bytes "+start+"-"+end+"/"+size);
  return response.body(new ByteArrayResource(bytes));
 }
 private DomainException missing(){return new DomainException("TRAINING_VIDEO_NOT_FOUND","Video chưa được mở học hoặc đã được ẩn.",HttpStatus.NOT_FOUND);}
}
