package com.taskly.catalogue;

import com.taskly.catalogue.dto.CatalogueDtos;
import com.taskly.common.api.ApiResponse;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/public")
public class PublicCatalogueController {
    private final CatalogueApplicationService catalogue;
    public PublicCatalogueController(CatalogueApplicationService catalogue) { this.catalogue = catalogue; }

    @GetMapping("/services")
    ApiResponse<CatalogueDtos.CatalogueResponse> catalogue(@RequestParam(required = false) String category) {
        return ApiResponse.success(catalogue.publicCatalogue(category));
    }

    @GetMapping("/services/{slug}")
    ApiResponse<CatalogueDtos.ServiceResponse> service(@PathVariable String slug) {
        return ApiResponse.success(catalogue.publicService(slug));
    }
}
