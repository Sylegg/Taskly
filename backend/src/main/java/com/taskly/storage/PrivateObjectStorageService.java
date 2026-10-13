package com.taskly.storage;

import com.taskly.common.exception.DomainException;
import com.taskly.storage.entity.FileScanStatus;
import com.taskly.storage.entity.StoredObject;
import com.taskly.storage.repository.StoredObjectRepository;
import com.taskly.user.entity.UserAccount;
import io.minio.BucketExistsArgs;
import io.minio.GetPresignedObjectUrlArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.Http.Method;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.security.MessageDigest;
import java.time.Clock;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import javax.imageio.ImageIO;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class PrivateObjectStorageService {
    private static final Set<String> ALLOWED_TYPES = Set.of("image/jpeg", "image/png");
    private final MinioClient minio;
    private final StorageProperties properties;
    private final StoredObjectRepository objects;
    private final Clock clock;
    private volatile boolean bucketReady;
    @org.springframework.beans.factory.annotation.Value("${app.storage.local-directory:}")
    private String localDirectory = "";
    @org.springframework.beans.factory.annotation.Value("${app.storage.public-base-url:http://127.0.0.1:8080}")
    private String publicBaseUrl;


    public PrivateObjectStorageService(MinioClient minio, StorageProperties properties,
                                       StoredObjectRepository objects, Clock clock) {
        this.minio = minio;
        this.properties = properties;
        this.objects = objects;
        this.clock = clock;
    }

    @Transactional
    public StoredObject uploadKycImage(UserAccount owner, String side, MultipartFile file) {
        ValidatedImage image = validate(file);
        String extension = image.contentType().equals("image/png") ? ".png" : ".jpg";
        String objectKey = "kyc/" + owner.getId() + "/" + UUID.randomUUID() + extension;
        try {
            if (!localDirectory.isBlank()) {
                java.nio.file.Path target = localPath(objectKey);
                java.nio.file.Files.createDirectories(target.getParent());
                java.nio.file.Files.write(target, image.bytes(), java.nio.file.StandardOpenOption.CREATE_NEW);
            } else {
            ensureBucket();
            minio.putObject(PutObjectArgs.builder()
                    .bucket(properties.privateBucket())
                    .object(objectKey)
                    .stream(new ByteArrayInputStream(image.bytes()), (long) image.bytes().length, -1L)
                    .contentType(image.contentType())
                    .build());
            }
        } catch (Exception failure) {
            throw new DomainException("STORAGE_UNAVAILABLE", "Không thể lưu tệp lúc này. Vui lòng thử lại.", HttpStatus.SERVICE_UNAVAILABLE);
        }
        StoredObject stored = new StoredObject(
                owner, "KYC_" + side, properties.privateBucket(), objectKey,
                safeFilename(file.getOriginalFilename()), image.contentType(), image.bytes().length,
                sha256(image.bytes()), FileScanStatus.CLEAN, clock.instant());
        return objects.save(stored);
    }

    public String signedReadUrl(StoredObject object) {
        if (object.getScanStatus() != FileScanStatus.CLEAN) {
            throw new DomainException("FILE_BLOCKED", "Tệp đã bị chặn.", HttpStatus.GONE);
        }
        if (!localDirectory.isBlank()) {
            long expires = clock.instant().getEpochSecond() + properties.signedUrlSeconds();
            return publicBaseUrl + "/api/v1/public/identity-images/" + object.getId()
                    + "?expires=" + expires + "&signature=" + signature(object.getId(), expires);
        }
        try {
            return minio.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                    .method(Method.GET)
                    .bucket(object.getBucketName())
                    .object(object.getObjectKey())
                    .expiry(properties.signedUrlSeconds())
                    .build());
        } catch (Exception failure) {
            throw new DomainException("STORAGE_UNAVAILABLE", "Không thể mở tệp lúc này.", HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    private java.nio.file.Path localPath(String key) {
        var root = java.nio.file.Path.of(localDirectory).toAbsolutePath().normalize();
        var target = root.resolve(key).normalize();
        if (!target.startsWith(root)) throw new IllegalArgumentException("Invalid object key");
        return target;
    }

    private String signature(UUID id, long expires) {
        try {
            var mac = javax.crypto.Mac.getInstance("HmacSHA256");
            mac.init(new javax.crypto.spec.SecretKeySpec(properties.secretKey().getBytes(java.nio.charset.StandardCharsets.UTF_8), "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal((id + ":" + expires).getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (Exception e) { throw new IllegalStateException(e); }
    }

    public org.springframework.http.ResponseEntity<byte[]> readLocal(UUID id, long expires, String token) {
        if (localDirectory.isBlank() || expires <= clock.instant().getEpochSecond()
                || !MessageDigest.isEqual(signature(id, expires).getBytes(java.nio.charset.StandardCharsets.UTF_8), token.getBytes(java.nio.charset.StandardCharsets.UTF_8))) {
            throw new DomainException("FILE_LINK_EXPIRED", "Invalid or expired image link", HttpStatus.FORBIDDEN);
        }
        var object = objects.findById(id).orElseThrow(() -> new DomainException("FILE_NOT_FOUND", "Image not found", HttpStatus.NOT_FOUND));
        if (object.getScanStatus() != FileScanStatus.CLEAN) throw new DomainException("FILE_BLOCKED", "Image blocked", HttpStatus.GONE);
        try {
            return org.springframework.http.ResponseEntity.ok()
                    .header("Cache-Control", "no-store").header("X-Content-Type-Options", "nosniff")
                    .contentType(org.springframework.http.MediaType.parseMediaType(object.getContentType()))
                    .body(java.nio.file.Files.readAllBytes(localPath(object.getObjectKey())));
        } catch (java.io.IOException e) { throw new DomainException("FILE_NOT_FOUND", "Image not found", HttpStatus.NOT_FOUND); }
    }

    private ValidatedImage validate(MultipartFile file) {
        if (file == null || file.isEmpty() || file.getSize() > properties.maxImageBytes()) {
            throw new DomainException("FILE_SIZE_INVALID", "Ảnh trống hoặc vượt giới hạn dung lượng.", HttpStatus.BAD_REQUEST);
        }
        String contentType = file.getContentType() == null ? "" : file.getContentType().toLowerCase(Locale.ROOT);
        if (!ALLOWED_TYPES.contains(contentType)) {
            throw new DomainException("FILE_TYPE_INVALID", "Chỉ chấp nhận ảnh JPEG hoặc PNG.", HttpStatus.BAD_REQUEST);
        }
        try {
            byte[] bytes = file.getBytes();
            if (!matchesMagic(bytes, contentType)) {
                throw new DomainException("FILE_SIGNATURE_INVALID", "Nội dung tệp không khớp định dạng ảnh.", HttpStatus.BAD_REQUEST);
            }
            BufferedImage decoded = ImageIO.read(new ByteArrayInputStream(bytes));
            if (decoded == null || decoded.getWidth() < 200 || decoded.getHeight() < 200
                    || decoded.getWidth() > 12000 || decoded.getHeight() > 12000) {
                throw new DomainException("IMAGE_INVALID", "Ảnh không đọc được hoặc kích thước không phù hợp.", HttpStatus.BAD_REQUEST);
            }
            // Re-encode decoded pixels to discard metadata and any appended payload.
            var sanitized = new java.io.ByteArrayOutputStream();
            if (!ImageIO.write(decoded, contentType.equals("image/png") ? "png" : "jpg", sanitized)) {
                throw new IllegalStateException("Cannot encode image");
            }
            if (sanitized.size() > properties.maxImageBytes()) {
                throw new DomainException("FILE_SIZE_INVALID", "Encoded image exceeds size limit", HttpStatus.BAD_REQUEST);
            }
            return new ValidatedImage(sanitized.toByteArray(), contentType);
        } catch (DomainException known) {
            throw known;
        } catch (Exception failure) {
            throw new DomainException("FILE_READ_FAILED", "Không thể đọc tệp tải lên.", HttpStatus.BAD_REQUEST);
        }
    }

    private boolean matchesMagic(byte[] bytes, String contentType) {
        if (contentType.equals("image/png")) {
            return bytes.length >= 8 && bytes[0] == (byte) 0x89 && bytes[1] == 0x50
                    && bytes[2] == 0x4E && bytes[3] == 0x47;
        }
        return bytes.length >= 3 && bytes[0] == (byte) 0xFF && bytes[1] == (byte) 0xD8 && bytes[2] == (byte) 0xFF;
    }

    private synchronized void ensureBucket() {
        if (bucketReady) return;
        try {
            boolean exists = minio.bucketExists(BucketExistsArgs.builder().bucket(properties.privateBucket()).build());
            if (!exists) minio.makeBucket(MakeBucketArgs.builder().bucket(properties.privateBucket()).build());
            bucketReady = true;
        } catch (Exception failure) {
            throw new DomainException("STORAGE_UNAVAILABLE", "Kho tệp tạm thời không khả dụng.", HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    private String safeFilename(String value) {
        if (value == null) return null;
        String cleaned = value.replaceAll("[^A-Za-z0-9._-]", "_");
        return cleaned.substring(0, Math.min(cleaned.length(), 200));
    }

    private String sha256(byte[] bytes) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (java.security.NoSuchAlgorithmException impossible) {
            throw new IllegalStateException(impossible);
        }
    }

    private record ValidatedImage(byte[] bytes, String contentType) {}
}
