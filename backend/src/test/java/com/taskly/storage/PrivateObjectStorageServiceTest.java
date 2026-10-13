package com.taskly.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

import com.taskly.common.exception.DomainException;
import com.taskly.storage.repository.StoredObjectRepository;
import com.taskly.user.entity.UserAccount;
import io.minio.MinioClient;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.time.Clock;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

class PrivateObjectStorageServiceTest {
    @Test void refusesUnscannedOrFailedPrivateFilesBeforeIssuingSignedUrl() {
        for (var status : java.util.List.of(com.taskly.storage.entity.FileScanStatus.PENDING,
                com.taskly.storage.entity.FileScanStatus.FAILED, com.taskly.storage.entity.FileScanStatus.INFECTED)) {
            var object = new com.taskly.storage.entity.StoredObject(mock(UserAccount.class),"KYC","private","fake",
                    "sample.png","image/png",100,"hash",status,java.time.Instant.now());
            assertThatThrownBy(() -> service.signedReadUrl(object)).isInstanceOf(DomainException.class);
        }
    }
    private final PrivateObjectStorageService service = new PrivateObjectStorageService(
            mock(MinioClient.class),
            new StorageProperties("http://storage", "access", "secret", "private", 10_000_000, 300),
            mock(StoredObjectRepository.class), Clock.systemUTC());

    @Test
    void rejectsContentWhoseMagicBytesDoNotMatchDeclaredMimeType() {
        var file = new MockMultipartFile("file", "identity.png", "image/png", "not-an-image".getBytes());

        assertThatThrownBy(() -> service.uploadKycImage(mock(UserAccount.class), "FRONT", file))
                .isInstanceOfSatisfying(DomainException.class,
                        failure -> assertThat(failure.getCode()).isEqualTo("FILE_SIGNATURE_INVALID"));
    }

    @Test
    void rejectsDecodedImageBelowMinimumDimensions() throws Exception {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(100, 100, BufferedImage.TYPE_INT_RGB), "png", output);
        var file = new MockMultipartFile("file", "tiny.png", "image/png", output.toByteArray());

        assertThatThrownBy(() -> service.uploadKycImage(mock(UserAccount.class), "FRONT", file))
                .isInstanceOfSatisfying(DomainException.class,
                        failure -> assertThat(failure.getCode()).isEqualTo("IMAGE_INVALID"));
    }

    @Test
    void rejectsOversizedUploadBeforeCallingObjectStorage() {
        var file = new MockMultipartFile("file", "large.jpg", "image/jpeg", new byte[10_000_001]);

        assertThatThrownBy(() -> service.uploadKycImage(mock(UserAccount.class), "FRONT", file))
                .isInstanceOfSatisfying(DomainException.class,
                        failure -> assertThat(failure.getCode()).isEqualTo("FILE_SIZE_INVALID"));
    }
}
