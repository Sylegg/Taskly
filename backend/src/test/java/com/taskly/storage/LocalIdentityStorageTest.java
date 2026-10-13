package com.taskly.storage;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.time.*;
import java.util.*;
import java.nio.file.Path;
import java.io.ByteArrayOutputStream;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.mock.web.MockMultipartFile;
import com.taskly.storage.repository.StoredObjectRepository;
import com.taskly.storage.entity.StoredObject;
import com.taskly.user.entity.UserAccount;
class LocalIdentityStorageTest {
 @TempDir Path directory;
 @Test void realImageSurvivesWriteAndSignedReadButTamperedLinksFail() throws Exception {
  var repository=mock(StoredObjectRepository.class);
  var properties=new StorageProperties("http://localhost:9000","test","test-secret","private",10485760,300);
  var clock=Clock.fixed(Instant.parse("2026-10-10T10:00:00Z"),ZoneOffset.UTC);
  var service=new PrivateObjectStorageService(mock(io.minio.MinioClient.class),properties,repository,clock);
  ReflectionTestUtils.setField(service,"localDirectory",directory.toString());
  ReflectionTestUtils.setField(service,"publicBaseUrl","http://127.0.0.1:8080");
  when(repository.save(any(StoredObject.class))).thenAnswer(invocation->invocation.getArgument(0));
  var owner=mock(UserAccount.class);when(owner.getId()).thenReturn(UUID.randomUUID());
  var bytes=new ByteArrayOutputStream();ImageIO.write(new BufferedImage(240,240,BufferedImage.TYPE_INT_RGB),"png",bytes);
  var stored=service.uploadKycImage(owner,"SELFIE",new MockMultipartFile("file","portrait.png","image/png",bytes.toByteArray()));
  assertTrue(java.nio.file.Files.exists(directory.resolve(stored.getObjectKey())));
  when(repository.findById(stored.getId())).thenReturn(Optional.of(stored));
  var url=service.signedReadUrl(stored);var query=java.net.URI.create(url).getQuery().split("&");
  long expires=Long.parseLong(query[0].split("=")[1]);String signature=query[1].split("=")[1];
  assertArrayEquals(java.nio.file.Files.readAllBytes(directory.resolve(stored.getObjectKey())),service.readLocal(stored.getId(),expires,signature).getBody());
  assertThrows(com.taskly.common.exception.DomainException.class,()->service.readLocal(stored.getId(),expires,"tampered"));
  assertThrows(com.taskly.common.exception.DomainException.class,()->service.readLocal(stored.getId(),clock.instant().getEpochSecond()-1,signature));
 }
}
