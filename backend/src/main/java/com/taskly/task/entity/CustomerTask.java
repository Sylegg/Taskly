package com.taskly.task.entity;

import com.taskly.catalogue.entity.CatalogueService;
import com.taskly.user.entity.UserAccount;
import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "tasks")
public class CustomerTask {
 @Id private UUID id; @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="customer_id") private UserAccount customer;
 @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="service_id") private CatalogueService service;
 @Enumerated(EnumType.STRING) @Column(nullable=false) private TaskStatus status;
 @Column(name="service_slug_snapshot",nullable=false) private String serviceSlugSnapshot; @Column(name="service_name_snapshot",nullable=false) private String serviceNameSnapshot;
 @Column(name="category_slug_snapshot",nullable=false) private String categorySlugSnapshot; @Column(name="category_name_snapshot",nullable=false) private String categoryNameSnapshot;
 @Column(name="suggested_price_min_snapshot",nullable=false) private long suggestedPriceMinSnapshot; @Column(name="suggested_price_max_snapshot",nullable=false) private long suggestedPriceMaxSnapshot;
 @Column(nullable=false) private String title; @Column(nullable=false) private String description; @Column(name="address_line_snapshot",nullable=false) private String addressLine;
 @Column(name="city_snapshot",nullable=false) private String city; private BigDecimal latitude; private BigDecimal longitude;
 @Column(name="scheduled_at",nullable=false) private Instant scheduledAt; @Column(name="estimated_duration_minutes",nullable=false) private int estimatedDurationMinutes;
 @Column(name="budget_amount",nullable=false) private long budgetAmount; @Column(nullable=false) private String currency; @Column(name="customer_notes") private String customerNotes; @Column(name="expires_at") private Instant expiresAt;
 @Column(name="verified_actual_end_at") private Instant verifiedActualEndAt;

 @Column(name="original_scheduled_start_at") private Instant originalScheduledStartAt;
 @Column(name="original_scheduled_end_at") private Instant originalScheduledEndAt;
 @Column(name="approved_start_at") private Instant approvedStartAt;
 @Column(name="expected_end_at") private Instant expectedEndAt;
 @Column(name="accepted_at") private Instant acceptedAt;
 @Column(name="checked_in_at") private Instant checkedInAt;
 @Column(name="actual_started_at") private Instant actualStartedAt;
 @Column(name="early_start_request_id") private UUID earlyStartRequestId;
 @Column(name="booking_timezone") private String bookingTimezone;

 @Version private long version; @Column(name="created_at",nullable=false) private Instant createdAt; @Column(name="updated_at",nullable=false) private Instant updatedAt;
 protected CustomerTask() {}
 public CustomerTask(UserAccount customer, CatalogueService service, String title, String description, String addressLine, String city, BigDecimal latitude, BigDecimal longitude, Instant scheduledAt, int duration, long budget, String currency, String notes, Instant now) {
     id=UUID.randomUUID();this.customer=customer;this.service=service; status=TaskStatus.DRAFT; snapshot(service);
     update(title,description,addressLine,city,latitude,longitude,scheduledAt,duration,budget,currency,notes,now);
     this.originalScheduledStartAt = scheduledAt;
     this.originalScheduledEndAt = scheduledAt.plusSeconds(duration * 60L);
     this.expectedEndAt = this.originalScheduledEndAt;
     this.bookingTimezone = "Asia/Ho_Chi_Minh";
     createdAt=now;
 }
 private void snapshot(CatalogueService s){serviceSlugSnapshot=s.getSlug();serviceNameSnapshot=s.getName();categorySlugSnapshot=s.getCategory().getSlug();categoryNameSnapshot=s.getCategory().getName();suggestedPriceMinSnapshot=s.getSuggestedPriceMin();suggestedPriceMaxSnapshot=s.getSuggestedPriceMax();}
 public void update(String title,String description,String addressLine,String city,BigDecimal lat,BigDecimal lng,Instant scheduled,int duration,long budget,String currency,String notes,Instant now){
     this.title=title;this.description=description;this.addressLine=addressLine;this.city=city;latitude=lat;longitude=lng;
     scheduledAt=scheduled;estimatedDurationMinutes=duration;budgetAmount=budget;this.currency=currency;customerNotes=notes;updatedAt=now;
     if (this.originalScheduledStartAt == null) {
         this.originalScheduledStartAt = scheduled;
         this.originalScheduledEndAt = scheduled.plusSeconds(duration * 60L);
         this.expectedEndAt = this.originalScheduledEndAt;
     }
 }
 public void post(Instant now){status=TaskStatus.POSTED;expiresAt=scheduledAt;updatedAt=now;}
 public UUID getId(){return id;}
 public UUID getCustomerId(){return customer.getId();}
 public TaskStatus getStatus(){return status;}
 public String getTitle(){return title;}
 public Instant getScheduledAt(){return scheduledAt;}
 public int getEstimatedDurationMinutes(){return estimatedDurationMinutes;}
 public long getBudgetAmount(){return budgetAmount;}
 public String getCurrency(){return currency;}
 public String getServiceNameSnapshot(){return serviceNameSnapshot;}
 public Instant getVerifiedActualEndAt(){return verifiedActualEndAt;}
 public void setVerifiedActualEndAt(Instant v){this.verifiedActualEndAt=v;}

 public Instant getOriginalScheduledStartAt(){return originalScheduledStartAt;}
 public void setOriginalScheduledStartAt(Instant v){this.originalScheduledStartAt=v;}
 public Instant getOriginalScheduledEndAt(){return originalScheduledEndAt;}
 public void setOriginalScheduledEndAt(Instant v){this.originalScheduledEndAt=v;}
 public Instant getApprovedStartAt(){return approvedStartAt;}
 public void setApprovedStartAt(Instant v){this.approvedStartAt=v;}
 public Instant getExpectedEndAt(){return expectedEndAt;}
 public void setExpectedEndAt(Instant v){this.expectedEndAt=v;}
 public Instant getAcceptedAt(){return acceptedAt;}
 public void setAcceptedAt(Instant v){this.acceptedAt=v;}
 public Instant getCheckedInAt(){return checkedInAt;}
 public void setCheckedInAt(Instant v){this.checkedInAt=v;}
 public Instant getActualStartedAt(){return actualStartedAt;}
 public void setActualStartedAt(Instant v){this.actualStartedAt=v;}
 public UUID getEarlyStartRequestId(){return earlyStartRequestId;}
 public void setEarlyStartRequestId(UUID v){this.earlyStartRequestId=v;}
 public String getBookingTimezone(){return bookingTimezone;}
 public void setBookingTimezone(String v){this.bookingTimezone=v;}
}
