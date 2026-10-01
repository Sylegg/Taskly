"use client";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="vi">
      <body>
        <main className="mx-auto flex min-h-screen max-w-xl flex-col justify-center px-6 text-center">
          <h1 className="text-3xl font-bold">TaskLy đang gặp sự cố</h1>
          <p className="mt-4 text-slate-600">
            Vui lòng thử lại. Mã hỗ trợ: {error.digest ?? "chưa có"}
          </p>
          <button
            className="mx-auto mt-8 rounded-lg bg-emerald-700 px-5 py-3 font-semibold text-white"
            type="button"
            onClick={reset}
          >
            Thử lại
          </button>
        </main>
      </body>
    </html>
  );
}
