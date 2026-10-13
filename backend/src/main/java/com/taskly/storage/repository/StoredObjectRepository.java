package com.taskly.storage.repository;

import com.taskly.storage.entity.StoredObject;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StoredObjectRepository extends JpaRepository<StoredObject, UUID> {
    Optional<StoredObject> findByIdAndOwnerId(UUID id, UUID ownerId);
}
