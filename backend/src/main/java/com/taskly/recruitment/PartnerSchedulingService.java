package com.taskly.recruitment;

import com.taskly.settings.SystemSettingsService;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class PartnerSchedulingService {
    private final JdbcTemplate db;
    private final SystemSettingsService settingsService;

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.of("Asia/Ho_Chi_Minh"));
    private static final DateTimeFormatter DATE_TIME_FMT = DateTimeFormatter.ofPattern("HH:mm 'ngày' dd/MM").withZone(ZoneId.of("Asia/Ho_Chi_Minh"));

    public PartnerSchedulingService(JdbcTemplate db, SystemSettingsService settingsService) {
        this.db = db;
        this.settingsService = settingsService;
    }

    public record ScheduleValidationResult(
        boolean eligible,
        String reasonCode,
        String message,
        UUID conflictingTaskId,
        Instant earliestEligibleStartAt,
        int requiredBufferMinutes
    ) {
        public static ScheduleValidationResult ok(int requiredBufferMinutes) {
            return new ScheduleValidationResult(true, null, "Lịch trình hợp lệ", null, null, requiredBufferMinutes);
        }

        public static ScheduleValidationResult conflict(String reasonCode, String message, UUID taskId, Instant earliest, int buffer) {
            return new ScheduleValidationResult(false, reasonCode, message, taskId, earliest, buffer);
        }
    }

    private Instant toInstant(Object value) {
        if (value instanceof Instant i) return i;
        if (value instanceof Timestamp t) return t.toInstant();
        if (value instanceof OffsetDateTime o) return o.toInstant();
        throw new IllegalArgumentException("Unknown timestamp type: " + value);
    }

    private String formatTime(Instant instant, Instant relativeTo) {
        if (instant == null) return "";
        ZoneId zone = ZoneId.of("Asia/Ho_Chi_Minh");
        if (relativeTo != null && instant.atZone(zone).toLocalDate().equals(relativeTo.atZone(zone).toLocalDate())) {
            return TIME_FMT.format(instant);
        }
        return DATE_TIME_FMT.format(instant);
    }

    public int calculateRequiredGap(BigDecimal lat1, BigDecimal lng1, BigDecimal lat2, BigDecimal lng2) {
        int minBuffer = settingsService.getMinBufferMinutes();
        int travelSafety = settingsService.getTravelSafetyMinutes();
        if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
            return minBuffer;
        }
        double dLat = Math.toRadians(lat2.doubleValue() - lat1.doubleValue());
        double dLng = Math.toRadians(lng2.doubleValue() - lng1.doubleValue());
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1.doubleValue())) * Math.cos(Math.toRadians(lat2.doubleValue()))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        double distanceKm = 6371.0 * c;
        // Average speed 25 km/h in urban traffic
        int travelMinutes = (int) Math.ceil((distanceKm / 25.0) * 60.0);
        return Math.max(minBuffer, travelMinutes + travelSafety);
    }

    public ScheduleValidationResult validateSchedule(
        UUID partnerId,
        UUID candidateTaskId,
        Instant newStart,
        int newDurationMinutes,
        BigDecimal targetLat,
        BigDecimal targetLng
    ) {
        int minBuffer = settingsService.getMinBufferMinutes();
        var limit=com.taskly.task.PartnerWorkPolicy.bookingLimit(db,partnerId,candidateTaskId,newStart,Instant.now());
        if(limit!=null)return ScheduleValidationResult.conflict(limit.code(),limit.message(),null,null,minBuffer);
        Instant newEnd = newStart.plusSeconds(newDurationMinutes * 60L);

        List<Map<String, Object>> existingTasks = db.queryForList("""
            SELECT id, title, scheduled_at, estimated_duration_minutes, status,
                   verified_actual_end_at, latitude, longitude,
                   approved_start_at, original_scheduled_start_at
            FROM tasks
            WHERE tasker_id = ?
              AND status IN ('ACCEPTED', 'TASKER_ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS')
              AND (id <> ? OR ? IS NULL)
            ORDER BY scheduled_at ASC
            """, partnerId, candidateTaskId, candidateTaskId);

        for (Map<String, Object> task : existingTasks) {
            if (Set.of("COMPLETED", "PAID", "CANCELLED", "REFUNDED", "EXPIRED").contains(String.valueOf(task.get("status")))) continue;
            UUID existingId = (UUID) task.get("id");
            String title = (String) task.get("title");
            Instant schedStart = toInstant(task.get("scheduled_at"));
            Instant approvedStart = task.get("approved_start_at") != null ? toInstant(task.get("approved_start_at")) : null;
            Instant resStart = approvedStart != null && approvedStart.isBefore(schedStart) ? approvedStart : schedStart;
            int durationMinutes = ((Number) task.get("estimated_duration_minutes")).intValue();
            BigDecimal lat = (BigDecimal) task.get("latitude");
            BigDecimal lng = (BigDecimal) task.get("longitude");

            Instant effectiveEnd;
            Object verifiedEndObj = task.get("verified_actual_end_at");
            if (verifiedEndObj != null) {
                effectiveEnd = toInstant(verifiedEndObj);
            } else {
                Instant schedEnd = schedStart.plusSeconds(durationMinutes * 60L);
                Instant approvedEnd = approvedStart != null ? approvedStart.plusSeconds(durationMinutes * 60L) : schedEnd;
                // Conservative reservation: hold [resStart, max(schedEnd, approvedEnd)] until verified complete
                effectiveEnd = schedEnd.isAfter(approvedEnd) ? schedEnd : approvedEnd;
            }

            int requiredGap = calculateRequiredGap(lat, lng, targetLat, targetLng);

            // Case 1: Direct overlap
            if (newStart.isBefore(effectiveEnd) && newEnd.isAfter(resStart)) {
                Instant earliest = effectiveEnd.plusSeconds(requiredGap * 60L);
                String msg = String.format(
                    "Trùng lịch với công việc \"%s\" (%s–%s). Bạn chỉ có thể nhận công việc từ %s.",
                    title, formatTime(resStart, newStart), formatTime(effectiveEnd, newStart), formatTime(earliest, newStart)
                );
                return ScheduleValidationResult.conflict("SCHEDULE_CONFLICT", msg, existingId, earliest, requiredGap);
            }

            // Case 2: Candidate job is AFTER reservation
            if (!newStart.isBefore(effectiveEnd)) {
                long gapMinutes = Duration.between(effectiveEnd, newStart).toMinutes();
                if (gapMinutes < requiredGap) {
                    Instant earliest = effectiveEnd.plusSeconds(requiredGap * 60L);
                    String msg = String.format(
                        "Công việc \"%s\" kết thúc lúc %s. Cần tối thiểu %d phút dự phòng, nên chỉ có thể nhận việc bắt đầu từ %s.",
                        title, formatTime(effectiveEnd, newStart), requiredGap, formatTime(earliest, newStart)
                    );
                    return ScheduleValidationResult.conflict("BUFFER_TOO_SHORT", msg, existingId, earliest, requiredGap);
                }
            }

            // Case 3: Candidate job is BEFORE reservation
            if (!newEnd.isAfter(resStart)) {
                long gapMinutes = Duration.between(newEnd, resStart).toMinutes();
                if (gapMinutes < requiredGap) {
                    Instant earliest = effectiveEnd.plusSeconds(requiredGap * 60L);
                    String msg = String.format(
                        "Công việc tiếp theo \"%s\" bắt đầu lúc %s. Cần tối thiểu %d phút dự phòng trước ca đó.",
                        title, formatTime(resStart, newStart), requiredGap
                    );
                    return ScheduleValidationResult.conflict("BUFFER_TOO_SHORT", msg, existingId, earliest, requiredGap);
                }
            }
        }

        return ScheduleValidationResult.ok(minBuffer);
    }

    public List<Map<String, Object>> getPartnerTimeline(UUID partnerId) {
        int minBuffer = settingsService.getMinBufferMinutes();
        List<Map<String, Object>> rows = db.queryForList("""
            SELECT id, title, service_name_snapshot, status, scheduled_at,
                   estimated_duration_minutes, verified_actual_end_at, latitude, longitude,
                   address_line_snapshot, city_snapshot, budget_amount,
                   approved_start_at, original_scheduled_start_at, original_scheduled_end_at,
                   expected_end_at, accepted_at, checked_in_at, actual_started_at
            FROM tasks
            WHERE tasker_id = ?
              AND status IN ('ACCEPTED', 'TASKER_ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED')
            ORDER BY scheduled_at ASC
            """, partnerId);

        List<Map<String, Object>> result = new ArrayList<>();
        for (int i = 0; i < rows.size(); i++) {
            Map<String, Object> cur = new LinkedHashMap<>(rows.get(i));
            Instant start = toInstant(cur.get("scheduled_at"));
            Instant approvedStart = cur.get("approved_start_at") != null ? toInstant(cur.get("approved_start_at")) : null;
            Instant effectiveStart = approvedStart != null && approvedStart.isBefore(start) ? approvedStart : start;
            int duration = ((Number) cur.get("estimated_duration_minutes")).intValue();
            Instant scheduledEnd = start.plusSeconds(duration * 60L);
            Instant effectiveEnd = cur.get("verified_actual_end_at") != null
                ? toInstant(cur.get("verified_actual_end_at"))
                : (approvedStart != null ? (scheduledEnd.isAfter(approvedStart.plusSeconds(duration * 60L)) ? scheduledEnd : approvedStart.plusSeconds(duration * 60L)) : scheduledEnd);

            cur.put("effectiveStartAt", effectiveStart);
            cur.put("scheduledEndAt", scheduledEnd);
            cur.put("effectiveEndAt", effectiveEnd);
            cur.put("bufferMinutes", minBuffer);
            cur.put("bufferEndAt", effectiveEnd.plusSeconds(minBuffer * 60L));

            boolean tightGap = false;
            if (i < rows.size() - 1) {
                Instant nextStart = toInstant(rows.get(i + 1).get("scheduled_at"));
                Instant nextApproved = rows.get(i + 1).get("approved_start_at") != null ? toInstant(rows.get(i + 1).get("approved_start_at")) : null;
                Instant nextEffectiveStart = nextApproved != null && nextApproved.isBefore(nextStart) ? nextApproved : nextStart;
                long gapMin = Duration.between(effectiveEnd, nextEffectiveStart).toMinutes();
                if (gapMin >= minBuffer && gapMin <= minBuffer + 30) {
                    tightGap = true;
                }
            }
            cur.put("tightGapWithNextJob", tightGap);
            result.add(cur);
        }
        return result;
    }
}
