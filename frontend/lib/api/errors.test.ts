import { describe, expect, it } from "vitest";
import { ApiError, toApiError } from "./errors";

describe("toApiError", () => {
  it("normalizes the backend error envelope", () => {
    const error = toApiError(409, {
      success: false,
      error: {
        code: "TASK_ALREADY_ACCEPTED",
        message: "Task has already been accepted",
        fieldErrors: [],
      },
      requestId: "req-1",
    });

    expect(error).toBeInstanceOf(ApiError);
    expect(error.code).toBe("TASK_ALREADY_ACCEPTED");
    expect(error.status).toBe(409);
    expect(error.requestId).toBe("req-1");
  });

  it("does not expose an unknown response body", () => {
    const error = toApiError(500, "server stack trace", "req-2");
    expect(error.code).toBe("UNEXPECTED_RESPONSE");
    expect(error.message).not.toContain("stack trace");
    expect(error.requestId).toBe("req-2");
  });
});
