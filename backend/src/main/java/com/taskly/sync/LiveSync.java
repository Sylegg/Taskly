package com.taskly.sync;

import com.taskly.common.api.ApiResponse;
import jakarta.annotation.PreDestroy;
import java.util.concurrent.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.context.request.async.DeferredResult;

/** Durable revision shared by backend instances; clients only receive an invalidation. */
@Service
public class LiveSync {
    private final JdbcTemplate db;
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
        var thread = new Thread(r, "taskly-live-sync"); thread.setDaemon(true); return thread;
    });
    private final ConcurrentHashMap<DeferredResult<ApiResponse<State>>,Long> waiting = new ConcurrentHashMap<>();
    public record State(long revision) {}
    public LiveSync(JdbcTemplate db) {
        this.db=db;
        scheduler.scheduleWithFixedDelay(this::publish,1,1,TimeUnit.SECONDS);
    }
    public long revision() { return db.queryForObject("SELECT revision FROM live_sync_revision WHERE id=1",Long.class); }
    public void changed() { db.update("UPDATE live_sync_revision SET revision=revision+1 WHERE id=1"); publish(); }
    public DeferredResult<ApiResponse<State>> waitFor(long since) {
        long current=revision();
        var result=new DeferredResult<ApiResponse<State>>(10000L);
        result.onCompletion(()->waiting.remove(result));
        result.onTimeout(()->result.setResult(ApiResponse.success(new State(revision()))));
        if(current!=since)result.setResult(ApiResponse.success(new State(current)));
        else { waiting.put(result,since); publish(); }
        return result;
    }
    private void publish() {
        if(waiting.isEmpty())return;
        try {
            long current=revision();
            waiting.forEach((result,since)->{if(current!=since){waiting.remove(result);result.setResult(ApiResponse.success(new State(current)));}});
        } catch(Exception ignored) { /* The client retries after the timeout. */ }
    }
    @PreDestroy public void close() { scheduler.shutdownNow(); waiting.clear(); }
}
