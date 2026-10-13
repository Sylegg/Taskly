package com.taskly.booking;

import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import tools.jackson.databind.ObjectMapper;
import com.taskly.common.exception.DomainException;
import org.springframework.http.HttpStatus;

@Service
public class CategoryBookingSchemas {
 private final JdbcTemplate db; private final ObjectMapper json;
 public CategoryBookingSchemas(JdbcTemplate db,ObjectMapper json){this.db=db;this.json=json;}
 public List<BookingSchemas.Field> fields(UUID category){
  var saved=db.queryForList("SELECT fields FROM category_quantity_fields WHERE category_id=?",String.class,category);
  if(!saved.isEmpty())return json.readValue(saved.getFirst(),new tools.jackson.core.type.TypeReference<List<BookingSchemas.Field>>(){});
  var slugs=db.queryForList("SELECT slug FROM services WHERE category_id=? AND deleted_at IS NULL",String.class,category);
  var fields=new LinkedHashMap<String,BookingSchemas.Field>();
  for(var schema:BookingSchemas.ALL)if(schema.serviceSlugs().stream().anyMatch(slugs::contains))for(var field:schema.fields())if(field.type().equals("number")&&!Set.of("floor","budget").contains(field.key()))fields.putIfAbsent(field.key(),field);
  return List.copyOf(fields.values());
 }
 public List<BookingSchemas.Schema> all(){
  var result=new ArrayList<BookingSchemas.Schema>();
  for(var row:db.queryForList("SELECT id,slug,category_id FROM services WHERE deleted_at IS NULL")){
   String slug=(String)row.get("slug");UUID category=(UUID)row.get("category_id");
   var original=BookingSchemas.ALL.stream().filter(s->s.serviceSlugs().contains(slug)).findFirst();
   var numbers=fields(category);var fields=new ArrayList<BookingSchemas.Field>();
   fields.addAll(serviceFields((UUID)row.get("id")));
   for(var number:numbers)if(fields.stream().noneMatch(f->f.key().equals(number.key())))fields.add(number);
   int version=db.queryForList("SELECT version FROM category_quantity_fields WHERE category_id=?",Integer.class,category).stream().findFirst().orElse(0)+1;
   version+=1000*db.queryForList("SELECT version FROM service_booking_fields WHERE service_id=?",Integer.class,row.get("id")).stream().findFirst().orElse(0);
   result.add(new BookingSchemas.Schema(original.map(BookingSchemas.Schema::key).orElse("category-"+category),version,List.of(slug),fields));
  }
  return result;
 }
 public List<BookingSchemas.Field> serviceFields(UUID service){
  var saved=db.queryForList("SELECT fields FROM service_booking_fields WHERE service_id=?",String.class,service);
  if(!saved.isEmpty())return json.readValue(saved.getFirst(),new tools.jackson.core.type.TypeReference<List<BookingSchemas.Field>>(){});
  var slugs=db.queryForList("SELECT slug FROM services WHERE id=?",String.class,service);
  if(slugs.isEmpty())return List.of();
  return BookingSchemas.ALL.stream().filter(s->s.serviceSlugs().contains(slugs.getFirst())).findFirst().map(s->s.fields().stream().filter(f->!f.type().equals("number")).toList()).orElse(List.of());
 }
 public BookingSchemas.Schema require(String key,int version,String slug){return all().stream().filter(s->s.key().equals(key)&&s.version()==version&&s.serviceSlugs().contains(slug)).findFirst().orElseThrow(()->new DomainException("INVALID_BOOKING_DETAILS","Biểu mẫu đã thay đổi. Vui lòng tải lại dịch vụ.",HttpStatus.UNPROCESSABLE_ENTITY));}
}
