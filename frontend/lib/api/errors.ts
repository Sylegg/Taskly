export type FieldError = Readonly<{
  field: string;
  message: string;
}>;

export class ApiError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status: number,
    public readonly requestId?: string,
    public readonly fieldErrors: readonly FieldError[] = [],
  ) {
    super(message);
    this.name = "ApiError";
  }
}

type ErrorEnvelope = {
  success: false;
  error: {
    code: string;
    message: string;
    fieldErrors?: FieldError[];
  };
  requestId?: string;
};

export function toApiError(
  status: number,
  payload: unknown,
  requestId?: string,
): ApiError {
  if (isErrorEnvelope(payload)) {
    return new ApiError(
      payload.error.code,
      payload.error.message,
      status,
      payload.requestId ?? requestId,
      payload.error.fieldErrors ?? [],
    );
  }
  return new ApiError(
    "UNEXPECTED_RESPONSE",
    "Không thể hoàn tất yêu cầu. Vui lòng thử lại.",
    status,
    requestId,
  );
}

function isErrorEnvelope(value: unknown): value is ErrorEnvelope {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Record<string, unknown>;
  if (
    candidate.success !== false ||
    typeof candidate.error !== "object" ||
    candidate.error === null
  ) {
    return false;
  }
  const error = candidate.error as Record<string, unknown>;
  return typeof error.code === "string" && typeof error.message === "string";
}
