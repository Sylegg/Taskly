import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "cn";
import type { HTMLAttributes } from "react";

const badgeVariants = cva(
  "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
  {
    variants: {
      variant: {
        default: "border-transparent bg-emerald-600 text-white shadow hover:bg-emerald-700",
        secondary: "border-transparent bg-slate-100 text-slate-900 hover:bg-slate-200",
        outline: "border border-slate-200 text-slate-700 hover:bg-slate-50",
        success: "border-emerald-200 bg-emerald-50 text-emerald-700 font-medium",
        warning: "border-amber-200 bg-amber-50 text-amber-700 font-medium",
        danger: "border-rose-200 bg-rose-50 text-rose-700 font-medium",
        info: "border-sky-200 bg-sky-50 text-sky-700 font-medium",
        neutral: "border-slate-200 bg-slate-50 text-slate-600 font-medium",
      },
      size: {
        sm: "px-2 py-0.5 text-[11px]",
        default: "px-2.5 py-0.5 text-xs",
        lg: "px-3 py-1 text-sm",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface BadgeProps
  extends HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, size, ...props }: BadgeProps) {
  return (
    <div className={cn(badgeVariants({ variant, size }), className)} {...props} />
  );
}
