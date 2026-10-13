package com.taskly.verification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.taskly.common.exception.DomainException;
import com.taskly.rbac.entity.Role;
import com.taskly.storage.PrivateObjectStorageService;
import com.taskly.storage.StorageProperties;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.repository.UserAccountRepository;
import com.taskly.verification.dto.VerificationDtos;
import com.taskly.verification.entity.IdentityVerification;
import com.taskly.verification.repository.IdentityVerificationRepository;
import com.taskly.verification.repository.TaskerProfileRepository;
import com.taskly.verification.repository.VerificationDocumentRepository;
import com.taskly.verification.repository.VerificationHistoryRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class VerificationServiceTest {
    private final UserAccountRepository users = mock(UserAccountRepository.class);
    private final TaskerProfileRepository taskerProfiles = mock(TaskerProfileRepository.class);
    private final IdentityVerificationRepository verifications = mock(IdentityVerificationRepository.class);
    private final VerificationDocumentRepository documents = mock(VerificationDocumentRepository.class);
    private final VerificationHistoryRepository history = mock(VerificationHistoryRepository.class);
    private final PrivateObjectStorageService storage = mock(PrivateObjectStorageService.class);
    private final StorageProperties storageProperties = mock(StorageProperties.class);
    private final Instant now = Instant.parse("2026-09-29T08:00:00Z");
    private VerificationService service;

    @BeforeEach
    void setUp() {
        service = new VerificationService(users, taskerProfiles, verifications, documents, history,
                storage, storageProperties, Clock.fixed(now, ZoneOffset.UTC), mock(com.taskly.recruitment.RecruitmentService.class));
    }

    @Test
    void incompleteIdentityCanBeSavedAsDraftButCannotBeSubmitted() {
        UserAccount user = user();
        IdentityVerification value = new IdentityVerification(user, now);
        when(verifications.findByIdAndUserId(value.getId(), user.getId())).thenReturn(Optional.of(value));
        when(documents.findByVerificationId(value.getId())).thenReturn(List.of());
        var saved=service.updateDraft(user.getId(),value.getId(),new VerificationDtos.DraftRequest("Tên nháp","NATIONAL_ID",""));
        assertThat(saved.legalName()).isEqualTo("Tên nháp");
        assertThat(saved.status()).isEqualTo(com.taskly.verification.entity.VerificationStatus.DRAFT);
        assertThatThrownBy(()->service.submit(user.getId(),value.getId(),new VerificationDtos.SubmitRequest(true)))
            .isInstanceOfSatisfying(DomainException.class,failure->assertThat(failure.getCode()).isEqualTo("KYC_INCOMPLETE"));
    }

    @Test
    void draftStoresOnlyMaskedDocumentNumber() {
        UserAccount user = user();
        IdentityVerification verification = new IdentityVerification(user, now);
        when(verifications.findByIdAndUserId(verification.getId(), user.getId()))
                .thenReturn(Optional.of(verification));
        when(documents.findByVerificationId(verification.getId())).thenReturn(List.of());

        var response = service.updateDraft(user.getId(), verification.getId(),
                new VerificationDtos.DraftRequest("Nguyen Van A", "NATIONAL_ID", "001234567890"));

        assertThat(response.documentNumberMasked()).isEqualTo("********7890");
        assertThat(response.documentNumberMasked()).doesNotContain("0012");
    }

    @Test
    void anotherUserCannotEditVerification() {
        UUID ownerId = UUID.randomUUID();
        UUID attackerId = UUID.randomUUID();
        UUID verificationId = UUID.randomUUID();
        when(verifications.findByIdAndUserId(verificationId, attackerId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.updateDraft(attackerId, verificationId,
                new VerificationDtos.DraftRequest("Nguyen Van A", "NATIONAL_ID", "001234567890")))
                .isInstanceOfSatisfying(DomainException.class,
                        failure -> assertThat(failure.getCode()).isEqualTo("KYC_NOT_FOUND"));
    }

    @Test
    void submittedVerificationCannotReturnToDraft() {
        UserAccount user = user();
        IdentityVerification verification = new IdentityVerification(user, now);
        verification.updateDraft("Nguyen Van A", "NATIONAL_ID", "********7890", now);
        verification.submit(now);
        when(verifications.findByIdAndUserId(verification.getId(), user.getId()))
                .thenReturn(Optional.of(verification));

        assertThatThrownBy(() -> service.updateDraft(user.getId(), verification.getId(),
                new VerificationDtos.DraftRequest("Changed Name", "PASSPORT", "A1234567")))
                .isInstanceOfSatisfying(DomainException.class,
                        failure -> assertThat(failure.getCode()).isEqualTo("KYC_NOT_EDITABLE"));
    }

    @Test
    void portraitUploadIsStoredAsIdentityEvidence() {
        UserAccount user = user();
        IdentityVerification value = new IdentityVerification(user, now);
        var side = com.taskly.verification.entity.DocumentSide.SELFIE;
        var file = new org.springframework.mock.web.MockMultipartFile("file", "portrait.png", "image/png", new byte[]{1, 2});
        var object = mock(com.taskly.storage.entity.StoredObject.class);
        when(verifications.findByIdAndUserId(value.getId(), user.getId())).thenReturn(Optional.of(value));
        when(storage.uploadKycImage(user, "SELFIE", file)).thenReturn(object);
        when(documents.findByVerificationIdAndSide(value.getId(), side)).thenReturn(Optional.empty());
        when(documents.findByVerificationId(value.getId())).thenReturn(List.of());
        service.upload(user.getId(), value.getId(), side, file);
        var saved = org.mockito.ArgumentCaptor.forClass(com.taskly.verification.entity.VerificationDocument.class);
        org.mockito.Mockito.verify(documents).save(saved.capture());
        assertThat(saved.getValue().getSide()).isEqualTo(side);
        assertThat(saved.getValue().getStoredObject()).isSameAs(object);
    }

    @Test
    void nationalIdRejectsLettersSpacesAndWrongLength() {
        UserAccount user=user();var value=new IdentityVerification(user,now);
        when(verifications.findByIdAndUserId(value.getId(),user.getId())).thenReturn(Optional.of(value));
        for (String number:List.of("0012 3456 7890","00123456789A","123","1234567890123")) {
            assertThatThrownBy(() -> service.updateDraft(user.getId(),value.getId(),new VerificationDtos.DraftRequest("Partner Name","NATIONAL_ID",number)))
                .isInstanceOfSatisfying(DomainException.class,e -> assertThat(e.getCode()).isEqualTo("KYC_NUMBER_INVALID"));
        }
    }
    @Test
    void ownerReadsActualSavedNumberWhileGeneralResponseRemainsMasked() {
        var user=user();var value=new IdentityVerification(user,now);
        when(verifications.findByIdAndUserId(value.getId(),user.getId())).thenReturn(Optional.of(value));
        when(verifications.findFirstByUserIdOrderByCreatedAtDesc(user.getId())).thenReturn(Optional.of(value));
        when(documents.findByVerificationId(value.getId())).thenReturn(List.of());
        assertThat(service.currentOwner(user.getId()).documentNumber()).isNull();
        var saved=service.updateDraft(user.getId(),value.getId(),new VerificationDtos.DraftRequest("Partner Name","NATIONAL_ID","001234567890"));
        assertThat(saved.documentNumber()).isNull();
        assertThat(service.currentOwner(user.getId()).documentNumber()).isEqualTo("001234567890");
        assertThat(service.current(user.getId()).documentNumber()).isNull();
    }
    private UserAccount user() {
        Role customer = mock(Role.class);
        when(customer.getKey()).thenReturn("CUSTOMER");
        return new UserAccount("kyc@example.com", null, "hash", customer, now);
    }
}
