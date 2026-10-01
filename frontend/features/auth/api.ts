import { apiRequest } from "@/lib/api/client";
import type { ApiEnvelope, TokenResponse } from "./types";
import type {
  ForgotPasswordInput,
  LoginInput,
  OtpInput,
  RegisterInput,
  ResetPasswordInput,
} from "./schemas";

export async function login(input: LoginInput) {
  return apiRequest<ApiEnvelope<TokenResponse>>("/auth/login", {
    method: "POST",
    body: input,
  });
}

export async function register(input: RegisterInput) {
  const { confirmPassword: _, ...body } = input;
  void _;
  return apiRequest<
    ApiEnvelope<{ userId: string; status: string; message: string }>
  >("/auth/register", { method: "POST", body });
}

export async function verifyOtp(input: OtpInput) {
  return apiRequest<ApiEnvelope<null>>("/auth/verify-otp", {
    method: "POST",
    body: input,
  });
}

export async function forgotPassword(input: ForgotPasswordInput) {
  return apiRequest<ApiEnvelope<null>>("/auth/forgot-password", {
    method: "POST",
    body: input,
  });
}

export async function resetPassword(input: ResetPasswordInput) {
  const { confirmPassword: _, ...body } = input;
  void _;
  return apiRequest<ApiEnvelope<null>>("/auth/reset-password", {
    method: "POST",
    body,
  });
}

export async function getCsrf() {
  return apiRequest<ApiEnvelope<{ headerName: string; token: string }>>(
    "/auth/csrf",
  );
}

export async function refreshSession() {
  const csrf = await getCsrf();
  return apiRequest<ApiEnvelope<TokenResponse>>("/auth/refresh", {
    method: "POST",
    headers: { [csrf.data.headerName]: csrf.data.token },
  });
}

export async function logoutSession() {
  const csrf = await getCsrf();
  return apiRequest<ApiEnvelope<null>>("/auth/logout", {
    method: "POST",
    headers: { [csrf.data.headerName]: csrf.data.token },
  });
}
