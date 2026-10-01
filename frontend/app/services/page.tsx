"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { getPublicCatalogue } from "@/features/catalogue/api";
import type { Catalogue } from "@/features/catalogue/types";

export default function ServicesPage() {
  const [data, setData] = useState<Catalogue | null>(null);
  const [category, setCategory] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    let active = true;
    getPublicCatalogue(category || undefined)
      .then((r) => {
        if (active) setData(r.data);
      })
      .catch((e: unknown) => {
        if (active)
          setError(e instanceof Error ? e.message : "Không thể tải danh mục.");
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [category]);
  return (
    <main className="mx-auto min-h-screen max-w-6xl px-6 py-10">
      <header className="flex items-center justify-between border-b pb-6">
        <Link className="text-2xl font-bold text-emerald-700" href="/">
          TaskLy
        </Link>
        <Link className="font-semibold" href="/auth/login">
          Đăng nhập
        </Link>
      </header>
      <section className="py-12">
        <p className="font-semibold text-emerald-700">DANH MỤC CÔNG KHAI</p>
        <h1 className="mt-2 text-4xl font-bold">Bạn cần hỗ trợ việc gì?</h1>
        {data && (
          <div className="mt-6 flex flex-wrap gap-2">
            <button
              className={`rounded-full px-4 py-2 ${category === "" ? "bg-emerald-700 text-white" : "border"}`}
              onClick={() => {
                setLoading(true);
                setCategory("");
              }}
              type="button"
            >
              Tất cả
            </button>
            {data.categories.map((item) => (
              <button
                className={`rounded-full px-4 py-2 ${category === item.slug ? "bg-emerald-700 text-white" : "border"}`}
                key={item.id}
                onClick={() => {
                  setLoading(true);
                  setCategory(item.slug);
                }}
                type="button"
              >
                {item.name}
              </button>
            ))}
          </div>
        )}
        {loading ? (
          <p className="mt-10" role="status">
            Đang tải dịch vụ…
          </p>
        ) : error ? (
          <p
            className="mt-10 rounded-lg bg-red-50 p-4 text-red-800"
            role="alert"
          >
            {error}
          </p>
        ) : !data?.services.length ? (
          <p className="mt-10 rounded-xl border border-dashed p-8 text-center text-slate-600">
            Chưa có dịch vụ đang hoạt động.
          </p>
        ) : (
          <div className="mt-8 grid gap-5 md:grid-cols-2 lg:grid-cols-3">
            {data.services.map((item) => (
              <Link
                className="rounded-2xl border p-6 transition hover:border-emerald-500"
                href={`/services/${item.slug}`}
                key={item.id}
              >
                <p className="text-xs font-bold text-emerald-700">
                  {item.category.name}
                </p>
                <h2 className="mt-2 text-xl font-bold">{item.name}</h2>
                <p className="mt-2 text-sm text-slate-600">
                  {item.shortDescription}
                </p>
                <p className="mt-5 font-semibold">
                  {money(item.suggestedPriceMin, item.currency)} –{" "}
                  {money(item.suggestedPriceMax, item.currency)}
                </p>
              </Link>
            ))}
          </div>
        )}
      </section>
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
