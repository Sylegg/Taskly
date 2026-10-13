package com.taskly.verification.entity;

import com.taskly.storage.entity.StoredObject;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "verification_documents")
public class VerificationDocument {
    @Id
    private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "verification_id", nullable = false)
    private IdentityVerification verification;
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "stored_object_id", nullable = false)
    private StoredObject storedObject;
    @Enumerated(EnumType.STRING)
    @Column(name = "document_side", nullable = false)
    private DocumentSide side;
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected VerificationDocument() {}

    public VerificationDocument(IdentityVerification verification, StoredObject object, DocumentSide side, Instant now) {
        this.id = UUID.randomUUID();
        this.verification = verification;
        this.storedObject = object;
        this.side = side;
        this.createdAt = now;
    }

    public UUID getId() { return id; }
    public StoredObject getStoredObject() { return storedObject; }
    public DocumentSide getSide() { return side; }
    public void replace(StoredObject value, Instant now) { storedObject = value; createdAt = now; }
}
