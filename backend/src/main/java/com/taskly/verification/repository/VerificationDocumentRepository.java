package com.taskly.verification.repository;

import com.taskly.verification.entity.DocumentSide;
import com.taskly.verification.entity.VerificationDocument;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VerificationDocumentRepository extends JpaRepository<VerificationDocument, UUID> {
    List<VerificationDocument> findByVerificationId(UUID verificationId);
    Optional<VerificationDocument> findByVerificationIdAndSide(UUID verificationId, DocumentSide side);
    long countByVerificationIdAndSideIn(UUID verificationId, List<DocumentSide> sides);
}
