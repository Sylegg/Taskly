package com.taskly.catalogue.repository;

import com.taskly.catalogue.entity.CatalogueService;
import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CatalogueServiceRepository extends JpaRepository<CatalogueService, UUID> {
    Optional<CatalogueService> findByIdAndDeletedAtIsNull(UUID id);
    Optional<CatalogueService> findBySlugAndActiveTrueAndDeletedAtIsNull(String slug);
    boolean existsBySlug(String slug);
    boolean existsBySlugAndIdNot(String slug, UUID id);
    boolean existsByCategoryIdAndDeletedAtIsNull(UUID categoryId);
    List<CatalogueService> findByActiveTrueAndDeletedAtIsNullAndCategoryActiveTrueAndCategoryDeletedAtIsNullOrderByDisplayOrderAscNameAsc();
    List<CatalogueService> findByActiveTrueAndDeletedAtIsNullAndCategoryActiveTrueAndCategoryDeletedAtIsNullAndCategorySlugOrderByDisplayOrderAscNameAsc(String categorySlug);
    List<CatalogueService> findByDeletedAtIsNullOrderByDisplayOrderAscNameAsc();
}
