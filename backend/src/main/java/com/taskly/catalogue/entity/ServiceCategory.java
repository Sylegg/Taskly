package com.taskly.catalogue.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "service_categories")
public class ServiceCategory {
    @Id private UUID id;
    @Column(nullable = false, unique = true, length = 80) private String slug;
    @Column(nullable = false, length = 160) private String name;
    @Column(length = 1000) private String description;
    @Column(nullable = false) private boolean active;
    @Column(name = "display_order", nullable = false) private int displayOrder;
    @Column(name="icon_key",length=40) private String iconKey;
    @Column(name="icon_image",columnDefinition="bytea") private byte[] iconImage;
    @Column(name="icon_image_hash",length=64) private String iconImageHash;
    public String getIconKey(){return iconKey;}
    public byte[] getIconImage(){return iconImage;}
    public String getIconImageHash(){return iconImageHash;}
    public void setIconKey(String value,Instant now){iconKey=value;updatedAt=now;}
    public void setIconImage(byte[] value,String hash,Instant now){iconImage=value;iconImageHash=hash;updatedAt=now;}
    @Version private long version;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    @Column(name = "deleted_at") private Instant deletedAt;

    protected ServiceCategory() {}
    public ServiceCategory(String slug, String name, String description, int displayOrder, Instant now) {
        id = UUID.randomUUID(); this.slug = slug; this.name = name; this.description = description;
        this.displayOrder = displayOrder; this.createdAt = now; this.updatedAt = now;
    }
    public UUID getId() { return id; }
    public String getSlug() { return slug; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public boolean isActive() { return active; }
    public int getDisplayOrder() { return displayOrder; }
    public Instant getCreatedAt() { return createdAt; }
    public void update(String slug, String name, String description, Instant now) {
        this.slug = slug; this.name = name; this.description = description; updatedAt = now;
    }
    public void setActive(boolean value, Instant now) { active = value; updatedAt = now; }
    public void reorder(int value, Instant now) { displayOrder = value; updatedAt = now; }
    public void delete(Instant now) { active = false; deletedAt = now; updatedAt = now; }
}
