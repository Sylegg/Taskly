package com.taskly.rbac.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

@Entity
@Table(name = "permissions")
public class Permission {
    @Id
    private UUID id;

    @Column(name = "permission_key", nullable = false, unique = true)
    private String key;

    protected Permission() {}

    public String getKey() {
        return key;
    }
}
