"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { useForm } from "react-hook-form";
import { FormField } from "@/components/shared/form-field";
import { verifyOtp } from "@/features/auth/api";
import { otpSchema, type OtpInput } from "@/features/auth/schemas";
import { ApiError } from "@/lib/api/errors";

function VerifyForm() {
  const router = useRouter();
  const params = useSearchParams();
  const form = useForm<OtpInput>({
    resolver: zodResolver(otpSchema),
    defaultValues: { email: params.get("email") ?? "", code: "" },
  });
  const mutation = useMutation({
    mutationFn: verifyOtp,
    onSuccess: () => router.replace("/auth/login?verified=1"),
  });
  const error =
    mutation.error instanceof ApiError ? mutation.error.message : null;
  return (
    <div>
      <h1 className="text-3xl font-bold">Xác minh email</h1>
      <p className="mt-2 text-slate-600">
        Nhập mã 6 chữ số đã gửi tới email của bạn.
      </p>
      <form
        className="mt-8 grid gap-5"
        onSubmit={form.handleSubmit((value) => mutation.mutate(value))}
      >
        {error ? (
          <div
            role="alert"
            className="rounded-lg bg-red-50 p-3 text-sm text-red-800"
          >
            {error}
          </div>
        ) : null}
        <FormField
          label="Email"
          type="email"
          readOnly
          {...form.register("email")}
          error={form.formState.errors.email?.message}
        />
        <FormField
          label="Mã xác minh"
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={6}
          {...form.register("code")}
          error={form.formState.errors.code?.message}
        />
        <button
          className="h-11 rounded-lg bg-emerald-700 font-semibold text-white disabled:opacity-60"
          disabled={mutation.isPending}
          type="submit"
        >
          {mutation.isPending ? "Đang xác minh…" : "Xác minh"}
        </button>
      </form>
      <Link
        className="mt-6 inline-block text-sm text-emerald-700 underline"
        href="/auth/login"
      >
        Quay lại đăng nhập
      </Link>
    </div>
  );
}

export default function VerifyPage() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <VerifyForm />
    </Suspense>
  );
}
