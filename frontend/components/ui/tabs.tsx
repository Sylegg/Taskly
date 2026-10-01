"use client";

import { cn } from "cn";
import type { ReactNode } from "react";

interface TabsListProps {
  children: ReactNode;
  className?: string;
}

export function TabsList({ children, className }: TabsListProps) {
  return (
    <div
      role="tablist"
      className={cn(
        "inline-flex items-center justify-center rounded-xl bg-slate-100 p-1 text-slate-500 shadow-inner",
        className,
      )}
    >
      {children}
    </div>
  );
}

interface TabTriggerProps {
  value: string;
  active: boolean;
  onClick: () => void;
  children: ReactNode;
  className?: string;
}

export function TabTrigger({
  active,
  onClick,
  children,
  className,
}: TabTriggerProps) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      onClick={onClick}
      className={cn(
        "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg px-3.5 py-1.5 text-xs sm:text-sm font-semibold transition-all outline-none",
        active
          ? "bg-white text-slate-900 shadow-xs"
          : "text-slate-600 hover:text-slate-900 hover:bg-slate-200/50",
        className,
      )}
    >
      {children}
    </button>
  );
}
