package com.taskly.catalogue;

import com.taskly.catalogue.dto.CatalogueDtos;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasAuthority('SERVICE_MANAGE')")
public class AdminCatalogueController {
    private final CatalogueApplicationService catalogue;
    public AdminCatalogueController(CatalogueApplicationService catalogue) { this.catalogue = catalogue; }

    @GetMapping("/service-categories")
    ApiResponse<List<CatalogueDtos.CategoryResponse>> categories() { return ApiResponse.success(catalogue.adminCategories()); }
    @PostMapping("/service-categories")
    ApiResponse<CatalogueDtos.CategoryResponse> createCategory(@Valid @RequestBody CatalogueDtos.CategoryWriteRequest request) { return ApiResponse.success(catalogue.createCategory(request)); }
    @PatchMapping("/service-categories/{id}")
    ApiResponse<CatalogueDtos.CategoryResponse> updateCategory(@PathVariable UUID id, @Valid @RequestBody CatalogueDtos.CategoryWriteRequest request) { return ApiResponse.success(catalogue.updateCategory(id, request)); }
    @PostMapping("/service-categories/{id}/activate")
    ApiResponse<CatalogueDtos.CategoryResponse> activateCategory(@PathVariable UUID id) { return ApiResponse.success(catalogue.setCategoryActive(id, true)); }
    @PostMapping("/service-categories/{id}/deactivate")
    ApiResponse<CatalogueDtos.CategoryResponse> deactivateCategory(@PathVariable UUID id) { return ApiResponse.success(catalogue.setCategoryActive(id, false)); }
    @PostMapping("/service-categories/{id}/order")
    ApiResponse<CatalogueDtos.CategoryResponse> orderCategory(@PathVariable UUID id, @Valid @RequestBody CatalogueDtos.OrderRequest request) { return ApiResponse.success(catalogue.reorderCategory(id, request.displayOrder())); }
    @DeleteMapping("/service-categories/{id}")
    ApiResponse<Void> deleteCategory(@PathVariable UUID id) { catalogue.deleteCategory(id); return ApiResponse.success(null, "Đã xóa danh mục."); }

    @GetMapping("/services")
    ApiResponse<List<CatalogueDtos.ServiceResponse>> services() { return ApiResponse.success(catalogue.adminServices()); }
    @PostMapping("/services")
    ApiResponse<CatalogueDtos.ServiceResponse> createService(@Valid @RequestBody CatalogueDtos.ServiceWriteRequest request) { return ApiResponse.success(catalogue.createService(request)); }
    @PatchMapping("/services/{id}")
    ApiResponse<CatalogueDtos.ServiceResponse> updateService(@PathVariable UUID id, @Valid @RequestBody CatalogueDtos.ServiceWriteRequest request) { return ApiResponse.success(catalogue.updateService(id, request)); }
    @PostMapping("/services/{id}/activate")
    ApiResponse<CatalogueDtos.ServiceResponse> activateService(@PathVariable UUID id) { return ApiResponse.success(catalogue.setServiceActive(id, true)); }
    @PostMapping("/services/{id}/deactivate")
    ApiResponse<CatalogueDtos.ServiceResponse> deactivateService(@PathVariable UUID id) { return ApiResponse.success(catalogue.setServiceActive(id, false)); }
    @PostMapping("/services/{id}/order")
    ApiResponse<CatalogueDtos.ServiceResponse> orderService(@PathVariable UUID id, @Valid @RequestBody CatalogueDtos.OrderRequest request) { return ApiResponse.success(catalogue.reorderService(id, request.displayOrder())); }
    @PatchMapping("/services/{id}/popular")
    ApiResponse<CatalogueDtos.ServiceResponse> popularService(@PathVariable UUID id, @Valid @RequestBody CatalogueDtos.PopularRequest request) { return ApiResponse.success(catalogue.setServicePopular(id, request.popular())); }
    @DeleteMapping("/services/{id}")
    ApiResponse<Void> deleteService(@PathVariable UUID id) { catalogue.deleteService(id); return ApiResponse.success(null, "Đã xóa dịch vụ."); }
}
