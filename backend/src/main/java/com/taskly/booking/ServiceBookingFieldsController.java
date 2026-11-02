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
@RestController @RequestMapping("/api/v1/admin/services/{id}/booking-fields") @PreAuthorize("hasAuthority('SERVICE_MANAGE')")
public class ServiceBookingFieldsController {
 private final JdbcTemplate db;private final ObjectMapper json;private final CategoryBookingSchemas schemas;
 public ServiceBookingFieldsController(JdbcTemplate db,ObjectMapper json,CategoryBookingSchemas schemas){this.db=db;this.json=json;this.schemas=schemas;}
 public record Field(@NotBlank @Pattern(regexp="[a-zA-Z][a-zA-Z0-9_]{0,79}") String key,@NotBlank @Size(max=120) String label,@NotBlank @Pattern(regexp="text|number|choice") String type,boolean required,@NotNull @Size(max=20) List<@NotBlank @Size(max=120) String> options){}
 @GetMapping public ApiResponse<?> get(@PathVariable UUID id){return ApiResponse.success(schemas.serviceFields(id));}
 @PutMapping @Transactional public ApiResponse<?> save(@PathVariable UUID id,@Valid @RequestBody @Size(max=10) List<@Valid Field> body){
  var categories=db.queryForList("SELECT category_id FROM services WHERE id=? AND deleted_at IS NULL FOR UPDATE",UUID.class,id);
  if(categories.isEmpty())throw new DomainException("SERVICE_NOT_FOUND","Không tìm thấy dịch vụ.",HttpStatus.NOT_FOUND);
  var keys=new HashSet<String>();schemas.fields(categories.getFirst()).forEach(f->keys.add(f.key()));
  for(var field:body)if(!keys.add(field.key())||(field.type().equals("choice")&&(field.options().isEmpty()||new HashSet<>(field.options()).size()!=field.options().size())))throw new DomainException("INVALID_BOOKING_FIELDS","Mã trường trùng hoặc danh sách lựa chọn không hợp lệ.",HttpStatus.UNPROCESSABLE_ENTITY);
  var fields=body.stream().map(f->new BookingSchemas.Field(f.key(),f.label().trim(),f.type(),f.required(),f.type().equals("number")?1:null,f.type().equals("choice")?f.options():List.of())).toList();
  if(db.update("UPDATE service_booking_fields SET fields=?,version=version+1 WHERE service_id=?",json.writeValueAsString(fields),id)==0)db.update("INSERT INTO service_booking_fields(service_id,fields) VALUES(?,?)",id,json.writeValueAsString(fields));
  var numericKeys=new HashSet<String>();schemas.fields(categories.getFirst()).forEach(f->numericKeys.add(f.key()));fields.stream().filter(f->f.type().equals("number")).forEach(f->numericKeys.add(f.key()));
  for(var rule:db.queryForList("SELECT quantity_field FROM service_pricing_rules WHERE service_id=? AND mode='FIELD'",id))if(!numericKeys.contains(rule.get("quantity_field")))db.update("UPDATE service_pricing_rules SET enabled=false,version=version+1,updated_at=CURRENT_TIMESTAMP WHERE service_id=? AND mode='FIELD'",id);
  return ApiResponse.success(fields);
 }
}
