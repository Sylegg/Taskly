package com.taskly.recruitment;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import com.taskly.common.exception.DomainException;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.junit.jupiter.api.Assertions.*;
class CompletionPhotosTest {
 @Test void rejectsMissingDuplicateOrUnconfirmedPhotos() {
  var db=mock(JdbcTemplate.class); var user=UUID.randomUUID(); var task=UUID.randomUUID();
  when(db.queryForList(anyString(),eq(task),eq(user))).thenReturn(List.of(Map.of("status","IN_PROGRESS")));
  var service=new RecruitmentActivationService(db,null,null,null,null);
  for(var request:List.of(
    new RecruitmentActivationService.Completion(List.of("one"),"test",true),
    new RecruitmentActivationService.Completion(List.of("same","same"),"test",true),
    new RecruitmentActivationService.Completion(List.of("one","two"),"test",false)))
   assertThrows(DomainException.class,()->service.completeWithPhotos(user,task,request));
  verify(db,never()).update(anyString(),any(),any(),any(),any(),any());
 }
}
