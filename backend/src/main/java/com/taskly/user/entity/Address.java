package com.taskly.user.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "addresses")
public class Address {
    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private UserAccount user;

    @Column(nullable = false, length = 100)
    private String label;
    @Column(name = "recipient_name", length = 160)
    private String recipientName;
    @Column(name = "recipient_phone", length = 32)
    private String recipientPhone;
    @Column(name = "address_line", nullable = false, length = 500)
    private String addressLine;
    private String ward;
    private String district;
    @Column(nullable = false)
    private String city;
    @Column(precision = 10, scale = 7)
    private BigDecimal latitude;
    @Column(precision = 10, scale = 7)
    private BigDecimal longitude;
    private String notes;
    @Column(name = "building_type", length = 100)
    private String buildingType;
    @Column(name = "building_description", length = 500)
    private String buildingDescription;

    public String getBuildingType() { return buildingType; }
    public String getBuildingDescription() { return buildingDescription; }
    public void setBuildingDetails(String type, String description) {
        buildingType = type;
        buildingDescription = description;
    }
    @Column(name = "is_default", nullable = false)
    private boolean defaultAddress;
    @Column(name = "deleted_at")
    private Instant deletedAt;
    @Version
    private long version;
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Address() {}

    public Address(UserAccount user, String label, String recipientName, String recipientPhone,
                   String addressLine, String ward, String district, String city,
                   BigDecimal latitude, BigDecimal longitude, String notes,
                   boolean defaultAddress, Instant now) {
        this.id = UUID.randomUUID();
        this.user = user;
        update(label, recipientName, recipientPhone, addressLine, ward, district, city,
                latitude, longitude, notes, defaultAddress, now);
        this.createdAt = now;
    }

    public UUID getId() { return id; }
    public String getLabel() { return label; }
    public String getRecipientName() { return recipientName; }
    public String getRecipientPhone() { return recipientPhone; }
    public String getAddressLine() { return addressLine; }
    public String getWard() { return ward; }
    public String getDistrict() { return district; }
    public String getCity() { return city; }
    public BigDecimal getLatitude() { return latitude; }
    public BigDecimal getLongitude() { return longitude; }
    public String getNotes() { return notes; }
    public boolean isDefaultAddress() { return defaultAddress; }

    public void update(String label, String recipientName, String recipientPhone,
                       String addressLine, String ward, String district, String city,
                       BigDecimal latitude, BigDecimal longitude, String notes,
                       boolean defaultAddress, Instant now) {
        this.label = label;
        this.recipientName = recipientName;
        this.recipientPhone = recipientPhone;
        this.addressLine = addressLine;
        this.ward = ward;
        this.district = district;
        this.city = city;
        this.latitude = latitude;
        this.longitude = longitude;
        this.notes = notes;
        this.defaultAddress = defaultAddress;
        this.updatedAt = now;
    }

    public void setDefaultAddress(boolean value, Instant now) {
        this.defaultAddress = value;
        this.updatedAt = now;
    }

    public void softDelete(Instant now) {
        deletedAt = now;
        defaultAddress = false;
        updatedAt = now;
    }
}
