package com.taskly.task;

import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import java.util.UUID;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import com.taskly.recruitment.PartnerSchedulingService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

@RestController
@RequestMapping("/api/v1/admin/tasks")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
public class AdminTaskController {
    private final JdbcTemplate db;
    private final tools.jackson.databind.ObjectMapper json;
    private final com.taskly.booking.CategoryBookingSchemas schemas;
    private final PartnerSchedulingService schedulingService;
    private final com.taskly.booking.BookingCheckout checkout;

    public AdminTaskController(JdbcTemplate db, tools.jackson.databind.ObjectMapper json, com.taskly.booking.CategoryBookingSchemas schemas, PartnerSchedulingService schedulingService, com.taskly.booking.BookingCheckout checkout) {
        this.db = db;
        this.json = json;
        this.schemas = schemas;
        this.schedulingService = schedulingService;
        this.checkout = checkout;
    }

    public record CancelRequest(@jakarta.validation.constraints.NotBlank @jakarta.validation.constraints.Size(max=1000) String reason) {}

    @PostMapping("/{id}/cancel")
    public ApiResponse<Map<String,Object>> cancel(@PathVariable UUID id,@Valid @RequestBody CancelRequest request) {
        checkout.adminCancel(id,request.reason().trim());
        return ApiResponse.success(db.queryForMap("SELECT id,status FROM tasks WHERE id=?",id));
    }

    @GetMapping
    public ApiResponse<List<Map<String, Object>>> list() {
        var tasks = new java.util.ArrayList<Map<String,Object>>(db.queryForList("""
            SELECT t.id, t.title, t.description, t.status,
              t.service_name_snapshot AS service, t.customer_id, t.tasker_id,
              COALESCE(c.full_name, '') AS customer, COALESCE(p.full_name, '') AS partner,
              t.address_line_snapshot AS address, t.city_snapshot AS city,
              t.scheduled_at, t.estimated_duration_minutes AS duration_minutes, t.customer_notes AS notes,
              t.latitude, t.longitude, t.budget_amount AS total, t.currency, t.created_at, t.updated_at,
              t.verified_actual_end_at, t.original_scheduled_start_at, t.original_scheduled_end_at,
              t.approved_start_at, t.expected_end_at, t.accepted_at, t.checked_in_at, t.actual_started_at,
              t.early_start_request_id
            FROM tasks t
            LEFT JOIN user_profiles c ON c.user_id=t.customer_id
            LEFT JOIN user_profiles p ON p.user_id=t.tasker_id
            ORDER BY t.created_at DESC, t.id
            """));
        for(var task:tasks) {
            var earnings=db.queryForMap("SELECT "+PartnerEarnings.FEE_SQL+" AS fee,(t.budget_amount-"+PartnerEarnings.FEE_SQL+") AS net FROM tasks t LEFT JOIN service_pricing_rules r ON r.service_id=t.service_id WHERE t.id=?",task.get("id"));
            task.put("platform_fee",earnings.get("fee"));task.put("partner_net_amount",earnings.get("net"));
            var payments=db.queryForList("SELECT p.method,p.status,p.draft_payload,q.line_items FROM task_booking_payments p JOIN customer_price_quotes q ON q.id=p.quote_id WHERE p.task_id=?",task.get("id"));
            if(!payments.isEmpty()) {
                var payment=payments.getFirst();var draft=json.readValue(payment.get("draft_payload").toString(),com.taskly.booking.BookingDraftController.Draft.class);
                task.put("booking_details",draft.details());task.put("description",draft.description());task.put("payment_method",payment.get("method"));task.put("payment_status",payment.get("status"));
                task.put("selected_services",json.readValue(payment.get("line_items").toString(),Object.class));
            }
            var earlyReqs = db.queryForList("SELECT id, requested_start_at, proposed_end_at, reason, status, requested_at, expires_at FROM early_start_requests WHERE task_id=? ORDER BY requested_at DESC LIMIT 1", task.get("id"));
            if (!earlyReqs.isEmpty()) {
                task.put("early_start_request", earlyReqs.getFirst());
            }
        }
        for(var row:db.queryForList("SELECT b.id,b.customer_id,b.payload,b.updated_at,COALESCE(p.full_name,'') AS customer FROM customer_pending_bookings b LEFT JOIN user_profiles p ON p.user_id=b.customer_id ORDER BY b.updated_at DESC")) {
            var draft=json.readValue(row.get("payload").toString(),com.taskly.booking.BookingDraftController.Draft.class);
            var services=db.queryForList("SELECT name FROM services WHERE id=?",String.class,draft.serviceId());
            var task=new java.util.LinkedHashMap<String,Object>();
            task.put("id",row.get("id"));task.put("customer_id",row.get("customer_id"));task.put("customer",row.get("customer"));
            task.put("service",services.isEmpty()?"Dịch vụ đã lưu":services.getFirst());task.put("title",task.get("service"));
            task.put("description",draft.description());task.put("status","INCOMPLETE");task.put("pending_booking",true);
            task.put("partner","");task.put("scheduled_at",draft.scheduledAt());task.put("currency","VND");task.put("total",null);
            task.put("created_at",row.get("updated_at"));task.put("updated_at",row.get("updated_at"));task.put("details",draft.details());task.put("notes",draft.notes());
            var addresses=draft.addressId()==null || draft.addressId().isBlank()?List.<Map<String,Object>>of():db.queryForList("SELECT label,address_line,city,ward,district,recipient_name,recipient_phone,building_type,building_description,notes,latitude,longitude,is_default FROM addresses WHERE id=? AND user_id=?",UUID.fromString(draft.addressId()),row.get("customer_id"));
            task.put("address",addresses.isEmpty()?"":addresses.getFirst().get("address_line"));task.put("city",addresses.isEmpty()?"":addresses.getFirst().get("city"));
            task.put("address_details",addresses.isEmpty()?null:addresses.getFirst());
            task.put("duration_minutes",draft.duration()*60);
            var selections=new java.util.ArrayList<Map<String,Object>>();
            var selectedIds=draft.details().get("selectedServiceIds") instanceof List<?> ids?ids:List.of(draft.serviceId().toString());
            var allSchemas=schemas.all();
            for(var selectedId:selectedIds) {
                UUID serviceId;
                try {serviceId=UUID.fromString(selectedId.toString());} catch(IllegalArgumentException e) {continue;}
                var serviceRows=db.queryForList("SELECT name,slug FROM services WHERE id=?",serviceId);
                if(serviceRows.isEmpty())continue;
                var selection=new java.util.LinkedHashMap<String,Object>();selection.put("name",serviceRows.getFirst().get("name"));
                String prefix=serviceId.equals(draft.serviceId())?"":serviceId+"_";
                var fields=new java.util.ArrayList<Map<String,Object>>();
                var schema=allSchemas.stream().filter(sc->sc.serviceSlugs().contains(serviceRows.getFirst().get("slug"))).findFirst();
                if(schema.isPresent())for(var field:schema.get().fields()) {
                    var value=draft.details().get(prefix+field.key());
                    if(value!=null) fields.add(Map.of("label",field.label(),"value",value));
                }
                selection.put("fields",fields);
                selection.put("description",draft.details().getOrDefault("service_desc_"+serviceId,serviceId.equals(draft.serviceId())?draft.description()==null?"":draft.description():""));
                selections.add(selection);
            }
            task.put("selected_services",selections);
            var quotes=db.queryForList("SELECT subtotal,platform_fee,total,currency,expires_at FROM customer_price_quotes WHERE customer_id=? AND draft_payload=? ORDER BY expires_at DESC LIMIT 1",row.get("customer_id"),row.get("payload"));
            task.put("quote",quotes.isEmpty()?null:quotes.getFirst());
            if(!quotes.isEmpty())task.put("total",quotes.getFirst().get("total"));
            tasks.add(task);
        }
        tasks.sort(java.util.Comparator.comparing((Map<String,Object> t)->t.get("updated_at").toString()).reversed());
        return ApiResponse.success(tasks);
    }

    @GetMapping("/{id}/messages")
    public ApiResponse<List<Map<String, Object>>> messages(@PathVariable UUID id) {
        if (db.queryForObject("SELECT COUNT(*) FROM tasks WHERE id=?", Integer.class, id) == 0)
            throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        return ApiResponse.success(db.queryForList("""
            SELECT m.id, m.content AS text, m.image_data, m.created_at AS at,
              COALESCE(NULLIF(p.full_name, ''), 'Người dùng') AS sender_name,
              COALESCE(m.sender_portal, CASE WHEN t.customer_id <> t.tasker_id
                THEN CASE WHEN m.sender_id=t.customer_id THEN 'CUSTOMER' ELSE 'PARTNER' END
                ELSE 'UNKNOWN' END) AS sender_portal
            FROM task_messages m JOIN tasks t ON t.id=m.task_id
            LEFT JOIN user_profiles p ON p.user_id=m.sender_id
            WHERE m.task_id=? ORDER BY m.created_at, m.id
            """, id));
    }

    @GetMapping("/{id}/history")
    public ApiResponse<List<Map<String, Object>>> history(@PathVariable UUID id) {
        if (db.queryForObject("SELECT COUNT(*) FROM tasks WHERE id=?", Integer.class, id) == 0)
            throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        return ApiResponse.success(db.queryForList("""
            SELECT h.to_status AS status, h.occurred_at AS at, h.reason,
              COALESCE(NULLIF(p.full_name, ''), h.actor_role) AS actor
            FROM task_status_history h LEFT JOIN user_profiles p ON p.user_id=h.actor_id
            WHERE h.task_id=? ORDER BY h.occurred_at, h.id
            """, id));
    }

    public record AssignPartnerRequest(@NotNull UUID partnerId, boolean override, String auditReason) {}
    public record RescheduleRequest(@NotNull Instant scheduledAt, Integer durationMinutes, String reason) {}
    public record VerifyCompletionRequest(Instant verifiedActualEndAt, String note) {}

    private Instant toInstant(Object value) {
        if (value instanceof Instant i) return i;
        if (value instanceof Timestamp t) return t.toInstant();
        if (value instanceof OffsetDateTime o) return o.toInstant();
        throw new IllegalArgumentException("Unknown timestamp type: " + value);
    }

    @PostMapping("/{id}/assign")
    @org.springframework.transaction.annotation.Transactional
    public ApiResponse<Map<String, Object>> assign(@PathVariable UUID id, @Valid @RequestBody AssignPartnerRequest req) {
        PartnerWorkPolicy.lock(db,req.partnerId());
        var rows = db.queryForList("SELECT id, status, tasker_id, service_id, city_snapshot, scheduled_at, estimated_duration_minutes, latitude, longitude FROM tasks WHERE id=? FOR UPDATE", id);
        if (rows.isEmpty()) throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        var task = rows.getFirst();
        if (!java.util.Set.of("POSTED", "MATCHING", "ACCEPTED").contains(task.get("status")))
            throw new DomainException("TASK_NOT_ASSIGNABLE", "Chỉ điều phối đơn đang tìm hoặc đã nhận Partner, chưa bắt đầu di chuyển.", HttpStatus.CONFLICT);
        var appRows = db.queryForList("SELECT id, status FROM partner_applications WHERE user_id=? FOR UPDATE", req.partnerId());
        if (appRows.isEmpty() || !"ACTIVE".equals(appRows.getFirst().get("status"))) {
            throw new DomainException("PARTNER_NOT_ACTIVE", "Chỉ có thể gán việc cho Đối tác có trạng thái ACTIVE.", HttpStatus.BAD_REQUEST);
        }
        UUID applicationId = (UUID) appRows.getFirst().get("id");
        boolean skill = db.queryForObject("SELECT COUNT(*) FROM partner_application_services WHERE application_id=? AND service_id=?", Integer.class, applicationId, task.get("service_id")) > 0;
        boolean area = db.queryForObject("""
            SELECT COUNT(*) FROM recruitment_areas r JOIN partner_application_areas pa ON pa.area_id=r.id
            WHERE pa.application_id=? AND (
              r.city=?
              OR LOWER(TRIM(r.city))=LOWER(TRIM(?))
              OR (LOWER(r.city) LIKE '%hồ chí minh%' AND LOWER(?) LIKE '%hồ chí minh%')
              OR (LOWER(r.city) LIKE '%hà nội%' AND LOWER(?) LIKE '%hà nội%')
              OR (LOWER(r.city) LIKE '%đà nẵng%' AND LOWER(?) LIKE '%đà nẵng%')
            )
            """, Integer.class, applicationId, task.get("city_snapshot"), task.get("city_snapshot"), task.get("city_snapshot"), task.get("city_snapshot"), task.get("city_snapshot")) > 0;
        if (!skill || !area) {
            if (!req.override()) throw new DomainException("PARTNER_NOT_MATCHED", "Đối tác chưa phù hợp kỹ năng hoặc khu vực. Chọn Đối tác khác hoặc điều phối đặc biệt có lý do.", HttpStatus.CONFLICT);
        }
        if (req.override() && (req.auditReason() == null || req.auditReason().isBlank()))
            throw new DomainException("AUDIT_REASON_REQUIRED", "Cần nhập lý do điều phối đặc biệt.", HttpStatus.BAD_REQUEST);
        Instant scheduledAt = toInstant(task.get("scheduled_at"));
        int duration = ((Number) task.get("estimated_duration_minutes")).intValue();
        BigDecimal lat = (BigDecimal) task.get("latitude");
        BigDecimal lng = (BigDecimal) task.get("longitude");
        var val = schedulingService.validateSchedule(req.partnerId(), id, scheduledAt, duration, lat, lng);
        if (!val.eligible()) {
            throw new DomainException(val.reasonCode(), val.message(), HttpStatus.CONFLICT);
        }
        if (req.partnerId().equals(task.get("tasker_id"))) return ApiResponse.success(Map.of("id", id, "tasker_id", req.partnerId(), "status", "ACCEPTED"));
        String fromStatus = (String) task.get("status");
        var now = Timestamp.from(Instant.now());
        db.update("UPDATE tasks SET tasker_id=?, status='ACCEPTED', updated_at=?, version=version+1 WHERE id=?", req.partnerId(), now, id);
        String histReason = req.override() ? "Admin điều phối đặc biệt (override): " + req.auditReason() : "Admin phân công Đối tác";
        db.update("INSERT INTO task_status_history(id,task_id,from_status,to_status,actor_role,reason,occurred_at) VALUES(?,?,?,?,'ADMIN',?,?)",
            UUID.randomUUID(), id, fromStatus, "ACCEPTED", histReason, now);
        db.update("UPDATE live_sync_revision SET revision=revision+1 WHERE id=1");
        db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) SELECT ?,customer_id,id,?,? FROM tasks WHERE id=?", UUID.randomUUID(), "Admin đã phân công Đối tác cho đơn #" + id.toString().substring(0,8).toUpperCase(), now, id);
        db.update("INSERT INTO partner_notification_outbox(id,application_id,task_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,?,'IN_APP','DELIVERED',?,?,?,?)", UUID.randomUUID(), applicationId, id, "Bạn được phân công công việc", "Admin đã phân công đơn #" + id.toString().substring(0,8).toUpperCase() + ". Mở công việc để xem chi tiết.", now, now);
        return ApiResponse.success(Map.of("id", id, "tasker_id", req.partnerId(), "status", "ACCEPTED"));
    }

    @PostMapping("/{id}/reschedule")
    @org.springframework.transaction.annotation.Transactional
    public ApiResponse<Map<String, Object>> reschedule(@PathVariable UUID id, @Valid @RequestBody RescheduleRequest req) {
        var rows = db.queryForList("SELECT id, status, tasker_id, estimated_duration_minutes, latitude, longitude FROM tasks WHERE id=? FOR UPDATE", id);
        if (rows.isEmpty()) throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        var task = rows.getFirst();
        UUID taskerId = (UUID) task.get("tasker_id");
        int duration = req.durationMinutes() != null ? req.durationMinutes() : ((Number) task.get("estimated_duration_minutes")).intValue();
        BigDecimal lat = (BigDecimal) task.get("latitude");
        BigDecimal lng = (BigDecimal) task.get("longitude");
        if (taskerId != null) {
            var val = schedulingService.validateSchedule(taskerId, id, req.scheduledAt(), duration, lat, lng);
            if (!val.eligible()) {
                throw new DomainException(val.reasonCode(), "Đổi lịch gây xung đột với lịch của Đối tác: " + val.message(), HttpStatus.CONFLICT);
            }
        }
        var now = Timestamp.from(Instant.now());
        db.update("UPDATE tasks SET scheduled_at=?, estimated_duration_minutes=?, updated_at=?, version=version+1 WHERE id=?",
            Timestamp.from(req.scheduledAt()), duration, now, id);
        db.update("INSERT INTO task_status_history(id,task_id,from_status,to_status,actor_role,reason,occurred_at) VALUES(?,?,?,?,'ADMIN',?,?)",
            UUID.randomUUID(), id, task.get("status"), task.get("status"), "Admin đổi lịch: " + Objects.toString(req.reason(), "Cập nhật thời gian"), now);
        return ApiResponse.success(Map.of("id", id, "scheduled_at", req.scheduledAt(), "estimated_duration_minutes", duration));
    }

    @GetMapping("/{id}/eligible-partners")
    public ApiResponse<List<Map<String, Object>>> eligiblePartners(@PathVariable UUID id) {
        var rows = db.queryForList("SELECT id, scheduled_at, estimated_duration_minutes, latitude, longitude, service_id, city_snapshot FROM tasks WHERE id=?", id);
        if (rows.isEmpty()) throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        var task = rows.getFirst();
        Instant scheduledAt = toInstant(task.get("scheduled_at"));
        int duration = ((Number) task.get("estimated_duration_minutes")).intValue();
        BigDecimal lat = (BigDecimal) task.get("latitude");
        BigDecimal lng = (BigDecimal) task.get("longitude");
        UUID serviceId = (UUID) task.get("service_id");
        String city = (String) task.get("city_snapshot");

        var activePartners = db.queryForList("""
            SELECT a.id AS application_id, a.user_id, a.full_name, u.email
            FROM partner_applications a JOIN users u ON u.id=a.user_id
            WHERE a.status='ACTIVE'
            """);

        List<Map<String, Object>> result = new java.util.ArrayList<>();
        for (var p : activePartners) {
            UUID userId = (UUID) p.get("user_id");
            UUID appId = (UUID) p.get("application_id");
            boolean skill = db.queryForObject("SELECT COUNT(*) FROM partner_application_services WHERE application_id=? AND service_id=?", Integer.class, appId, serviceId) > 0;
            boolean area = db.queryForObject("""
                SELECT COUNT(*) FROM recruitment_areas r JOIN partner_application_areas pa ON pa.area_id=r.id
                WHERE pa.application_id=? AND (
                  r.city=?
                  OR LOWER(TRIM(r.city))=LOWER(TRIM(?))
                  OR (LOWER(r.city) LIKE '%hồ chí minh%' AND LOWER(?) LIKE '%hồ chí minh%')
                  OR (LOWER(r.city) LIKE '%hà nội%' AND LOWER(?) LIKE '%hà nội%')
                  OR (LOWER(r.city) LIKE '%đà nẵng%' AND LOWER(?) LIKE '%đà nẵng%')
                )
                """, Integer.class, appId, city, city, city, city, city) > 0;
            var val = schedulingService.validateSchedule(userId, id, scheduledAt, duration, lat, lng);
            var item = new java.util.LinkedHashMap<String, Object>();
            item.put("partnerId", userId);
            item.put("fullName", p.get("full_name"));
            item.put("email", p.get("email"));
            item.put("skillMatch", skill);
            item.put("areaMatch", area);
            item.put("scheduleEligible", val.eligible());
            item.put("reasonCode", val.reasonCode());
            item.put("message", val.message());
            item.put("earliestEligibleStartAt", val.earliestEligibleStartAt());
            item.put("overallEligible", skill && area && val.eligible());
            result.add(item);
        }
        return ApiResponse.success(result);
    }

    @PostMapping("/{id}/verify-completion")
    @org.springframework.transaction.annotation.Transactional
    public ApiResponse<Map<String, Object>> verifyCompletion(@PathVariable UUID id, @RequestBody(required=false) VerifyCompletionRequest req) {
        var rows = db.queryForList("SELECT id, status FROM tasks WHERE id=? FOR UPDATE", id);
        if (rows.isEmpty()) throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        Instant actualEnd = (req != null && req.verifiedActualEndAt() != null) ? req.verifiedActualEndAt() : Instant.now();
        var now = Timestamp.from(Instant.now());
        db.update("UPDATE tasks SET verified_actual_end_at=?, status='COMPLETED', updated_at=?, version=version+1 WHERE id=?",
            Timestamp.from(actualEnd), now, id);
        db.update("INSERT INTO task_status_history(id,task_id,from_status,to_status,actor_role,reason,occurred_at) VALUES(?,?,?,?,'ADMIN',?,?)",
            UUID.randomUUID(), id, rows.getFirst().get("status"), "COMPLETED", "Admin xác thực hoàn thành thực tế lúc " + actualEnd, now);
        return ApiResponse.success(Map.of("id", id, "status", "COMPLETED", "verified_actual_end_at", actualEnd));
    }
}
