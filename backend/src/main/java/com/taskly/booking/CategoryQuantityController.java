package com.taskly.booking;
import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.jdbc.core.JdbcTemplate;
import tools.jackson.databind.ObjectMapper;
import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import org.springframework.http.HttpStatus;
@RestController @RequestMapping("/api/v1/admin/service-categories/{id}/quantity-fields") @PreAuthorize("hasAuthority('SERVICE_MANAGE')")
public class CategoryQuantityController {
 private final JdbcTemplate db;private final ObjectMapper json;private final CategoryBookingSchemas schemas;
 public CategoryQuantityController(JdbcTemplate db,ObjectMapper json,CategoryBookingSchemas schemas){this.db=db;this.json=json;this.schemas=schemas;}
 public record Field(@NotBlank @Pattern(regexp="[a-zA-Z][a-zA-Z0-9_]{0,79}") String key,@NotBlank @Size(max=120) String label,@Min(0) @Max(100000000) int minimum){}
 public record Write(@NotNull @Size(max=10) List<@Valid Field> fields){}
 @GetMapping public ApiResponse<?> get(@PathVariable UUID id){return ApiResponse.success(schemas.fields(id));}
 @PutMapping @Transactional public ApiResponse<?> save(@PathVariable UUID id,@Valid @RequestBody Write body){
  if(db.queryForList("SELECT id FROM service_categories WHERE id=? AND deleted_at IS NULL FOR UPDATE",UUID.class,id).isEmpty())throw new DomainException("CATEGORY_NOT_FOUND","Không tìm thấy danh mục.",HttpStatus.NOT_FOUND);
  var keys=new HashSet<String>();for(var f:body.fields())if(!keys.add(f.key())||Set.of("floor","budget").contains(f.key()))throw new DomainException("INVALID_QUANTITY_FIELDS","Mã trường trùng hoặc dành cho thông tin khác.",HttpStatus.UNPROCESSABLE_ENTITY);
  var fields=body.fields().stream().map(f->new BookingSchemas.Field(f.key(),f.label().trim(),"number",true,f.minimum(),List.of())).toList();
  if(db.update("UPDATE category_quantity_fields SET fields=?,version=version+1,updated_at=CURRENT_TIMESTAMP WHERE category_id=?",json.writeValueAsString(fields),id)==0)db.update("INSERT INTO category_quantity_fields(category_id,fields) VALUES(?,?)",id,json.writeValueAsString(fields));
  for(var schema:schemas.all())for(var field:fields)if(schema.serviceSlugs().stream().anyMatch(slug->db.queryForObject("SELECT COUNT(*) FROM services WHERE slug=? AND category_id=?",Integer.class,slug,id)>0)&&schema.fields().stream().anyMatch(f->!f.type().equals("number")&&f.key().equals(field.key())))throw new DomainException("INVALID_QUANTITY_FIELDS","Mã trường trùng với thông tin trong biểu mẫu.",HttpStatus.UNPROCESSABLE_ENTITY);
  var services=db.queryForList("SELECT id FROM services WHERE category_id=?",UUID.class,id);
  for(var service:services){var validKeys=new HashSet<>(keys);schemas.serviceFields(service).stream().filter(f->f.type().equals("number")).forEach(f->validKeys.add(f.key()));for(var rule:db.queryForList("SELECT quantity_field FROM service_pricing_rules WHERE service_id=? AND mode='FIELD'",service))if(!validKeys.contains(rule.get("quantity_field")))db.update("UPDATE service_pricing_rules SET enabled=false,version=version+1,updated_at=CURRENT_TIMESTAMP WHERE service_id=? AND mode='FIELD'",service);}
  return ApiResponse.success(fields);
 }
}
