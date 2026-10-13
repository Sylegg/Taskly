package com.taskly.verification.entity;

import com.taskly.user.entity.UserAccount;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "verification_history")
public class VerificationHistory {
    @Id
    private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "verification_id", nullable = false)
    private IdentityVerification verification;
    @Enumerated(EnumType.STRING)
    @Column(name = "from_status")
    private VerificationStatus fromStatus;
    @Enumerated(EnumType.STRING)
    @Column(name = "to_status", nullable = false)
    private VerificationStatus toStatus;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "actor_id", nullable = false)
    private UserAccount actor;
    private String reason;
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected VerificationHistory() {}

    public VerificationHistory(IdentityVerification verification, VerificationStatus fromStatus,
                               VerificationStatus toStatus, UserAccount actor, String reason, Instant now) {
        this.id = UUID.randomUUID();
        this.verification = verification;
        this.fromStatus = fromStatus;
        this.toStatus = toStatus;
        this.actor = actor;
        this.reason = reason;
        this.createdAt = now;
    }
}
