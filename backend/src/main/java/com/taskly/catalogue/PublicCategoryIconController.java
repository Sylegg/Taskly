package com.taskly.catalogue;

import java.time.Duration;
import java.util.UUID;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.context.request.WebRequest;

@RestController
@RequestMapping("/api/v1/public/category-icons")
public class PublicCategoryIconController {
    private static final CacheControl ICON_CACHE = CacheControl.maxAge(Duration.ofDays(365)).cachePublic().immutable();
    private final CatalogueApplicationService catalogue;

    public PublicCategoryIconController(CatalogueApplicationService catalogue) { this.catalogue = catalogue; }

    @GetMapping(value = "/{id}/{hash}.png", produces = MediaType.IMAGE_PNG_VALUE)
    ResponseEntity<byte[]> icon(@PathVariable UUID id, @PathVariable String hash, WebRequest request) {
        CatalogueApplicationService.ServiceIconImage image = catalogue.publicCategoryIcon(id, hash);
        boolean unchanged = request.checkNotModified('"' + image.hash() + '"');
        var response = ResponseEntity.status(unchanged ? HttpStatus.NOT_MODIFIED : HttpStatus.OK)
                .contentType(MediaType.IMAGE_PNG)
                .cacheControl(ICON_CACHE)
                .eTag(image.hash())
                .header("X-Content-Type-Options", "nosniff");
        return unchanged ? response.build() : response.body(image.pngBytes());
    }
}
