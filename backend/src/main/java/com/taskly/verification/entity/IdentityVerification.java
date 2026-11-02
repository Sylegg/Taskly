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
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "identity_verifications")
public class IdentityVerification {
    @Id
    private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private UserAccount user;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VerificationStatus status;
    @Column(name = "legal_name")
    private String legalName;
    @Column(name = "document_type")
    private String documentType;
    @Column(name = "document_number_masked")
    private String documentNumberMasked;
    @Column(name = "document_number", length = 30)
    private String documentNumber;
    public String getDocumentNumber() { return documentNumber; }
    public void setDocumentNumber(String number) { documentNumber = number; }

    @Column(name = "consent_accepted_at")
    private Instant consentAcceptedAt;
    @Column(name = "submitted_at")
    private Instant submittedAt;
    @Column(name = "reviewed_at")
    private Instant reviewedAt;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by")
    private UserAccount reviewedBy;
    @Column(name = "decision_reason")
    private String decisionReason;
    @Version
    private long version;
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected IdentityVerification() {}

    public IdentityVerification(UserAccount user, Instant now) {
        this.id = UUID.randomUUID();
        this.user = user;
        this.status = VerificationStatus.DRAFT;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() { return id; }
    public UserAccount getUser() { return user; }
    public VerificationStatus getStatus() { return status; }
    public String getLegalName() { return legalName; }
    public String getDocumentType() { return documentType; }
    public String getDocumentNumberMasked() { return documentNumberMasked; }
    public Instant getSubmittedAt() { return submittedAt; }
    public String getDecisionReason() { return decisionReason; }

    public void updateDraft(String legalName, String documentType, String maskedNumber, Instant now) {
        if (status != VerificationStatus.DRAFT && status != VerificationStatus.SUBMITTED) {
            throw new IllegalStateException("Verification is not editable");
        }
        this.legalName = legalName;
        this.documentType = documentType;
        this.documentNumberMasked = maskedNumber;
        this.updatedAt = now;
    }

    public void submit(Instant now) {
        require(VerificationStatus.DRAFT);
        consentAcceptedAt = now;
        submittedAt = now;
        transition(VerificationStatus.SUBMITTED, now);
    }

    public void beginReview(Instant now) {
        if (status == VerificationStatus.SUBMITTED) transition(VerificationStatus.UNDER_REVIEW, now);
        else require(VerificationStatus.UNDER_REVIEW);
    }

    public void decide(VerificationStatus next, UserAccount admin, String reason, Instant now) {
        if (status != VerificationStatus.SUBMITTED && status != VerificationStatus.UNDER_REVIEW) {
            throw new IllegalStateException("Verification is not reviewable");
        }
        if (next != VerificationStatus.APPROVED && next != VerificationStatus.REJECTED) {
            throw new IllegalArgumentException("Invalid KYC decision");
        }
        status = next;
        reviewedBy = admin;
        reviewedAt = now;
        decisionReason = reason;
        updatedAt = now;
    }

    private void transition(VerificationStatus next, Instant now) {
        status = next;
        updatedAt = now;
    }

    private void require(VerificationStatus expected) {
        if (status != expected) throw new IllegalStateException("Invalid KYC state");
    }
}
