package com.taskly.user.entity;

import com.taskly.rbac.entity.Role;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.UUID;

@Entity
@Table(name = "users")
public class UserAccount {
    @Id
    private UUID id;

    @Column(nullable = false, unique = true, length = 320)
    private String email;

    @Column(unique = true, length = 32)
    private String phone;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private UserStatus status;

    @Enumerated(EnumType.STRING)
    @Column(name = "active_mode", nullable = false)
    private UserMode activeMode;

    @Column(name = "email_verified_at")
    private Instant emailVerifiedAt;

    @Column(name = "failed_login_attempts", nullable = false)
    private int failedLoginAttempts;

    @Column(name = "locked_until")
    private Instant lockedUntil;

    @Column(name = "last_login_at")
    private Instant lastLoginAt;

    @Column(name = "used_customer", nullable = false)
    private boolean usedCustomer;

    @Column(name = "used_partner", nullable = false)
    private boolean usedPartner;

    public void recordAppUse(com.taskly.auth.dto.AuthDtos.AppType appType, Instant now) {
        if (appType == com.taskly.auth.dto.AuthDtos.AppType.PARTNER) usedPartner = true;
        else usedCustomer = true;
        updatedAt = now;
    }

    @Version
    private long version;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
            name = "user_roles",
            joinColumns = @JoinColumn(name = "user_id"),
            inverseJoinColumns = @JoinColumn(name = "role_id"))
    private Set<Role> roles = new LinkedHashSet<>();

    protected UserAccount() {}

    public UserAccount(String email, String phone, String passwordHash, Role customerRole, Instant now) {
        this.id = UUID.randomUUID();
        this.email = email;
        this.phone = phone;
        this.passwordHash = passwordHash;
        this.status = UserStatus.PENDING_VERIFICATION;
        this.activeMode = UserMode.CUSTOMER;
        this.createdAt = now;
        this.updatedAt = now;
        this.roles.add(customerRole);
    }

    public UUID getId() { return id; }
    public String getEmail() { return email; }
    public String getPhone() { return phone; }
    public String getPasswordHash() { return passwordHash; }
    public UserStatus getStatus() { return status; }
    public UserMode getActiveMode() { return activeMode; }
    public Instant getLockedUntil() { return lockedUntil; }
    public Set<Role> getRoles() { return Set.copyOf(roles); }

    public void verifyEmail(Instant now) {
        emailVerifiedAt = now;
        status = UserStatus.ACTIVE;
        updatedAt = now;
    }

    public void recordLoginSuccess(Instant now) {
        failedLoginAttempts = 0;
        lockedUntil = null;
        lastLoginAt = now;
        updatedAt = now;
    }

    public void recordLoginFailure(Instant now, int maxAttempts, long cooldownSeconds) {
        failedLoginAttempts++;
        if (failedLoginAttempts >= maxAttempts) {
            lockedUntil = now.plusSeconds(cooldownSeconds);
            failedLoginAttempts = 0;
        }
        updatedAt = now;
    }

    public boolean isLocked(Instant now) {
        return lockedUntil != null && lockedUntil.isAfter(now);
    }

    public void changePassword(String passwordHash, Instant now) {
        this.passwordHash = passwordHash;
        this.updatedAt = now;
    }

    public void enableRole(Role role, Instant now) {
        this.roles.add(role);
        this.updatedAt = now;
    }

    public void changePhone(String phone, Instant now) {
        this.phone = phone;
        this.updatedAt = now;
    }

    public void switchMode(UserMode mode, Instant now) {
        boolean allowed = mode == UserMode.CUSTOMER
                || roles.stream().anyMatch(role -> role.getKey().equals("TASKER"));
        if (!allowed) throw new IllegalStateException("Tasker role is not enabled");
        this.activeMode = mode;
        this.updatedAt = now;
    }
}
