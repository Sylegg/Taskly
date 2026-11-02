package com.taskly.storage;
import java.util.UUID;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
@RestController
@RequestMapping("/api/v1/public/identity-images")
public class LocalIdentityImageController {
 private final PrivateObjectStorageService storage;
 public LocalIdentityImageController(PrivateObjectStorageService storage) { this.storage = storage; }
 @GetMapping("/{id}")
 public ResponseEntity<byte[]> read(@PathVariable UUID id, @RequestParam long expires, @RequestParam String signature) {
  return storage.readLocal(id, expires, signature);
 }
}
