package com.taskly.auth;

import org.springframework.beans.factory.annotation.Value;
import com.taskly.common.exception.DomainException;
import org.springframework.http.HttpStatus;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class OtpMailSender {
    private final JavaMailSender mailSender;
    private final String from;
    private final int ttlMinutes;

    public OtpMailSender(JavaMailSender mailSender, @Value("${app.mail.from}") String from,
                         @Value("${app.auth.otp-ttl-minutes}") int ttlMinutes) {
        this.mailSender = mailSender;
        this.from = from;
        this.ttlMinutes = ttlMinutes;
    }

    public void sendVerification(String email, String code) {
        send(email, "Xác minh tài khoản TaskLy", "Mã xác minh TaskLy của bạn là " + code);
    }

    public void sendPasswordReset(String email, String code) {
        send(email, "Khôi phục mật khẩu TaskLy", "Mã khôi phục mật khẩu TaskLy của bạn là " + code);
    }

    private void send(String email, String subject, String body) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(from);
        message.setTo(email);
        message.setSubject(subject);
        message.setText(body + ".\nMã có hiệu lực trong " + ttlMinutes
                + " phút. Không chia sẻ mã này với bất kỳ ai.\nNếu bạn không yêu cầu, hãy bỏ qua email này.");
        try {
            mailSender.send(message);
        } catch (MailException failure) {
            throw new DomainException("EMAIL_DELIVERY_FAILED",
                    "Chưa gửi được email xác minh. Vui lòng thử lại sau.", HttpStatus.SERVICE_UNAVAILABLE);
        }
    }
}
