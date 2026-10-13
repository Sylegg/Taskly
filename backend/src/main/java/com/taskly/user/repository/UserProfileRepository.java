package com.taskly.user.repository;

import com.taskly.user.entity.UserProfile;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserProfileRepository extends JpaRepository<UserProfile, UUID> {}
