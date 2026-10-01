import { cn } from "cn";

type TasklyLogoProps = {
  variant?: "default" | "partner";
  className?: string;
  showWordmark?: boolean;
};

/** The Taskly mark, with a dedicated green treatment for the Partner portal. */
export function TasklyLogo({
  variant = "default",
  className,
  showWordmark = true,
}: TasklyLogoProps) {
  const partner = variant === "partner";
  const primaryColor = partner ? "#059669" : "#007DF0";

  return (
    <div className={cn("inline-flex items-center gap-2.5", className)}>
      <img
        src={partner ? "/logo_partner.png" : "/logo_customer.png"}
        alt={partner ? "TaskLy Partner" : "TaskLy"}
        className="size-9 rounded-xl object-contain drop-shadow-sm"
      />
      {showWordmark && (
        <span className="text-xl font-extrabold tracking-tight text-slate-900">
          Task<span style={{ color: primaryColor }}>Ly</span>
          {partner && (
            <span className="ml-1.5 text-xs px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 font-bold uppercase tracking-wider">
              Partner
            </span>
          )}
        </span>
      )}
    </div>
  );
}
