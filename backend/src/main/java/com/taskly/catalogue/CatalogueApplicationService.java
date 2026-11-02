package com.taskly.catalogue;

import com.taskly.catalogue.dto.CatalogueDtos;
import com.taskly.catalogue.entity.CatalogueService;
import com.taskly.catalogue.entity.ServiceCategory;
import com.taskly.catalogue.repository.CatalogueServiceRepository;
import com.taskly.catalogue.repository.ServiceCategoryRepository;
import com.taskly.common.exception.DomainException;
import java.time.Clock;
import java.util.List;
import java.util.UUID;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CatalogueApplicationService {
    private final ServiceCategoryRepository categories;
    private final CatalogueServiceRepository services;
    private final ServiceIconProcessor icons;
    private final Clock clock;
    private final org.springframework.jdbc.core.JdbcTemplate db;
    private final com.taskly.booking.CategoryQuantityController quantity;

    public CatalogueApplicationService(ServiceCategoryRepository categories,
                                       CatalogueServiceRepository services, ServiceIconProcessor icons, Clock clock, org.springframework.jdbc.core.JdbcTemplate db, com.taskly.booking.CategoryQuantityController quantity) {
        this.categories = categories; this.services = services; this.icons = icons; this.clock = clock; this.db=db; this.quantity=quantity;
    }

    @Cacheable(cacheNames = "publicCatalogue", key = "#p0 == null ? 'all' : #p0")
    @Transactional(readOnly = true)
    public CatalogueDtos.CatalogueResponse publicCatalogue(String categorySlug) {
        var categoryItems = categories.findByActiveTrueAndDeletedAtIsNullOrderByDisplayOrderAscNameAsc();
        var serviceItems = categorySlug == null
                ? services.findByActiveTrueAndDeletedAtIsNullAndCategoryActiveTrueAndCategoryDeletedAtIsNullOrderByDisplayOrderAscNameAsc()
                : services.findByActiveTrueAndDeletedAtIsNullAndCategoryActiveTrueAndCategoryDeletedAtIsNullAndCategorySlugOrderByDisplayOrderAscNameAsc(categorySlug);
        return new CatalogueDtos.CatalogueResponse(categoryItems.stream().map(this::categoryResponse).toList(),
                serviceItems.stream().map(this::serviceResponse).toList());
    }

    @Cacheable(cacheNames = "publicService", key = "#p0")
    @Transactional(readOnly = true)
    public CatalogueDtos.ServiceResponse publicService(String slug) {
        return serviceResponse(services.findBySlugAndActiveTrueAndDeletedAtIsNull(slug)
                .filter(value -> value.getCategory().isActive())
                .orElseThrow(() -> notFound("SERVICE_NOT_FOUND", "Không tìm thấy dịch vụ.")));
    }

    @Transactional(readOnly = true)
    public List<CatalogueDtos.CategoryResponse> adminCategories() {
        return categories.findByDeletedAtIsNullOrderByDisplayOrderAscNameAsc().stream().map(this::categoryResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<CatalogueDtos.ServiceResponse> adminServices() {
        return services.findByDeletedAtIsNullOrderByDisplayOrderAscNameAsc().stream().map(this::serviceResponse).toList();
    }

    @Transactional(readOnly = true)
    public ServiceIconImage publicServiceIcon(UUID id, String hash) {
        CatalogueService value = requireService(id);
        if (value.getIconImageHash() == null || !value.getIconImageHash().equals(hash)) {
            throw notFound("SERVICE_ICON_NOT_FOUND", "Không tìm thấy ảnh biểu tượng dịch vụ.");
        }
        byte[] image = value.getIconImage();
        if (image == null) throw notFound("SERVICE_ICON_NOT_FOUND", "Không tìm thấy ảnh biểu tượng dịch vụ.");
        return new ServiceIconImage(image, value.getIconImageHash());
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public CatalogueDtos.CategoryResponse createCategory(CatalogueDtos.CategoryWriteRequest request) {
        if (categories.existsBySlug(request.slug())) throw conflict("CATEGORY_SLUG_EXISTS", "Slug danh mục đã tồn tại.");
        ServiceCategory value = new ServiceCategory(request.slug(), request.name().trim(),
                trim(request.description()), request.displayOrder(), clock.instant());
        applyCategoryIcon(value,request);
        categories.saveAndFlush(value);
        if(request.quantityFields()!=null)quantity.save(value.getId(),new com.taskly.booking.CategoryQuantityController.Write(request.quantityFields()));
        return categoryResponse(value);
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public CatalogueDtos.CategoryResponse updateCategory(UUID id, CatalogueDtos.CategoryWriteRequest request) {
        ServiceCategory value = requireCategory(id);
        if (categories.existsBySlugAndIdNot(request.slug(), id)) throw conflict("CATEGORY_SLUG_EXISTS", "Slug danh mục đã tồn tại.");
        value.update(request.slug(), request.name().trim(), trim(request.description()), clock.instant());
        value.reorder(request.displayOrder(), clock.instant());
        applyCategoryIcon(value,request);
        if(request.quantityFields()!=null)quantity.save(value.getId(),new com.taskly.booking.CategoryQuantityController.Write(request.quantityFields()));
        return categoryResponse(value);
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public CatalogueDtos.CategoryResponse setCategoryActive(UUID id, boolean active) {
        ServiceCategory value = requireCategory(id); value.setActive(active, clock.instant()); return categoryResponse(value);
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public CatalogueDtos.CategoryResponse reorderCategory(UUID id, int order) {
        ServiceCategory value = requireCategory(id); value.reorder(order, clock.instant()); return categoryResponse(value);
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public void deleteCategory(UUID id) {
        ServiceCategory value = requireCategory(id);
        if (services.existsByCategoryIdAndDeletedAtIsNull(id)) throw conflict("CATEGORY_NOT_EMPTY", "Danh mục còn dịch vụ và không thể xóa.");
        value.delete(clock.instant());
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public CatalogueDtos.ServiceResponse createService(CatalogueDtos.ServiceWriteRequest request) {
        validatePrices(request.suggestedPriceMin(), request.suggestedPriceMax());
        if (services.existsBySlug(request.slug())) throw conflict("SERVICE_SLUG_EXISTS", "Slug dịch vụ đã tồn tại.");
        ServiceCategory category = requireCategory(request.categoryId());
        CatalogueService value = new CatalogueService(category, request.slug(), request.name().trim(),
                request.shortDescription().trim(), trim(request.description()), request.suggestedPriceMin(),
                request.suggestedPriceMax(), request.currency(), request.estimatedDurationMinutes(),
                request.displayOrder(), clock.instant());
        applyIconChanges(value, request);
        return serviceResponse(services.save(value));
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public CatalogueDtos.ServiceResponse updateService(UUID id, CatalogueDtos.ServiceWriteRequest request) {
        validatePrices(request.suggestedPriceMin(), request.suggestedPriceMax());
        CatalogueService value = requireService(id);
        if(!value.getCategory().getId().equals(request.categoryId())) db.update("UPDATE service_pricing_rules SET enabled=false,version=version+1,updated_at=CURRENT_TIMESTAMP WHERE service_id=? AND mode='FIELD'",id);
        if (services.existsBySlugAndIdNot(request.slug(), id)) throw conflict("SERVICE_SLUG_EXISTS", "Slug dịch vụ đã tồn tại.");
        applyIconChanges(value, request);
        value.update(requireCategory(request.categoryId()), request.slug(), request.name().trim(),
                request.shortDescription().trim(), trim(request.description()), request.suggestedPriceMin(),
                request.suggestedPriceMax(), request.currency(), request.estimatedDurationMinutes(), clock.instant());
        value.reorder(request.displayOrder(), clock.instant());
        return serviceResponse(value);
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public CatalogueDtos.ServiceResponse setServiceActive(UUID id, boolean active) {
        CatalogueService value = requireService(id);
        if (active && !value.getCategory().isActive())
            throw new DomainException("CATEGORY_INACTIVE", "Hãy kích hoạt danh mục trước.", HttpStatus.UNPROCESSABLE_ENTITY);
        value.setActive(active, clock.instant()); return serviceResponse(value);
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public CatalogueDtos.ServiceResponse reorderService(UUID id, int order) {
        CatalogueService value = requireService(id); value.reorder(order, clock.instant()); return serviceResponse(value);
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public CatalogueDtos.ServiceResponse setServicePopular(UUID id, boolean popular) {
        CatalogueService value = requireService(id);
        value.setPopular(popular, clock.instant());
        return serviceResponse(value);
    }

    @CacheEvict(cacheNames = {"publicCatalogue", "publicService"}, allEntries = true)
    @Transactional
    public void deleteService(UUID id) { requireService(id).delete(clock.instant()); }

    @Transactional(readOnly=true)
    public ServiceIconImage publicCategoryIcon(UUID id,String hash){
        ServiceCategory value=requireCategory(id);
        if(!hash.equals(value.getIconImageHash()) || value.getIconImage()==null)
            throw notFound("CATEGORY_ICON_NOT_FOUND","Không tìm thấy ảnh danh mục.");
        return new ServiceIconImage(value.getIconImage(),value.getIconImageHash());
    }
    private void applyCategoryIcon(ServiceCategory value,CatalogueDtos.CategoryWriteRequest request){
        if(request.iconKey()!=null)value.setIconKey(icons.validateKey(request.iconKey()),clock.instant());
        if(request.iconDataUrl()!=null){
            var image=request.iconDataUrl().isEmpty()?null:icons.normalize(request.iconDataUrl());
            value.setIconImage(image==null?null:image.pngBytes(),image==null?null:image.hash(),clock.instant());
        }
    }

    private void applyIconChanges(CatalogueService value, CatalogueDtos.ServiceWriteRequest request) {
        String iconKey = request.iconKey() == null ? null : icons.validateKey(request.iconKey());
        ServiceIconProcessor.NormalizedIcon image = request.iconDataUrl() == null || request.iconDataUrl().isEmpty()
                ? null : icons.normalize(request.iconDataUrl());
        if (request.iconKey() != null) value.setIconKey(iconKey, clock.instant());
        if (request.iconDataUrl() != null) {
            value.setIconImage(image == null ? null : image.pngBytes(), image == null ? null : image.hash(), clock.instant());
        }
    }

    private void validatePrices(long min, long max) {
        if (max < min) throw new DomainException("PRICE_RANGE_INVALID", "Giá tối đa phải lớn hơn hoặc bằng giá tối thiểu.", HttpStatus.UNPROCESSABLE_ENTITY);
    }
    private ServiceCategory requireCategory(UUID id) { return categories.findByIdAndDeletedAtIsNull(id).orElseThrow(() -> notFound("CATEGORY_NOT_FOUND", "Không tìm thấy danh mục.")); }
    private CatalogueService requireService(UUID id) { return services.findByIdAndDeletedAtIsNull(id).orElseThrow(() -> notFound("SERVICE_NOT_FOUND", "Không tìm thấy dịch vụ.")); }
    private CatalogueDtos.CategoryResponse categoryResponse(ServiceCategory value) { return new CatalogueDtos.CategoryResponse(value.getId(), value.getSlug(), value.getName(), value.getDescription(), value.isActive(), value.getDisplayOrder(), value.getCreatedAt(), value.getIconKey(), value.getIconImageHash()==null?null:"/api/v1/public/category-icons/"+value.getId()+"/"+value.getIconImageHash()+".png"); }
    private CatalogueDtos.ServiceResponse serviceResponse(CatalogueService value) { return new CatalogueDtos.ServiceResponse(value.getId(), categoryResponse(value.getCategory()), value.getSlug(), value.getName(), value.getShortDescription(), value.getDescription(), value.getSuggestedPriceMin(), value.getSuggestedPriceMax(), value.getCurrency(), value.getEstimatedDurationMinutes(), value.isActive(), value.getDisplayOrder(), value.getCreatedAt(), value.getIconKey(), value.getIconImageHash() == null ? null : "/api/v1/public/service-icons/" + value.getId() + "/" + value.getIconImageHash() + ".png", value.isPopular(), pricingPreview(value.getId())); }
    private CatalogueDtos.PricingPreview pricingPreview(UUID id) {
        var rules=db.query("SELECT mode,base_amount,unit_amount,quantity_field,enabled FROM service_pricing_rules WHERE service_id=?",
            (r,n)->new CatalogueDtos.PricingPreview(r.getString("mode"),r.getLong("base_amount"),r.getLong("unit_amount"),r.getString("quantity_field"),r.getBoolean("enabled")),id);
        return rules.isEmpty()?null:rules.getFirst();
    }
    private String trim(String value) { return value == null ? null : value.trim(); }
    private DomainException notFound(String code, String message) { return new DomainException(code, message, HttpStatus.NOT_FOUND); }
    private DomainException conflict(String code, String message) { return new DomainException(code, message, HttpStatus.CONFLICT); }

    public record ServiceIconImage(byte[] pngBytes, String hash) {}
}
