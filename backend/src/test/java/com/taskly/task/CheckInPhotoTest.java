package com.taskly.task;

import com.taskly.common.exception.DomainException;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;
import org.springframework.jdbc.core.JdbcTemplate;

class CheckInPhotoTest {
    @Test void rejectsMissingPhotoBeforeChangingTask() {
        var db = mock(JdbcTemplate.class);
        var service = new EarlyStartService(db, null, null);
        for (String photo : new String[]{null, "", " "}) {
            assertThrows(DomainException.class, () ->
                service.checkInWithPhoto(null, null, null, null, "PHOTO", "test", photo));
        }
        verifyNoInteractions(db);
    }

    @Test void rejectsFakeImageBeforeChangingTask() {
        var db = mock(JdbcTemplate.class);
        var service = new EarlyStartService(db, null, null);
        assertThrows(DomainException.class, () ->
            service.checkInWithPhoto(null, null, null, null, "PHOTO", "test", "data:image/jpeg;base64,aGVsbG8="));
        verifyNoInteractions(db);
    }
}
