package com.taskly.verification.repository;

import com.taskly.verification.entity.TaskerProfile;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TaskerProfileRepository extends JpaRepository<TaskerProfile, UUID> {}
