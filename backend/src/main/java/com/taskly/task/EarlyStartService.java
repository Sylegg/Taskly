package com.taskly.task;

import com.taskly.common.exception.DomainException;
import com.taskly.recruitment.PartnerSchedulingService;
import com.taskly.settings.SystemSettingsService;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EarlyStartService {
    private final JdbcTemplate db;
    private final SystemSettingsService settingsService;
    private final PartnerSchedulingService schedulingService;

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.of("Asia/Ho_Chi_Minh"));
    private static final DateTimeFormatter DATE_TIME_FMT = DateTimeFormatter.ofPattern("HH:mm 'ngày' dd/MM").withZone(ZoneId.of("Asia/Ho_Chi_Minh"));

    public EarlyStartService(
        JdbcTemplate db,
        SystemSettingsService settingsService,
        PartnerSchedulingService schedulingService
    ) {
        this.db = db;
        this.settingsService = settingsService;
        this.schedulingService = schedulingService;
    }

    private Instant toInstant(Object value) {
        if (value == null) return null;
        if (value instanceof Instant i) return i;
        if (value instanceof Timestamp t) return t.toInstant();
        if (value instanceof OffsetDateTime o) return o.toInstant();
        throw new IllegalArgumentException("Unknown timestamp type: " + value);
    }

    private String formatTime(Instant instant) {
        if (instant == null) return "";
        return TIME_FMT.format(instant);
    }

    public record EarlyStartRequestDto(
        UUID id,
        UUID taskId,
        UUID partnerId,
        Instant requestedStartAt,
        Instant proposedEndAt,
        String reason,
        String status,
        Instant requestedAt,
        Instant respondedAt,
        UUID respondedBy,
        Instant expiresAt,
        long version
    ) {}

    public record StartEligibilityDto(
        boolean canTravel,
        boolean canCheckIn,
        boolean canRequestEarlyStart,
        boolean canStart,
        boolean checkedIn,
        Instant allowedStartAt,
        Instant scheduledStartAt,
        Instant originalScheduledStartAt,
        Instant approvedStartAt,
        Instant expectedEndAt,
        int earlyCheckInWindowMinutes,
        int minBufferMinutes,
        int maxEarlyStartMinutes,
        EarlyStartRequestDto activeRequest,
        Instant serverNow,
        String message
    ) {}

    /**
     * Compute full eligibility for a task based on current server clock and domain policies.
     */
    public StartEligibilityDto getStartEligibility(UUID userId, UUID taskId, boolean partner) {
        var rows = db.queryForList("""
            SELECT id, customer_id, tasker_id, status, scheduled_at, estimated_duration_minutes,
                   original_scheduled_start_at, approved_start_at, checked_in_at, actual_started_at,
                   expected_end_at, verified_actual_end_at
            FROM tasks WHERE id = ?
            """, taskId);
        if (rows.isEmpty()) {
            throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        }
        var task = rows.getFirst();
        UUID customerId = (UUID) task.get("customer_id");
        UUID taskerId = (UUID) task.get("tasker_id");

        if (partner && (taskerId == null || !userId.equals(taskerId))) {
            throw new DomainException("NOT_ASSIGNED_PARTNER", "Bạn không được phân công cho công việc này.", HttpStatus.FORBIDDEN);
        }
        if (!partner && !userId.equals(customerId)) {
            throw new DomainException("UNAUTHORIZED_ACTION", "Chỉ khách hàng sở hữu đơn mới có quyền truy cập.", HttpStatus.FORBIDDEN);
        }

        Instant serverNow = Instant.now();
        Instant scheduledAt = toInstant(task.get("scheduled_at"));
        Instant origStart = toInstant(task.get("original_scheduled_start_at"));
        if (origStart == null) origStart = scheduledAt;
        Instant approvedStart = toInstant(task.get("approved_start_at"));
        Instant checkedInAt = toInstant(task.get("checked_in_at"));
        Instant actualStartedAt = toInstant(task.get("actual_started_at"));
        String status = (String) task.get("status");
        int duration = ((Number) task.get("estimated_duration_minutes")).intValue();
        int earlyCheckinWindow = settingsService.getEarlyCheckinWindowMinutes();
        int minBuffer = settingsService.getMinBufferMinutes();

        Instant targetStart = approvedStart != null ? approvedStart : scheduledAt;
        Instant earliestCheckIn = targetStart.minusSeconds(earlyCheckinWindow * 60L);
        Instant allowedStartAt = targetStart;
        Instant expectedEnd = approvedStart != null ? approvedStart.plusSeconds(duration * 60L) : scheduledAt.plusSeconds(duration * 60L);

        boolean checkedIn = checkedInAt != null;
        boolean canCheckIn = !checkedIn
            && Set.of("ACCEPTED", "TASKER_ON_THE_WAY").contains(status)
            && !serverNow.isBefore(earliestCheckIn);

        // Active early request
        var reqList = getEarlyStartRequests(taskId);
        EarlyStartRequestDto activeReq = reqList.stream()
            .filter(r -> "PENDING".equals(r.status()))
            .findFirst()
            .orElse(null);

        boolean canRequestEarly = taskerId != null
            && actualStartedAt == null
            && !Set.of("IN_PROGRESS", "COMPLETED", "PAID", "CANCELLED", "REFUNDED", "EXPIRED").contains(status)
            && serverNow.isBefore(scheduledAt)
            && activeReq == null;

        boolean canStart = checkedIn
            && "ARRIVED".equals(status)
            && actualStartedAt == null
            && !serverNow.isBefore(allowedStartAt);

        String message;
        if (actualStartedAt != null || "IN_PROGRESS".equals(status)) {
            message = "Công việc đang được thực hiện.";
        } else if (!checkedIn) {
            if (serverNow.isBefore(earliestCheckIn)) {
                message = String.format("Khách hẹn %s. Bạn có thể check-in từ %s (trước %d phút).", formatTime(targetStart), formatTime(earliestCheckIn), earlyCheckinWindow);
            } else {
                message = "Bạn đã có thể check-in có mặt tại địa chỉ làm việc.";
            }
        } else if (serverNow.isBefore(allowedStartAt)) {
            message = String.format("Đã check-in. Giờ bắt đầu là %s. Nếu muốn làm sớm, hãy gửi yêu cầu và đợi khách đồng ý.", formatTime(allowedStartAt));
        } else {
            message = "Đã đủ điều kiện. Bạn có thể bấm bắt đầu công việc.";
        }

        boolean otherWork = taskerId != null && PartnerWorkPolicy.hasOtherWork(db,taskerId,taskId);
        if(otherWork){canCheckIn=false;canStart=false;canRequestEarly=false;message=PartnerWorkPolicy.BUSY_MESSAGE;}
        return new StartEligibilityDto(
            !otherWork && taskerId != null && TaskTravelPolicy.canTravel(db, taskId, taskerId, serverNow),
            canCheckIn,
            canRequestEarly,
            canStart,
            checkedIn,
            allowedStartAt,
            scheduledAt,
            origStart,
            approvedStart,
            expectedEnd,
            earlyCheckinWindow,
            minBuffer,
            settingsService.getMaxEarlyStartMinutes(),
            activeReq,
            serverNow,
            message
        );
    }

    public Map<String, Object> checkIn(UUID partnerId, UUID taskId, Double lat, Double lng) {
        return checkIn(partnerId, taskId, lat != null ? BigDecimal.valueOf(lat) : null, lng != null ? BigDecimal.valueOf(lng) : null, "GPS", "checkin-" + UUID.randomUUID());
    }

    public Map<String, Object> checkIn(UUID partnerId, UUID taskId, BigDecimal lat, BigDecimal lng) {
        return checkIn(partnerId, taskId, lat, lng, "GPS", "checkin-" + UUID.randomUUID());
    }

    /**
     * Partner checks in on-site. Validates check-in window against server clock.
     */
    @Transactional
    public Map<String, Object> checkIn(UUID partnerId, UUID taskId, BigDecimal lat, BigDecimal lng, String method, String requestId) {
        PartnerWorkPolicy.lock(db,partnerId);
        PartnerWorkPolicy.requireFree(db,partnerId,taskId);
        var rows = db.queryForList("""
            SELECT id, customer_id, tasker_id, status, scheduled_at, approved_start_at,
                   checked_in_at, service_name_snapshot, version
            FROM tasks WHERE id = ? FOR UPDATE
            """, taskId);
        if (rows.isEmpty()) {
            throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        }
        var task = rows.getFirst();
        UUID taskerId = (UUID) task.get("tasker_id");
        if (taskerId == null || !partnerId.equals(taskerId)) {
            throw new DomainException("NOT_ASSIGNED_PARTNER", "Bạn không được phân công công việc này.", HttpStatus.FORBIDDEN);
        }

        // Active Partner check
        var partnerStatus = db.queryForList("SELECT status FROM partner_applications WHERE user_id = ?", String.class, partnerId);
        if (partnerStatus.isEmpty() || !"ACTIVE".equals(partnerStatus.getFirst())) {
            throw new DomainException("PARTNER_NOT_ACTIVE", "Tài khoản đối tác chưa ACTIVE, không thể check-in.", HttpStatus.FORBIDDEN);
        }

        String currentStatus = (String) task.get("status");
        if (Set.of("COMPLETED", "PAID", "CANCELLED", "REFUNDED", "EXPIRED").contains(currentStatus)) {
            throw new DomainException("INVALID_START_STATE", "Công việc đã kết thúc hoặc bị hủy, không thể check-in.", HttpStatus.CONFLICT);
        }

        // Idempotency check if already arrived
        Instant alreadyCheckedInAt = toInstant(task.get("checked_in_at"));
        if (alreadyCheckedInAt != null && "ARRIVED".equals(currentStatus)) {
            return Map.of("id", taskId, "status", "ARRIVED", "checkedInAt", alreadyCheckedInAt);
        }

        Instant serverNow = Instant.now();
        Instant scheduledAt = toInstant(task.get("scheduled_at"));
        Instant approvedStartAt = toInstant(task.get("approved_start_at"));
        Instant targetStart = approvedStartAt != null ? approvedStartAt : scheduledAt;

        int windowMinutes = settingsService.getEarlyCheckinWindowMinutes();
        Instant earliestCheckIn = targetStart.minusSeconds(windowMinutes * 60L);

        if (serverNow.isBefore(earliestCheckIn)) {
            String msg = String.format("Chưa đến thời gian check-in. Giờ làm việc là %s. Bạn chỉ có thể check-in trước tối đa %d phút (từ %s).",
                formatTime(targetStart), windowMinutes, formatTime(earliestCheckIn));
            throw new DomainException("CHECKIN_TOO_EARLY", msg, HttpStatus.CONFLICT);
        }

        Timestamp nowTs = Timestamp.from(serverNow);
        db.update("""
            UPDATE tasks
            SET checked_in_at = COALESCE(checked_in_at, ?),
                status = 'ARRIVED',
                updated_at = ?,
                version = version + 1
            WHERE id = ?
            """, nowTs, nowTs, taskId);

        db.update("""
            INSERT INTO task_status_history(id, task_id, from_status, to_status, actor_role, reason, occurred_at)
            VALUES(?, ?, ?, 'ARRIVED', 'TASKER', ?, ?)
            """, UUID.randomUUID(), taskId, currentStatus, "Partner check-in có mặt tại địa điểm (" + (method != null ? method : "GPS/App") + ")", nowTs);

        UUID customerId = (UUID) task.get("customer_id");
        var partnerName = db.queryForList("SELECT full_name FROM user_profiles WHERE user_id = ?", String.class, partnerId)
            .stream().findFirst().orElse("Đối tác TaskLy");
        db.update("""
            INSERT INTO customer_booking_notifications(id, customer_id, task_id, title, created_at)
            VALUES(?, ?, ?, ?, ?)
            """, UUID.randomUUID(), customerId, taskId, "Đối tác " + partnerName + " đã có mặt tại địa điểm dịch vụ.", nowTs);

        return Map.of("id", taskId, "status", "ARRIVED", "checkedInAt", serverNow);
    }

    @Transactional
    public Map<String, Object> checkInWithPhoto(UUID partnerId, UUID taskId, BigDecimal lat, BigDecimal lng, String method, String requestId, String imageData) {
        if (imageData == null || imageData.isBlank()) {
            throw new DomainException("CHECKIN_PHOTO_REQUIRED", "Bạn phải chụp ảnh trước khi check-in.", HttpStatus.BAD_REQUEST);
        }
        TaskActivityController.validateImage(imageData);
        var result = checkIn(partnerId, taskId, lat, lng, method, requestId);
        String notice = "Tôi đã check-in, đã có mặt tại địa điểm dịch vụ. Đây là ảnh xác nhận.";
        if (db.queryForObject("SELECT COUNT(*) FROM task_messages WHERE task_id=? AND sender_id=? AND content IN (?,?)", Integer.class,
                taskId, partnerId, notice, "Ảnh check-in tại địa điểm dịch vụ") == 0) {
            boolean photoAlreadySent = db.queryForObject("SELECT COUNT(*) FROM task_messages WHERE task_id=? AND sender_id=? AND sender_portal='PARTNER' AND image_data=?", Integer.class, taskId, partnerId, imageData) > 0;
            db.update("INSERT INTO task_messages(id,task_id,sender_id,content,image_data,sender_portal) VALUES(?,?,?,?,?,'PARTNER')",
                UUID.randomUUID(), taskId, partnerId, notice, photoAlreadySent ? null : imageData);
        }
        return result;
    }

    public EarlyStartRequestDto createEarlyStartRequest(UUID partnerId, UUID taskId, Instant requestedStartAt, String reason) {
        return createEarlyStartRequest(partnerId, taskId, requestedStartAt, reason, "early-" + UUID.randomUUID());
    }

    /**
     * Partner creates an EarlyStartRequest.
     */
    @Transactional
    public EarlyStartRequestDto createEarlyStartRequest(
        UUID partnerId,
        UUID taskId,
        Instant requestedStartAt,
        String reason,
        String requestId
    ) {
        var rows = db.queryForList("""
            SELECT id, customer_id, tasker_id, status, scheduled_at, estimated_duration_minutes,
                   latitude, longitude, service_name_snapshot, actual_started_at, version
            FROM tasks WHERE id = ? FOR UPDATE
            """, taskId);
        if (rows.isEmpty()) {
            throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        }
        var task = rows.getFirst();
        UUID taskerId = (UUID) task.get("tasker_id");
        if (taskerId == null || !partnerId.equals(taskerId)) {
            throw new DomainException("NOT_ASSIGNED_PARTNER", "Bạn không được phân công cho công việc này.", HttpStatus.FORBIDDEN);
        }

        // Active Partner check
        var partnerStatus = db.queryForList("SELECT status FROM partner_applications WHERE user_id = ?", String.class, partnerId);
        if (partnerStatus.isEmpty() || !"ACTIVE".equals(partnerStatus.getFirst())) {
            throw new DomainException("PARTNER_NOT_ACTIVE", "Tài khoản đối tác chưa ACTIVE, không thể xin bắt đầu sớm.", HttpStatus.FORBIDDEN);
        }

        String status = (String) task.get("status");
        if (task.get("actual_started_at") != null || Set.of("IN_PROGRESS", "COMPLETED", "PAID", "CANCELLED", "REFUNDED", "EXPIRED").contains(status)) {
            throw new DomainException("INVALID_START_STATE", "Công việc đã bắt đầu hoặc đã kết thúc, không thể xin bắt đầu sớm.", HttpStatus.CONFLICT);
        }

        Instant scheduledAt = toInstant(task.get("scheduled_at"));
        Instant serverNow = Instant.now();

        if (!requestedStartAt.isBefore(scheduledAt)) {
            throw new DomainException("INVALID_START_TIME", "Giờ đề nghị bắt đầu sớm phải trước giờ hẹn ban đầu.", HttpStatus.BAD_REQUEST);
        }

        int maxEarlyMinutes = settingsService.getMaxEarlyStartMinutes();
        Instant earliestAllowed = scheduledAt.minusSeconds(maxEarlyMinutes * 60L);
        if (requestedStartAt.isBefore(earliestAllowed)) {
            throw new DomainException("MAX_EARLY_LIMIT_EXCEEDED",
                String.format("Chỉ được đề nghị bắt đầu sớm tối đa %d phút trước giờ hẹn (từ %s).", maxEarlyMinutes, formatTime(earliestAllowed)),
                HttpStatus.BAD_REQUEST);
        }

        if (requestedStartAt.isBefore(serverNow.minusSeconds(300))) {
            throw new DomainException("INVALID_START_TIME", "Thời điểm đề nghị bắt đầu không được ở trong quá khứ.", HttpStatus.BAD_REQUEST);
        }

        // Anti-spam / duplicate check: check existing PENDING requests
        var pendingRows = db.queryForList("""
            SELECT id, expires_at, status FROM early_start_requests
            WHERE task_id = ? AND status = 'PENDING' FOR UPDATE
            """, taskId);
        for (var pr : pendingRows) {
            Instant exp = toInstant(pr.get("expires_at"));
            if (serverNow.isBefore(exp)) {
                throw new DomainException("STALE_REQUEST", "Đã có đề nghị bắt đầu sớm đang chờ khách hàng phản hồi.", HttpStatus.CONFLICT);
            } else {
                // Auto-expire stale pending request
                db.update("UPDATE early_start_requests SET status = 'EXPIRED' WHERE id = ?", pr.get("id"));
            }
        }

        int duration = ((Number) task.get("estimated_duration_minutes")).intValue();
        BigDecimal lat = (BigDecimal) task.get("latitude");
        BigDecimal lng = (BigDecimal) task.get("longitude");
        Instant proposedEndAt = requestedStartAt.plusSeconds(duration * 60L);

        // Validate partner's schedule & buffer against prior jobs before creating request!
        var scheduleCheck = schedulingService.validateSchedule(partnerId, taskId, requestedStartAt, duration, lat, lng);
        if (!scheduleCheck.eligible()) {
            throw new DomainException(scheduleCheck.reasonCode(),
                "Không thể đề nghị thời gian này: " + scheduleCheck.message(),
                HttpStatus.CONFLICT);
        }

        int expiryMinutes = settingsService.getEarlyStartExpiryMinutes();
        Instant expiresAt = serverNow.plusSeconds(expiryMinutes * 60L);
        if (expiresAt.isAfter(scheduledAt)) expiresAt = scheduledAt;

        UUID newId = UUID.randomUUID();
        Timestamp nowTs = Timestamp.from(serverNow);

        db.update("""
            INSERT INTO early_start_requests(
                id, task_id, partner_id, requested_start_at, proposed_end_at,
                reason, status, requested_at, expires_at, version
            ) VALUES(?, ?, ?, ?, ?, ?, 'PENDING', ?, ?, 0)
            """,
            newId, taskId, partnerId, Timestamp.from(requestedStartAt), Timestamp.from(proposedEndAt),
            reason != null ? reason.trim() : "Đối tác đã có mặt sớm và xin bắt đầu công việc",
            nowTs, Timestamp.from(expiresAt));

        db.update("UPDATE tasks SET early_start_request_id = ? WHERE id = ?", newId, taskId);

        // Notify Customer
        UUID customerId = (UUID) task.get("customer_id");
        var partnerName = db.queryForList("SELECT full_name FROM user_profiles WHERE user_id = ?", String.class, partnerId)
            .stream().findFirst().orElse("Đối tác TaskLy");
        String notifTitle = String.format("Đối tác %s đề nghị bắt đầu sớm lúc %s (kết thúc %s)",
            partnerName, formatTime(requestedStartAt), formatTime(proposedEndAt));
        db.update("""
            INSERT INTO customer_booking_notifications(id, customer_id, task_id, title, created_at)
            VALUES(?, ?, ?, ?, ?)
            """, UUID.randomUUID(), customerId, taskId, notifTitle, nowTs);

        db.update("INSERT INTO task_messages(id,task_id,sender_id,content,sender_portal,created_at) VALUES(?,?,?,?,'PARTNER',?)", UUID.randomUUID(), taskId, partnerId,
            "Tôi đề nghị đến / làm sớm lúc " + DATE_TIME_FMT.format(requestedStartAt) + ", kết thúc " + DATE_TIME_FMT.format(proposedEndAt) + ". Bạn vui lòng duyệt yêu cầu trong chi tiết đơn." + (reason == null || reason.isBlank() ? "" : " Lý do: " + reason), nowTs);
        return new EarlyStartRequestDto(
            newId, taskId, partnerId, requestedStartAt, proposedEndAt, reason, "PENDING",
            serverNow, null, null, expiresAt, 0
        );
    }

    /**
     * Customer responds to EarlyStartRequest (APPROVE / REJECT).
     */
    @Transactional
    public EarlyStartRequestDto customerDecision(
        UUID customerId,
        UUID taskId,
        UUID requestId,
        String decision,
        String reason
    ) {
        var taskRows = db.queryForList("""
            SELECT id, customer_id, tasker_id, status, scheduled_at, estimated_duration_minutes,
                   latitude, longitude, service_name_snapshot, version
            FROM tasks WHERE id = ? FOR UPDATE
            """, taskId);
        if (taskRows.isEmpty()) {
            throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy đơn dịch vụ.", HttpStatus.NOT_FOUND);
        }
        var task = taskRows.getFirst();
        if (!customerId.equals(task.get("customer_id"))) {
            throw new DomainException("UNAUTHORIZED_ACTION", "Chỉ khách hàng sở hữu đơn mới được quyền quyết định.", HttpStatus.FORBIDDEN);
        }

        var reqRows = db.queryForList("""
            SELECT id, task_id, partner_id, requested_start_at, proposed_end_at, reason,
                   status, requested_at, expires_at, version
            FROM early_start_requests WHERE id = ? AND task_id = ? FOR UPDATE
            """, requestId, taskId);
        if (reqRows.isEmpty()) {
            throw new DomainException("REQUEST_NOT_FOUND", "Không tìm thấy yêu cầu bắt đầu sớm.", HttpStatus.NOT_FOUND);
        }
        var req = reqRows.getFirst();
        String currentStatus = (String) req.get("status");
        if (!"PENDING".equals(currentStatus)) {
            throw new DomainException("STALE_REQUEST", "Yêu cầu đã được xử lý trước đó (trạng thái: " + currentStatus + ").", HttpStatus.CONFLICT);
        }

        Instant serverNow = Instant.now();
        Instant expiresAt = toInstant(req.get("expires_at"));
        if (serverNow.isAfter(expiresAt)) {
            db.update("UPDATE early_start_requests SET status = 'EXPIRED' WHERE id = ?", requestId);
            throw new DomainException("EARLY_START_REQUEST_EXPIRED", "Yêu cầu bắt đầu sớm này đã hết hạn hiệu lực.", HttpStatus.CONFLICT);
        }

        Instant requestedStartAt = toInstant(req.get("requested_start_at"));
        Instant proposedEndAt = toInstant(req.get("proposed_end_at"));
        UUID partnerId = (UUID) req.get("partner_id");
        int duration = ((Number) task.get("estimated_duration_minutes")).intValue();
        BigDecimal lat = (BigDecimal) task.get("latitude");
        BigDecimal lng = (BigDecimal) task.get("longitude");

        Timestamp nowTs = Timestamp.from(serverNow);

        if ("REJECT".equalsIgnoreCase(decision)) {
            db.update("""
                UPDATE early_start_requests
                SET status = 'REJECTED', responded_at = ?, responded_by = ?, version = version + 1
                WHERE id = ?
                """, nowTs, customerId, requestId);

            // Notify partner
            var appIds = db.queryForList("SELECT id FROM partner_applications WHERE user_id = ?", UUID.class, partnerId);
            if (!appIds.isEmpty()) {
                db.update("""
                    INSERT INTO partner_notification_outbox(id, application_id, task_id, channel, status, title, message, created_at, delivered_at)
                    VALUES(?, ?, ?, 'IN_APP', 'DELIVERED', ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """, UUID.randomUUID(), appIds.getFirst(), taskId,
                    "Khách hàng giữ nguyên lịch hẹn",
                    "Khách hàng muốn giữ nguyên giờ đặt ban đầu lúc " + formatTime(toInstant(task.get("scheduled_at"))) + ".");
            }

            return new EarlyStartRequestDto(
                requestId, taskId, partnerId, requestedStartAt, proposedEndAt,
                (String) req.get("reason"), "REJECTED", toInstant(req.get("requested_at")),
                serverNow, customerId, expiresAt, ((Number) req.get("version")).longValue() + 1
            );
        } else if ("APPROVE".equalsIgnoreCase(decision)) {
            // Revalidate partner's buffer at customer approval time!
            var scheduleVal = schedulingService.validateSchedule(partnerId, taskId, requestedStartAt, duration, lat, lng);
            if (!scheduleVal.eligible()) {
                throw new DomainException(scheduleVal.reasonCode(),
                    "Không thể duyệt bắt đầu sớm do ca trước của đối tác kéo dài hoặc vi phạm khoảng cách an toàn: " + scheduleVal.message(),
                    HttpStatus.CONFLICT);
            }

            db.update("""
                UPDATE early_start_requests
                SET status = 'APPROVED', responded_at = ?, responded_by = ?, version = version + 1
                WHERE id = ?
                """, nowTs, customerId, requestId);

            db.update("""
                UPDATE tasks
                SET approved_start_at = ?, expected_end_at = ?, updated_at = ?, version = version + 1
                WHERE id = ?
                """, Timestamp.from(requestedStartAt), Timestamp.from(proposedEndAt), nowTs, taskId);

            // Notify partner
            var appIds = db.queryForList("SELECT id FROM partner_applications WHERE user_id = ?", UUID.class, partnerId);
            if (!appIds.isEmpty()) {
                db.update("""
                    INSERT INTO partner_notification_outbox(id, application_id, task_id, channel, status, title, message, created_at, delivered_at)
                    VALUES(?, ?, ?, 'IN_APP', 'DELIVERED', ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """, UUID.randomUUID(), appIds.getFirst(), taskId,
                    "Khách hàng đã đồng ý bắt đầu sớm!",
                    "Khách hàng đã chấp thuận bắt đầu công việc lúc " + formatTime(requestedStartAt) + " (dự kiến hoàn thành " + formatTime(proposedEndAt) + ").");
            }

            return new EarlyStartRequestDto(
                requestId, taskId, partnerId, requestedStartAt, proposedEndAt,
                (String) req.get("reason"), "APPROVED", toInstant(req.get("requested_at")),
                serverNow, customerId, expiresAt, ((Number) req.get("version")).longValue() + 1
            );
        } else {
            throw new DomainException("INVALID_DECISION", "Hành động quyết định phải là APPROVE hoặc REJECT.", HttpStatus.BAD_REQUEST);
        }
    }

    public Map<String, Object> startJob(UUID partnerId, UUID taskId) {
        return startJob(partnerId, taskId, "start-" + UUID.randomUUID());
    }

    /**
     * Partner starts the job. Full backend authoritative enforcement:
     * - Must be assigned partner
     * - Status must be ARRIVED
     * - checked_in_at must not be null
     * - Server time must be >= allowedStartAt (approved_start_at != null ? approved_start_at : scheduled_at)
     * - Revalidates schedule buffer
     * - Transitions to IN_PROGRESS, sets actual_started_at
     */
    @Transactional
    public Map<String, Object> startJob(UUID partnerId, UUID taskId, String requestId) {
        PartnerWorkPolicy.lock(db,partnerId);
        PartnerWorkPolicy.requireFree(db,partnerId,taskId);
        var rows = db.queryForList("""
            SELECT id, customer_id, tasker_id, status, scheduled_at, estimated_duration_minutes,
                   approved_start_at, checked_in_at, actual_started_at, latitude, longitude,
                   service_name_snapshot, version
            FROM tasks WHERE id = ? FOR UPDATE
            """, taskId);
        if (rows.isEmpty()) {
            throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        }
        var task = rows.getFirst();
        UUID taskerId = (UUID) task.get("tasker_id");
        if (taskerId == null || !partnerId.equals(taskerId)) {
            throw new DomainException("NOT_ASSIGNED_PARTNER", "Bạn không được phân công cho công việc này.", HttpStatus.FORBIDDEN);
        }

        // Active Partner check
        var partnerStatus = db.queryForList("SELECT status FROM partner_applications WHERE user_id = ?", String.class, partnerId);
        if (partnerStatus.isEmpty() || !"ACTIVE".equals(partnerStatus.getFirst())) {
            throw new DomainException("PARTNER_NOT_ACTIVE", "Tài khoản đối tác chưa ACTIVE, không thể bắt đầu công việc.", HttpStatus.FORBIDDEN);
        }

        String currentStatus = (String) task.get("status");

        // Idempotency: if already started, return existing state
        if ("IN_PROGRESS".equals(currentStatus) && task.get("actual_started_at") != null) {
            return Map.of("id", taskId, "status", "IN_PROGRESS", "actualStartedAt", toInstant(task.get("actual_started_at")));
        }

        if (Set.of("COMPLETED", "PAID", "CANCELLED", "REFUNDED", "EXPIRED").contains(currentStatus)) {
            throw new DomainException("INVALID_START_STATE", "Công việc đã kết thúc hoặc bị hủy, không thể bắt đầu.", HttpStatus.CONFLICT);
        }

        // Must be checked in & ARRIVED
        Instant checkedInAt = toInstant(task.get("checked_in_at"));
        if (checkedInAt == null || !"ARRIVED".equals(currentStatus)) {
            throw new DomainException("CHECKIN_REQUIRED", "Bạn cần check-in xác nhận có mặt tại địa điểm trước khi bắt đầu công việc.", HttpStatus.CONFLICT);
        }

        Instant serverNow = Instant.now();
        Instant scheduledAt = toInstant(task.get("scheduled_at"));
        Instant approvedStartAt = toInstant(task.get("approved_start_at"));
        Instant allowedStartAt = approvedStartAt != null ? approvedStartAt : scheduledAt;

        // If clock is before allowedStartAt -> Reject with EARLY_START_REQUIRES_APPROVAL
        if (serverNow.isBefore(allowedStartAt)) {
            String msg = String.format("Chưa đến giờ bắt đầu (%s). Để bắt đầu sớm trước giờ hẹn, bạn cần gửi đề nghị và được khách hàng đồng ý trong ứng dụng.",
                formatTime(allowedStartAt));
            throw new DomainException("EARLY_START_REQUIRES_APPROVAL", msg, HttpStatus.CONFLICT);
        }

        // Revalidate schedule buffer
        int duration = ((Number) task.get("estimated_duration_minutes")).intValue();
        BigDecimal lat = (BigDecimal) task.get("latitude");
        BigDecimal lng = (BigDecimal) task.get("longitude");
        var schedVal = schedulingService.validateSchedule(partnerId, taskId, allowedStartAt, duration, lat, lng);
        if (!schedVal.eligible()) {
            throw new DomainException(schedVal.reasonCode(), "Không thể bắt đầu: " + schedVal.message(), HttpStatus.CONFLICT);
        }

        Timestamp nowTs = Timestamp.from(serverNow);

        db.update("""
            UPDATE tasks
            SET status = 'IN_PROGRESS',
                actual_started_at = ?,
                updated_at = ?,
                version = version + 1
            WHERE id = ?
            """, nowTs, nowTs, taskId);

        // Mark any approved request as APPLIED
        db.update("UPDATE early_start_requests SET status = 'APPLIED' WHERE task_id = ? AND status = 'APPROVED'", taskId);

        db.update("""
            INSERT INTO task_status_history(id, task_id, from_status, to_status, actor_role, reason, occurred_at)
            VALUES(?, ?, 'ARRIVED', 'IN_PROGRESS', 'TASKER', 'Bắt đầu thực hiện công việc', ?)
            """, UUID.randomUUID(), taskId, nowTs);

        UUID customerId = (UUID) task.get("customer_id");
        var partnerName = db.queryForList("SELECT full_name FROM user_profiles WHERE user_id = ?", String.class, partnerId)
            .stream().findFirst().orElse("Đối tác TaskLy");
        db.update("""
            INSERT INTO customer_booking_notifications(id, customer_id, task_id, title, created_at)
            VALUES(?, ?, ?, ?, ?)
            """, UUID.randomUUID(), customerId, taskId,
            "Đối tác " + partnerName + " đã bắt đầu thực hiện công việc \"" + task.get("service_name_snapshot") + "\" lúc " + formatTime(serverNow) + ".",
            nowTs);

        db.update("INSERT INTO task_messages(id,task_id,sender_id,content,sender_portal,created_at) VALUES(?,?,?,?,'PARTNER',?)", UUID.randomUUID(), taskId, partnerId,
            "Tôi đã bắt đầu thực hiện công việc lúc " + DATE_TIME_FMT.format(serverNow) + ".", nowTs);
        return Map.of("id", taskId, "status", "IN_PROGRESS", "actualStartedAt", serverNow);
    }

    public List<EarlyStartRequestDto> getEarlyStartRequests(UUID taskId) {
        return db.query("""
            SELECT id, task_id, partner_id, requested_start_at, proposed_end_at, reason,
                   status, requested_at, responded_at, responded_by, expires_at, version
            FROM early_start_requests WHERE task_id = ?
            ORDER BY requested_at DESC
            """,
            (r, n) -> new EarlyStartRequestDto(
                r.getObject("id", UUID.class),
                r.getObject("task_id", UUID.class),
                r.getObject("partner_id", UUID.class),
                toInstant(r.getTimestamp("requested_start_at")),
                toInstant(r.getTimestamp("proposed_end_at")),
                r.getString("reason"),
                r.getString("status"),
                toInstant(r.getTimestamp("requested_at")),
                toInstant(r.getTimestamp("responded_at")),
                r.getObject("responded_by", UUID.class),
                toInstant(r.getTimestamp("expires_at")),
                r.getLong("version")
            ),
            taskId
        );
    }
}
