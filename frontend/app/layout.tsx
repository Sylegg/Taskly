import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import { AppProviders } from "./providers";
import { Geist } from "next/font/google";
import { cn } from "@/lib/utils";

const geist = Geist({ subsets: ["latin"], variable: "--font-sans" });

export const metadata: Metadata = {
  metadataBase: new URL(
    process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000",
  ),
  title: {
    default: "TaskLy — Kết nối việc cần, người phù hợp",
    template: "%s | TaskLy",
  },
  description:
    "TaskLy kết nối Customer với Tasker đã được xác minh để thực hiện các công việc ngắn hạn an toàn và minh bạch.",
  applicationName: "TaskLy",
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#078c5c",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="vi" className={cn("h-full", "font-sans", geist.variable)}>
      <body className="min-h-full bg-slate-50 text-slate-950 antialiased">
        <AppProviders>{children}</AppProviders>
      </body>
    </html>
  );
}
