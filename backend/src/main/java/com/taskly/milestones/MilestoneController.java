package com.taskly.milestones;
import java.util.*;
import com.taskly.common.api.ApiResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

@RestController
@RequestMapping("/api/v1")
public class MilestoneController {
 private final JdbcTemplate db; private final ObjectMapper json;
 public MilestoneController(JdbcTemplate db,ObjectMapper json){this.db=db;this.json=json;}
 private List<Map<String,Object>> list(boolean active){
  List<Map<String,Object>> rows=db.query("SELECT payload FROM partner_daily_milestones",(rs,n)->json.readValue(rs.getString(1),Map.class));
  rows.removeIf(m->active && !Boolean.TRUE.equals(m.get("active")));
  rows.sort(Comparator.comparingInt(m->((Number)m.get("display_order")).intValue()));return rows;
 }
 @GetMapping("/public/partner-milestones") public ApiResponse<?> published(){return ApiResponse.success(list(true));}
 @GetMapping("/admin/partner-milestones") @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')") public ApiResponse<?> all(){return ApiResponse.success(list(false));}
 private void save(Map<String,Object> m){
  if(!(m.get("min_orders") instanceof Number n) || n.intValue()<1 || n.doubleValue()!=n.intValue() || !(m.get("bonus_amount") instanceof Number b) || b.longValue()<1 || b.doubleValue()!=b.longValue()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid milestone threshold or bonus");
  if(!(m.get("display_order") instanceof Number order) || order.intValue()<1) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid display order");
  for(String key:List.of("orders","bonus","icon","badge","perk","color","bgColor","borderColor")){
   if(!(m.get(key) instanceof String text) || text.length()>2000) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid milestone field: "+key);
  }
  for(String key:List.of("color","bgColor","borderColor")) if(!m.get(key).toString().matches("#[0-9a-fA-F]{6}")) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid color");
  if(!(m.get("active") instanceof Boolean)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid publication status");
  m.put("updated_at",java.time.Instant.now().toString());
  String payload=json.writeValueAsString(m);
  if(db.update("UPDATE partner_daily_milestones SET payload=? WHERE id=?",payload,m.get("id"))==0) db.update("INSERT INTO partner_daily_milestones(id,payload) VALUES (?,?)",m.get("id"),payload);
 }
 @PostMapping("/admin/partner-milestones") @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')") @Transactional
 public ApiResponse<?> create(@RequestBody Map<String,Object> body){body.put("id",UUID.randomUUID().toString());save(body);return ApiResponse.success(list(false));}
 @RequestMapping(value="/admin/partner-milestones",method={RequestMethod.PUT,RequestMethod.PATCH}) @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')") @Transactional
 public ApiResponse<?> update(@RequestBody Map<String,Object> body){
  var existing=list(false).stream().filter(m->Objects.equals(m.get("id"),body.get("id"))).findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));existing.putAll(body);save(existing);return ApiResponse.success(list(false));
 }
 @DeleteMapping("/admin/partner-milestones") @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')") @Transactional
 public ApiResponse<?> delete(@RequestParam String id){if(db.update("DELETE FROM partner_daily_milestones WHERE id=?",id)==0)throw new ResponseStatusException(HttpStatus.NOT_FOUND);return ApiResponse.success(list(false));}
}
