"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { FormField } from "@/components/shared/form-field";
import { forgotPassword } from "@/features/auth/api";
import {
  forgotPasswordSchema,
  type ForgotPasswordInput,
} from "@/features/auth/schemas";
import { ApiError } from "@/lib/api/errors";

export default function ForgotPasswordPage() {
  const router = useRouter();
  const form = useForm<ForgotPasswordInput>({
    resolver: zodResolver(forgotPasswordSchema),
    defaultValues: { email: "" },
  });
  const mutation = useMutation({
    mutationFn: forgotPassword,
    onSuccess: (_, input) =>
      router.push(
        `/auth/reset-password?email=${encodeURIComponent(input.email)}`,
      ),
  });
  const error =
    mutation.error instanceof ApiError ? mutation.error.message : null;
  return (
    <div>
      <h1 className="text-3xl font-bold">Khôi phục mật khẩu</h1>
      <p className="mt-2 text-slate-600">
        Nếu email tồn tại, TaskLy sẽ gửi mã khôi phục. Phản hồi không tiết lộ
        tài khoản có tồn tại hay không.
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
          autoComplete="email"
          {...form.register("email")}
          error={form.formState.errors.email?.message}
        />
        <button
          className="h-11 rounded-lg bg-emerald-700 font-semibold text-white disabled:opacity-60"
          disabled={mutation.isPending}
          type="submit"
        >
          {mutation.isPending ? "Đang gửi…" : "Gửi mã khôi phục"}
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
