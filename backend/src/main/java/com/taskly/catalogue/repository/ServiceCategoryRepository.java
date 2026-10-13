package com.taskly.catalogue.repository;

import com.taskly.catalogue.entity.ServiceCategory;
import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ServiceCategoryRepository extends JpaRepository<ServiceCategory, UUID> {
    Optional<ServiceCategory> findByIdAndDeletedAtIsNull(UUID id);
    Optional<ServiceCategory> findBySlugAndDeletedAtIsNull(String slug);
    boolean existsBySlugAndIdNot(String slug, UUID id);
    boolean existsBySlug(String slug);
    List<ServiceCategory> findByActiveTrueAndDeletedAtIsNullOrderByDisplayOrderAscNameAsc();
    List<ServiceCategory> findByDeletedAtIsNullOrderByDisplayOrderAscNameAsc();
}
