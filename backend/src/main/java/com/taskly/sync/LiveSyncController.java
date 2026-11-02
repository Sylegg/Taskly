package com.taskly.sync;

import com.taskly.common.api.ApiResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.context.request.async.DeferredResult;

@RestController
@RequestMapping("/api/v1/live-sync")
@PreAuthorize("isAuthenticated()")
public class LiveSyncController {
    private final LiveSync sync;
    public LiveSyncController(LiveSync sync) { this.sync=sync; }
    @GetMapping public DeferredResult<ApiResponse<LiveSync.State>> changes(@RequestParam(defaultValue="-1") long since) {
        return sync.waitFor(since);
    }
}
