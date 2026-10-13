package com.taskly.auth;

import com.taskly.common.exception.DomainException;
import org.junit.jupiter.api.Test;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.mockito.ArgumentCaptor;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class OtpMailSenderTest {
    @Test
    void verificationEmailContainsCodeRecipientAndExpiry() {
        JavaMailSender mail = mock(JavaMailSender.class);
        new OtpMailSender(mail, "sender@gmail.com", 5).sendVerification("customer@gmail.com", "012345");
        ArgumentCaptor<SimpleMailMessage> message = ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mail).send(message.capture());
        assertEquals("sender@gmail.com", message.getValue().getFrom());
        assertArrayEquals(new String[]{"customer@gmail.com"}, message.getValue().getTo());
        assertTrue(message.getValue().getText().contains("012345"));
        assertTrue(message.getValue().getText().contains("5 phút"));
    }

    @Test
    void deliveryFailureReturnsUsefulErrorWithoutSmtpDetails() {
        JavaMailSender mail = mock(JavaMailSender.class);
        doThrow(new MailSendException("private SMTP details")).when(mail).send(any(SimpleMailMessage.class));
        DomainException error = assertThrows(DomainException.class,
                () -> new OtpMailSender(mail, "sender@gmail.com", 5).sendVerification("customer@gmail.com", "012345"));
        assertEquals("EMAIL_DELIVERY_FAILED", error.getCode());
        assertFalse(error.getMessage().contains("private SMTP details"));
    }
}
