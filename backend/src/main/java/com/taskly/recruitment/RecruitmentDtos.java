package com.taskly.recruitment;

import jakarta.validation.constraints.*;
import java.time.*;
import java.util.*;

public final class RecruitmentDtos {
 private RecruitmentDtos() {}
 public record Registration(@PositiveOrZero long version, @NotNull @Size(max=160) String fullName,
   @NotNull @Size(max=32) String contactPhone, LocalDate dateOfBirth,
   @NotNull @Size(max=10) List<UUID> areaIds, @NotNull @Size(max=30) List<UUID> serviceIds,
   @NotNull @Size(max=1000) String experience, @NotNull @Size(max=40) String transport,
   @NotNull @Size(max=100) String referral) {}
 public record Submit(@PositiveOrZero long version, @NotBlank @Size(max=100) String requestId) {}
 public record AreaWrite(@NotBlank @Size(max=160) String city, @NotBlank @Size(max=160) String name,
   boolean recruiting, @Min(0) @Max(100000) int capacity, @NotNull @Size(max=30) List<UUID> serviceIds,
   @PositiveOrZero long version) {}
 public record Area(UUID id,String city,String name,boolean recruiting,int capacity,long version,List<UUID> serviceIds) {}
 public record Application(UUID id,UUID userId,String status,String fullName,String contactPhone,
   String email, LocalDate dateOfBirth,String experience,String transport,String referral,
   List<UUID> areaIds,List<UUID> serviceIds,String reason,List<String> requiredChanges,
   Map<String,Boolean> eligibility,Instant documentsReceivedAt,Instant activatedAt,
   Instant createdAt,Instant updatedAt,long version,Instant firstSubmittedAt,Instant editableUntil,
   boolean editable,boolean reviewReady) {}
}
