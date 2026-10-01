"use client";

import { useCallback, useEffect, useState } from "react";
import {
  beginVerificationReview,
  decideVerification,
  getAdminDocumentUrl,
  getVerificationQueue,
} from "./api";
import type { Verification, VerificationStatus } from "./types";

export function AdminReviewPanel({ allowed }: { allowed: boolean }) {
  const [items, setItems] = useState<Verification[]>([]);
  const [filter, setFilter] = useState<VerificationStatus | "">("");
  const [loading, setLoading] = useState(allowed);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [reason, setReason] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!allowed) return;
    setLoading(true);
    setError(null);
    try {
      const response = await getVerificationQueue(filter || undefined);
      setItems(response.data.items);
    } catch (caught) {
      setError(message(caught));
    } finally {
      setLoading(false);
    }
  }, [allowed, filter]);

  useEffect(() => {
    if (!allowed) return;
    let active = true;
    getVerificationQueue(filter || undefined)
      .then((response) => {
        if (active) setItems(response.data.items);
      })
      .catch((caught: unknown) => {
        if (active) setError(message(caught));
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [allowed, filter]);

  if (!allowed) {
    return (
      <p
        className="mt-8 rounded-xl bg-amber-50 p-5 text-amber-900"
        role="alert"
      >
        Tài khoản không có quyền KYC_REVIEW. Dữ liệu hồ sơ không được tải.
      </p>
    );
  }

  async function mutate(
    id: string,
    action: () => Promise<void>,
    success: string,
  ) {
    setBusyId(id);
    setError(null);
    setNotice(null);
    try {
      await action();
      setNotice(success);
      await load();
    } catch (caught) {
      setError(message(caught));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <section className="mt-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <label className="grid gap-2 text-sm font-semibold">
          Trạng thái
          <select
            className="rounded-lg border bg-white p-3 font-normal"
            onChange={(e) =>
              setFilter(e.target.value as VerificationStatus | "")
            }
            value={filter}
          >
            <option value="">Hàng chờ mặc định</option>
            <option value="SUBMITTED">Đã gửi</option>
            <option value="UNDER_REVIEW">Đang xét duyệt</option>
            <option value="APPROVED">Đã duyệt</option>
            <option value="REJECTED">Đã từ chối</option>
          </select>
        </label>
        <button
          className="rounded-lg border px-4 py-2 font-semibold"
          disabled={loading}
          onClick={() => void load()}
          type="button"
        >
          Làm mới
        </button>
      </div>
      {error && (
        <p
          className="mt-4 rounded-lg bg-red-50 p-3 text-sm text-red-800"
          role="alert"
        >
          {error}
        </p>
      )}
      {notice && (
        <p
          className="mt-4 rounded-lg bg-emerald-50 p-3 text-sm text-emerald-800"
          role="status"
        >
          {notice}
        </p>
      )}
      {loading ? (
        <p className="mt-8" role="status">
          Đang tải hàng chờ…
        </p>
      ) : items.length === 0 ? (
        <p className="mt-8 rounded-xl border border-dashed p-8 text-center text-slate-600">
          Không có hồ sơ trong hàng chờ này.
        </p>
      ) : (
        <div className="mt-6 grid gap-5">
          {items.map((item) => (
            <article className="rounded-2xl border bg-white p-6" key={item.id}>
              <div className="flex flex-wrap justify-between gap-3">
                <div>
                  <p className="text-xs font-bold text-emerald-700">
                    {item.status}
                  </p>
                  <h2 className="text-xl font-bold">
                    {item.legalName ?? "Chưa có họ tên"}
                  </h2>
                  <p className="text-sm text-slate-500">User {item.userId}</p>
                </div>
                <div className="text-right text-sm">
                  <p>{item.documentType ?? "—"}</p>
                  <p className="font-mono">
                    {item.documentNumberMasked ?? "—"}
                  </p>
                </div>
              </div>
              <div className="mt-5 flex flex-wrap gap-3">
                {item.documents.map((document) => (
                  <button
                    className="rounded-lg border px-3 py-2 text-sm font-semibold"
                    key={document.id}
                    onClick={() =>
                      void mutate(
                        item.id,
                        async () => {
                          const response = await getAdminDocumentUrl(
                            item.id,
                            document.id,
                          );
                          window.open(
                            response.data.url,
                            "_blank",
                            "noopener,noreferrer",
                          );
                        },
                        `Đã tạo liên kết ${document.side} có thời hạn.`,
                      )
                    }
                    type="button"
                  >
                    Mở {document.side} · {document.scanStatus}
                  </button>
                ))}
              </div>
              {(item.status === "SUBMITTED" ||
                item.status === "UNDER_REVIEW") && (
                <div className="mt-5 grid gap-3">
                  {item.status === "SUBMITTED" && (
                    <button
                      className="w-fit rounded-lg border border-emerald-700 px-4 py-2 font-semibold text-emerald-800 disabled:opacity-50"
                      disabled={busyId === item.id}
                      onClick={() =>
                        void mutate(
                          item.id,
                          async () => {
                            await beginVerificationReview(item.id);
                          },
                          "Đã nhận xét duyệt hồ sơ.",
                        )
                      }
                      type="button"
                    >
                      Bắt đầu xét duyệt
                    </button>
                  )}
                  <label className="grid gap-2 text-sm font-semibold">
                    Lý do quyết định
                    <textarea
                      className="min-h-24 rounded-lg border p-3 font-normal"
                      maxLength={1000}
                      minLength={5}
                      onChange={(e) =>
                        setReason((current) => ({
                          ...current,
                          [item.id]: e.target.value,
                        }))
                      }
                      value={reason[item.id] ?? ""}
                    />
                  </label>
                  <div className="flex gap-3">
                    <button
                      className="rounded-lg bg-emerald-700 px-4 py-2 font-semibold text-white disabled:opacity-50"
                      disabled={
                        busyId === item.id ||
                        (reason[item.id]?.trim().length ?? 0) < 5
                      }
                      onClick={() =>
                        void mutate(
                          item.id,
                          async () => {
                            await decideVerification(
                              item.id,
                              "approve",
                              (reason[item.id] ?? "").trim(),
                            );
                          },
                          "Đã phê duyệt hồ sơ.",
                        )
                      }
                      type="button"
                    >
                      Phê duyệt
                    </button>
                    <button
                      className="rounded-lg bg-red-700 px-4 py-2 font-semibold text-white disabled:opacity-50"
                      disabled={
                        busyId === item.id ||
                        (reason[item.id]?.trim().length ?? 0) < 5
                      }
                      onClick={() =>
                        void mutate(
                          item.id,
                          async () => {
                            await decideVerification(
                              item.id,
                              "reject",
                              (reason[item.id] ?? "").trim(),
                            );
                          },
                          "Đã từ chối hồ sơ.",
                        )
                      }
                      type="button"
                    >
                      Từ chối
                    </button>
                  </div>
                </div>
              )}
            </article>
          ))}
        </div>
      )}
    </section>
  );
}

function message(value: unknown) {
  return value instanceof Error ? value.message : "Không thể hoàn tất yêu cầu.";
}
