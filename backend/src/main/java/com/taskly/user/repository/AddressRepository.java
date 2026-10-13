package com.taskly.user.repository;

import com.taskly.user.entity.Address;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AddressRepository extends JpaRepository<Address, UUID> {
    List<Address> findByUserIdAndDeletedAtIsNullOrderByDefaultAddressDescCreatedAtAsc(UUID userId);
    Optional<Address> findByIdAndUserIdAndDeletedAtIsNull(UUID id, UUID userId);
    long countByUserIdAndDeletedAtIsNull(UUID userId);
}
