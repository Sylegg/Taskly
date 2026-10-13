package com.taskly.user.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.MapsId;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "user_profiles")
public class UserProfile {
    @Id
    @Column(name = "user_id")
    private UUID userId;

    @MapsId
    @OneToOne(optional = false)
    @jakarta.persistence.JoinColumn(name = "user_id")
    private UserAccount user;

    @Column(name = "full_name", nullable = false, length = 160)
    private String fullName;

    @Column(nullable = false, length = 12)
    private String language;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected UserProfile() {}

    public UserProfile(UserAccount user, String fullName, Instant now) {
        this.user = user;
        this.fullName = fullName;
        this.language = "vi";
        this.createdAt = now;
        this.updatedAt = now;
    }

    public String getFullName() { return fullName; }
    public String getLanguage() { return language; }

    public void update(String fullName, String language, Instant now) {
        this.fullName = fullName;
        this.language = language;
        this.updatedAt = now;
    }
}
