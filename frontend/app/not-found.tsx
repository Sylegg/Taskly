import Link from "next/link";

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col justify-center px-6 text-center">
      <p className="text-sm font-semibold text-emerald-700">404</p>
      <h1 className="mt-3 text-3xl font-bold">Không tìm thấy trang</h1>
      <p className="mt-4 text-slate-600">
        Đường dẫn không tồn tại hoặc tài nguyên đã được di chuyển.
      </p>
      <Link className="mt-8 font-semibold text-emerald-700 underline" href="/">
        Về trang chủ
      </Link>
    </main>
  );
}
