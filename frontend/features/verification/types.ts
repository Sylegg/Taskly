import type { ApiEnvelope } from "@/features/auth/types";

export type VerificationStatus =
  | "NOT_STARTED"
  | "DRAFT"
  | "SUBMITTED"
  | "UNDER_REVIEW"
  | "APPROVED"
  | "REJECTED";

export type DocumentSide = "FRONT" | "BACK";

export type VerificationDocument = Readonly<{
  id: string;
  side: DocumentSide | "SELFIE";
  scanStatus: "PENDING" | "CLEAN" | "INFECTED" | "FAILED";
}>;

export type Verification = Readonly<{
  id: string;
  userId: string;
  status: VerificationStatus;
  legalName: string | null;
  documentType: "NATIONAL_ID" | "PASSPORT" | null;
  documentNumberMasked: string | null;
  submittedAt: string | null;
  decisionReason: string | null;
  documents: VerificationDocument[];
}>;

export type VerificationPage = Readonly<{
  items: Verification[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}>;

export type VerificationEnvelope = ApiEnvelope<Verification>;
