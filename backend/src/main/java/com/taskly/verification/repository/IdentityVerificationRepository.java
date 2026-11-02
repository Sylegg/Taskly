package com.taskly.verification.repository;

import com.taskly.verification.entity.IdentityVerification;
import com.taskly.verification.entity.VerificationStatus;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface IdentityVerificationRepository extends JpaRepository<IdentityVerification, UUID> {
    Optional<IdentityVerification> findFirstByUserIdOrderByCreatedAtDesc(UUID userId);
    Optional<IdentityVerification> findByIdAndUserId(UUID id, UUID userId);
    Page<IdentityVerification> findByStatusIn(Collection<VerificationStatus> statuses, Pageable pageable);
    List<IdentityVerification> findByUserIdOrderByCreatedAtDesc(UUID userId);
}
