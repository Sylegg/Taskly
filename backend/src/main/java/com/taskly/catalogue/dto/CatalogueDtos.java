package com.taskly.catalogue.dto;

import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class CatalogueDtos {
    private CatalogueDtos() {}
    private static final String SLUG = "^[a-z0-9]+(?:-[a-z0-9]+)*$";

    public record CategoryWriteRequest(
            @NotBlank @Size(max = 80) @Pattern(regexp = SLUG) String slug,
            @NotBlank @Size(max = 160) String name,
            @Size(max = 1000) String description,
            @Min(0) @Max(100000) int displayOrder,
            String iconKey, String iconDataUrl,
            @jakarta.validation.Valid @Size(max=10) List<com.taskly.booking.CategoryQuantityController.Field> quantityFields) {
        public CategoryWriteRequest(String slug,String name,String description,int displayOrder){this(slug,name,description,displayOrder,null,null,null);}
        public CategoryWriteRequest(String slug,String name,String description,int displayOrder,String iconKey,String iconDataUrl){this(slug,name,description,displayOrder,iconKey,iconDataUrl,null);}
    }

    public record ServiceWriteRequest(
            @NotNull UUID categoryId,
            @NotBlank @Size(max = 100) @Pattern(regexp = SLUG) String slug,
            @NotBlank @Size(max = 160) String name,
            @NotBlank @Size(max = 500) String shortDescription,
            @Size(max = 4000) String description,
            @PositiveOrZero long suggestedPriceMin,
            @PositiveOrZero long suggestedPriceMax,
            @NotBlank @Pattern(regexp = "^[A-Z]{3}$") String currency,
            @Min(15) @Max(1440) Integer estimatedDurationMinutes,
            @Min(0) @Max(100000) int displayOrder,
            String iconKey,
            String iconDataUrl) {}

    public record OrderRequest(@Min(0) @Max(100000) int displayOrder) {}
    public record PopularRequest(@NotNull Boolean popular) {}
    public record CategoryResponse(UUID id, String slug, String name, String description,
                                   boolean active, int displayOrder, Instant createdAt, String iconKey, String iconUrl) implements java.io.Serializable {}
    public record ServiceResponse(UUID id, CategoryResponse category, String slug, String name,
                                  String shortDescription, String description,
                                  long suggestedPriceMin, long suggestedPriceMax, String currency,
                                  Integer estimatedDurationMinutes, boolean active,
                                  int displayOrder, Instant createdAt,
                                  String iconKey, String iconUrl, boolean popular, PricingPreview pricing) implements java.io.Serializable {}
    public record PricingPreview(String mode, long baseAmount, long unitAmount, String quantityField, boolean enabled) implements java.io.Serializable {}
    public record CatalogueResponse(List<CategoryResponse> categories, List<ServiceResponse> services) implements java.io.Serializable {}
}
