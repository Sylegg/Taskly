package com.taskly.storage.entity;

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
@Table(name = "stored_objects")
public class StoredObject {
    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "owner_id", nullable = false)
    private UserAccount owner;

    @Column(nullable = false)
    private String purpose;
    @Column(name = "bucket_name", nullable = false)
    private String bucketName;
    @Column(name = "object_key", nullable = false, unique = true)
    private String objectKey;
    @Column(name = "original_filename")
    private String originalFilename;
    @Column(name = "content_type", nullable = false)
    private String contentType;
    @Column(name = "size_bytes", nullable = false)
    private long sizeBytes;
    @Column(nullable = false, length = 64)
    private String sha256;
    @Enumerated(EnumType.STRING)
    @Column(name = "scan_status", nullable = false)
    private FileScanStatus scanStatus;
    @Column(name = "private_object", nullable = false)
    private boolean privateObject;
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected StoredObject() {}

    public StoredObject(UserAccount owner, String purpose, String bucketName, String objectKey,
                        String originalFilename, String contentType, long sizeBytes,
                        String sha256, FileScanStatus scanStatus, Instant now) {
        this.id = UUID.randomUUID();
        this.owner = owner;
        this.purpose = purpose;
        this.bucketName = bucketName;
        this.objectKey = objectKey;
        this.originalFilename = originalFilename;
        this.contentType = contentType;
        this.sizeBytes = sizeBytes;
        this.sha256 = sha256;
        this.scanStatus = scanStatus;
        this.privateObject = true;
        this.createdAt = now;
    }

    public UUID getId() { return id; }
    public UserAccount getOwner() { return owner; }
    public String getPurpose() { return purpose; }
    public String getBucketName() { return bucketName; }
    public String getObjectKey() { return objectKey; }
    public String getContentType() { return contentType; }
    public long getSizeBytes() { return sizeBytes; }
    public FileScanStatus getScanStatus() { return scanStatus; }
}
