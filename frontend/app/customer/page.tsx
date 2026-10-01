"use client";

import { useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { useAuth } from "@/features/auth/auth-provider";
import { AppShell } from "@/components/layout/app-shell";
import { TaskProvider } from "@/features/tasks/task-context";
import { DashboardView } from "@/features/dashboard/dashboard-view";

function CustomerPageContent() {
  const auth = useAuth();
  const searchParams = useSearchParams();
  const currentTab = searchParams.get("tab") ?? "overview";

  const displayName = auth.user?.fullName ?? "Khách hàng";
  const userRole = auth.user?.roles?.[0] ?? "Customer";

  return (
    <TaskProvider>
      <AppShell
        userName={displayName}
        userRole={userRole}
        onLogout={auth.user ? () => auth.logout() : undefined}
      >
        <DashboardView userName={displayName} initialTab={currentTab} />
      </AppShell>
    </TaskProvider>
  );
}

export default function CustomerPage() {
  return (
    <Suspense
      fallback={
        <div className="flex h-screen items-center justify-center bg-slate-50 text-slate-500 font-medium">
          Đang tải không gian làm việc TaskLy...
        </div>
      }
    >
      <CustomerPageContent />
    </Suspense>
  );
}
