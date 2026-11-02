package com.taskly.catalogue;
import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
@RestController
@RequestMapping("/api/v1")
public class HomeBannerController {
 private final JdbcTemplate db;
 private final ServiceIconProcessor images;
 public HomeBannerController(JdbcTemplate db,ServiceIconProcessor images){this.db=db;this.images=images;}
 public record Banner(UUID id,String title,String imageUrl,boolean active,int displayOrder){}
 public record Write(@Size(max=160) String title,Boolean active,Integer displayOrder,@Size(max=7000000) String imageDataUrl){}
 private List<Banner> list(boolean published){return db.query("SELECT id,title,image_hash,active,display_order FROM home_banners "+(published?"WHERE active=true ":"")+"ORDER BY created_at,insertion_order",(r,n)->new Banner(r.getObject("id",UUID.class),r.getString("title"),"/api/v1/public/banner-images/"+r.getString("id")+"/"+r.getString("image_hash")+".png",r.getBoolean("active"),r.getInt("display_order")));}
 @GetMapping("/public/banners") public ApiResponse<List<Banner>> published(){return ApiResponse.success(list(true));}
 @GetMapping("/admin/banners") @PreAuthorize("hasAuthority('SERVICE_MANAGE')") public ApiResponse<List<Banner>> admin(){return ApiResponse.success(list(false));}
 @PostMapping("/admin/banners") @PreAuthorize("hasAuthority('SERVICE_MANAGE')")
 public ApiResponse<Banner> create(@Valid @RequestBody Write w){
  if(w.imageDataUrl()==null||w.imageDataUrl().isBlank())throw new DomainException("BANNER_IMAGE_REQUIRED","Vui lòng tải ảnh banner.",HttpStatus.UNPROCESSABLE_ENTITY);
  var image=images.normalizeBanner(w.imageDataUrl());var id=UUID.randomUUID();
  db.update("INSERT INTO home_banners(id,title,image_data,image_hash,active,display_order) VALUES(?,?,?,?,?,?)",id,"Banner",image.pngBytes(),image.hash(),w.active()==null || w.active(),0);return ApiResponse.success(find(id));
 }
 @PatchMapping("/admin/banners/{id}") @PreAuthorize("hasAuthority('SERVICE_MANAGE')")
 public ApiResponse<Banner> update(@PathVariable UUID id,@Valid @RequestBody Write w){
  var current=find(id);boolean active=w.active()==null?current.active():w.active();
  if(w.imageDataUrl()!=null){var image=images.normalizeBanner(w.imageDataUrl());db.update("UPDATE home_banners SET active=?,image_data=?,image_hash=? WHERE id=?",active,image.pngBytes(),image.hash(),id);}
  else db.update("UPDATE home_banners SET active=? WHERE id=?",active,id);
  return ApiResponse.success(find(id));
 }
 @DeleteMapping("/admin/banners/{id}") @PreAuthorize("hasAuthority('SERVICE_MANAGE')") public ApiResponse<Void> delete(@PathVariable UUID id){if(db.update("DELETE FROM home_banners WHERE id=?",id)==0)throw missing();return ApiResponse.success(null);}
 private Banner find(UUID id){return list(false).stream().filter(b->b.id().equals(id)).findFirst().orElseThrow(this::missing);}
 private DomainException missing(){return new DomainException("BANNER_NOT_FOUND","Không tìm thấy banner.",HttpStatus.NOT_FOUND);}
 @GetMapping(value="/public/banner-images/{id}/{hash}.png",produces=MediaType.IMAGE_PNG_VALUE)
 public ResponseEntity<byte[]> image(@PathVariable UUID id,@PathVariable String hash){
  var bytes=db.query("SELECT image_data FROM home_banners WHERE id=? AND image_hash=?",(r,n)->r.getBytes(1),id,hash);if(bytes.isEmpty())throw missing();
  return ResponseEntity.ok().contentType(MediaType.IMAGE_PNG).cacheControl(CacheControl.maxAge(Duration.ofMinutes(5)).cachePublic()).header("X-Content-Type-Options","nosniff").body(bytes.getFirst());
 }
}
