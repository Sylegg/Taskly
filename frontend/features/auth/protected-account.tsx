"use client";

import { useRouter } from "next/navigation";
import { useEffect, type ReactNode } from "react";
import { useAuth } from "./auth-provider";

export function ProtectedAccount({
  children,
}: {
  children: (name: string, logout: () => Promise<void>) => ReactNode;
}) {
  const auth = useAuth();
  const router = useRouter();
  useEffect(() => {
    if (!auth.loading && !auth.user) router.replace("/auth/login");
  }, [auth.loading, auth.user, router]);
  if (auth.loading)
    return (
      <main className="p-8" role="status">
        Đang khôi phục phiên đăng nhập…
      </main>
    );
  if (!auth.user) return null;
  return children(auth.user.fullName, async () => {
    await auth.logout();
    router.replace("/auth/login");
  });
}
