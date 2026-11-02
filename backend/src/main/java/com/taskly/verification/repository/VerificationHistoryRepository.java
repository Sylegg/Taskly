package com.taskly.verification.repository;

import com.taskly.verification.entity.VerificationHistory;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VerificationHistoryRepository extends JpaRepository<VerificationHistory, UUID> {}
