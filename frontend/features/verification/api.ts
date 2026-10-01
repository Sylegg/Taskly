import type { ApiEnvelope } from "@/features/auth/types";
import { apiRequest } from "@/lib/api/client";
import type {
  DocumentSide,
  Verification,
  VerificationEnvelope,
  VerificationPage,
  VerificationStatus,
} from "./types";

export async function enableTaskerMode() {
  return apiRequest<ApiEnvelope<unknown>>("/users/me/modes/tasker", {
    method: "POST",
  });
}

export async function getMyVerification() {
  return apiRequest<ApiEnvelope<Verification | null>>("/verifications/me");
}

export async function startVerification() {
  return apiRequest<VerificationEnvelope>("/verifications", { method: "POST" });
}

export async function updateVerification(
  id: string,
  input: {
    legalName: string;
    documentType: "NATIONAL_ID" | "PASSPORT";
    documentNumber: string;
  },
) {
  return apiRequest<VerificationEnvelope>(`/verifications/${id}/draft`, {
    method: "PATCH",
    body: input,
  });
}

export async function uploadVerificationDocument(
  id: string,
  side: DocumentSide,
  file: File,
) {
  const form = new FormData();
  form.set("file", file);
  return apiRequest<VerificationEnvelope>(
    `/verifications/${id}/documents/${side}`,
    { method: "POST", body: form },
  );
}

export async function submitVerification(id: string) {
  return apiRequest<VerificationEnvelope>(`/verifications/${id}/submit`, {
    method: "POST",
    body: { consent: true },
  });
}

export async function getVerificationQueue(status?: VerificationStatus) {
  const query = status ? `?status=${status}` : "";
  return apiRequest<ApiEnvelope<VerificationPage>>(
    `/admin/verifications${query}`,
  );
}

export async function beginVerificationReview(id: string) {
  return apiRequest<VerificationEnvelope>(
    `/admin/verifications/${id}/begin-review`,
    { method: "POST" },
  );
}

export async function decideVerification(
  id: string,
  decision: "approve" | "reject",
  reason: string,
) {
  return apiRequest<VerificationEnvelope>(
    `/admin/verifications/${id}/${decision}`,
    { method: "POST", body: { reason } },
  );
}

export async function getAdminDocumentUrl(
  verificationId: string,
  documentId: string,
) {
  return apiRequest<ApiEnvelope<{ url: string; expiresInSeconds: number }>>(
    `/admin/verifications/${verificationId}/documents/${documentId}/url`,
  );
}
