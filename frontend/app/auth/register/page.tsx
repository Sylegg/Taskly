"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { FormField } from "@/components/shared/form-field";
import { register } from "@/features/auth/api";
import { registerSchema, type RegisterInput } from "@/features/auth/schemas";
import { ApiError } from "@/lib/api/errors";

export default function RegisterPage() {
  const router = useRouter();
  const form = useForm<RegisterInput>({
    resolver: zodResolver(registerSchema),
    defaultValues: {
      fullName: "",
      email: "",
      phone: "",
      password: "",
      confirmPassword: "",
    },
  });
  const mutation = useMutation({
    mutationFn: register,
    onSuccess: (_, input) =>
      router.push(`/auth/verify?email=${encodeURIComponent(input.email)}`),
  });
  const error =
    mutation.error instanceof ApiError ? mutation.error.message : null;

  return (
    <div>
      <Link className="font-bold text-emerald-700 lg:hidden" href="/">
        TaskLy
      </Link>
      <h1 className="mt-6 text-3xl font-bold">Tạo tài khoản</h1>
      <p className="mt-2 text-slate-600">
        Một tài khoản có thể sử dụng cả Customer và Tasker.
      </p>
      <form
        className="mt-8 grid gap-4"
        onSubmit={form.handleSubmit((value) => mutation.mutate(value))}
        noValidate
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
          label="Họ và tên"
          autoComplete="name"
          {...form.register("fullName")}
          error={form.formState.errors.fullName?.message}
        />
        <FormField
          label="Email"
          type="email"
          autoComplete="email"
          {...form.register("email")}
          error={form.formState.errors.email?.message}
        />
        <FormField
          label="Số điện thoại"
          inputMode="numeric"
          autoComplete="tel"
          {...form.register("phone")}
          error={form.formState.errors.phone?.message}
        />
        <FormField
          label="Mật khẩu"
          type="password"
          autoComplete="new-password"
          {...form.register("password")}
          error={form.formState.errors.password?.message}
        />
        <FormField
          label="Xác nhận mật khẩu"
          type="password"
          autoComplete="new-password"
          {...form.register("confirmPassword")}
          error={form.formState.errors.confirmPassword?.message}
        />
        <button
          className="mt-2 h-11 rounded-lg bg-emerald-700 font-semibold text-white disabled:opacity-60"
          disabled={mutation.isPending}
          type="submit"
        >
          {mutation.isPending ? "Đang tạo tài khoản…" : "Đăng ký"}
        </button>
      </form>
      <p className="mt-6 text-sm text-slate-600">
        Đã có tài khoản?{" "}
        <Link className="text-emerald-700 underline" href="/auth/login">
          Đăng nhập
        </Link>
      </p>
    </div>
  );
}
