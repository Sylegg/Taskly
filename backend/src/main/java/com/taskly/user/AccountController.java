package com.taskly.user;

import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Max;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

/** Stores payment preferences only; registering a method never charges a user. */
@RestController
@RequestMapping("/api/v1/users/me")
public class AccountController {
    private final JdbcTemplate db;
    public AccountController(JdbcTemplate db) { this.db = db; }
    public record MethodRequest(@NotBlank @Pattern(regexp = "CASH|BANK") String kind,
            @NotBlank @Size(max = 100) String name,
            @NotBlank @Size(max = 500) String detail) {}
    public record SettingsRequest(boolean notificationsEnabled) {}
    @GetMapping("/statistics")
    public ApiResponse<Map<String,Object>> statistics(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(db.queryForMap("SELECT COUNT(*) AS \"total\", COUNT(CASE WHEN status IN ('COMPLETED','PAID') THEN 1 END) AS \"completed\" FROM tasks WHERE customer_id = ?", user(jwt)));
    }
    public record ReviewRequest(@Min(1) @Max(5) int stars, @Size(max = 2000) String comment) {}
    @GetMapping("/reviews")
    public ApiResponse<List<Map<String,Object>>> reviews(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(db.queryForList("SELECT r.task_id AS \"taskId\", t.title, r.stars, r.comment, r.created_at AS \"createdAt\" FROM customer_reviews r JOIN tasks t ON t.id = r.task_id WHERE r.customer_id = ? ORDER BY r.created_at DESC", user(jwt)));
    }
    @PostMapping("/reviews/{taskId}")
    @Transactional
    public ApiResponse<Void> review(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID taskId, @Valid @RequestBody ReviewRequest request) {
        UUID user = user(jwt); lock(user);
        List<String> statuses = db.query("SELECT status FROM tasks WHERE id = ? AND customer_id = ? FOR UPDATE", (rs, row) -> rs.getString(1), taskId, user);
        if (statuses.isEmpty()) throw new DomainException("TASK_NOT_FOUND", "Không tìm thấy công việc.", HttpStatus.NOT_FOUND);
        if (!statuses.getFirst().equals("PAID")) throw new DomainException("REVIEW_NOT_ALLOWED", "Chỉ đánh giá công việc đã hoàn tất và thanh toán.", HttpStatus.UNPROCESSABLE_ENTITY);
        if (db.queryForObject("SELECT count(*) FROM customer_reviews WHERE task_id = ?", Integer.class, taskId) > 0)
            throw new DomainException("ALREADY_REVIEWED", "Bạn đã đánh giá công việc này.", HttpStatus.CONFLICT);
        db.update("INSERT INTO customer_reviews(task_id, customer_id, stars, comment) VALUES (?,?,?,?)", taskId, user, request.stars(), request.comment() == null ? "" : request.comment().trim());
        return ApiResponse.success(null);
    }
    private UUID user(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }
    private void lock(UUID user) {
        db.queryForObject("SELECT id FROM users WHERE id = ? FOR UPDATE", UUID.class, user);
    }
    private void requireMethod(UUID user, UUID id) {
        if (db.queryForObject("SELECT count(*) FROM user_payment_methods WHERE user_id = ? AND id = ?",
                Integer.class, user, id) == 0)
            throw new DomainException("METHOD_NOT_FOUND", "Không tìm thấy phương thức thanh toán.", HttpStatus.NOT_FOUND);
    }
    @GetMapping("/payment-methods")
    public ApiResponse<List<Map<String,Object>>> methods(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(db.queryForList("SELECT id, kind, name, detail, is_default AS \"isDefault\" FROM user_payment_methods WHERE user_id = ? ORDER BY is_default DESC, created_at, id", user(jwt)));
    }
    @PostMapping("/payment-methods")
    @Transactional
    public ApiResponse<Void> add(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody MethodRequest request) {
        UUID user = user(jwt);
        lock(user);
        String name = request.kind().equals("CASH") ? "Tiền mặt" : request.name().trim();
        String detail = request.kind().equals("CASH") ? "Trả trực tiếp sau khi hoàn tất" : request.detail().trim();
        if (name.isBlank() || detail.isBlank())
            throw new DomainException("INVALID_METHOD", "Nhập thông tin phương thức.", HttpStatus.UNPROCESSABLE_ENTITY);
        if (db.queryForObject("SELECT count(*) FROM user_payment_methods WHERE user_id = ? AND kind = ? AND name = ? AND detail = ?",
                Integer.class, user, request.kind(), name, detail) > 0)
            throw new DomainException("METHOD_EXISTS", "Phương thức đã được thêm.", HttpStatus.CONFLICT);
        boolean first = db.queryForObject("SELECT count(*) FROM user_payment_methods WHERE user_id = ?", Integer.class, user) == 0;
        db.update("INSERT INTO user_payment_methods(id,user_id,kind,name,detail,is_default) VALUES (?,?,?,?,?,?)",
                UUID.randomUUID(), user, request.kind(), name, detail, first);
        return ApiResponse.success(null);
    }
    @PostMapping("/payment-methods/{id}/default")
    @Transactional
    public ApiResponse<Void> defaultMethod(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        UUID user = user(jwt); lock(user); requireMethod(user, id);
        db.update("UPDATE user_payment_methods SET is_default = FALSE WHERE user_id = ?", user);
        db.update("UPDATE user_payment_methods SET is_default = TRUE WHERE user_id = ? AND id = ?", user, id);
        return ApiResponse.success(null);
    }
    @DeleteMapping("/payment-methods/{id}")
    @Transactional
    public ApiResponse<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        UUID user = user(jwt); lock(user); requireMethod(user, id);
        db.update("DELETE FROM user_payment_methods WHERE user_id = ? AND id = ?", user, id);
        db.update("UPDATE user_payment_methods SET is_default = TRUE WHERE id = (SELECT id FROM user_payment_methods WHERE user_id = ? ORDER BY is_default DESC, created_at, id LIMIT 1)", user);
        return ApiResponse.success(null);
    }
    @GetMapping("/settings")
    public ApiResponse<Map<String,Object>> settings(@AuthenticationPrincipal Jwt jwt) {
        List<Boolean> values = db.query("SELECT notifications_enabled FROM user_preferences WHERE user_id = ?",
                (rs, row) -> rs.getBoolean(1), user(jwt));
        return ApiResponse.success(Map.of("notificationsEnabled", values.isEmpty() || values.getFirst()));
    }
    @PutMapping("/settings")
    @Transactional
    public ApiResponse<Void> settings(@AuthenticationPrincipal Jwt jwt, @RequestBody SettingsRequest request) {
        UUID user = user(jwt); lock(user);
        if (db.update("UPDATE user_preferences SET notifications_enabled = ? WHERE user_id = ?", request.notificationsEnabled(), user) == 0)
            db.update("INSERT INTO user_preferences(user_id, notifications_enabled) VALUES (?,?)", user, request.notificationsEnabled());
        return ApiResponse.success(null);
    }
}
