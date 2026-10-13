package com.taskly.auth.repository;

import com.taskly.auth.entity.RefreshToken;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {
    Optional<RefreshToken> findByTokenHash(String tokenHash);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select token from RefreshToken token where token.tokenHash = :tokenHash")
    Optional<RefreshToken> findForUpdateByTokenHash(String tokenHash);

    List<RefreshToken> findByUserIdAndRevokedAtIsNullAndExpiresAtAfterOrderByCreatedAtDesc(UUID userId, Instant now);
    List<RefreshToken> findByFamilyIdAndRevokedAtIsNull(UUID familyId);

    @Modifying
    @Query("update RefreshToken token set token.revokedAt = :now where token.user.id = :userId and token.revokedAt is null")
    int revokeAllForUser(UUID userId, Instant now);
}
