package com.taskly.verification.entity;

import com.taskly.user.entity.UserAccount;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.MapsId;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "tasker_profiles")
public class TaskerProfile {
    @Id
    @Column(name = "user_id")
    private UUID userId;
    @MapsId
    @OneToOne(optional = false)
    @JoinColumn(name = "user_id")
    private UserAccount user;
    @Enumerated(EnumType.STRING)
    @Column(name = "kyc_status", nullable = false)
    private VerificationStatus kycStatus;
    @Column(nullable = false)
    private boolean available;
    @Column(name = "service_radius_km", nullable = false)
    private int serviceRadiusKm;
    @Column(name = "approved_at")
    private Instant approvedAt;
    @Version
    private long version;
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected TaskerProfile() {}

    public TaskerProfile(UserAccount user, Instant now) {
        this.user = user;
        this.kycStatus = VerificationStatus.NOT_STARTED;
        this.serviceRadiusKm = 10;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public VerificationStatus getKycStatus() { return kycStatus; }

    public void updateKyc(VerificationStatus status, Instant now) {
        this.kycStatus = status;
        this.approvedAt = status == VerificationStatus.APPROVED ? now : null;
        if (status != VerificationStatus.APPROVED) this.available = false;
        this.updatedAt = now;
    }
}
