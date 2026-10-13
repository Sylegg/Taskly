package com.taskly.task;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.Jwt;
import com.taskly.recruitment.RecruitmentActivationService;
class TaskerViewTest {
 @Test void ownOrderDoesNotCountAsTaskerViewAndOtherViewerIsRecorded() {
  var db=mock(JdbcTemplate.class);var activation=mock(RecruitmentActivationService.class);
  var user=UUID.randomUUID();var id=UUID.randomUUID();
  var jwt=Jwt.withTokenValue("test").header("alg","none").subject(user.toString()).build();
  when(activation.feed(user)).thenReturn(List.of(Map.of("id",id)));
  var row=new HashMap<String,Object>();row.put("customer_id",user);row.put("status","POSTED");
  when(db.queryForMap(anyString(),eq(id))).thenReturn(row);
  var controller=new TaskActivityController(db,null,null,activation);
  assertDoesNotThrow(()->controller.recordView(jwt,id));
  verify(db,never()).update(anyString(),eq(user),eq(id));
  row.put("customer_id",UUID.randomUUID());
  when(db.update(anyString(),eq(user),eq(id))).thenReturn(1);
  controller.recordView(jwt,id);
  verify(db).update(contains("tasker_viewed_by=?"),eq(user),eq(id));
  verify(db).update("UPDATE live_sync_revision SET revision=revision+1 WHERE id=1");
  row.put("status","CANCELLED");
  assertThrows(com.taskly.common.exception.DomainException.class,()->controller.recordView(jwt,id));
 }
}
