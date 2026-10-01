import type { ReactNode } from "react";

export function LoadingState({
  label = "Đang tải dữ liệu",
}: {
  label?: string;
}) {
  return (
    <div
      role="status"
      aria-live="polite"
      className="animate-pulse rounded-xl bg-slate-100 p-6 text-slate-600"
    >
      {label}…
    </div>
  );
}

export function EmptyState({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <section className="rounded-xl border border-dashed border-slate-300 p-8 text-center">
      <h2 className="font-semibold">{title}</h2>
      <p className="mt-2 text-sm text-slate-600">{description}</p>
    </section>
  );
}

export function ErrorState({
  title = "Không thể tải dữ liệu",
  description,
  action,
}: {
  title?: string;
  description: string;
  action?: ReactNode;
}) {
  return (
    <section
      role="alert"
      className="rounded-xl border border-red-200 bg-red-50 p-6"
    >
      <h2 className="font-semibold text-red-900">{title}</h2>
      <p className="mt-2 text-sm text-red-800">{description}</p>
      {action ? <div className="mt-4">{action}</div> : null}
    </section>
  );
}
