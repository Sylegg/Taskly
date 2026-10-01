"use client";

import Link from "next/link";
import { useAuth } from "@/features/auth/auth-provider";
import { ProtectedAccount } from "@/features/auth/protected-account";
import { AdminCataloguePanel } from "@/features/catalogue/admin-catalogue-panel";

export default function AdminCataloguePage() {
  const auth = useAuth();
  return (
    <ProtectedAccount>
      {(name, logout) => (
        <main className="mx-auto min-h-screen max-w-7xl px-6 py-10">
          <header className="flex flex-wrap items-center justify-between gap-4 border-b pb-6">
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
          <section className="pt-10">
            <p className="font-semibold text-emerald-700">NỘI DUNG NỀN TẢNG</p>
            <h1 className="mt-2 text-4xl font-bold">Quản lý catalogue</h1>
            <p className="mt-3 max-w-2xl text-slate-600">
              Danh mục và dịch vụ mới luôn bắt đầu ở trạng thái ẩn. Chỉ dữ liệu
              đã kích hoạt mới xuất hiện công khai.
            </p>
            <AdminCataloguePanel
              allowed={
                auth.user?.permissions.includes("SERVICE_MANAGE") ?? false
              }
            />
          </section>
        </main>
      )}
    </ProtectedAccount>
  );
}
