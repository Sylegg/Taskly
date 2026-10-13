package com.taskly.auth;

import com.taskly.rbac.entity.Permission;
import com.taskly.rbac.entity.Role;
import com.taskly.user.entity.UserAccount;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.stereotype.Service;

@Service
public class JwtService {
    private final JwtEncoder encoder;
    private final AuthProperties properties;

    public JwtService(JwtEncoder encoder, AuthProperties properties) {
        this.encoder = encoder;
        this.properties = properties;
    }

    public IssuedAccessToken issue(UserAccount user, Instant now) {
        Instant expiresAt = now.plus(properties.accessTtlMinutes(), ChronoUnit.MINUTES);
        List<String> roles = user.getRoles().stream().map(Role::getKey).sorted().toList();
        List<String> permissions = user.getRoles().stream()
                .flatMap(role -> role.getPermissions().stream())
                .map(Permission::getKey)
                .distinct()
                .sorted()
                .toList();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("taskly")
                .issuedAt(now)
                .expiresAt(expiresAt)
                .subject(user.getId().toString())
                .claim("email", user.getEmail())
                .claim("mode", user.getActiveMode().name())
                .claim("roles", roles)
                .claim("permissions", permissions)
                .build();
        String token = encoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
        return new IssuedAccessToken(token, expiresAt);
    }

    public record IssuedAccessToken(String value, Instant expiresAt) {}
}
