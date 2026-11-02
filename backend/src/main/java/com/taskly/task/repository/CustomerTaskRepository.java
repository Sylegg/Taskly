package com.taskly.task.repository;
import com.taskly.task.entity.CustomerTask; import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
public interface CustomerTaskRepository extends JpaRepository<CustomerTask, UUID> { List<CustomerTask> findByCustomerIdOrderByCreatedAtDesc(UUID customerId); Optional<CustomerTask> findByIdAndCustomerId(UUID id, UUID customerId); }
