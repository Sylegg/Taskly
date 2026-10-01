import Link from "next/link";
import type { ReactNode } from "react";

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <main className="grid min-h-screen bg-slate-50 lg:grid-cols-2">
      <section className="hidden bg-emerald-800 p-12 text-white lg:flex lg:flex-col lg:justify-between">
        <Link className="text-2xl font-bold" href="/">
          TaskLy
        </Link>
        <div>
          <p className="text-sm font-semibold tracking-widest text-emerald-200 uppercase">
            An toàn • Minh bạch • Linh hoạt
          </p>
          <h1 className="mt-4 max-w-xl text-5xl font-bold tracking-tight">
            Một tài khoản cho Customer và Tasker.
          </h1>
          <p className="mt-5 max-w-lg text-emerald-100">
            Quản lý công việc, bảo mật phiên đăng nhập và chuyển đổi chế độ
            trong cùng một tài khoản.
          </p>
        </div>
        <p className="text-sm text-emerald-200">
          TaskLy closed-beta foundation
        </p>
      </section>
      <section className="flex items-center justify-center p-6 sm:p-12">
        <div className="w-full max-w-md">{children}</div>
      </section>
    </main>
  );
}
