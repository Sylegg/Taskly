import type { InputHTMLAttributes } from "react";

export function FormField({
  label,
  error,
  ...props
}: InputHTMLAttributes<HTMLInputElement> & { label: string; error?: string }) {
  const id = props.id ?? props.name;
  const errorId = error && id ? `${id}-error` : undefined;
  return (
    <label className="grid gap-2 text-sm font-medium" htmlFor={id}>
      {label}
      <input
        {...props}
        id={id}
        aria-invalid={Boolean(error)}
        aria-describedby={errorId}
        className="h-11 rounded-lg border border-slate-300 bg-white px-3 transition outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
      />
      {error ? (
        <span id={errorId} className="text-sm font-normal text-red-700">
          {error}
        </span>
      ) : null}
    </label>
  );
}
