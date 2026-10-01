export type UserSummary = Readonly<{
  id: string;
  email: string;
  fullName: string;
  status: string;
  activeMode: "CUSTOMER" | "TASKER";
  roles: string[];
  permissions: string[];
}>;

export type TokenResponse = Readonly<{
  accessToken: string;
  tokenType: "Bearer";
  expiresAt: string;
  user: UserSummary;
}>;

export type ApiEnvelope<T> = Readonly<{
  success: true;
  data: T;
  message?: string;
  timestamp: string;
}>;
