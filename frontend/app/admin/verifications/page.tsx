"use client";

import Link from "next/link";
import { useAuth } from "@/features/auth/auth-provider";
import { ProtectedAccount } from "@/features/auth/protected-account";
import { AdminReviewPanel } from "@/features/verification/admin-review-panel";

export default function AdminVerificationPage() {
  const auth = useAuth();
  return (
    <ProtectedAccount>
      {(name, logout) => (
        <main className="mx-auto min-h-screen max-w-6xl px-6 py-10">
          <header className="flex flex-wrap items-center justify-between gap-4 border-b border-slate-200 pb-6">
            <div>
              <Link className="text-2xl font-bold text-emerald-700" href="/">
                TaskLy Admin
              </Link>
              <p className="text-sm text-slate-500">Đăng nhập: {name}</p>
            </div>
            <button
              className="rounded-lg border px-4 py-2 text-sm font-semibold"
              onClick={() => void logout()}
              type="button"
            >
              Đăng xuất
            </button>
          </header>
          <div className="pt-10">
            <p className="font-semibold text-emerald-700">TRUST &amp; SAFETY</p>
            <h1 className="mt-2 text-4xl font-bold">Xét duyệt KYC</h1>
            <p className="mt-3 max-w-2xl text-slate-600">
              Chỉ tài khoản có quyền KYC_REVIEW mới có thể tải hàng chờ, mở tài
              liệu riêng tư và ra quyết định.
            </p>
          </div>
          <AdminReviewPanel
            allowed={auth.user?.permissions.includes("KYC_REVIEW") ?? false}
          />
        </main>
      )}
    </ProtectedAccount>
  );
}
