"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { getPublicService } from "@/features/catalogue/api";
import type { ServiceItem } from "@/features/catalogue/types";

export default function ServiceDetailPage() {
  const slug = String(useParams<{ slug: string }>().slug);
  const [item, setItem] = useState<ServiceItem | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    let active = true;
    getPublicService(slug)
      .then((r) => {
        if (active) setItem(r.data);
      })
      .catch((e: unknown) => {
        if (active)
          setError(e instanceof Error ? e.message : "Không thể tải dịch vụ.");
      });
    return () => {
      active = false;
    };
  }, [slug]);
  return (
    <main className="mx-auto min-h-screen max-w-4xl px-6 py-10">
      <Link className="font-semibold text-emerald-700" href="/services">
        ← Danh mục dịch vụ
      </Link>
      {error ? (
        <p className="mt-10 rounded-lg bg-red-50 p-4 text-red-800" role="alert">
          {error}
        </p>
      ) : !item ? (
        <p className="mt-10" role="status">
          Đang tải dịch vụ…
        </p>
      ) : (
        <article className="mt-10 rounded-3xl border p-8">
          <p className="font-semibold text-emerald-700">{item.category.name}</p>
          <h1 className="mt-2 text-4xl font-bold">{item.name}</h1>
          <p className="mt-5 text-lg text-slate-600">{item.shortDescription}</p>
          {item.description && (
            <p className="mt-6 whitespace-pre-wrap">{item.description}</p>
          )}
          <dl className="mt-8 grid gap-4 rounded-2xl bg-slate-50 p-6 sm:grid-cols-2">
            <div>
              <dt className="text-sm text-slate-500">Khoảng giá gợi ý</dt>
              <dd className="font-bold">
                {money(item.suggestedPriceMin, item.currency)} –{" "}
                {money(item.suggestedPriceMax, item.currency)}
              </dd>
            </div>
            <div>
              <dt className="text-sm text-slate-500">Thời lượng tham khảo</dt>
              <dd className="font-bold">
                {item.estimatedDurationMinutes
                  ? `${item.estimatedDurationMinutes} phút`
                  : "Trao đổi theo công việc"}
              </dd>
            </div>
          </dl>
          <p className="mt-6 text-sm text-slate-500">
            Tạo yêu cầu công việc sẽ được mở ở Phase 5. Trang này không tạo đơn
            hoặc thanh toán giả.
          </p>
        </article>
      )}
    </main>
  );
}
function money(value: number, currency: string) {
  return new Intl.NumberFormat("vi-VN", {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(value);
}
