"use client";

import { useState, type ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  CheckSquare,
  Kanban,
  Calendar,
  Grid,
  Settings,
  Bell,
  Search,
  Plus,
  LogOut,
  Menu,
  X,
  Sparkles,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { CreateTaskModal } from "@/features/tasks/create-task-modal";
import { TasklyLogo } from "@/components/brand/taskly-logo";
import { cn } from "cn";

interface AppShellProps {
  children: ReactNode;
  userName?: string;
  userRole?: string;
  onLogout?: () => Promise<void> | void;
}

export function AppShell({
  children,
  userName = "Khách hàng",
  userRole = "Customer",
  onLogout,
}: AppShellProps) {
  const pathname = usePathname();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);

  const navItems = [
    { label: "Tổng quan", href: "/customer", icon: LayoutDashboard },
    { label: "Công việc", href: "/customer?tab=tasks", icon: CheckSquare },
    { label: "Bảng Kanban", href: "/customer?tab=board", icon: Kanban },
    { label: "Lịch hẹn", href: "/customer?tab=calendar", icon: Calendar },
    { label: "Danh mục dịch vụ", href: "/services", icon: Grid },
    { label: "Cài đặt & Hồ sơ", href: "/customer?tab=settings", icon: Settings },
  ];

  return (
    <div className="min-h-screen bg-slate-50/60 flex flex-col antialiased text-slate-900">
      {/* Quick Add Modal */}
      <CreateTaskModal
        open={createModalOpen}
        onOpenChange={setCreateModalOpen}
      />

      {/* Top Navbar */}
      <header className="sticky top-0 z-40 flex h-16 w-full items-center justify-between border-b border-slate-200/80 bg-white/95 px-4 sm:px-6 backdrop-blur-md">
        <div className="flex items-center gap-3">
          <button
            type="button"
            className="md:hidden rounded-lg p-2 text-slate-600 hover:bg-slate-100"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            aria-label="Mở menu"
          >
            {mobileMenuOpen ? <X className="size-5" /> : <Menu className="size-5" />}
          </button>

          <Link href="/" className="flex items-center gap-2 group">
            <TasklyLogo className="group-hover:scale-105 transition-transform" />
          </Link>

          <span className="hidden sm:inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-semibold text-emerald-700 border border-emerald-200/60 ml-2">
            {userRole}
          </span>
        </div>

        {/* Center / Search bar */}
        <div className="hidden lg:flex items-center relative max-w-md w-full mx-6">
          <Search className="absolute left-3.5 size-4 text-slate-400 pointer-events-none" />
          <input
            type="text"
            placeholder="Tìm kiếm công việc, dịch vụ hoặc Tasker..."
            className="w-full rounded-xl border border-slate-200 bg-slate-50/70 pl-10 pr-4 py-2 text-sm text-slate-900 placeholder:text-slate-400 focus:bg-white focus:border-emerald-600 focus:outline-none focus:ring-3 focus:ring-emerald-600/10 transition-all"
          />
        </div>

        {/* Right action controls */}
        <div className="flex items-center gap-2 sm:gap-3">
          <Button
            size="sm"
            className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold shadow-xs gap-1.5 rounded-xl h-9 px-3.5"
            onClick={() => setCreateModalOpen(true)}
          >
            <Plus className="size-4" />
            <span className="hidden sm:inline">Đăng việc mới</span>
          </Button>

          {/* Notifications button */}
          <div className="relative">
            <button
              type="button"
              className="relative rounded-xl p-2 text-slate-600 hover:bg-slate-100 hover:text-slate-900 transition-colors"
              onClick={() => setNotificationsOpen(!notificationsOpen)}
              aria-label="Thông báo"
            >
              <Bell className="size-5" />
              <span className="absolute top-1.5 right-1.5 size-2 rounded-full bg-emerald-600 ring-2 ring-white" />
            </button>

            {notificationsOpen && (
              <div className="absolute right-0 mt-2 w-80 rounded-2xl border border-slate-200 bg-white p-4 shadow-xl z-50 animate-in fade-in zoom-in-95 duration-150">
                <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                  <span className="font-bold text-sm text-slate-900">Thông báo mới</span>
                  <span className="text-[11px] text-emerald-600 font-semibold cursor-pointer">
                    Đánh dấu đã đọc
                  </span>
                </div>
                <div className="divide-y divide-slate-100 max-h-64 overflow-y-auto pt-2">
                  <div className="py-2.5 text-xs">
                    <p className="font-semibold text-slate-800">
                      Tasker Nguyễn Văn Hùng đang di chuyển
                    </p>
                    <p className="text-slate-500 mt-0.5">Dọn dẹp căn hộ 2 phòng ngủ • 15 phút trước</p>
                  </div>
                  <div className="py-2.5 text-xs">
                    <p className="font-semibold text-slate-800">
                      Công việc đã có 3 Tasker quan tâm
                    </p>
                    <p className="text-slate-500 mt-0.5">Lắp ráp bàn làm việc • 1 giờ trước</p>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* User Profile avatar */}
          <div className="flex items-center gap-2 pl-2 border-l border-slate-200">
            <div className="size-9 rounded-full bg-emerald-100 text-emerald-800 font-bold flex items-center justify-center text-sm border border-emerald-200">
              {userName[0]?.toUpperCase() ?? "U"}
            </div>
            <div className="hidden xl:block text-left text-xs">
              <div className="font-semibold text-slate-900 leading-tight">{userName}</div>
              <div className="text-slate-400 text-[11px]">{userRole}</div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Layout Area */}
      <div className="flex flex-1 overflow-hidden">
        {/* Desktop Sidebar */}
        <aside className="hidden md:flex flex-col w-64 border-r border-slate-200/80 bg-white p-4 shrink-0">
          <div className="text-[11px] font-bold uppercase tracking-wider text-slate-400 px-3 mb-2">
            Không gian làm việc
          </div>

          <nav className="space-y-1">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isActive =
                item.href === "/customer"
                  ? pathname === "/customer" && !item.href.includes("tab=")
                  : pathname === item.href;

              return (
                <Link
                  key={item.label}
                  href={item.href}
                  className={cn(
                    "flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm font-semibold transition-colors",
                    isActive
                      ? "bg-emerald-50 text-emerald-800 shadow-2xs font-bold"
                      : "text-slate-600 hover:bg-slate-100 hover:text-slate-900",
                  )}
                >
                  <Icon className={cn("size-4", isActive ? "text-emerald-700" : "text-slate-400")} />
                  {item.label}
                </Link>
              );
            })}
          </nav>

          {/* Pro Banner */}
          <div className="mt-auto pt-6">
            <div className="rounded-2xl bg-gradient-to-br from-emerald-700 to-teal-900 p-4 text-white shadow-md">
              <div className="flex items-center gap-2 mb-2 font-bold text-sm">
                <Sparkles className="size-4 text-emerald-300" />
                TaskLy Pro Guard
              </div>
              <p className="text-xs text-emerald-100 leading-relaxed">
                Mọi công việc đều được bảo hiểm bồi thường rủi ro và xác thực lý lịch Tasker 100%.
              </p>
            </div>

            {onLogout && (
              <button
                type="button"
                onClick={() => void onLogout()}
                className="mt-3 flex w-full items-center gap-3 rounded-xl px-3.5 py-2 text-xs font-semibold text-slate-500 hover:bg-slate-100 hover:text-slate-800 transition-colors"
              >
                <LogOut className="size-4 text-slate-400" />
                Đăng xuất phiên làm việc
              </button>
            )}
          </div>
        </aside>

        {/* Mobile Slide-over Menu */}
        {mobileMenuOpen && (
          <div className="fixed inset-0 z-50 md:hidden flex">
            <div
              className="fixed inset-0 bg-slate-950/40 backdrop-blur-xs"
              onClick={() => setMobileMenuOpen(false)}
            />
            <div className="relative z-10 w-72 bg-white h-full p-5 flex flex-col shadow-2xl">
              <div className="flex items-center justify-between pb-4 border-b border-slate-100">
                <span className="font-bold text-lg text-emerald-700">TaskLy Menu</span>
                <button
                  onClick={() => setMobileMenuOpen(false)}
                  className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100"
                >
                  <X className="size-5" />
                </button>
              </div>
              <nav className="mt-4 space-y-1 flex-1">
                {navItems.map((item) => (
                  <Link
                    key={item.label}
                    href={item.href}
                    onClick={() => setMobileMenuOpen(false)}
                    className="flex items-center gap-3 rounded-xl px-3.5 py-3 text-sm font-semibold text-slate-700 hover:bg-emerald-50 hover:text-emerald-800"
                  >
                    <item.icon className="size-5 text-emerald-600" />
                    {item.label}
                  </Link>
                ))}
              </nav>
              {onLogout && (
                <button
                  type="button"
                  onClick={() => {
                    setMobileMenuOpen(false);
                    void onLogout();
                  }}
                  className="flex w-full items-center gap-3 rounded-xl p-3 text-sm font-semibold text-rose-600 hover:bg-rose-50"
                >
                  <LogOut className="size-4" />
                  Đăng xuất
                </button>
              )}
            </div>
          </div>
        )}

        {/* Main Content Viewport */}
        <main className="flex-1 overflow-y-auto px-4 sm:px-8 py-6 max-w-7xl mx-auto w-full">
          {children}
        </main>
      </div>
    </div>
  );
}
