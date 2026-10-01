import { ApiError, toApiError } from "./errors";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8080/api/v1";
let accessToken: string | null = null;

export function setAccessToken(token: string | null) {
  accessToken = token;
}

type RequestOptions = Omit<RequestInit, "body"> & {
  body?: unknown;
};

export async function apiRequest<T>(
  path: string,
  options: RequestOptions = {},
): Promise<T> {
  const headers = new Headers(options.headers);
  headers.set("Accept", "application/json");
  if (accessToken && !headers.has("Authorization")) {
    headers.set("Authorization", `Bearer ${accessToken}`);
  }
  const isFormData = options.body instanceof FormData;
  if (options.body !== undefined && !isFormData)
    headers.set("Content-Type", "application/json");

  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      ...options,
      body:
        options.body === undefined
          ? undefined
          : options.body instanceof FormData
            ? options.body
            : JSON.stringify(options.body),
      credentials: "include",
      headers,
    });
  } catch {
    throw new ApiError("NETWORK_ERROR", "Không thể kết nối tới TaskLy.", 0);
  }

  const requestId = response.headers.get("X-Request-ID") ?? undefined;
  const payload: unknown =
    response.status === 204 ? null : await safeJson(response);
  if (!response.ok) throw toApiError(response.status, payload, requestId);
  return payload as T;
}

async function safeJson(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch {
    return null;
  }
}
