package com.taskly.user;

import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/users/me")
public class FavoriteHelpersController {
    private final JdbcTemplate db;
    public FavoriteHelpersController(JdbcTemplate db) { this.db = db; }
    @GetMapping("/helpers")
    public ApiResponse<List<Map<String,Object>>> helpers(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(db.queryForList("SELECT u.id, p.full_name AS name, COALESCE(p.bio, '') AS bio FROM users u JOIN user_profiles p ON p.user_id = u.id WHERE u.id <> ? AND u.status = 'ACTIVE' AND EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = u.id AND r.role_key = 'TASKER') ORDER BY p.full_name, u.id", user(jwt)));
    }
    @GetMapping("/favorite-helpers")
    public ApiResponse<List<Map<String,Object>>> favorites(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(db.queryForList("SELECT h.helper_id AS id FROM favorite_helpers h WHERE h.customer_id = ? ORDER BY h.created_at DESC", user(jwt)));
    }
    @PutMapping("/favorite-helpers/{id}")
    @Transactional
    public ApiResponse<Void> favorite(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        UUID customer = user(jwt); lock(customer);
        if (customer.equals(id) || db.queryForObject("SELECT COUNT(*) FROM users u WHERE u.id = ? AND u.status = 'ACTIVE' AND EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = u.id AND r.role_key = 'TASKER')", Integer.class, id) == 0)
            throw new DomainException("HELPER_NOT_FOUND", "Không tìm thấy người giúp khả dụng.", HttpStatus.NOT_FOUND);
        if (db.queryForObject("SELECT COUNT(*) FROM favorite_helpers WHERE customer_id = ? AND helper_id = ?", Integer.class, customer, id) == 0)
            db.update("INSERT INTO favorite_helpers(customer_id, helper_id) VALUES (?, ?)", customer, id);
        return ApiResponse.success(null);
    }
    @DeleteMapping("/favorite-helpers/{id}")
    @Transactional
    public ApiResponse<Void> unfavorite(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        UUID customer = user(jwt); lock(customer);
        db.update("DELETE FROM favorite_helpers WHERE customer_id = ? AND helper_id = ?", customer, id);
        return ApiResponse.success(null);
    }

    private UUID user(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }
    private void lock(UUID id) {
        db.queryForObject("SELECT id FROM users WHERE id = ? FOR UPDATE", UUID.class, id);
    }
}
