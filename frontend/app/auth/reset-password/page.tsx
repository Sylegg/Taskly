"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { useForm } from "react-hook-form";
import { FormField } from "@/components/shared/form-field";
import { resetPassword } from "@/features/auth/api";
import {
  resetPasswordSchema,
  type ResetPasswordInput,
} from "@/features/auth/schemas";
import { ApiError } from "@/lib/api/errors";

function ResetForm() {
  const router = useRouter();
  const params = useSearchParams();
  const form = useForm<ResetPasswordInput>({
    resolver: zodResolver(resetPasswordSchema),
    defaultValues: {
      email: params.get("email") ?? "",
      code: "",
      newPassword: "",
      confirmPassword: "",
    },
  });
  const mutation = useMutation({
    mutationFn: resetPassword,
    onSuccess: () => router.replace("/auth/login?reset=1"),
  });
  const error =
    mutation.error instanceof ApiError ? mutation.error.message : null;
  return (
    <div>
      <h1 className="text-3xl font-bold">Đặt mật khẩu mới</h1>
      <p className="mt-2 text-slate-600">
        Mọi refresh session cũ sẽ bị thu hồi sau khi đổi mật khẩu.
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
          label="Mã khôi phục"
          inputMode="numeric"
          maxLength={6}
          {...form.register("code")}
          error={form.formState.errors.code?.message}
        />
        <FormField
          label="Mật khẩu mới"
          type="password"
          autoComplete="new-password"
          {...form.register("newPassword")}
          error={form.formState.errors.newPassword?.message}
        />
        <FormField
          label="Xác nhận mật khẩu"
          type="password"
          autoComplete="new-password"
          {...form.register("confirmPassword")}
          error={form.formState.errors.confirmPassword?.message}
        />
        <button
          className="h-11 rounded-lg bg-emerald-700 font-semibold text-white disabled:opacity-60"
          disabled={mutation.isPending}
          type="submit"
        >
          {mutation.isPending ? "Đang cập nhật…" : "Cập nhật mật khẩu"}
        </button>
      </form>
    </div>
  );
}

export default function ResetPasswordPage() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <ResetForm />
    </Suspense>
  );
}
