import { z } from "zod";

export const loginSchema = z.object({
  email: z.string().email("Email chưa hợp lệ"),
  password: z.string().min(1, "Nhập mật khẩu").max(128),
  deviceName: z.string().max(200).optional(),
});

export const registerSchema = z
  .object({
    fullName: z.string().trim().min(2, "Tên cần ít nhất 2 ký tự").max(160),
    email: z.string().email("Email chưa hợp lệ"),
    phone: z.string().regex(/^0[0-9]{9}$/, "Số điện thoại phải có 10 chữ số"),
    password: z.string().min(10, "Mật khẩu cần ít nhất 10 ký tự").max(128),
    confirmPassword: z.string(),
  })
  .refine((value) => value.password === value.confirmPassword, {
    message: "Mật khẩu xác nhận chưa khớp",
    path: ["confirmPassword"],
  });

export const otpSchema = z.object({
  email: z.string().email(),
  code: z.string().regex(/^[0-9]{6}$/, "Mã xác minh gồm 6 chữ số"),
});

export const forgotPasswordSchema = z.object({
  email: z.string().email("Email chưa hợp lệ"),
});

export const resetPasswordSchema = z
  .object({
    email: z.string().email("Email chưa hợp lệ"),
    code: z.string().regex(/^[0-9]{6}$/, "Mã khôi phục gồm 6 chữ số"),
    newPassword: z.string().min(10, "Mật khẩu cần ít nhất 10 ký tự").max(128),
    confirmPassword: z.string(),
  })
  .refine((value) => value.newPassword === value.confirmPassword, {
    message: "Mật khẩu xác nhận chưa khớp",
    path: ["confirmPassword"],
  });

export type LoginInput = z.infer<typeof loginSchema>;
export type RegisterInput = z.infer<typeof registerSchema>;
export type OtpInput = z.infer<typeof otpSchema>;
export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>;
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;
