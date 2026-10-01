export type TaskStatus =
  | "DRAFT"
  | "POSTED"
  | "MATCHING"
  | "ACCEPTED"
  | "IN_PROGRESS"
  | "COMPLETED"
  | "PAID"
  | "CANCELLED";

export type TaskPriority = "URGENT" | "HIGH" | "MEDIUM" | "LOW";

export interface Task {
  id: string;
  title: string;
  description: string;
  serviceName: string;
  serviceSlug: string;
  categoryName: string;
  status: TaskStatus;
  priority: TaskPriority;
  budgetAmount: number;
  currency: string;
  addressLine: string;
  city: string;
  scheduledAt: string;
  estimatedDurationMinutes: number;
  taskerName?: string;
  taskerAvatar?: string;
  taskerRating?: number;
  taskerPhone?: string;
  customerNotes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateTaskInput {
  title: string;
  description: string;
  serviceName: string;
  serviceSlug: string;
  categoryName: string;
  priority: TaskPriority;
  budgetAmount: number;
  addressLine: string;
  city: string;
  scheduledAt: string;
  estimatedDurationMinutes: number;
  customerNotes?: string;
}
