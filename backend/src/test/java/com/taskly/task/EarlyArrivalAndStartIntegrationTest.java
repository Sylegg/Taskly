package com.taskly.task;

import com.taskly.catalogue.entity.CatalogueService;
import com.taskly.catalogue.entity.ServiceCategory;
import com.taskly.catalogue.repository.CatalogueServiceRepository;
import com.taskly.catalogue.repository.ServiceCategoryRepository;
import com.taskly.common.exception.DomainException;
import com.taskly.rbac.repository.RoleRepository;
import com.taskly.recruitment.PartnerSchedulingService;
import com.taskly.recruitment.RecruitmentActivationService;
import com.taskly.recruitment.RecruitmentDtos;
import com.taskly.recruitment.RecruitmentService;
import com.taskly.settings.SystemSettingsService;
import com.taskly.task.entity.CustomerTask;
import com.taskly.task.repository.CustomerTaskRepository;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.repository.UserAccountRepository;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
public class EarlyArrivalAndStartIntegrationTest {

    @Autowired private JdbcTemplate db;
    @Autowired private EarlyStartService earlyStartService;
    @Autowired private PartnerSchedulingService schedulingService;
    @Autowired private RecruitmentActivationService activationService;
    @Autowired private SystemSettingsService settingsService;
    @Autowired private UserAccountRepository users;
    @Autowired private ServiceCategoryRepository categories;
    @Autowired private CatalogueServiceRepository services;
    @Autowired private RoleRepository roles;
    @Autowired private CustomerTaskRepository tasks;
    @Autowired private RecruitmentService recruitment;
    @Autowired private jakarta.persistence.EntityManager em;

    private UserAccount partnerUser;
    private UserAccount otherPartner;
    private UserAccount customerUser;
    private UserAccount otherCustomer;
    private CatalogueService testService;
    private UUID areaId;

    private UserAccount createUser(String roleName) {
        var role = roles.findByKey(roleName).orElseGet(() -> roles.findByKey("CUSTOMER").orElseThrow());
        var u = new UserAccount(UUID.randomUUID() + "@test.example", null, "hash", role, Instant.now());
        u.verifyEmail(Instant.now());
        return users.saveAndFlush(u);
    }

    @BeforeEach
    void setup() {
        settingsService.setSetting("partner.min_buffer_minutes", "60", "Default 60m buffer");
        settingsService.setSetting("partner.travel_safety_minutes", "15", "Default 15m safety");
        settingsService.setSetting("operations.early_checkin_window_minutes", "15", "Default 15m checkin window");
        settingsService.setSetting("operations.max_early_start_minutes", "60", "Max 60m early start");
        settingsService.setSetting("operations.early_start_expiry_minutes", "15", "Early start request expires in 15m");

        Instant now = Instant.now();
        partnerUser = createUser("TASKER");
        otherPartner = createUser("TASKER");
        customerUser = createUser("CUSTOMER");
        otherCustomer = createUser("CUSTOMER");

        var cat = categories.saveAndFlush(new ServiceCategory("cat-" + UUID.randomUUID(), "Dịch vụ TaskLy", "", 0, now));
        testService = services.saveAndFlush(new CatalogueService(cat, "svc-" + UUID.randomUUID(), "Dọn dẹp nhà cửa", "Chi tiết", "", 0, 200000, "VND", 120, 0, now));
        db.update("UPDATE services SET active=true WHERE id=?", testService.getId());

        areaId = UUID.randomUUID();
        recruitment.saveArea(customerUser.getId(), areaId, new RecruitmentDtos.AreaWrite("Hà Nội", "Cầu Giấy", true, 10, List.of(testService.getId()), 0));

        for (var type : List.of("PARTNER_CONDUCT", "PARTNER_SAFETY", "PARTNER_COOPERATION", "PARTNER_PRIVACY", "PARTNER_UNIFORM")) {
            var termId = UUID.randomUUID();
            db.update("INSERT INTO terms_versions(id,document_type,version,content_url,effective_at,active,created_at) VALUES(?,?,?,'https://example.test/terms',?,true,?)",
                termId, type, "v1", Timestamp.from(now.minusSeconds(3600)), Timestamp.from(now.minusSeconds(3600)));
        }

        setupActivePartner(partnerUser.getId(), "Đối Tác Alpha", "0901000001");
        setupActivePartner(otherPartner.getId(), "Đối Tác Beta", "0901000002");
    }

    private void setupActivePartner(UUID userId, String name, String phone) {
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

    private CustomerTask createBooking(String title, Instant scheduledAt, int durationMinutes, String status, UUID taskerId) {
        Instant now = Instant.now();
        var task = new CustomerTask(customerUser, testService, title, "Mô tả " + title, "123 Cầu Giấy", "Hà Nội",
            BigDecimal.valueOf(21.0285), BigDecimal.valueOf(105.8542), scheduledAt, durationMinutes, 200000L, "VND", "", now);
        if ("POSTED".equals(status)) {
            task.post(now);
        }
        task = tasks.saveAndFlush(task);
        if (!"DRAFT".equals(status) && !"POSTED".equals(status)) {
            db.update("UPDATE tasks SET status = ?, tasker_id = ?, expires_at = NULL WHERE id = ?", status, taskerId, task.getId());
        }
        db.update("UPDATE tasks SET original_scheduled_start_at = ?, original_scheduled_end_at = ?, expected_end_at = ? WHERE id = ?",
            Timestamp.from(scheduledAt), Timestamp.from(scheduledAt.plus(Duration.ofMinutes(durationMinutes))), Timestamp.from(scheduledAt.plus(Duration.ofMinutes(durationMinutes))), task.getId());
        return task;
    }

    // ==========================================
    // CASE 1: Partner accepts advance booking days ahead -> ACCEPTED, not auto-started
    // ==========================================
    @Test
    @DisplayName("Case 1: Partner accepts job for Oct 14 on Oct 12 -> ACCEPTED, acceptedAt set, not IN_PROGRESS")
    void case01_partnerAcceptsAdvanceBooking_notAutoStarted() {
        Instant oct14Noon = Instant.parse("2026-10-14T12:00:00Z");
        var task = createBooking("Đơn ngày 14", oct14Noon, 120, "POSTED", null);

        var result = activationService.accept(partnerUser.getId(), task.getId());
        assertEquals("ACCEPTED", result.get("status"));

        em.clear();
        var refreshed = tasks.findById(task.getId()).orElseThrow();
        assertEquals("ACCEPTED", refreshed.getStatus().name());
        assertNotNull(refreshed.getAcceptedAt());
        assertEquals(oct14Noon, refreshed.getOriginalScheduledStartAt());
        assertNull(refreshed.getActualStartedAt());
        assertNull(refreshed.getCheckedInAt());
    }

    // ==========================================
    // CASE 2: Early check-in before 15-min window is blocked
    // ==========================================
    @Test
    @DisplayName("Case 2: Check-in 30 mins before scheduled time (11:30 for 12:00) -> blocked with CHECKIN_TOO_EARLY")
    void case02_checkinTooEarly_blocked() {
        // Scheduled 30 minutes in the future (outside 15-min window)
        Instant futureStart = Instant.now().plus(Duration.ofMinutes(30));
        var task = createBooking("Đơn 30m sau", futureStart, 120, "ACCEPTED", partnerUser.getId());

        var ex = assertThrows(DomainException.class, () -> earlyStartService.checkIn(partnerUser.getId(), task.getId(), 21.0285, 105.8542));
        assertEquals("CHECKIN_TOO_EARLY", ex.getCode());
    }

    // ==========================================
    // CASE 3: Check-in within 15-min window succeeds -> ARRIVED, start not yet enabled
    // ==========================================
    @Test
    @DisplayName("Case 3: Check-in 10 mins before start -> succeeds ARRIVED, checkedInAt set, canStart is false")
    void case03_checkinWithin15Mins_succeedsArrived() {
        Instant futureStart = Instant.now().plus(Duration.ofMinutes(10));
        var task = createBooking("Đơn 10m sau", futureStart, 120, "ACCEPTED", partnerUser.getId());

        var checkinRes = earlyStartService.checkIn(partnerUser.getId(), task.getId(), 21.0285, 105.8542);
        assertEquals("ARRIVED", checkinRes.get("status"));
        assertNotNull(checkinRes.get("checkedInAt"));

        var eligibility = earlyStartService.getStartEligibility(partnerUser.getId(), task.getId(), true);
        assertTrue(eligibility.checkedIn());
        assertFalse(eligibility.canStart(), "Start button must not be enabled yet because current time < scheduledStart and no early consent");
    }

    // ==========================================
    // CASE 4: Partner clicks Start before schedule without consent -> blocked
    // ==========================================
    @Test
    @DisplayName("Case 4: Partner starts before scheduled time without consent -> blocked with EARLY_START_REQUIRES_APPROVAL")
    void case04_startEarlyWithoutConsent_blocked() {
        Instant futureStart = Instant.now().plus(Duration.ofMinutes(10));
        var task = createBooking("Đơn chưa duyệt", futureStart, 120, "ACCEPTED", partnerUser.getId());
        earlyStartService.checkIn(partnerUser.getId(), task.getId(), 21.0285, 105.8542);

        var ex = assertThrows(DomainException.class, () -> earlyStartService.startJob(partnerUser.getId(), task.getId()));
        assertEquals("EARLY_START_REQUIRES_APPROVAL", ex.getCode());
    }

    // ==========================================
    // CASE 5: Partner sends early start request -> Customer can see proposal
    // ==========================================
    @Test
    @DisplayName("Case 5: Partner creates early start request -> Customer sees proposed start and end")
    void case05_createEarlyStartRequest_visibleToCustomer() {
        Instant origStart = Instant.now().plus(Duration.ofMinutes(45));
        Instant requestedStart = Instant.now().plus(Duration.ofMinutes(15));
        var task = createBooking("Đơn xin làm sớm", origStart, 120, "ACCEPTED", partnerUser.getId());

        var req = earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), requestedStart, "Đã có mặt sớm");
        assertNotNull(req.id());
        assertEquals("PENDING", req.status());
        assertEquals(requestedStart, req.requestedStartAt());
        assertEquals(requestedStart.plus(Duration.ofMinutes(120)), req.proposedEndAt());

        var customerRequests = earlyStartService.getEarlyStartRequests(task.getId());
        assertFalse(customerRequests.isEmpty());
        assertEquals(req.id(), customerRequests.getFirst().id());
    }

    // ==========================================
    // CASE 6: Customer approves early start -> Start allowed after check-in, actualStartedAt recorded
    // ==========================================
    @Test
    @DisplayName("Case 6: Customer approves early start -> Partner can start at requested time, actualStartedAt recorded")
    void case06_customerApproves_earlyStartSucceeds() {
        Instant origStart = Instant.now().plus(Duration.ofMinutes(30));
        // Requested start is 1 second in the past (so serverNow >= requestedStart)
        Instant requestedStart = Instant.now().minusSeconds(2);
        var task = createBooking("Đơn được duyệt sớm", origStart, 120, "ACCEPTED", partnerUser.getId());

        var req = earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), requestedStart, "Tôi đã đến nơi");
        earlyStartService.customerDecision(customerUser.getId(), task.getId(), req.id(), "APPROVE", null);

        em.clear();
        var refreshed = tasks.findById(task.getId()).orElseThrow();
        assertEquals(requestedStart.getEpochSecond(), refreshed.getApprovedStartAt().getEpochSecond());

        // Check-in and start
        earlyStartService.checkIn(partnerUser.getId(), task.getId(), 21.0285, 105.8542);
        var startResult = earlyStartService.startJob(partnerUser.getId(), task.getId());

        assertEquals("IN_PROGRESS", startResult.get("status"));
        em.clear();
        var taskAfterStart = tasks.findById(task.getId()).orElseThrow();
        assertEquals("IN_PROGRESS", taskAfterStart.getStatus().name());
        assertNotNull(taskAfterStart.getActualStartedAt());
    }

    // ==========================================
    // CASE 7: Customer rejects early start -> original schedule kept, cannot start early
    // ==========================================
    @Test
    @DisplayName("Case 7: Customer rejects early start -> original schedule kept, cannot start early")
    void case07_customerRejects_originalScheduleRetained() {
        Instant origStart = Instant.now().plus(Duration.ofMinutes(30));
        Instant requestedStart = Instant.now().minusSeconds(2);
        var task = createBooking("Đơn bị từ chối", origStart, 120, "ACCEPTED", partnerUser.getId());

        var req = earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), requestedStart, "Muốn làm sớm");
        earlyStartService.customerDecision(customerUser.getId(), task.getId(), req.id(), "REJECT", "Chưa có nhà");

        var refreshed = tasks.findById(task.getId()).orElseThrow();
        assertNull(refreshed.getApprovedStartAt());

        // Checkin fails if still > 15m from origStart
        var ex = assertThrows(DomainException.class, () -> earlyStartService.checkIn(partnerUser.getId(), task.getId(), 21.0285, 105.8542));
        assertEquals("CHECKIN_TOO_EARLY", ex.getCode());
    }

    // ==========================================
    // CASE 8: Start at scheduled time after check-in does not require early consent
    // ==========================================
    @Test
    @DisplayName("Case 8: At scheduled time after check-in -> Start allowed without consent")
    void case08_startAtScheduledTime_noConsentNeeded() {
        Instant pastStart = Instant.now().minusSeconds(10);
        var task = createBooking("Đơn đúng giờ", pastStart, 120, "ACCEPTED", partnerUser.getId());

        earlyStartService.checkIn(partnerUser.getId(), task.getId(), 21.0285, 105.8542);
        var startResult = earlyStartService.startJob(partnerUser.getId(), task.getId());

        assertEquals("IN_PROGRESS", startResult.get("status"));
    }

    // ==========================================
    // CASE 9: Start at scheduled time without check-in is blocked
    // ==========================================
    @Test
    @DisplayName("Case 9: At scheduled time without check-in -> blocked with CHECKIN_REQUIRED, no auto-start")
    void case09_startWithoutCheckin_blocked() {
        Instant pastStart = Instant.now().minusSeconds(10);
        var task = createBooking("Đơn chưa check-in", pastStart, 120, "ACCEPTED", partnerUser.getId());

        var ex = assertThrows(DomainException.class, () -> earlyStartService.startJob(partnerUser.getId(), task.getId()));
        assertEquals("CHECKIN_REQUIRED", ex.getCode());
    }

    // ==========================================
    // CASE 10: Customer approves early start, but partner has not checked in -> blocked
    // ==========================================
    @Test
    @DisplayName("Case 10: Customer approves, but partner not checked in -> blocked with CHECKIN_REQUIRED")
    void case10_customerApproved_notCheckedIn_blocked() {
        Instant origStart = Instant.now().plus(Duration.ofMinutes(30));
        Instant requestedStart = Instant.now().minusSeconds(2);
        var task = createBooking("Đơn chưa check-in", origStart, 120, "ACCEPTED", partnerUser.getId());

        var req = earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), requestedStart, "Xin làm sớm");
        earlyStartService.customerDecision(customerUser.getId(), task.getId(), req.id(), "APPROVE", null);

        var ex = assertThrows(DomainException.class, () -> earlyStartService.startJob(partnerUser.getId(), task.getId()));
        assertEquals("CHECKIN_REQUIRED", ex.getCode());
    }

    // ==========================================
    // CASE 11: Customer approves, partner checked in, but partner does not click start -> remains ARRIVED
    // ==========================================
    @Test
    @DisplayName("Case 11: Customer approves, partner arrived, but no start click -> remains ARRIVED")
    void case11_customerApproved_partnerDoesNotClickStart_remainsArrived() {
        Instant origStart = Instant.now().plus(Duration.ofMinutes(30));
        Instant requestedStart = Instant.now().minusSeconds(2);
        var task = createBooking("Đơn chờ bấm start", origStart, 120, "ACCEPTED", partnerUser.getId());

        var req = earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), requestedStart, "Xin làm sớm");
        earlyStartService.customerDecision(customerUser.getId(), task.getId(), req.id(), "APPROVE", null);
        earlyStartService.checkIn(partnerUser.getId(), task.getId(), 21.0285, 105.8542);

        em.clear();
        var current = tasks.findById(task.getId()).orElseThrow();
        assertEquals("ARRIVED", current.getStatus().name());
        assertNull(current.getActualStartedAt());
    }

    // ==========================================
    // CASE 12: 120-min service moves start 12:00 -> 11:45 -> expectedEnd 13:45, price unchanged
    // ==========================================
    @Test
    @DisplayName("Case 12: Proposed end preserves duration, price remains identical")
    void case12_durationPreserved_priceUnchanged() {
        Instant origStart = Instant.parse("2026-10-14T12:00:00Z");
        Instant reqStart = Instant.parse("2026-10-14T11:45:00Z");
        var task = createBooking("Đơn 120p", origStart, 120, "ACCEPTED", partnerUser.getId());

        var req = earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), reqStart, "Đến sớm 15p");
        assertEquals(Instant.parse("2026-10-14T13:45:00Z"), req.proposedEndAt());

        var current = tasks.findById(task.getId()).orElseThrow();
        assertEquals(200000L, current.getBudgetAmount());
    }

    // ==========================================
    // CASE 13: Early start exceeds maxEarlyStartMinutes -> blocked
    // ==========================================
    @Test
    @DisplayName("Case 13: Early start request exceeds maxEarlyStartMinutes (e.g. 75 mins early) -> blocked")
    void case13_earlyStartExceedsMaxLimit_blocked() {
        Instant origStart = Instant.now().plus(Duration.ofMinutes(90));
        Instant reqStart = Instant.now().plus(Duration.ofMinutes(15)); // 75 mins early > 60m max
        var task = createBooking("Đơn quá sớm", origStart, 120, "ACCEPTED", partnerUser.getId());

        var ex = assertThrows(DomainException.class, () -> earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), reqStart, "Làm sớm quá mức"));
        assertEquals("MAX_EARLY_LIMIT_EXCEEDED", ex.getCode());
    }

    // ==========================================
    // CASE 14: Job 1 ends at 11:00, buffer 60, Job 2 at 12:00 requests 11:45 -> blocked by 60m buffer
    // ==========================================
    @Test
    @DisplayName("Case 14: Previous job ends 11:00, buffer 60, requesting 11:45 -> blocked by buffer")
    void case14_bufferViolationWithPreviousJob_blocked() {
        Instant t09 = Instant.parse("2026-10-15T09:00:00Z");
        createBooking("Ca sáng", t09, 120, "ACCEPTED", partnerUser.getId()); // 09:00 - 11:00

        Instant t12 = Instant.parse("2026-10-15T12:00:00Z");
        var job2 = createBooking("Ca trưa", t12, 120, "ACCEPTED", partnerUser.getId()); // 12:00 - 14:00

        // Request 11:45 -> gap after Ca sáng is 45 mins < 60 mins required
        Instant t1145 = Instant.parse("2026-10-15T11:45:00Z");
        var ex = assertThrows(DomainException.class, () -> earlyStartService.createEarlyStartRequest(partnerUser.getId(), job2.getId(), t1145, "Làm sớm 11:45"));
        assertEquals("BUFFER_TOO_SHORT", ex.getCode());
    }

    // ==========================================
    // CASE 15: Previous job completed early with verified end 10:45 -> 11:45 allowed
    // ==========================================
    @Test
    @DisplayName("Case 15: Previous job completed early with verified end 10:45 -> 11:45 early start allowed")
    void case15_verifiedEarlyEnd_allowsEarlyStart() {
        Instant t09 = Instant.parse("2026-10-15T09:00:00Z");
        var job1 = createBooking("Ca sáng kết thúc sớm", t09, 120, "COMPLETED", partnerUser.getId());
        db.update("UPDATE tasks SET verified_actual_end_at = ? WHERE id = ?", Timestamp.from(Instant.parse("2026-10-15T10:45:00Z")), job1.getId());

        Instant t12 = Instant.parse("2026-10-15T12:00:00Z");
        var job2 = createBooking("Ca trưa", t12, 120, "ACCEPTED", partnerUser.getId());

        // Gap from verified end (10:45) to 11:45 is exactly 60 minutes -> Allowed!
        Instant t1145 = Instant.parse("2026-10-15T11:45:00Z");
        var req = earlyStartService.createEarlyStartRequest(partnerUser.getId(), job2.getId(), t1145, "Đã xong ca trước sớm");
        assertNotNull(req.id());
        assertEquals("PENDING", req.status());
    }

    // ==========================================
    // CASE 16: Start revalidation detects previous job overrun
    // ==========================================
    @Test
    @DisplayName("Case 16: Start revalidation detects previous job still active or overrun -> blocks start")
    void case16_startRevalidationDetectsPreviousJobOverrun() {
        Instant t09 = Instant.now().minus(Duration.ofMinutes(150));
        // Job 1 scheduled 09:00 - 11:00, but STILL IN_PROGRESS at 11:45!
        createBooking("Ca sáng chưa xong", t09, 120, "IN_PROGRESS", partnerUser.getId());

        Instant origStart = Instant.now().plus(Duration.ofMinutes(30));
        Instant reqStart = Instant.now().minusSeconds(5);
        var job2 = createBooking("Ca trưa", origStart, 120, "ACCEPTED", partnerUser.getId());

        // Force approved_start_at and check-in (ARRIVED)
        db.update("UPDATE tasks SET status = 'ARRIVED', approved_start_at = ?, checked_in_at = ? WHERE id = ?", Timestamp.from(reqStart), Timestamp.from(reqStart), job2.getId());

        // Attempting to start job2 should revalidate active job1 and fail with SCHEDULE_CONFLICT / BUFFER_TOO_SHORT
        var ex = assertThrows(DomainException.class, () -> earlyStartService.startJob(partnerUser.getId(), job2.getId()));
        assertTrue(Set.of("SCHEDULE_CONFLICT", "BUFFER_TOO_SHORT").contains(ex.getCode()));
    }

    // ==========================================
    // CASE 17: Conservative reservation holds until actual end
    // ==========================================
    @Test
    @DisplayName("Case 17: Conservative reservation holds until actual verified end")
    void case17_conservativeReservationHoldsUntilActualEnd() {
        Instant t12 = Instant.parse("2026-10-15T12:00:00Z");
        var job = createBooking("Ca 12h", t12, 120, "ACCEPTED", partnerUser.getId()); // 12:00 - 14:00
        // Approved early start: 11:45 - 13:45
        db.update("UPDATE tasks SET approved_start_at = ?, expected_end_at = ? WHERE id = ?",
            Timestamp.from(Instant.parse("2026-10-15T11:45:00Z")), Timestamp.from(Instant.parse("2026-10-15T13:45:00Z")), job.getId());

        // A new job trying to start at 14:30 (violates original reservation end 14:00 + 60m buffer = 15:00)
        var val = schedulingService.validateSchedule(partnerUser.getId(), UUID.randomUUID(), Instant.parse("2026-10-15T14:30:00Z"), 60, BigDecimal.valueOf(21.0285), BigDecimal.valueOf(105.8542));
        assertFalse(val.eligible(), "Cannot encroach on conservative reservation span [11:45, 14:00] + 60m buffer");
    }

    // ==========================================
    // CASE 18: Double-tap / duplicate early start request prevented
    // ==========================================
    @Test
    @DisplayName("Case 18: Double-tap early start request throws STALE_REQUEST")
    void case18_duplicateEarlyStartRequest_prevented() {
        Instant origStart = Instant.now().plus(Duration.ofMinutes(45));
        Instant reqStart = Instant.now().plus(Duration.ofMinutes(15));
        var task = createBooking("Đơn gửi lặp", origStart, 120, "ACCEPTED", partnerUser.getId());

        earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), reqStart, "Yêu cầu 1");

        var ex = assertThrows(DomainException.class, () -> earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), reqStart, "Yêu cầu 2"));
        assertEquals("STALE_REQUEST", ex.getCode());
    }

    // ==========================================
    // CASE 19: Concurrent customer decision on already resolved request
    // ==========================================
    @Test
    @DisplayName("Case 19: Second customer decision on resolved request throws STALE_REQUEST")
    void case19_concurrentCustomerDecision_prevented() {
        Instant origStart = Instant.now().plus(Duration.ofMinutes(45));
        Instant reqStart = Instant.now().plus(Duration.ofMinutes(15));
        var task = createBooking("Đơn quyết định trùng", origStart, 120, "ACCEPTED", partnerUser.getId());

        var req = earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), reqStart, "Xin sớm");
        earlyStartService.customerDecision(customerUser.getId(), task.getId(), req.id(), "APPROVE", null);

        var ex = assertThrows(DomainException.class, () -> earlyStartService.customerDecision(customerUser.getId(), task.getId(), req.id(), "REJECT", null));
        assertEquals("STALE_REQUEST", ex.getCode());
    }

    // ==========================================
    // CASE 20: Unauthorized partner cannot check-in or start
    // ==========================================
    @Test
    @DisplayName("Case 20: Unauthorized partner cannot check in or start job")
    void case20_unauthorizedPartner_forbidden() {
        Instant pastStart = Instant.now().minusSeconds(10);
        var task = createBooking("Đơn của Alpha", pastStart, 120, "ACCEPTED", partnerUser.getId());

        var exCheckin = assertThrows(DomainException.class, () -> earlyStartService.checkIn(otherPartner.getId(), task.getId(), 21.0285, 105.8542));
        assertEquals("NOT_ASSIGNED_PARTNER", exCheckin.getCode());

        var exStart = assertThrows(DomainException.class, () -> earlyStartService.startJob(otherPartner.getId(), task.getId()));
        assertEquals("NOT_ASSIGNED_PARTNER", exStart.getCode());
    }

    // ==========================================
    // CASE 21: Unauthorized customer cannot decide early start request
    // ==========================================
    @Test
    @DisplayName("Case 21: Unauthorized customer cannot decide early start request")
    void case21_unauthorizedCustomer_forbidden() {
        Instant origStart = Instant.now().plus(Duration.ofMinutes(45));
        Instant reqStart = Instant.now().plus(Duration.ofMinutes(15));
        var task = createBooking("Đơn của khách", origStart, 120, "ACCEPTED", partnerUser.getId());

        var req = earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), reqStart, "Xin sớm");

        var ex = assertThrows(DomainException.class, () -> earlyStartService.customerDecision(otherCustomer.getId(), task.getId(), req.id(), "APPROVE", null));
        assertEquals("UNAUTHORIZED_ACTION", ex.getCode());
    }

    // ==========================================
    // CASE 22: Suspended partner cannot check in or start
    // ==========================================
    @Test
    @DisplayName("Case 22: Suspended partner cannot check in or start")
    void case22_suspendedPartner_blocked() {
        Instant pastStart = Instant.now().minusSeconds(10);
        var task = createBooking("Đơn của bị đình chỉ", pastStart, 120, "ACCEPTED", partnerUser.getId());

        // Suspend partner
        db.update("UPDATE partner_applications SET status = 'SUSPENDED' WHERE user_id = ?", partnerUser.getId());

        var ex = assertThrows(DomainException.class, () -> earlyStartService.checkIn(partnerUser.getId(), task.getId(), 21.0285, 105.8542));
        assertEquals("PARTNER_NOT_ACTIVE", ex.getCode());
    }

    // ==========================================
    // CASE 23: Completed or cancelled job cannot check-in or start
    // ==========================================
    @Test
    @DisplayName("Case 23: Completed or cancelled job cannot start")
    void case23_completedOrCancelledJob_cannotStart() {
        Instant pastStart = Instant.now().minusSeconds(10);
        var task = createBooking("Đơn đã huỷ", pastStart, 120, "CANCELLED", partnerUser.getId());

        var ex = assertThrows(DomainException.class, () -> earlyStartService.checkIn(partnerUser.getId(), task.getId(), 21.0285, 105.8542));
        assertEquals("INVALID_START_STATE", ex.getCode());
    }

    // ==========================================
    // CASE 24: Admin modifies policy config without breaking existing bookings
    // ==========================================
    @Test
    @DisplayName("Case 24: Admin modifies policy config without breaking existing bookings")
    void case24_adminModifiesPolicyConfig_safe() {
        Instant t12 = Instant.parse("2026-10-15T12:00:00Z");
        var existingTask = createBooking("Đơn hiện hữu", t12, 120, "ACCEPTED", partnerUser.getId());

        // Update settings: 15 -> 20, 60 -> 90
        settingsService.setSetting("partner.early_checkin_window_minutes", "20", "Updated window");
        settingsService.setSetting("partner.min_buffer_minutes", "90", "Updated buffer");

        assertEquals(20, settingsService.getEarlyCheckinWindowMinutes());
        assertEquals(90, settingsService.getMinBufferMinutes());

        // Existing booking still exists with its original scheduled start intact
        em.clear();
        var refreshed = tasks.findById(existingTask.getId()).orElseThrow();
        assertEquals(t12, refreshed.getOriginalScheduledStartAt());
        assertEquals("ACCEPTED", refreshed.getStatus().name());
    }

    // ==========================================
    // CASE 25: Cross-midnight job handles full timestamps accurately
    // ==========================================
    @Test
    @DisplayName("Case 25: Cross-midnight job preserves full timestamps and duration across dates")
    void case25_crossMidnightJob_handlesFullTimestamps() {
        Instant t2330 = Instant.parse("2026-10-15T23:30:00Z");
        var task = createBooking("Đơn ca đêm", t2330, 120, "ACCEPTED", partnerUser.getId()); // 23:30 - 01:30 (+1 day)

        var refreshed = tasks.findById(task.getId()).orElseThrow();
        assertEquals(t2330, refreshed.getOriginalScheduledStartAt());
        assertEquals(Instant.parse("2026-10-16T01:30:00Z"), refreshed.getOriginalScheduledEndAt());
    }

    // ==========================================
    // CASE 26: Expired early start request cannot be approved
    // ==========================================
    @Test
    @DisplayName("Case 26: Expired early start request throws EARLY_START_REQUEST_EXPIRED")
    void case26_expiredEarlyStartRequest_blocked() {
        Instant origStart = Instant.now().plus(Duration.ofMinutes(45));
        Instant reqStart = Instant.now().plus(Duration.ofMinutes(15));
        var task = createBooking("Đơn hết hạn", origStart, 120, "ACCEPTED", partnerUser.getId());

        var req = earlyStartService.createEarlyStartRequest(partnerUser.getId(), task.getId(), reqStart, "Xin sớm");
        // Force expires_at into the past
        db.update("UPDATE early_start_requests SET expires_at = ? WHERE id = ?", Timestamp.from(Instant.now().minusSeconds(60)), req.id());

        var ex = assertThrows(DomainException.class, () -> earlyStartService.customerDecision(customerUser.getId(), task.getId(), req.id(), "APPROVE", null));
        assertEquals("EARLY_START_REQUEST_EXPIRED", ex.getCode());
    }

    // ==========================================
    // CASE 27: Eligibility DTO provides accurate flags and guidance
    // ==========================================
    @Test
    @DisplayName("Case 27: Eligibility DTO provides accurate flags, server clock, and guidance message")
    void case27_getStartEligibility_returnsAccurateGatingAndMessage() {
        Instant futureStart = Instant.now().plus(Duration.ofMinutes(45));
        var task = createBooking("Đơn xem điều kiện", futureStart, 120, "ACCEPTED", partnerUser.getId());

        var eligibility = earlyStartService.getStartEligibility(partnerUser.getId(), task.getId(), true);
        assertFalse(eligibility.canCheckIn());
        assertFalse(eligibility.canStart());
        assertFalse(eligibility.canTravel());
        assertTrue(eligibility.canRequestEarlyStart());
        assertNotNull(eligibility.serverNow());
        assertNotNull(eligibility.message());
    }

    @Test
    void earlyTravelRequiresCustomerApproval() {
        var now = Instant.now();
        var task = createBooking("Đơn di chuyển sớm", now.plusSeconds(2700), 120, "ACCEPTED", partnerUser.getId());
        var id = task.getId();
        assertFalse(TaskTravelPolicy.canTravel(db,id,partnerUser.getId(),now));
        var blocked = assertThrows(DomainException.class, () -> activationService.progressJob(partnerUser.getId(),id,new RecruitmentActivationService.JobStatus("ACCEPTED","TASKER_ON_THE_WAY","travel-blocked-"+UUID.randomUUID())));
        assertEquals("EARLY_TRAVEL_REQUIRES_APPROVAL",blocked.getCode());
        var request = earlyStartService.createEarlyStartRequest(partnerUser.getId(),id,now.plusSeconds(600),"Xin đến sớm");
        assertFalse(TaskTravelPolicy.canTravel(db,id,partnerUser.getId(),now));
        earlyStartService.customerDecision(customerUser.getId(),id,request.id(),"APPROVE",null);
        assertTrue(earlyStartService.getStartEligibility(partnerUser.getId(),id,true).canTravel());
        assertFalse(TaskTravelPolicy.canTravel(db,id,otherPartner.getId(),now));
        activationService.progressJob(partnerUser.getId(),id,new RecruitmentActivationService.JobStatus("ACCEPTED","TASKER_ON_THE_WAY","travel-approved-"+UUID.randomUUID()));
        assertEquals("TASKER_ON_THE_WAY",db.queryForObject("SELECT status FROM tasks WHERE id=?",String.class,id));
        assertEquals("Tôi đang đến địa chỉ thực hiện dịch vụ.", db.queryForObject("SELECT content FROM task_messages WHERE task_id=? AND sender_portal='PARTNER' AND content='Tôi đang đến địa chỉ thực hiện dịch vụ.'", String.class, id));
    }

    @Test
    void checkInPhotoAndNoticeAreSentOnce() throws Exception {
        var task = createBooking("Đơn check-in ảnh", Instant.now().minusSeconds(60), 60, "TASKER_ON_THE_WAY", partnerUser.getId());
        var bytes = new java.io.ByteArrayOutputStream();
        javax.imageio.ImageIO.write(new java.awt.image.BufferedImage(2, 2, java.awt.image.BufferedImage.TYPE_INT_RGB), "jpeg", bytes);
        var photo = "data:image/jpeg;base64," + java.util.Base64.getEncoder().encodeToString(bytes.toByteArray());
        for (int i = 0; i < 2; i++) {
            earlyStartService.checkInWithPhoto(partnerUser.getId(), task.getId(), null, null, "PHOTO", "photo-check", photo);
        }
        assertEquals(1, db.queryForObject("SELECT COUNT(*) FROM task_messages WHERE task_id=? AND sender_portal='PARTNER' AND image_data=? AND content LIKE 'Tôi đã check-in%'", Integer.class, task.getId(), photo));
        assertEquals("ARRIVED", db.queryForObject("SELECT status FROM tasks WHERE id=?", String.class, task.getId()));
    }

    @Test
    void completedJobDoesNotBlockNextBookingWithBuffer() {
        var now = Instant.now();
        var done = createBooking("Đơn đã xong", now.minusSeconds(3600), 120, "COMPLETED", partnerUser.getId());
        db.update("UPDATE tasks SET verified_actual_end_at=? WHERE id=?", java.sql.Timestamp.from(now), done.getId());
        var result = schedulingService.validateSchedule(partnerUser.getId(), UUID.randomUUID(), now.plusSeconds(60), 60, null, null);
        assertTrue(result.eligible(), "Đơn hoàn thành không được giữ khoảng nghỉ để chặn đơn mới");
    }

    // ==========================================
    // CASE 28: Idempotent start returns existing state safely
    // ==========================================
    @Test
    @DisplayName("Case 28: Calling startJob when already IN_PROGRESS returns existing state idempotently")
    void case28_idempotentStartJob() {
        Instant pastStart = Instant.now().minusSeconds(10);
        var task = createBooking("Đơn idempotent", pastStart, 120, "ACCEPTED", partnerUser.getId());

        earlyStartService.checkIn(partnerUser.getId(), task.getId(), 21.0285, 105.8542);
        var first = earlyStartService.startJob(partnerUser.getId(), task.getId());
        assertEquals("IN_PROGRESS", first.get("status"));

        var second = earlyStartService.startJob(partnerUser.getId(), task.getId());
        assertEquals("IN_PROGRESS", second.get("status"));
    }
}
