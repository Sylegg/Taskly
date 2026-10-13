package com.taskly.recruitment;

import com.taskly.catalogue.entity.CatalogueService;
import com.taskly.catalogue.entity.ServiceCategory;
import com.taskly.catalogue.repository.CatalogueServiceRepository;
import com.taskly.catalogue.repository.ServiceCategoryRepository;
import com.taskly.common.exception.DomainException;
import com.taskly.rbac.repository.RoleRepository;
import com.taskly.settings.SystemSettingsService;
import com.taskly.task.AdminTaskController;
import com.taskly.task.entity.CustomerTask;
import com.taskly.task.repository.CustomerTaskRepository;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.repository.UserAccountRepository;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
public class PartnerScheduleBufferTest {

    @Autowired private JdbcTemplate db;
    @Autowired private PartnerSchedulingService schedulingService;
    @Autowired private RecruitmentActivationService activationService;
    @Autowired private SystemSettingsService settingsService;
    @Autowired private AdminTaskController adminTaskController;
    @Autowired private UserAccountRepository users;
    @Autowired private ServiceCategoryRepository categories;
    @Autowired private CatalogueServiceRepository services;
    @Autowired private RoleRepository roles;
    @Autowired private CustomerTaskRepository tasks;
    @Autowired private RecruitmentService recruitment;

    private UserAccount partnerUser;
    private UserAccount otherPartner;
    private UserAccount customerUser;
    private CatalogueService testService;
    private UUID areaId;

    private UserAccount createUser() {
        var role = roles.findByKey("CUSTOMER").orElseThrow();
        var u = new UserAccount(UUID.randomUUID() + "@test.example", null, "hash", role, Instant.now());
        u.verifyEmail(Instant.now());
        return users.saveAndFlush(u);
    }

    @BeforeEach
    void setup() {
        settingsService.setSetting("partner.min_buffer_minutes", "60", "Default 60m buffer");
        settingsService.setSetting("partner.travel_safety_minutes", "15", "Default 15m safety");

        Instant now = Instant.now();
        partnerUser = createUser();
        otherPartner = createUser();
        customerUser = createUser();

        var cat = categories.saveAndFlush(new ServiceCategory("cat-" + UUID.randomUUID(), "Dịch vụ thử nghiệm", "", 0, now));
        testService = services.saveAndFlush(new CatalogueService(cat, "svc-" + UUID.randomUUID(), "Sửa chữa thử nghiệm", "Desc", "", 0, 100000, "VND", 60, 0, now));
        db.update("UPDATE services SET active=true WHERE id=?", testService.getId());

        areaId = UUID.randomUUID();
        recruitment.saveArea(customerUser.getId(), areaId, new RecruitmentDtos.AreaWrite("Hà Nội", "Ba Đình", true, 10, List.of(testService.getId()), 0));

        for(var type:List.of("PARTNER_CONDUCT","PARTNER_SAFETY","PARTNER_COOPERATION","PARTNER_PRIVACY","PARTNER_UNIFORM")){
            var termId=UUID.randomUUID();
            db.update("INSERT INTO terms_versions(id,document_type,version,content_url,effective_at,active,created_at) VALUES(?,?,?,'https://example.test/terms',?,true,?)",
                termId, type, "v1", Timestamp.from(now.minusSeconds(3600)), Timestamp.from(now.minusSeconds(3600)));
        }

        setupActivePartner(partnerUser.getId(), "Đối Tác Thử Nghiệm", "0911000001");
        setupActivePartner(otherPartner.getId(), "Đối Tác 2", "0911000002");
    }

    private void setupActivePartner(UUID userId, String name, String phone) {
        Instant now = Instant.now();
        UUID appId = UUID.randomUUID();
        db.update("""
            INSERT INTO partner_applications(
                id, user_id, status, full_name, contact_phone, date_of_birth,
                exam_passed, training_complete, agreements_current, profile_complete,
                preliminary_approved, uniform_resolved, appointment_checked_in, documents_valid,
                final_approved, skills_configured, areas_configured, availability_configured,
                documents_received_at, activated_at, created_at, updated_at
            ) VALUES (
                ?, ?, 'ACTIVE', ?, ?, '1990-01-01',
                true, true, true, true,
                true, true, true, true,
                true, true, true, true,
                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            )
            """, appId, userId, name, phone);

        db.update("INSERT INTO partner_application_services(application_id, service_id) VALUES (?, ?)", appId, testService.getId());
        db.update("INSERT INTO partner_application_areas(application_id, area_id) VALUES (?, ?)", appId, areaId);
        db.update("INSERT INTO user_profiles(user_id, full_name, created_at, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
            userId, name);
        db.update("INSERT INTO partner_bank_accounts(user_id, bank_name, account_name, account_number, updated_at) VALUES(?, 'MB Bank', ?, '123456789', CURRENT_TIMESTAMP)",
            userId, name);
        db.update("INSERT INTO identity_verifications(id,user_id,status,legal_name,document_type,document_number_masked,reviewed_by,reviewed_at,created_at,updated_at) VALUES(?,?,'APPROVED','Test Identity','NATIONAL_ID','001234567890',?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)", UUID.randomUUID(), userId, userId);
        var allTerms = db.queryForList("SELECT id FROM terms_versions WHERE active=true", UUID.class);
        for(var termId : allTerms) {
            db.update("INSERT INTO user_consents(id,user_id,terms_version_id,accepted_at) VALUES(?,?,?,CURRENT_TIMESTAMP)",
                UUID.randomUUID(), userId, termId);
        }
    }

    private CustomerTask createTask(String title, Instant scheduledAt, int durationMinutes, String status, UUID taskerId) {
        Instant now = Instant.now();
        var task = new CustomerTask(customerUser, testService, title, "Mô tả", "123 Phố Huế", "Hà Nội",
            BigDecimal.valueOf(21.01), BigDecimal.valueOf(105.85), scheduledAt, durationMinutes, 100000, "VND", "", now);
        if ("POSTED".equals(status)) {
            task.post(now);
        }
        task = tasks.saveAndFlush(task);
        if (!"DRAFT".equals(status) && !"POSTED".equals(status)) {
            db.update("UPDATE tasks SET status=?, tasker_id=?, expires_at=NULL WHERE id=?", status, taskerId, task.getId());
        }
        return task;
    }

    // Scenario 1: 10:00–12:00 + 11:00–13:00 -> Blocked by SCHEDULE_CONFLICT
    @Test
    void scenario1_overlapIsBlocked() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        createTask("Task A", t10, 120, "ACCEPTED", partnerUser.getId());

        Instant t11 = Instant.parse("2026-10-15T11:00:00Z");
        var val = schedulingService.validateSchedule(partnerUser.getId(), null, t11, 120, null, null);
        assertFalse(val.eligible());
        assertEquals("SCHEDULE_CONFLICT", val.reasonCode());
        assertTrue(val.message().contains("Trùng lịch"));
    }

    // Scenario 2: 10:00–12:00 + 12:30–14:00 -> Blocked because gap is only 30m (< 60m)
    @Test
    void scenario2_insufficientBufferIsBlocked() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        createTask("Task A", t10, 120, "ACCEPTED", partnerUser.getId());

        Instant t1230 = Instant.parse("2026-10-15T12:30:00Z");
        var val = schedulingService.validateSchedule(partnerUser.getId(), null, t1230, 90, null, null);
        assertFalse(val.eligible());
        assertEquals("BUFFER_TOO_SHORT", val.reasonCode());
        assertTrue(val.message().contains("Cần tối thiểu 60 phút"));
        assertEquals(Instant.parse("2026-10-15T13:00:00Z"), val.earliestEligibleStartAt());
    }

    // Scenario 3: 10:00–12:00 + 12:59 is blocked, + 13:00 is allowed (boundary)
    @Test
    void scenario3_boundaryGapExact60Minutes() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        createTask("Task A", t10, 120, "ACCEPTED", partnerUser.getId());

        // 12:59 -> 59 minutes gap -> Blocked
        Instant t1259 = Instant.parse("2026-10-15T12:59:00Z");
        var val59 = schedulingService.validateSchedule(partnerUser.getId(), null, t1259, 60, null, null);
        assertFalse(val59.eligible());
        assertEquals("BUFFER_TOO_SHORT", val59.reasonCode());

        // 13:00 -> exactly 60 minutes gap -> Allowed
        Instant t1300 = Instant.parse("2026-10-15T13:00:00Z");
        var val60 = schedulingService.validateSchedule(partnerUser.getId(), null, t1300, 60, null, null);
        assertTrue(val60.eligible());
    }

    // Scenario 4: New job is scheduled BEFORE existing job with insufficient buffer
    @Test
    void scenario4_earlierJobWithInsufficientBufferIsBlocked() {
        // Existing job: 14:00 - 16:00
        Instant t14 = Instant.parse("2026-10-15T14:00:00Z");
        createTask("Task Later", t14, 120, "ACCEPTED", partnerUser.getId());

        // Candidate job: 12:30 - 13:30 (ends at 13:30, only 30m before 14:00) -> Blocked
        Instant t1230 = Instant.parse("2026-10-15T12:30:00Z");
        var valBlocked = schedulingService.validateSchedule(partnerUser.getId(), null, t1230, 60, null, null);
        assertFalse(valBlocked.eligible());
        assertEquals("BUFFER_TOO_SHORT", valBlocked.reasonCode());

        // Candidate job: 11:00 - 13:00 (ends at 13:00, exactly 60m before 14:00) -> Allowed
        Instant t11 = Instant.parse("2026-10-15T11:00:00Z");
        var valAllowed = schedulingService.validateSchedule(partnerUser.getId(), null, t11, 120, null, null);
        assertTrue(valAllowed.eligible());
    }

    // Scenario 5: Already has job tomorrow, can still accept job today
    @Test
    void scenario5_tomorrowJobDoesNotBlockToday() {
        Instant tomorrow = Instant.parse("2026-10-16T09:00:00Z");
        createTask("Tomorrow Job", tomorrow, 120, "ACCEPTED", partnerUser.getId());

        Instant today = Instant.parse("2026-10-15T14:00:00Z");
        var val = schedulingService.validateSchedule(partnerUser.getId(), null, today, 120, null, null);
        assertTrue(val.eligible());
    }

    // Scenario 6: Already has job today, can accept job tomorrow / next week
    @Test
    void scenario6_todayJobDoesNotBlockTomorrow() {
        Instant today = Instant.parse("2026-10-15T10:00:00Z");
        createTask("Today Job", today, 120, "ACCEPTED", partnerUser.getId());

        Instant tomorrow = Instant.parse("2026-10-16T09:00:00Z");
        var val = schedulingService.validateSchedule(partnerUser.getId(), null, tomorrow, 120, null, null);
        assertTrue(val.eligible());
    }

    // Scenario 7: Overnight job crossing midnight (23:00–00:30 next day)
    @Test
    void scenario7_overnightJobHandling() {
        Instant t23 = Instant.parse("2026-10-15T23:00:00Z");
        createTask("Overnight Job", t23, 90, "ACCEPTED", partnerUser.getId()); // Ends 2026-10-16T00:30:00Z

        // Next day 01:00 -> gap is 30m -> Blocked
        Instant nextDay0100 = Instant.parse("2026-10-16T01:00:00Z");
        var val30 = schedulingService.validateSchedule(partnerUser.getId(), null, nextDay0100, 60, null, null);
        assertFalse(val30.eligible());
        assertEquals("BUFFER_TOO_SHORT", val30.reasonCode());
        assertEquals(Instant.parse("2026-10-16T01:30:00Z"), val30.earliestEligibleStartAt());

        // Next day 01:30 -> gap is 60m -> Allowed
        Instant nextDay0130 = Instant.parse("2026-10-16T01:30:00Z");
        var val60 = schedulingService.validateSchedule(partnerUser.getId(), null, nextDay0130, 60, null, null);
        assertTrue(val60.eligible());
    }

    // Scenario 8: Verified early completion (scheduled 10:00-12:00, verified actual end 11:00) opens buffer earlier
    @Test
    void scenario8_verifiedEarlyCompletionReleasesBufferEarly() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        var task = createTask("Early Verified Task", t10, 120, "COMPLETED", partnerUser.getId());
        Instant verifiedEnd = Instant.parse("2026-10-15T11:00:00Z");
        db.update("UPDATE tasks SET verified_actual_end_at=? WHERE id=?", Timestamp.from(verifiedEnd), task.getId());

        // Job at 12:00–13:00 (which is 60m after verified 11:00) -> Allowed!
        Instant t12 = Instant.parse("2026-10-15T12:00:00Z");
        var val = schedulingService.validateSchedule(partnerUser.getId(), null, t12, 60, null, null);
        assertTrue(val.eligible());
    }

    // Scenario 9: Self-reported completion without verification retains buffer to scheduled end
    @Test
    void scenario9_unverifiedCompletionRetainsScheduledBuffer() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        createTask("Unverified Completed Task", t10, 120, "COMPLETED", partnerUser.getId()); // verified_actual_end_at is null

        // Job at 12:00–13:00 -> scheduled end is 12:00, gap is 0m -> Blocked!
        Instant t12 = Instant.parse("2026-10-15T12:00:00Z");
        var val = schedulingService.validateSchedule(partnerUser.getId(), null, t12, 60, null, null);
        assertFalse(val.eligible());
        assertEquals("BUFFER_TOO_SHORT", val.reasonCode());
    }

    // Scenario 10: CANCELLED tasks do not retain schedule
    @Test
    void scenario10_cancelledTasksReleaseSlot() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        createTask("Cancelled Task", t10, 120, "CANCELLED", partnerUser.getId());

        Instant t11 = Instant.parse("2026-10-15T11:00:00Z");
        var val = schedulingService.validateSchedule(partnerUser.getId(), null, t11, 120, null, null);
        assertTrue(val.eligible());
    }

    // Scenario 11: POSTED / MATCHING tasks without partner assignment do not retain schedule
    @Test
    void scenario11_unassignedTasksDoNotRetainSchedule() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        createTask("Matching Task", t10, 120, "MATCHING", null);

        var val = schedulingService.validateSchedule(partnerUser.getId(), null, t10, 120, null, null);
        assertTrue(val.eligible());
    }

    // Scenario 12: ACCEPTED, TASKER_ON_THE_WAY, ARRIVED, IN_PROGRESS retain schedule
    @Test
    void scenario12_inProgressStatusesRetainSchedule() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        for (String status : List.of("ACCEPTED", "TASKER_ON_THE_WAY", "ARRIVED", "IN_PROGRESS")) {
            var task = createTask("Task in " + status, t10, 120, status, partnerUser.getId());
            var val = schedulingService.validateSchedule(partnerUser.getId(), null, t10.plusSeconds(1800), 60, null, null);
            assertFalse(val.eligible(), "Status " + status + " should retain schedule");
            db.update("DELETE FROM tasks WHERE id=?", task.getId());
        }
    }

    // Scenario 13: Accept via activationService throws 409 BUFFER_TOO_SHORT when buffer violated
    @Test
    void scenario13_acceptThrowsDomainExceptionConflict() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        createTask("Existing Job", t10, 120, "ACCEPTED", partnerUser.getId());

        Instant t1230 = Instant.parse("2026-10-15T12:30:00Z");
        var candidateTask = createTask("Candidate Job", t1230, 60, "POSTED", null);

        var ex = assertThrows(DomainException.class, () -> activationService.accept(partnerUser.getId(), candidateTask.getId()));
        assertEquals("BUFFER_TOO_SHORT", ex.getCode());
        assertEquals(HttpStatus.CONFLICT, ex.getStatus());
    }

    // Scenario 14: Dynamic buffer settings update changes validation immediately
    @Test
    void scenario14_dynamicBufferConfiguration() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        createTask("Task A", t10, 120, "ACCEPTED", partnerUser.getId()); // ends 12:00

        Instant t1300 = Instant.parse("2026-10-15T13:00:00Z"); // gap is 60m

        // With 60m config -> Allowed
        settingsService.setSetting("partner.min_buffer_minutes", "60", "60m");
        assertTrue(schedulingService.validateSchedule(partnerUser.getId(), null, t1300, 60, null, null).eligible());

        // Admin increases buffer to 90m -> Gap 60m is now BLOCKED!
        settingsService.updateOperationsSettings(90, 15);
        var val90 = schedulingService.validateSchedule(partnerUser.getId(), null, t1300, 60, null, null);
        assertFalse(val90.eligible());
        assertEquals("BUFFER_TOO_SHORT", val90.reasonCode());
        assertEquals(90, val90.requiredBufferMinutes());
    }

    // Scenario 15: Partner not active cannot accept
    @Test
    void scenario15_suspendedPartnerBlocked() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        var task = createTask("Task Open", t10, 60, "POSTED", null);

        db.update("UPDATE partner_applications SET status='SUSPENDED' WHERE user_id=?", partnerUser.getId());
        var ex = assertThrows(DomainException.class, () -> activationService.accept(partnerUser.getId(), task.getId()));
        assertEquals("PARTNER_NOT_ACTIVE", ex.getCode());
    }

    // Scenario 16: Admin assign partner with conflict and override
    @Test
    @WithMockUser(roles = "ADMIN")
    void scenario16_adminAssignWithConflictAndOverride() {
        createTask("Existing Task", Instant.parse("2026-10-15T10:00:00Z"), 120, "ACCEPTED", partnerUser.getId());
        var targetTask = createTask("Target Task", Instant.parse("2026-10-15T12:30:00Z"), 60, "POSTED", null);
        for (boolean override : List.of(false, true)) {
            var request = new AdminTaskController.AssignPartnerRequest(partnerUser.getId(), override, "Khẩn cấp");
            assertEquals("BUFFER_TOO_SHORT", assertThrows(DomainException.class, () -> adminTaskController.assign(targetTask.getId(), request)).getCode());
        }
        assertTrue(adminTaskController.eligiblePartners(targetTask.getId()).data().stream().anyMatch(p -> partnerUser.getId().equals(p.get("partnerId"))));
        db.update("UPDATE tasks SET scheduled_at=? WHERE id=?", Timestamp.from(Instant.parse("2026-10-15T13:00:00Z")), targetTask.getId());
        var request = new AdminTaskController.AssignPartnerRequest(partnerUser.getId(), false, null);
        assertTrue(adminTaskController.assign(targetTask.getId(), request).success());
        adminTaskController.assign(targetTask.getId(), request);
        assertEquals(1, db.queryForObject("SELECT COUNT(*) FROM task_status_history WHERE task_id=?", Integer.class, targetTask.getId()));
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminAssignmentRejectsClosedTasksAndRequiresReasonForSkillOverride() {
        var task = createTask("Dispatch validation", Instant.parse("2026-10-15T10:00:00Z"), 60, "CANCELLED", null);
        var request = new AdminTaskController.AssignPartnerRequest(partnerUser.getId(), false, null);
        assertEquals("TASK_NOT_ASSIGNABLE", assertThrows(DomainException.class, () -> adminTaskController.assign(task.getId(), request)).getCode());
        db.update("UPDATE tasks SET status='POSTED' WHERE id=?", task.getId());
        db.update("DELETE FROM partner_application_services WHERE application_id IN (SELECT id FROM partner_applications WHERE user_id=?)", partnerUser.getId());
        assertEquals("PARTNER_NOT_MATCHED", assertThrows(DomainException.class, () -> adminTaskController.assign(task.getId(), request)).getCode());
        var override = new AdminTaskController.AssignPartnerRequest(partnerUser.getId(), true, "Admin đã xác nhận kỹ năng trực tiếp");
        assertTrue(adminTaskController.assign(task.getId(), override).success());
    }

    // Scenario 17: Admin reschedule validates partner schedule and rejects conflict
    @Test
    @WithMockUser(roles = "ADMIN")
    void scenario17_adminRescheduleRejectsConflict() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        createTask("Morning Task", t10, 120, "ACCEPTED", partnerUser.getId()); // 10:00 - 12:00

        Instant t15 = Instant.parse("2026-10-15T15:00:00Z");
        var afternoonTask = createTask("Afternoon Task", t15, 60, "ACCEPTED", partnerUser.getId());

        // Reschedule afternoonTask to 12:30 (only 30m gap after Morning Task) -> Conflict!
        Instant t1230 = Instant.parse("2026-10-15T12:30:00Z");
        var reschedReq = new AdminTaskController.RescheduleRequest(t1230, 60, "Khách đổi giờ");
        var ex = assertThrows(DomainException.class, () -> adminTaskController.reschedule(afternoonTask.getId(), reschedReq));
        assertEquals("BUFFER_TOO_SHORT", ex.getCode());
    }

    // Scenario 18: Idempotent accept returns existing assignment
    @Test
    void scenario18_idempotentAccept() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        var task = createTask("Task A", t10, 60, "POSTED", null);

        var first = activationService.accept(partnerUser.getId(), task.getId());
        assertEquals("ACCEPTED", first.get("status"));

        var second = activationService.accept(partnerUser.getId(), task.getId());
        assertEquals("ACCEPTED", second.get("status"));
    }

    // Scenario 19: Job already taken by another partner returns JOB_ALREADY_ASSIGNED
    @Test
    void scenario19_jobAlreadyAssignedToOtherPartner() {
        Instant t10 = Instant.parse("2026-10-15T10:00:00Z");
        var task = createTask("Contested Task", t10, 60, "POSTED", null);

        activationService.accept(partnerUser.getId(), task.getId());

        var ex = assertThrows(DomainException.class, () -> activationService.accept(otherPartner.getId(), task.getId()));
        assertEquals("JOB_ALREADY_ASSIGNED", ex.getCode());
    }

    // Scenario 20: Travel ETA increases required buffer when distance is large
    @Test
    void scenario20_travelEtaIncreasesRequiredBuffer() {
        // Location in Hanoi (Center: 21.0285, 105.8542)
        BigDecimal latCenter = BigDecimal.valueOf(21.0285);
        BigDecimal lngCenter = BigDecimal.valueOf(105.8542);

        // Location far away (e.g. Noi Bai airport: 21.2187, 105.8042 ~ 22 km away)
        BigDecimal latFar = BigDecimal.valueOf(21.2187);
        BigDecimal lngFar = BigDecimal.valueOf(105.8042);

        // Required gap should be max(60, travelTime + 15). At 22 km / 25 km/h -> ~53 mins + 15 mins = 68 mins
        int gap = schedulingService.calculateRequiredGap(latCenter, lngCenter, latFar, lngFar);
        assertTrue(gap > 60, "Gap with travel time should exceed 60 minutes for 22km distance, was: " + gap);
    }
}
