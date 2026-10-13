package com.taskly.user;

import com.taskly.auth.RefreshTokenService;
import com.taskly.common.exception.DomainException;
import com.taskly.rbac.entity.Permission;
import com.taskly.rbac.entity.Role;
import com.taskly.rbac.repository.RoleRepository;
import com.taskly.user.dto.UserDtos;
import com.taskly.user.entity.Address;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.entity.UserMode;
import com.taskly.user.entity.UserProfile;
import com.taskly.user.repository.AddressRepository;
import com.taskly.user.repository.UserAccountRepository;
import com.taskly.user.repository.UserProfileRepository;
import com.taskly.verification.entity.TaskerProfile;
import com.taskly.verification.repository.TaskerProfileRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {
    private final UserAccountRepository users;
    private final UserProfileRepository profiles;
    private final AddressRepository addresses;
    private final RoleRepository roles;
    private final PasswordEncoder passwordEncoder;
    private final RefreshTokenService refreshTokens;
    private final TaskerProfileRepository taskerProfiles;
    private final Clock clock;
    @org.springframework.beans.factory.annotation.Autowired
    private org.springframework.jdbc.core.JdbcTemplate db;

    private boolean nameLocked(UUID id) {
        return Boolean.TRUE.equals(db.queryForObject(
                "SELECT EXISTS(SELECT 1 FROM partner_applications WHERE user_id=?)", Boolean.class, id));
    }

    public UserService(UserAccountRepository users, UserProfileRepository profiles, AddressRepository addresses,
                       RoleRepository roles, PasswordEncoder passwordEncoder,
                       RefreshTokenService refreshTokens, TaskerProfileRepository taskerProfiles, Clock clock) {
        this.users = users;
        this.profiles = profiles;
        this.addresses = addresses;
        this.roles = roles;
        this.passwordEncoder = passwordEncoder;
        this.refreshTokens = refreshTokens;
        this.taskerProfiles = taskerProfiles;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public UserDtos.MeResponse me(UUID userId) {
        UserAccount user = requireUser(userId);
        UserProfile profile = requireProfile(userId);
        List<String> roleKeys = user.getRoles().stream().map(Role::getKey).sorted().toList();
        List<String> permissions = user.getRoles().stream()
                .flatMap(role -> role.getPermissions().stream()).map(Permission::getKey)
                .distinct().sorted().toList();
        return new UserDtos.MeResponse(
                user.getId(), user.getEmail(), user.getPhone(), profile.getFullName(), profile.getLanguage(),
                user.getStatus(), user.getActiveMode(), roleKeys, permissions, nameLocked(userId));
    }

    @Transactional
    public UserDtos.MeResponse updateProfile(UUID userId, UserDtos.UpdateProfileRequest request) {
        UserAccount user = requireUser(userId);
        if (nameLocked(userId) && !request.fullName().trim().equals(requireProfile(userId).getFullName())) {
            throw new DomainException("NAME_LOCKED", "Tên tài khoản theo hồ sơ CCCD và không thể tự chỉnh sửa.", HttpStatus.CONFLICT);
        }
        if (request.phone() != null && !request.phone().isBlank()) {
            String newPhone = request.phone().trim();
            if (!newPhone.equals(user.getPhone())) {
                if (users.existsByPhone(newPhone)) {
                    throw new DomainException("PHONE_ALREADY_EXISTS", "Số điện thoại này đã được sử dụng.", HttpStatus.CONFLICT);
                }
                user.changePhone(newPhone, clock.instant());
            }
        }
        requireProfile(userId).update(request.fullName().trim(), request.language(), clock.instant());
        return me(userId);
    }

    @Transactional
    public void changePassword(UUID userId, UserDtos.ChangePasswordRequest request) {
        UserAccount user = requireUser(userId);
        if (!passwordEncoder.matches(request.currentPassword(), user.getPasswordHash())) {
            throw new DomainException("CURRENT_PASSWORD_INVALID", "Mật khẩu hiện tại chưa đúng.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        if (passwordEncoder.matches(request.newPassword(), user.getPasswordHash())) {
            throw new DomainException("PASSWORD_REUSED", "Mật khẩu mới phải khác mật khẩu hiện tại.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        Instant now = clock.instant();
        user.changePassword(passwordEncoder.encode(request.newPassword()), now);
        refreshTokens.revokeAll(userId, now);
    }

    @Transactional
    public UserDtos.MeResponse enableTasker(UUID userId) {
        UserAccount user = requireUser(userId);
        Role tasker = roles.findByKey("TASKER").orElseThrow(() -> new IllegalStateException("TASKER role seed is missing"));
        Instant now = clock.instant();
        user.enableRole(tasker, now);
        taskerProfiles.findById(userId).orElseGet(() -> taskerProfiles.save(new TaskerProfile(user, now)));
        return me(userId);
    }

    @Transactional
    public UserDtos.MeResponse switchMode(UUID userId, UserMode mode) {
        if (mode == null) throw new DomainException("MODE_REQUIRED", "Vui lòng chọn chế độ.", HttpStatus.BAD_REQUEST);
        UserAccount user = requireUser(userId);
        try {
            user.switchMode(mode, clock.instant());
        } catch (IllegalStateException notEnabled) {
            throw new DomainException("TASKER_MODE_NOT_ENABLED", "Hãy bật chế độ Tasker trước.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        return me(userId);
    }

    @Transactional(readOnly = true)
    public List<UserDtos.AddressResponse> addresses(UUID userId) {
        requireUser(userId);
        return addresses.findByUserIdAndDeletedAtIsNullOrderByDefaultAddressDescCreatedAtAsc(userId)
                .stream().map(this::addressResponse).toList();
    }

    @Transactional
    public UserDtos.AddressResponse createAddress(UUID userId, UserDtos.AddressRequest request) {
        UserAccount user = requireUser(userId);
        Instant now = clock.instant();
        boolean makeDefault = request.defaultAddress() || addresses.countByUserIdAndDeletedAtIsNull(userId) == 0;
        if (makeDefault) clearDefault(userId, now);
        Address address = new Address(user, request.label().trim(), trim(request.recipientName()), request.recipientPhone(),
                request.addressLine().trim(), trim(request.ward()), trim(request.district()), request.city().trim(),
                request.latitude(), request.longitude(), trim(request.notes()), makeDefault, now);
        address.setBuildingDetails(trim(request.buildingType()), trim(request.buildingDescription()));
        return addressResponse(addresses.save(address));
    }

    @Transactional
    public UserDtos.AddressResponse updateAddress(UUID userId, UUID id, UserDtos.AddressRequest request) {
        Address address = requireAddress(userId, id);
        Instant now = clock.instant();
        boolean makeDefault = request.defaultAddress() || address.isDefaultAddress();
        if (request.defaultAddress()) clearDefault(userId, now);
        address.update(request.label().trim(), trim(request.recipientName()), request.recipientPhone(),
                request.addressLine().trim(), trim(request.ward()), trim(request.district()), request.city().trim(),
                request.latitude(), request.longitude(), trim(request.notes()), makeDefault, now);
        address.setBuildingDetails(trim(request.buildingType()), trim(request.buildingDescription()));
        return addressResponse(address);
    }

    @Transactional
    public void setDefaultAddress(UUID userId, UUID id) {
        Address address = requireAddress(userId, id);
        Instant now = clock.instant();
        clearDefault(userId, now);
        address.setDefaultAddress(true, now);
    }

    @Transactional
    public void deleteAddress(UUID userId, UUID id) {
        Address address = requireAddress(userId, id);
        boolean wasDefault = address.isDefaultAddress();
        Instant now = clock.instant();
        address.softDelete(now);
        if (wasDefault) {
            addresses.findByUserIdAndDeletedAtIsNullOrderByDefaultAddressDescCreatedAtAsc(userId).stream()
                    .filter(item -> !item.getId().equals(id)).findFirst()
                    .ifPresent(item -> item.setDefaultAddress(true, now));
        }
    }

    private void clearDefault(UUID userId, Instant now) {
        addresses.findByUserIdAndDeletedAtIsNullOrderByDefaultAddressDescCreatedAtAsc(userId)
                .forEach(address -> address.setDefaultAddress(false, now));
    }

    private UserAccount requireUser(UUID id) {
        return users.findById(id).orElseThrow(() ->
                new DomainException("USER_NOT_FOUND", "Không tìm thấy tài khoản.", HttpStatus.NOT_FOUND));
    }

    private UserProfile requireProfile(UUID id) {
        return profiles.findById(id).orElseThrow(() ->
                new DomainException("PROFILE_NOT_FOUND", "Không tìm thấy hồ sơ.", HttpStatus.NOT_FOUND));
    }

    private Address requireAddress(UUID userId, UUID id) {
        return addresses.findByIdAndUserIdAndDeletedAtIsNull(id, userId).orElseThrow(() ->
                new DomainException("ADDRESS_NOT_FOUND", "Không tìm thấy địa chỉ.", HttpStatus.NOT_FOUND));
    }

    private UserDtos.AddressResponse addressResponse(Address value) {
        return new UserDtos.AddressResponse(value.getId(), value.getLabel(), value.getRecipientName(),
                value.getRecipientPhone(), value.getAddressLine(), value.getWard(), value.getDistrict(),
                value.getCity(), value.getLatitude(), value.getLongitude(), value.getNotes(), value.isDefaultAddress(), value.getBuildingType(), value.getBuildingDescription());
    }

    private String trim(String value) { return value == null ? null : value.trim(); }
}
