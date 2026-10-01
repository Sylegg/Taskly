"use client";

import Link from "next/link";
import { ProtectedAccount } from "@/features/auth/protected-account";
import { useAuth } from "@/features/auth/auth-provider";
import { TaskerKycPanel } from "@/features/verification/tasker-kyc-panel";
import { TasklyLogo } from "@/components/brand/taskly-logo";

export default function TaskerDashboard() {
  const auth = useAuth();
  return (
    <ProtectedAccount>
      {(name, logout) => (
        <main className="min-h-screen bg-gradient-to-b from-green-50 via-white to-emerald-50/40 px-6 py-10 text-slate-900">
          <div className="mx-auto max-w-6xl">
          <header className="flex items-center justify-between border-b border-green-200/80 pb-6">
            <Link className="flex items-center gap-2" href="/">
              <TasklyLogo variant="partner" />
              <span className="rounded-full bg-green-100 px-2.5 py-1 text-xs font-bold text-green-800">PARTNER</span>
            </Link>
            <button
              className="rounded-lg border border-green-200 bg-white px-4 py-2 text-sm font-semibold text-green-800 hover:bg-green-50"
              onClick={() => void logout()}
              type="button"
            >
              Đăng xuất
            </button>
          </header>
          <section className="py-12">
            <p className="font-semibold text-green-700">CỔNG ĐỐI TÁC TASKLY</p>
            <h1 className="mt-2 text-4xl font-bold">Xin chào, {name}</h1>
            <p className="mt-4 max-w-2xl text-slate-600">
              Hoàn tất xác minh danh tính để đủ điều kiện nhận việc. Quyết định
              KYC được kiểm soát bởi backend và nhân sự có quyền xét duyệt.
            </p>
            <TaskerKycPanel
              hasTaskerRole={auth.user?.roles.includes("TASKER") ?? false}
            />
          </section>
          </div>
        </main>
      )}
    </ProtectedAccount>
  );
}
