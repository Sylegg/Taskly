"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { FormField } from "@/components/shared/form-field";
import { login } from "@/features/auth/api";
import { useAuth } from "@/features/auth/auth-provider";
import { loginSchema, type LoginInput } from "@/features/auth/schemas";
import { ApiError } from "@/lib/api/errors";

export default function LoginPage() {
  const router = useRouter();
  const auth = useAuth();
  const form = useForm<LoginInput>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "", deviceName: "Trình duyệt web" },
  });
  const mutation = useMutation({
    mutationFn: login,
    onSuccess: (response) => {
      auth.applySession(response.data);
      router.replace(
        response.data.user.activeMode === "TASKER" ? "/tasker" : "/customer",
      );
    },
  });
  const error =
    mutation.error instanceof ApiError ? mutation.error.message : null;

  return (
    <div>
      <Link className="font-bold text-emerald-700 lg:hidden" href="/">
        TaskLy
      </Link>
      <h1 className="mt-6 text-3xl font-bold">Đăng nhập</h1>
      <p className="mt-2 text-slate-600">
        Tiếp tục quản lý công việc và tài khoản của bạn.
      </p>
      <form
        className="mt-8 grid gap-5"
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
          label="Email"
          type="email"
          autoComplete="email"
          {...form.register("email")}
          error={form.formState.errors.email?.message}
        />
        <FormField
          label="Mật khẩu"
          type="password"
          autoComplete="current-password"
          {...form.register("password")}
          error={form.formState.errors.password?.message}
        />
        <button
          className="h-11 rounded-lg bg-emerald-700 font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
          disabled={mutation.isPending}
          type="submit"
        >
          {mutation.isPending ? "Đang đăng nhập…" : "Đăng nhập"}
        </button>
      </form>
      <div className="mt-6 flex justify-between text-sm">
        <Link
          className="text-emerald-700 underline"
          href="/auth/forgot-password"
        >
          Quên mật khẩu?
        </Link>
        <Link className="text-emerald-700 underline" href="/auth/register">
          Tạo tài khoản
        </Link>
      </div>
    </div>
  );
}
