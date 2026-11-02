package com.taskly.booking;

import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import tools.jackson.databind.ObjectMapper;

@RestController
public class BookingDraftController {
    private final JdbcTemplate db;
    private final ObjectMapper json;
    private final CategoryBookingSchemas schemas; public BookingDraftController(JdbcTemplate db, ObjectMapper json, CategoryBookingSchemas schemas) { this.db = db; this.json = json; this.schemas=schemas; }
    public record Draft(@NotNull UUID serviceId, @NotBlank String schemaKey,
        @Min(1) int schemaVersion, @NotNull @Size(max=20) Map<String,Object> details,
        @Size(max=36) String addressId, Instant scheduledAt, @Min(1) @Max(8) int duration,
        @Size(max=4000) String description, @Size(max=2000) String notes) {}
    @GetMapping("/api/v1/users/me/booking-capacity")
    @PreAuthorize("hasRole('CUSTOMER')")
    public ApiResponse<Map<String,Object>> capacity(@AuthenticationPrincipal Jwt jwt) {
        int count=activeOrders(user(jwt));
        return ApiResponse.success(Map.of("activeOrders",count,"limit",3,"canCreate",count<3));
    }
    private int activeOrders(UUID owner) {
        return db.queryForObject("SELECT COUNT(*) FROM tasks WHERE customer_id=? AND status IN ('POSTED','MATCHING','ACCEPTED','TASKER_ON_THE_WAY','ARRIVED','IN_PROGRESS','DISPUTED')",Integer.class,owner);
    }
    private void requireCapacity(UUID owner) {
        if(activeOrders(owner)>=3)throw new DomainException("ORDER_LIMIT","Bạn đang có 3 đơn dịch vụ. Vui lòng chờ một đơn hoàn thành hoặc hủy trước khi chọn dịch vụ và tạo đơn mới.",HttpStatus.CONFLICT);
    }
    @GetMapping("/api/v1/public/booking-schemas")
    public ApiResponse<List<BookingSchemas.Schema>> schemas() { return ApiResponse.success(schemas.all()); }
    @GetMapping("/api/v1/users/me/booking-draft")
    @PreAuthorize("hasRole('CUSTOMER')")
    public ApiResponse<Draft> get(@AuthenticationPrincipal Jwt jwt) {
        var values = db.query("SELECT payload FROM customer_booking_drafts WHERE customer_id = ?",
            (rs, row) -> json.readValue(rs.getString(1), Draft.class), user(jwt));
        return ApiResponse.success(values.isEmpty() ? null : values.getFirst());
    }
    @PutMapping("/api/v1/users/me/booking-draft")
    @PreAuthorize("hasRole('CUSTOMER')")
    @Transactional
    public ApiResponse<Void> save(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody Draft draft) {
        UUID owner = user(jwt);
        db.queryForObject("SELECT id FROM users WHERE id = ? FOR UPDATE", UUID.class, owner);
        requireCapacity(owner);
        var slugs = db.query("SELECT s.slug FROM services s JOIN service_categories c ON c.id = s.category_id WHERE s.id = ? AND s.active = TRUE AND s.deleted_at IS NULL AND c.active = TRUE AND c.deleted_at IS NULL AND s.currency = 'VND'",
            (rs, row) -> rs.getString(1), draft.serviceId());
        if (slugs.isEmpty()) throw new DomainException("SERVICE_UNAVAILABLE", "Dịch vụ hiện không khả dụng.", HttpStatus.UNPROCESSABLE_ENTITY);
        BookingSchemas.validatePartial(schemas.require(draft.schemaKey(), draft.schemaVersion(), slugs.getFirst()), draft.details());
        if (draft.addressId() != null && !draft.addressId().isBlank()) {
            UUID address;
            try { address = UUID.fromString(draft.addressId()); }
            catch (IllegalArgumentException e) { throw new DomainException("INVALID_ADDRESS", "Địa chỉ không hợp lệ.", HttpStatus.UNPROCESSABLE_ENTITY); }
            if (db.queryForObject("SELECT count(*) FROM addresses WHERE id = ? AND user_id = ? AND deleted_at IS NULL", Integer.class, address, owner) == 0)
                throw new DomainException("ADDRESS_NOT_FOUND", "Không tìm thấy địa chỉ của bạn.", HttpStatus.NOT_FOUND);
        }
        String payload = json.writeValueAsString(draft);
        if (db.update("UPDATE customer_booking_drafts SET payload = ?, updated_at = CURRENT_TIMESTAMP WHERE customer_id = ?", payload, owner) == 0)
            db.update("INSERT INTO customer_booking_drafts(customer_id, payload) VALUES (?,?)", owner, payload);
        return ApiResponse.success(null);
    }
    @DeleteMapping("/api/v1/users/me/booking-draft")
    @PreAuthorize("hasRole('CUSTOMER')")
    public ApiResponse<Void> delete(@AuthenticationPrincipal Jwt jwt) {
        db.update("DELETE FROM customer_booking_drafts WHERE customer_id = ?", user(jwt));
        return ApiResponse.success(null);
    }
    public record Pending(String id, Draft draft) {}
    @GetMapping("/api/v1/users/me/pending-bookings")
    @PreAuthorize("hasRole('CUSTOMER')")
    public ApiResponse<List<Pending>> pending(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(db.query("SELECT id,payload FROM customer_pending_bookings WHERE customer_id=? ORDER BY updated_at DESC",
            (rs,n)->new Pending(rs.getString(1),json.readValue(rs.getString(2),Draft.class)),user(jwt)));
    }
    @PutMapping("/api/v1/users/me/pending-bookings/{id}")
    @PreAuthorize("hasRole('CUSTOMER')")
    @Transactional
    public ApiResponse<Void> savePending(@AuthenticationPrincipal Jwt jwt,@PathVariable String id,@Valid @RequestBody Draft draft) {
        UUID owner=user(jwt);
        if(id.length()>64) throw new DomainException("INVALID_ID","Đơn không hợp lệ.",HttpStatus.BAD_REQUEST);
        db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,owner);
        requireCapacity(owner);
        int existing=db.queryForObject("SELECT count(*) FROM customer_pending_bookings WHERE id=? AND customer_id=?",Integer.class,id,owner);
        if(existing==0 && db.queryForObject("SELECT count(*) FROM customer_pending_bookings WHERE customer_id=?",Integer.class,owner)>=3)
            throw new DomainException("BOOKING_LIMIT","Bạn đã có 3 đơn chưa hoàn thành. Vui lòng sửa đơn đang có.",HttpStatus.CONFLICT);
        if(existing==0 && db.queryForObject("SELECT count(*) FROM customer_pending_bookings WHERE id=?",Integer.class,id)>0)
            throw new DomainException("NOT_FOUND","Không tìm thấy đơn.",HttpStatus.NOT_FOUND);
        save(jwt,draft);
        String payload=json.writeValueAsString(draft);
        if(existing>0) db.update("UPDATE customer_pending_bookings SET payload=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND customer_id=?",payload,id,owner);
        else db.update("INSERT INTO customer_pending_bookings(id,customer_id,payload) VALUES (?,?,?)",id,owner,payload);
        return ApiResponse.success(null);
    }
    @DeleteMapping("/api/v1/users/me/pending-bookings/{id}")
    @PreAuthorize("hasRole('CUSTOMER')")
    public ApiResponse<Void> deletePending(@AuthenticationPrincipal Jwt jwt,@PathVariable String id) {
        db.update("DELETE FROM customer_pending_bookings WHERE id=? AND customer_id=?",id,user(jwt));
        return ApiResponse.success(null);
    }
    private UUID user(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }
}
