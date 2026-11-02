package com.taskly.catalogue.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "services")
public class CatalogueService {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "category_id", nullable = false) private ServiceCategory category;
    @Column(nullable = false, unique = true, length = 100) private String slug;
    @Column(nullable = false, length = 160) private String name;
    @Column(name = "short_description", nullable = false, length = 500) private String shortDescription;
    @Column(length = 4000) private String description;
    @Column(name = "suggested_price_min", nullable = false) private long suggestedPriceMin;
    @Column(name = "suggested_price_max", nullable = false) private long suggestedPriceMax;
    @Column(nullable = false, length = 3) private String currency;
    @Column(name = "estimated_duration_minutes") private Integer estimatedDurationMinutes;
    @Column(name = "icon_key", length = 40) private String iconKey;
    @Column(name = "icon_image", columnDefinition = "bytea") private byte[] iconImage;
    @Column(name = "icon_image_hash", length = 64) private String iconImageHash;
    @Column(nullable = false) private boolean active;
    @Column(nullable = false) private boolean popular;
    @Column(name = "display_order", nullable = false) private int displayOrder;
    @Version private long version;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    @Column(name = "deleted_at") private Instant deletedAt;

    protected CatalogueService() {}
    public CatalogueService(ServiceCategory category, String slug, String name, String shortDescription,
                            String description, long priceMin, long priceMax, String currency,
                            Integer durationMinutes, int displayOrder, Instant now) {
        id = UUID.randomUUID(); this.category = category; this.slug = slug; this.name = name;
        this.shortDescription = shortDescription; this.description = description;
        this.suggestedPriceMin = priceMin; this.suggestedPriceMax = priceMax; this.currency = currency;
        this.estimatedDurationMinutes = durationMinutes; this.displayOrder = displayOrder;
        this.createdAt = now; this.updatedAt = now;
    }
    public UUID getId() { return id; }
    public ServiceCategory getCategory() { return category; }
    public String getSlug() { return slug; }
    public String getName() { return name; }
    public String getShortDescription() { return shortDescription; }
    public String getDescription() { return description; }
    public long getSuggestedPriceMin() { return suggestedPriceMin; }
    public long getSuggestedPriceMax() { return suggestedPriceMax; }
    public String getCurrency() { return currency; }
    public Integer getEstimatedDurationMinutes() { return estimatedDurationMinutes; }
    public String getIconKey() { return iconKey; }
    public byte[] getIconImage() { return iconImage == null ? null : iconImage.clone(); }
    public String getIconImageHash() { return iconImageHash; }
    public boolean isActive() { return active; }
    public boolean isPopular() { return popular; }
    public void setPopular(boolean value, Instant now) { popular = value; updatedAt = now; }
    public int getDisplayOrder() { return displayOrder; }
    public Instant getCreatedAt() { return createdAt; }
    public void update(ServiceCategory category, String slug, String name, String shortDescription,
                       String description, long priceMin, long priceMax, String currency,
                       Integer durationMinutes, Instant now) {
        this.category = category; this.slug = slug; this.name = name; this.shortDescription = shortDescription;
        this.description = description; this.suggestedPriceMin = priceMin; this.suggestedPriceMax = priceMax;
        this.currency = currency; this.estimatedDurationMinutes = durationMinutes; updatedAt = now;
    }
    public void setActive(boolean value, Instant now) { active = value; updatedAt = now; }
    public void setIconKey(String value, Instant now) { iconKey = value; updatedAt = now; }
    public void setIconImage(byte[] value, String hash, Instant now) {
        iconImage = value == null ? null : value.clone(); iconImageHash = hash; updatedAt = now;
    }
    public void reorder(int value, Instant now) { displayOrder = value; updatedAt = now; }
    public void delete(Instant now) { active = false; deletedAt = now; updatedAt = now; }
}
