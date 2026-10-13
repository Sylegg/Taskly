package com.taskly.booking;

import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.time.Clock;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import tools.jackson.databind.ObjectMapper;

/** All amounts and quote lifetimes must be configured by authorized Admins. */
@RestController
public class CustomerPricingController {
    private final JdbcTemplate db;
    private final Clock clock;
    private final ObjectMapper json;
    private final CategoryBookingSchemas schemas; public CustomerPricingController(JdbcTemplate db, Clock clock, ObjectMapper json, CategoryBookingSchemas schemas) { this.db=db; this.clock=clock; this.json=json; this.schemas=schemas; }
    public record Rule(@NotBlank @Pattern(regexp="FIXED|HOURLY|FIELD") String mode,
        @Size(max=80) String quantityField, @Min(0) @Max(1000000000) long baseAmount,
        @Min(0) @Max(1000000000) long unitAmount, @Min(0) @Max(1000000000) long platformFeeAmount,
        @Min(1) @Max(60) int quoteTtlMinutes, boolean enabled, @DecimalMin("0") @DecimalMax("100") @Digits(integer=3,fraction=2) java.math.BigDecimal platformFeePercent) {}
    public record QuoteLine(UUID serviceId, String serviceName, String mode, long quantity,
        String quantityLabel, long baseAmount, long unitAmount, long subtotal, long platformFee,
        java.math.BigDecimal platformFeePercent, long total, long ruleVersion) {}
    public record Quote(UUID id, long subtotal, long platformFee, long total, String currency,
        long ruleVersion, Instant expiresAt, List<QuoteLine> items) {}
    @GetMapping("/api/v1/users/me/booking-quotes/{id}")
    @PreAuthorize("hasRole('CUSTOMER')")
    @Transactional
    public ApiResponse<Quote> quote(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {return ApiResponse.success(validateQuote(UUID.fromString(jwt.getSubject()),id));}
    public Quote validateQuote(UUID owner,UUID id) {
        var quotes = db.query("SELECT * FROM customer_price_quotes WHERE id=? AND customer_id=?",
            (rs,n) -> new Quote(rs.getObject("id", UUID.class), rs.getLong("subtotal"), rs.getLong("platform_fee"), rs.getLong("total"), rs.getString("currency"), rs.getLong("rule_version"), rs.getTimestamp("expires_at").toInstant(), json.readValue(rs.getString("line_items"), new tools.jackson.core.type.TypeReference<List<QuoteLine>>(){})),
            id, owner);
        if (quotes.isEmpty()) throw failure("QUOTE_NOT_FOUND", "Không tìm thấy báo giá.", HttpStatus.NOT_FOUND);
        var quote = quotes.getFirst();
        var payload=db.queryForObject("SELECT draft_payload FROM customer_price_quotes WHERE id=? AND customer_id=?",String.class,id,owner);
        var draft=json.readValue(payload,BookingDraftController.Draft.class);
        var cities=db.queryForList("SELECT city FROM addresses WHERE id=? AND user_id=? AND deleted_at IS NULL",String.class,UUID.fromString(draft.addressId()),owner);
        com.taskly.recruitment.RecruitmentService.requireOpenCity(db,cities.isEmpty()?null:cities.getFirst());
        if (!quote.expiresAt().isAfter(clock.instant())) throw failure("QUOTE_EXPIRED", "Báo giá đã hết hạn. Vui lòng lấy giá mới.", HttpStatus.CONFLICT);
        if (db.queryForObject("SELECT count(*) FROM customer_price_quotes q JOIN service_pricing_rules r ON r.service_id=q.service_id JOIN services s ON s.id=q.service_id JOIN service_categories c ON c.id=s.category_id WHERE q.id=? AND r.enabled=TRUE AND s.active=TRUE AND c.active=TRUE AND s.deleted_at IS NULL AND c.deleted_at IS NULL", Integer.class, id) == 0)
            throw failure("QUOTE_CHANGED", "Bảng giá đã thay đổi. Vui lòng lấy giá mới.", HttpStatus.CONFLICT);
        for (var item : quote.items()) {
            if (db.queryForObject("SELECT count(*) FROM service_pricing_rules r JOIN services s ON s.id=r.service_id JOIN service_categories c ON c.id=s.category_id WHERE s.id=? AND r.enabled=TRUE AND s.active=TRUE AND c.active=TRUE AND s.deleted_at IS NULL AND c.deleted_at IS NULL", Integer.class, item.serviceId()) == 0)
                throw failure("QUOTE_CHANGED", "Bảng giá đã thay đổi. Vui lòng lấy giá mới.", HttpStatus.CONFLICT);
        }
        return quote;
    }
    @GetMapping("/api/v1/admin/services/{serviceId}/pricing")
    @PreAuthorize("hasAuthority('SERVICE_MANAGE')")
    public ApiResponse<Map<String,Object>> rule(@PathVariable UUID serviceId) {
        var rules = db.queryForList("SELECT mode, quantity_field AS \"quantityField\", base_amount AS \"baseAmount\", unit_amount AS \"unitAmount\", platform_fee_amount AS \"platformFeeAmount\", quote_ttl_minutes AS \"quoteTtlMinutes\", platform_fee_percent AS \"platformFeePercent\", enabled, version FROM service_pricing_rules WHERE service_id = ?", serviceId);
        return ApiResponse.success(rules.isEmpty() ? null : rules.getFirst());
    }
    @PutMapping("/api/v1/admin/services/{serviceId}/pricing")
    @PreAuthorize("hasAuthority('SERVICE_MANAGE')")
    @Transactional
    @org.springframework.cache.annotation.CacheEvict(cacheNames={"publicCatalogue","publicService"},allEntries=true)
    public ApiResponse<Void> rule(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID serviceId, @Valid @RequestBody Rule rule) {
        var slugs = db.query("SELECT slug FROM services WHERE id = ? AND deleted_at IS NULL FOR UPDATE", (rs,n)->rs.getString(1), serviceId);
        if (slugs.isEmpty()) throw failure("SERVICE_NOT_FOUND", "Không tìm thấy dịch vụ.", HttpStatus.NOT_FOUND);
        if (rule.mode().equals("FIELD")) {
            var schema = schemas.all().stream().filter(s -> s.serviceSlugs().contains(slugs.getFirst())).findFirst()
                .orElseThrow(() -> failure("INVALID_PRICE_RULE", "Dịch vụ chưa có biểu mẫu.", HttpStatus.UNPROCESSABLE_ENTITY));
            UUID category=db.queryForObject("SELECT category_id FROM services WHERE id=?",UUID.class,serviceId);
            if (schema.fields().stream().noneMatch(f -> f.type().equals("number") && f.key().equals(rule.quantityField())))
                throw failure("INVALID_PRICE_RULE", "Chọn trường số lượng hợp lệ của dịch vụ.", HttpStatus.UNPROCESSABLE_ENTITY);
        } else if (rule.quantityField() != null && !rule.quantityField().isBlank()) {
            throw failure("INVALID_PRICE_RULE", "Chỉ giá theo số lượng được chọn trường số lượng.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        if (rule.mode().equals("FIXED") && rule.unitAmount() != 0)
            throw failure("INVALID_PRICE_RULE", "Giá cố định không có đơn giá số lượng.", HttpStatus.UNPROCESSABLE_ENTITY);
        if (rule.baseAmount() == 0 && rule.unitAmount() == 0 && rule.platformFeeAmount() == 0 && rule.enabled())
            throw failure("INVALID_PRICE_RULE", "Cần cấu hình giá trước khi bật báo giá.", HttpStatus.UNPROCESSABLE_ENTITY);
        UUID actor = UUID.fromString(jwt.getSubject());
        if (db.update("UPDATE service_pricing_rules SET mode=?, quantity_field=?, base_amount=?, unit_amount=?, platform_fee_amount=?, platform_fee_percent=?, quote_ttl_minutes=?, enabled=?, version=version+1, updated_by=?, updated_at=CURRENT_TIMESTAMP WHERE service_id=?",
            rule.mode(), rule.quantityField(), rule.baseAmount(), rule.unitAmount(), rule.platformFeeAmount(), rule.platformFeePercent(), rule.quoteTtlMinutes(), rule.enabled(), actor, serviceId) == 0)
            db.update("INSERT INTO service_pricing_rules(service_id,mode,quantity_field,base_amount,unit_amount,platform_fee_amount,platform_fee_percent,quote_ttl_minutes,enabled,updated_by) VALUES (?,?,?,?,?,?,?,?,?,?)",
                serviceId, rule.mode(), rule.quantityField(), rule.baseAmount(), rule.unitAmount(), rule.platformFeeAmount(), rule.platformFeePercent(), rule.quoteTtlMinutes(), rule.enabled(), actor);
        return ApiResponse.success(null);
    }
    @PostMapping("/api/v1/users/me/booking-quotes")
    @PreAuthorize("hasRole('CUSTOMER')")
    @Transactional
    public ApiResponse<Quote> quote(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody BookingDraftController.Draft draft) {
        UUID owner = UUID.fromString(jwt.getSubject());
        db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE", UUID.class, owner);
        UUID bookingId=null;
        if(draft.details().containsKey("quoteSessionId")) {
            try { bookingId=UUID.fromString(draft.details().get("quoteSessionId").toString()); }
            catch(RuntimeException e) { throw failure("INVALID_BOOKING", "Mã phiên đặt dịch vụ không hợp lệ.", HttpStatus.UNPROCESSABLE_ENTITY); }
        }
        var slugs = db.query("SELECT s.slug FROM services s JOIN service_categories c ON c.id=s.category_id WHERE s.id=? AND s.active=TRUE AND c.active=TRUE AND s.deleted_at IS NULL AND c.deleted_at IS NULL AND s.currency='VND'",
            (rs,n)->rs.getString(1), draft.serviceId());
        if (slugs.isEmpty()) throw failure("SERVICE_UNAVAILABLE", "Dịch vụ hiện không khả dụng.", HttpStatus.UNPROCESSABLE_ENTITY);
        var schema = schemas.require(draft.schemaKey(), draft.schemaVersion(), slugs.getFirst());
        BookingSchemas.validatePartial(schema, draft.details());
        for (var field : schema.fields()) if (field.required() && (draft.details().get(field.key()) == null || draft.details().get(field.key()).toString().isBlank()))
            throw failure("INCOMPLETE_BOOKING", "Vui lòng nhập " + field.label() + ".", HttpStatus.UNPROCESSABLE_ENTITY);
        Instant now = clock.instant();
        if (draft.scheduledAt() == null || !draft.scheduledAt().isAfter(now))
            throw failure("INVALID_SCHEDULE", "Chọn thời gian trong tương lai.", HttpStatus.UNPROCESSABLE_ENTITY);
        UUID address;
        try { address = UUID.fromString(draft.addressId()); }
        catch (IllegalArgumentException | NullPointerException e) { throw failure("INVALID_ADDRESS", "Chọn địa chỉ của bạn.", HttpStatus.UNPROCESSABLE_ENTITY); }
        if (db.queryForObject("SELECT count(*) FROM addresses WHERE id=? AND user_id=? AND deleted_at IS NULL", Integer.class, address, owner) == 0)
            throw failure("ADDRESS_NOT_FOUND", "Không tìm thấy địa chỉ của bạn.", HttpStatus.NOT_FOUND);
        com.taskly.recruitment.RecruitmentService.requireOpenCity(db,db.queryForObject("SELECT city FROM addresses WHERE id=? AND user_id=? AND deleted_at IS NULL",String.class,address,owner));
        var ids = new java.util.LinkedHashSet<UUID>();
        ids.add(draft.serviceId());
        if (draft.details().containsKey("selectedServiceIds")) {
            if (!(draft.details().get("selectedServiceIds") instanceof List<?> selected) || selected.isEmpty() || selected.size()>3)
                throw failure("INVALID_SERVICES", "Chọn từ 1 đến 3 dịch vụ.", HttpStatus.UNPROCESSABLE_ENTITY);
            try { for (var value : selected) ids.add(UUID.fromString(value.toString())); }
            catch (IllegalArgumentException e) { throw failure("INVALID_SERVICES", "Dịch vụ không hợp lệ.", HttpStatus.UNPROCESSABLE_ENTITY); }
        }
        if (ids.size()>3) throw failure("INVALID_SERVICES", "Chỉ được chọn tối đa 3 dịch vụ.", HttpStatus.UNPROCESSABLE_ENTITY);
        var items = new java.util.ArrayList<QuoteLine>();
        long subtotal=0, fee=0, total=0;
        Instant expires=now.plusSeconds(3600);
        for (var id : ids.stream().sorted().toList()) {
            var serviceRows=db.queryForList("SELECT s.slug,s.name FROM services s JOIN service_categories c ON c.id=s.category_id WHERE s.id=? AND s.active=TRUE AND c.active=TRUE AND s.deleted_at IS NULL AND c.deleted_at IS NULL AND s.currency='VND'",id);
            if(serviceRows.isEmpty())throw failure("SERVICE_UNAVAILABLE","Một dịch vụ đã chọn không còn khả dụng.",HttpStatus.UNPROCESSABLE_ENTITY);
            var service=serviceRows.getFirst();String name=service.get("name").toString();
            var itemSchema=id.equals(draft.serviceId()) ? schema : schemas.all().stream().filter(x->x.serviceSlugs().contains(service.get("slug").toString())).findFirst().orElseThrow(()->failure("INVALID_BOOKING_DETAILS",name+": chưa có biểu mẫu.",HttpStatus.UNPROCESSABLE_ENTITY));
            var values=new java.util.LinkedHashMap<String,Object>();
            String prefix=id.equals(draft.serviceId()) ? "" : id+"_";
            for(var field:itemSchema.fields()) {
                Object value=draft.details().get(prefix+field.key());
                if(value!=null)values.put(field.key(),value);
                if(field.required()&&(value==null||value.toString().isBlank()))throw failure("INCOMPLETE_BOOKING",name+": vui lòng nhập "+field.label()+".",HttpStatus.UNPROCESSABLE_ENTITY);
            }
            BookingSchemas.validatePartial(itemSchema,values);
            if(db.queryForObject("SELECT count(*) FROM service_pricing_rules WHERE service_id=? AND enabled=TRUE",Integer.class,id)==0)
                throw failure("PRICING_UNAVAILABLE",name+": chưa có bảng giá. Vui lòng liên hệ hỗ trợ.",HttpStatus.UNPROCESSABLE_ENTITY);
            List<Map<String,Object>> rules=bookingId==null?List.of():db.query("SELECT rule_payload FROM booking_price_snapshots WHERE customer_id=? AND booking_id=? AND service_id=?",(r,n)->json.readValue(r.getString(1),new tools.jackson.core.type.TypeReference<Map<String,Object>>(){}),owner,bookingId,id);
            if(rules.isEmpty()) {
                rules=db.queryForList("SELECT * FROM service_pricing_rules WHERE service_id=? AND enabled=TRUE FOR UPDATE",id);
                if(!rules.isEmpty()&&bookingId!=null) {
                    var saved=new java.util.LinkedHashMap<String,Object>();
                    for(var key:List.of("mode","quantity_field","base_amount","unit_amount","platform_fee_amount","platform_fee_percent","quote_ttl_minutes","version"))saved.put(key,rules.getFirst().get(key));
                    db.update("INSERT INTO booking_price_snapshots(customer_id,booking_id,service_id,rule_payload) VALUES(?,?,?,?)",owner,bookingId,id,json.writeValueAsString(saved));
                }
            }
            if(rules.isEmpty())throw failure("PRICING_UNAVAILABLE",name+": chưa có bảng giá. Vui lòng liên hệ hỗ trợ.",HttpStatus.UNPROCESSABLE_ENTITY);
            var rule=rules.getFirst();String mode=rule.get("mode").toString();String label="";long quantity=0;
            if(mode.equals("HOURLY")){quantity=draft.duration();label="giờ";}
            if(mode.equals("FIELD")) {
                String key=rule.get("quantity_field").toString();
                var field=itemSchema.fields().stream().filter(f->f.type().equals("number")&&f.key().equals(key)).findFirst().orElseThrow(()->failure("PRICING_UNAVAILABLE",name+": cần cấu hình lại trường số lượng.",HttpStatus.UNPROCESSABLE_ENTITY));
                if(values.get(key)==null||values.get(key).toString().isBlank())throw failure("INCOMPLETE_BOOKING",name+": vui lòng nhập "+field.label()+".",HttpStatus.UNPROCESSABLE_ENTITY);
                try { quantity=Long.parseLong(values.get(key).toString()); }
                catch(NumberFormatException e){throw failure("INCOMPLETE_BOOKING",name+": số lượng không hợp lệ.",HttpStatus.UNPROCESSABLE_ENTITY);}
                label=field.label();
            }
            long base=((Number)rule.get("base_amount")).longValue(), unit=((Number)rule.get("unit_amount")).longValue();
            java.math.BigDecimal percent=rule.get("platform_fee_percent")==null?null:new java.math.BigDecimal(rule.get("platform_fee_percent").toString());
            try {
                long amount=Math.addExact(base,Math.multiplyExact(quantity,unit));
                long itemFee=percent==null?((Number)rule.get("platform_fee_amount")).longValue():java.math.BigDecimal.valueOf(amount).multiply(percent).divide(java.math.BigDecimal.valueOf(100),0,java.math.RoundingMode.HALF_UP).longValueExact();
                if(itemFee>amount)throw failure("INVALID_PLATFORM_FEE","Phí sàn không được vượt tiền dịch vụ.",HttpStatus.UNPROCESSABLE_ENTITY);
                long itemTotal=amount;
                items.add(new QuoteLine(id,name,mode,quantity,label,base,unit,amount,itemFee,percent,itemTotal,((Number)rule.get("version")).longValue()));
                subtotal=Math.addExact(subtotal,amount);fee=Math.addExact(fee,itemFee);total=Math.addExact(total,itemTotal);
            } catch(ArithmeticException e){throw failure("PRICE_LIMIT","Yêu cầu vượt giới hạn báo giá.",HttpStatus.UNPROCESSABLE_ENTITY);}
            var itemExpiry=now.plusSeconds(((Number)rule.get("quote_ttl_minutes")).longValue()*60);
            if(itemExpiry.isBefore(expires))expires=itemExpiry;
        }
        if(total<=0||total>1000000000L)throw failure("PRICE_LIMIT","Yêu cầu vượt giới hạn báo giá.",HttpStatus.UNPROCESSABLE_ENTITY);
        // Display services in the same order the customer selected them.
        items.sort(java.util.Comparator.comparingInt(item->new java.util.ArrayList<>(ids).indexOf(item.serviceId())));
        long primaryVersion=items.stream().filter(item->item.serviceId().equals(draft.serviceId())).findFirst().orElseThrow().ruleVersion();
        var quote=new Quote(UUID.randomUUID(),subtotal,fee,total,"VND",primaryVersion,expires,List.copyOf(items));
        db.update("INSERT INTO customer_price_quotes(id,customer_id,service_id,rule_version,draft_payload,subtotal,platform_fee,total,currency,expires_at,line_items) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            quote.id(),owner,draft.serviceId(),quote.ruleVersion(),json.writeValueAsString(draft),subtotal,fee,total,"VND",java.sql.Timestamp.from(expires),json.writeValueAsString(items));
        return ApiResponse.success(quote);
    }
    private DomainException failure(String code, String message, HttpStatus status) { return new DomainException(code,message,status); }
}
