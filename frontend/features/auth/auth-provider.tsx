"use client";

import { setAccessToken } from "@/lib/api/client";
import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { logoutSession, refreshSession } from "./api";
import type { TokenResponse, UserSummary } from "./types";

type AuthContextValue = {
  user: UserSummary | null;
  loading: boolean;
  applySession: (session: TokenResponse) => void;
  logout: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<UserSummary | null>(null);
  const [loading, setLoading] = useState(true);

  const applySession = (session: TokenResponse) => {
    setAccessToken(session.accessToken);
    setUser(session.user);
  };

  useEffect(() => {
    let mounted = true;
    refreshSession()
      .then((response) => {
        if (mounted) applySession(response.data);
      })
      .catch(() => {
        if (mounted) {
          setAccessToken(null);
          setUser(null);
        }
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      loading,
      applySession,
      logout: async () => {
        try {
          await logoutSession();
        } finally {
          setAccessToken(null);
          setUser(null);
        }
      },
    }),
    [user, loading],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used inside AuthProvider");
  return context;
}
