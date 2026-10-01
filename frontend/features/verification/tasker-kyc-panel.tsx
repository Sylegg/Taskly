"use client";

import { useEffect, useState, type FormEvent } from "react";
import {
  enableTaskerMode,
  getMyVerification,
  startVerification,
  submitVerification,
  updateVerification,
  uploadVerificationDocument,
} from "./api";
import type { DocumentSide, Verification } from "./types";

const statusText: Record<Verification["status"], string> = {
  NOT_STARTED: "Chưa bắt đầu",
  DRAFT: "Bản nháp",
  SUBMITTED: "Đã gửi",
  UNDER_REVIEW: "Đang xét duyệt",
  APPROVED: "Đã phê duyệt",
  REJECTED: "Bị từ chối",
};

export function TaskerKycPanel({ hasTaskerRole }: { hasTaskerRole: boolean }) {
  const [taskerEnabled, setTaskerEnabled] = useState(hasTaskerRole);
  const [verification, setVerification] = useState<Verification | null>(null);
  const [loading, setLoading] = useState(hasTaskerRole);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [legalName, setLegalName] = useState("");
  const [documentType, setDocumentType] = useState<"NATIONAL_ID" | "PASSPORT">(
    "NATIONAL_ID",
  );
  const [documentNumber, setDocumentNumber] = useState("");
  const [consent, setConsent] = useState(false);

  useEffect(() => {
    if (!taskerEnabled) return;
    let active = true;
    getMyVerification()
      .then((response) => {
        if (!active) return;
        setVerification(response.data);
        if (response.data) {
          setLegalName(response.data.legalName ?? "");
          setDocumentType(response.data.documentType ?? "NATIONAL_ID");
        }
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
  }, [taskerEnabled]);

  async function run(action: () => Promise<Verification>, success: string) {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      const value = await action();
      setVerification(value);
      setNotice(success);
    } catch (caught) {
      setError(message(caught));
    } finally {
      setBusy(false);
    }
  }

  if (!taskerEnabled) {
    return (
      <section className="mt-8 rounded-2xl border border-amber-200 bg-amber-50 p-6">
        <h2 className="text-xl font-bold">Bật chế độ Tasker</h2>
        <p className="mt-2 text-sm text-slate-700">
          Bạn cần bật vai trò Tasker trước khi tạo hồ sơ KYC. Thao tác này không
          tự phê duyệt KYC.
        </p>
        {error && <Alert text={error} />}
        <button
          className="mt-5 rounded-lg bg-emerald-700 px-4 py-2 font-semibold text-white disabled:opacity-50"
          disabled={busy}
          onClick={() => {
            setBusy(true);
            setError(null);
            void enableTaskerMode()
              .then(() => {
                setLoading(true);
                setTaskerEnabled(true);
              })
              .catch((caught: unknown) => setError(message(caught)))
              .finally(() => setBusy(false));
          }}
          type="button"
        >
          {busy ? "Đang bật…" : "Bật chế độ Tasker"}
        </button>
      </section>
    );
  }

  if (loading)
    return (
      <p className="mt-8" role="status">
        Đang tải trạng thái KYC…
      </p>
    );

  if (!verification) {
    return (
      <section className="mt-8 rounded-2xl border p-6">
        <h2 className="text-xl font-bold">Xác minh danh tính</h2>
        <p className="mt-2 text-sm text-slate-600">
          Tasker chỉ có thể nhận việc sau khi hồ sơ được phê duyệt.
        </p>
        {error && <Alert text={error} />}
        <button
          className="mt-5 rounded-lg bg-emerald-700 px-4 py-2 font-semibold text-white disabled:opacity-50"
          disabled={busy}
          onClick={() =>
            void run(
              async () => (await startVerification()).data,
              "Đã tạo bản nháp KYC.",
            )
          }
          type="button"
        >
          Bắt đầu KYC
        </button>
      </section>
    );
  }

  const editable = verification.status === "DRAFT";
  const hasFront = verification.documents.some((item) => item.side === "FRONT");
  const hasBack = verification.documents.some((item) => item.side === "BACK");

  return (
    <section className="mt-8 rounded-2xl border p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-emerald-700">HỒ SƠ KYC</p>
          <h2 className="text-2xl font-bold">
            {statusText[verification.status]}
          </h2>
        </div>
        <span className="rounded-full bg-slate-100 px-3 py-1 text-sm">
          {verification.id.slice(0, 8)}
        </span>
      </div>
      {error && <Alert text={error} />}
      {notice && (
        <p
          className="mt-4 rounded-lg bg-emerald-50 p-3 text-sm text-emerald-800"
          role="status"
        >
          {notice}
        </p>
      )}
      {verification.decisionReason && (
        <p className="mt-4 rounded-lg bg-amber-50 p-3 text-sm">
          <strong>Lý do quyết định:</strong> {verification.decisionReason}
        </p>
      )}

      {editable ? (
        <form
          className="mt-6 grid gap-5"
          onSubmit={(event: FormEvent) => {
            event.preventDefault();
            void run(
              async () =>
                (
                  await updateVerification(verification.id, {
                    legalName,
                    documentType,
                    documentNumber,
                  })
                ).data,
              "Đã lưu thông tin. Số giấy tờ thô không được lưu trên hệ thống.",
            );
          }}
        >
          <label className="grid gap-2 text-sm font-semibold">
            Họ tên pháp lý
            <input
              className="rounded-lg border p-3 font-normal"
              maxLength={160}
              minLength={2}
              onChange={(e) => setLegalName(e.target.value)}
              required
              value={legalName}
            />
          </label>
          <label className="grid gap-2 text-sm font-semibold">
            Loại giấy tờ
            <select
              className="rounded-lg border p-3 font-normal"
              onChange={(e) =>
                setDocumentType(e.target.value as "NATIONAL_ID" | "PASSPORT")
              }
              value={documentType}
            >
              <option value="NATIONAL_ID">CCCD / căn cước</option>
              <option value="PASSPORT">Hộ chiếu</option>
            </select>
          </label>
          <label className="grid gap-2 text-sm font-semibold">
            Số giấy tờ
            <input
              className="rounded-lg border p-3 font-normal"
              maxLength={30}
              minLength={6}
              onChange={(e) => setDocumentNumber(e.target.value)}
              required
              value={documentNumber}
            />
            <span className="font-normal text-slate-500">
              Chỉ 4 ký tự cuối được giữ lại sau khi lưu.
            </span>
          </label>
          <button
            className="w-fit rounded-lg border border-emerald-700 px-4 py-2 font-semibold text-emerald-800 disabled:opacity-50"
            disabled={busy}
            type="submit"
          >
            Lưu thông tin
          </button>

          <div className="grid gap-4 sm:grid-cols-2">
            <Upload
              side="FRONT"
              complete={hasFront}
              disabled={busy}
              onUpload={(file) =>
                run(
                  async () =>
                    (
                      await uploadVerificationDocument(
                        verification.id,
                        "FRONT",
                        file,
                      )
                    ).data,
                  "Đã tải ảnh mặt trước.",
                )
              }
            />
            <Upload
              side="BACK"
              complete={hasBack}
              disabled={busy}
              onUpload={(file) =>
                run(
                  async () =>
                    (
                      await uploadVerificationDocument(
                        verification.id,
                        "BACK",
                        file,
                      )
                    ).data,
                  "Đã tải ảnh mặt sau.",
                )
              }
            />
          </div>
          <label className="flex items-start gap-3 text-sm">
            <input
              checked={consent}
              className="mt-1"
              onChange={(e) => setConsent(e.target.checked)}
              type="checkbox"
            />
            Tôi đồng ý cho TaskLy xử lý dữ liệu KYC nhằm xác minh danh tính và
            đảm bảo an toàn nền tảng.
          </label>
          <button
            className="w-fit rounded-lg bg-emerald-700 px-5 py-3 font-semibold text-white disabled:opacity-50"
            disabled={
              busy ||
              !consent ||
              !hasFront ||
              !hasBack ||
              !verification.legalName
            }
            onClick={() =>
              void run(
                async () => (await submitVerification(verification.id)).data,
                "Đã gửi hồ sơ để xét duyệt.",
              )
            }
            type="button"
          >
            Gửi xét duyệt
          </button>
        </form>
      ) : (
        <div className="mt-6 text-sm text-slate-600">
          <p>Tài liệu: {verification.documents.length}/2 ảnh bắt buộc.</p>
          {verification.status === "APPROVED" && (
            <p className="mt-2 font-semibold text-emerald-700">
              Đủ điều kiện KYC để nhận việc khi module công việc được mở.
            </p>
          )}
          {verification.status === "REJECTED" && (
            <p className="mt-2">Bạn có thể bắt đầu hồ sơ mới để gửi lại.</p>
          )}
        </div>
      )}
      {verification.status === "REJECTED" && (
        <button
          className="mt-5 rounded-lg bg-emerald-700 px-4 py-2 font-semibold text-white disabled:opacity-50"
          disabled={busy}
          onClick={() =>
            void run(
              async () => (await startVerification()).data,
              "Đã tạo hồ sơ gửi lại.",
            )
          }
          type="button"
        >
          Tạo hồ sơ mới
        </button>
      )}
    </section>
  );
}

function Upload({
  side,
  complete,
  disabled,
  onUpload,
}: {
  side: DocumentSide;
  complete: boolean;
  disabled: boolean;
  onUpload: (file: File) => Promise<void>;
}) {
  return (
    <label className="grid gap-2 rounded-xl border border-dashed p-4 text-sm font-semibold">
      {side === "FRONT" ? "Ảnh mặt trước" : "Ảnh mặt sau"} {complete ? "✓" : ""}
      <input
        accept="image/jpeg,image/png"
        disabled={disabled}
        onChange={(event) => {
          const file = event.target.files?.[0];
          if (file) void onUpload(file);
        }}
        type="file"
      />
      <span className="font-normal text-slate-500">
        JPEG/PNG, tối đa 10 MB.
      </span>
    </label>
  );
}

function Alert({ text }: { text: string }) {
  return (
    <p
      className="mt-4 rounded-lg bg-red-50 p-3 text-sm text-red-800"
      role="alert"
    >
      {text}
    </p>
  );
}

function message(value: unknown) {
  return value instanceof Error ? value.message : "Không thể hoàn tất yêu cầu.";
}
