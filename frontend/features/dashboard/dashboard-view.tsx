"use client";

import { useState } from "react";
import { useTasks } from "@/features/tasks/task-context";
import { TaskStatusBadge } from "@/features/tasks/task-status-badge";
import { TaskPriorityBadge } from "@/features/tasks/task-priority-badge";
import { TaskDetailModal } from "@/features/tasks/task-detail-modal";
import { CreateTaskModal } from "@/features/tasks/create-task-modal";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { TabsList, TabTrigger } from "@/components/ui/tabs";
import type { Task, TaskStatus } from "@/features/tasks/types";
import {
  Plus,
  Clock,
  CheckCircle2,
  DollarSign,
  Briefcase,
  Search,
  Filter,
  MapPin,
  Calendar as CalendarIcon,
  ChevronRight,
  Sparkles,
  ArrowRight,
  TrendingUp,
  User,
  ShieldCheck,
} from "lucide-react";

export function DashboardView({
  userName = "Khách hàng",
  initialTab = "overview",
}: {
  userName?: string;
  initialTab?: string;
}) {
  const { tasks, stats, updateTaskStatus } = useTasks();

  const [activeTab, setActiveTab] = useState(initialTab);
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);
  const [detailModalOpen, setDetailModalOpen] = useState(false);
  const [createModalOpen, setCreateModalOpen] = useState(false);

  // Filters for List view
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("ALL");

  const formatVND = (amt: number) =>
    new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND" }).format(amt);

  const formatDate = (iso: string) => {
    try {
      const d = new Date(iso);
      return d.toLocaleDateString("vi-VN", {
        day: "2-digit",
        month: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
      });
    } catch {
      return iso;
    }
  };

  const handleOpenDetail = (task: Task) => {
    setSelectedTask(task);
    setDetailModalOpen(true);
  };

  // Filtered tasks for list view
  const filteredTasks = tasks.filter((t) => {
    const matchesSearch =
      t.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      t.serviceName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      t.addressLine.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesStatus = statusFilter === "ALL" || t.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <div className="space-y-6">
      {/* Modals */}
      <CreateTaskModal
        open={createModalOpen}
        onOpenChange={setCreateModalOpen}
      />
      <TaskDetailModal
        task={selectedTask}
        open={detailModalOpen}
        onOpenChange={setDetailModalOpen}
      />

      {/* Top Banner / Welcome */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 rounded-3xl bg-gradient-to-r from-emerald-800 via-teal-800 to-slate-900 p-6 sm:p-8 text-white shadow-xl shadow-emerald-950/10">
        <div>
          <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-emerald-300">
            <Sparkles className="size-4" />
            Trung tâm quản lý công việc TaskLy
          </div>
          <h1 className="mt-2 text-2xl sm:text-3xl font-extrabold tracking-tight">
            Xin chào, {userName}!
          </h1>
          <p className="mt-1 text-sm text-emerald-100/90 max-w-xl">
            Bạn có <span className="font-bold text-white">{stats.active} công việc</span> đang được tiến hành hoặc chờ ghép Tasker hôm nay.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <Button
            onClick={() => setCreateModalOpen(true)}
            className="bg-white text-emerald-900 hover:bg-emerald-50 font-bold rounded-xl shadow-md gap-2 h-11 px-5"
          >
            <Plus className="size-4 text-emerald-700" />
            Đăng việc mới
          </Button>
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3.5 sm:gap-4">
        <Card className="border-slate-200/90 bg-white">
          <CardContent className="p-4 sm:p-5">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Tổng công việc
              </span>
              <div className="flex size-8 items-center justify-center rounded-xl bg-slate-100 text-slate-700">
                <Briefcase className="size-4" />
              </div>
            </div>
            <div className="mt-2 text-2xl sm:text-3xl font-extrabold text-slate-900">
              {stats.total}
            </div>
            <div className="mt-1 flex items-center text-[11px] text-slate-500 font-medium">
              Tất cả các dịch vụ đã yêu cầu
            </div>
          </CardContent>
        </Card>

        <Card className="border-emerald-200/90 bg-gradient-to-b from-emerald-50/50 to-white">
          <CardContent className="p-4 sm:p-5">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-emerald-700 uppercase tracking-wider">
                Đang thực hiện
              </span>
              <div className="flex size-8 items-center justify-center rounded-xl bg-emerald-100 text-emerald-700">
                <Clock className="size-4" />
              </div>
            </div>
            <div className="mt-2 text-2xl sm:text-3xl font-extrabold text-emerald-900">
              {stats.active}
            </div>
            <div className="mt-1 flex items-center text-[11px] text-emerald-700 font-semibold gap-1">
              <TrendingUp className="size-3" /> Đang xử lý theo tiến độ
            </div>
          </CardContent>
        </Card>

        <Card className="border-slate-200/90 bg-white">
          <CardContent className="p-4 sm:p-5">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Đã hoàn tất
              </span>
              <div className="flex size-8 items-center justify-center rounded-xl bg-teal-50 text-teal-700">
                <CheckCircle2 className="size-4" />
              </div>
            </div>
            <div className="mt-2 text-2xl sm:text-3xl font-extrabold text-slate-900">
              {stats.completed}
            </div>
            <div className="mt-1 flex items-center text-[11px] text-teal-700 font-medium">
              Đã nghiệm thu & thanh toán
            </div>
          </CardContent>
        </Card>

        <Card className="border-slate-200/90 bg-white">
          <CardContent className="p-4 sm:p-5">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Ngân sách đã chi
              </span>
              <div className="flex size-8 items-center justify-center rounded-xl bg-amber-50 text-amber-700">
                <DollarSign className="size-4" />
              </div>
            </div>
            <div className="mt-2 text-xl sm:text-2xl font-extrabold text-slate-900 truncate">
              {formatVND(stats.totalSpent)}
            </div>
            <div className="mt-1 flex items-center text-[11px] text-slate-500 font-medium">
              Ký quỹ minh bạch 100%
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Main Tabs Navigation */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-200 pb-3">
        <TabsList>
          <TabTrigger
            value="overview"
            active={activeTab === "overview"}
            onClick={() => setActiveTab("overview")}
          >
            Tổng quan
          </TabTrigger>
          <TabTrigger
            value="tasks"
            active={activeTab === "tasks"}
            onClick={() => setActiveTab("tasks")}
          >
            Danh sách việc ({tasks.length})
          </TabTrigger>
          <TabTrigger
            value="board"
            active={activeTab === "board"}
            onClick={() => setActiveTab("board")}
          >
            Bảng Kanban
          </TabTrigger>
          <TabTrigger
            value="calendar"
            active={activeTab === "calendar"}
            onClick={() => setActiveTab("calendar")}
          >
            Lịch biểu
          </TabTrigger>
          <TabTrigger
            value="settings"
            active={activeTab === "settings"}
            onClick={() => setActiveTab("settings")}
          >
            Hồ sơ & Cài đặt
          </TabTrigger>
        </TabsList>
      </div>

      {/* TAB 1: OVERVIEW */}
      {activeTab === "overview" && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Active Tasks Feed */}
          <div className="lg:col-span-2 space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-slate-900">
                Công việc đang cần theo dõi
              </h2>
              <button
                onClick={() => setActiveTab("tasks")}
                className="text-xs font-semibold text-emerald-700 hover:underline flex items-center gap-1"
              >
                Xem tất cả ({tasks.length})
                <ChevronRight className="size-3.5" />
              </button>
            </div>

            <div className="space-y-3">
              {tasks.slice(0, 4).map((task) => (
                <div
                  key={task.id}
                  onClick={() => handleOpenDetail(task)}
                  className="group relative flex flex-col sm:flex-row sm:items-center justify-between gap-3 rounded-2xl border border-slate-200/80 bg-white p-4 sm:p-5 shadow-xs transition-all hover:border-emerald-300 hover:shadow-md cursor-pointer"
                >
                  <div className="space-y-1.5 flex-1 min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <TaskStatusBadge status={task.status} />
                      <TaskPriorityBadge priority={task.priority} />
                      <span className="text-[11px] font-semibold text-slate-400">
                        {task.serviceName}
                      </span>
                    </div>
                    <h3 className="text-base font-bold text-slate-900 group-hover:text-emerald-700 transition-colors truncate">
                      {task.title}
                    </h3>
                    <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-slate-500">
                      <span className="flex items-center gap-1">
                        <CalendarIcon className="size-3 text-slate-400" />
                        {formatDate(task.scheduledAt)}
                      </span>
                      <span className="flex items-center gap-1 truncate max-w-xs">
                        <MapPin className="size-3 text-slate-400" />
                        {task.addressLine}
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center justify-between sm:flex-col sm:items-end gap-2 shrink-0 border-t sm:border-t-0 pt-2 sm:pt-0 border-slate-100">
                    <div className="text-right">
                      <div className="text-[11px] text-slate-400">Ngân sách</div>
                      <div className="font-extrabold text-slate-900 text-sm sm:text-base">
                        {formatVND(task.budgetAmount)}
                      </div>
                    </div>
                    {task.taskerName && (
                      <div className="flex items-center gap-1.5 text-xs text-emerald-800 bg-emerald-50 px-2 py-0.5 rounded-full font-medium">
                        <div className="size-4 rounded-full bg-emerald-300 flex items-center justify-center text-[10px] font-bold">
                          {task.taskerName[0]}
                        </div>
                        {task.taskerName}
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>

            {/* Quick popular services */}
            <div className="mt-8 pt-4 border-t border-slate-200">
              <h3 className="text-sm font-bold uppercase tracking-wider text-slate-400 mb-3">
                Đặt dịch vụ nhanh theo yêu cầu
              </h3>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                {[
                  { name: "Dọn dẹp nhà", price: "Từ 150.000đ/buổi", slug: "cleaning" },
                  { name: "Lắp ráp đồ gỗ", price: "Từ 200.000đ", slug: "assembly" },
                  { name: "Vận chuyển", price: "Từ 300.000đ", slug: "moving" },
                ].map((s) => (
                  <div
                    key={s.slug}
                    onClick={() => setCreateModalOpen(true)}
                    className="p-3.5 rounded-2xl border border-slate-200/90 bg-white hover:border-emerald-400 hover:shadow-xs cursor-pointer transition-all"
                  >
                    <div className="font-bold text-sm text-slate-800">{s.name}</div>
                    <div className="text-xs text-emerald-700 font-medium mt-0.5">{s.price}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Right column: Safety & Profile summary */}
          <div className="space-y-4">
            <Card className="border-slate-200 bg-white">
              <CardHeader className="pb-3">
                <CardTitle className="text-base flex items-center gap-2">
                  <ShieldCheck className="size-5 text-emerald-600" />
                  Chính sách đảm bảo TaskLy
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3 text-xs text-slate-600 leading-relaxed">
                <div className="flex items-start gap-2.5">
                  <div className="size-2 rounded-full bg-emerald-500 mt-1.5 shrink-0" />
                  <div>
                    <strong className="text-slate-800">Tiền được giữ an toàn:</strong> Tiền của bạn chỉ được chuyển cho Tasker sau khi bạn xác nhận hoàn thành công việc.
                  </div>
                </div>
                <div className="flex items-start gap-2.5">
                  <div className="size-2 rounded-full bg-emerald-500 mt-1.5 shrink-0" />
                  <div>
                    <strong className="text-slate-800">Xác minh định danh:</strong> 100% Tasker đã nộp căn cước và xác thực hình ảnh KYC.
                  </div>
                </div>
                <div className="flex items-start gap-2.5">
                  <div className="size-2 rounded-full bg-emerald-500 mt-1.5 shrink-0" />
                  <div>
                    <strong className="text-slate-800">Bảo hiểm rủi ro:</strong> Hỗ trợ đền bù thiệt hại vật chất trong suốt quá trình thực hiện dịch vụ.
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="border-slate-200 bg-white">
              <CardHeader className="pb-3">
                <CardTitle className="text-base">Mẹo sử dụng hiệu quả</CardTitle>
              </CardHeader>
              <CardContent className="space-y-2 text-xs text-slate-600">
                <p>
                  💡 <strong>Mô tả chi tiết:</strong> Hãy ghi rõ số lượng phòng, tầng lầu hoặc ghi chú dụng cụ để Tasker chuẩn bị tốt nhất.
                </p>
                <p>
                  ⭐ <strong>Đánh giá sau khi làm:</strong> Phản hồi chân thực của bạn giúp cộng đồng chọn được Tasker uy tín nhất.
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      )}

      {/* TAB 2: TASKS LIST */}
      {activeTab === "tasks" && (
        <div className="space-y-4">
          {/* Filters Bar */}
          <div className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between rounded-2xl bg-white p-3.5 border border-slate-200 shadow-2xs">
            <div className="relative flex-1">
              <Search className="absolute left-3 size-4 text-slate-400 top-3 pointer-events-none" />
              <input
                type="text"
                placeholder="Tìm theo tiêu đề, dịch vụ, địa chỉ..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-9 pr-4 py-1.5 text-sm rounded-xl border border-slate-200 focus:border-emerald-600 focus:outline-none"
              />
            </div>

            <div className="flex items-center gap-2">
              <Filter className="size-4 text-slate-400" />
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="text-xs font-semibold rounded-xl border border-slate-200 bg-white px-3 py-2 text-slate-700 focus:border-emerald-600 focus:outline-none"
              >
                <option value="ALL">Tất cả trạng thái</option>
                <option value="POSTED">Đã đăng</option>
                <option value="MATCHING">Đang ghép Tasker</option>
                <option value="ACCEPTED">Đã nhận việc</option>
                <option value="IN_PROGRESS">Đang làm</option>
                <option value="COMPLETED">Chờ nghiệm thu</option>
                <option value="PAID">Đã hoàn tất</option>
                <option value="DRAFT">Bản nháp</option>
              </select>
            </div>
          </div>

          {/* List items */}
          <div className="space-y-3">
            {filteredTasks.length === 0 ? (
              <div className="rounded-2xl border border-dashed border-slate-300 p-12 text-center bg-white">
                <Briefcase className="size-8 mx-auto text-slate-300 mb-3" />
                <h3 className="font-bold text-slate-800">Không tìm thấy công việc nào</h3>
                <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
                  Không có công việc nào khớp với bộ lọc hiện tại. Bạn có thể đăng yêu cầu mới ngay bây giờ.
                </p>
                <Button
                  onClick={() => setCreateModalOpen(true)}
                  className="mt-4 bg-emerald-600 text-white rounded-xl text-xs font-semibold"
                >
                  Đăng việc mới
                </Button>
              </div>
            ) : (
              filteredTasks.map((task) => (
                <div
                  key={task.id}
                  onClick={() => handleOpenDetail(task)}
                  className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 rounded-2xl border border-slate-200 bg-white p-4.5 hover:border-emerald-400 hover:shadow-xs transition-all cursor-pointer"
                >
                  <div className="space-y-1.5 flex-1 min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <TaskStatusBadge status={task.status} />
                      <TaskPriorityBadge priority={task.priority} />
                      <span className="text-xs font-semibold text-emerald-700">
                        {task.serviceName}
                      </span>
                    </div>
                    <div className="text-base font-bold text-slate-900 truncate">
                      {task.title}
                    </div>
                    <div className="text-xs text-slate-500 flex flex-wrap gap-x-4 gap-y-1">
                      <span>Lên lịch: {formatDate(task.scheduledAt)}</span>
                      <span>{task.addressLine}</span>
                    </div>
                  </div>

                  <div className="flex items-center justify-between sm:flex-col sm:items-end gap-2 border-t sm:border-0 pt-2 sm:pt-0 border-slate-100">
                    <div className="font-extrabold text-base text-slate-900">
                      {formatVND(task.budgetAmount)}
                    </div>
                    <span className="text-xs font-semibold text-emerald-600 flex items-center gap-1 hover:underline">
                      Xem chi tiết <ArrowRight className="size-3.5" />
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* TAB 3: KANBAN BOARD */}
      {activeTab === "board" && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 overflow-x-auto pb-4">
          {[
            {
              title: "1. Đã đăng & Chờ nhận",
              statuses: ["DRAFT", "POSTED"],
              badgeBg: "bg-slate-100 text-slate-700",
            },
            {
              title: "2. Đang ghép Tasker",
              statuses: ["MATCHING"],
              badgeBg: "bg-amber-100 text-amber-800",
            },
            {
              title: "3. Đang thực hiện",
              statuses: ["ACCEPTED", "IN_PROGRESS"],
              badgeBg: "bg-blue-100 text-blue-800",
            },
            {
              title: "4. Hoàn tất & Đã nghiệm thu",
              statuses: ["COMPLETED", "PAID"],
              badgeBg: "bg-emerald-100 text-emerald-800",
            },
          ].map((col) => {
            const colTasks = tasks.filter((t) => col.statuses.includes(t.status));
            return (
              <div
                key={col.title}
                className="flex flex-col rounded-2xl bg-slate-100/70 p-3.5 border border-slate-200/80 min-w-[260px]"
              >
                <div className="flex items-center justify-between pb-3 font-bold text-xs text-slate-800">
                  <span>{col.title}</span>
                  <span className={`px-2 py-0.5 rounded-full text-[11px] font-bold ${col.badgeBg}`}>
                    {colTasks.length}
                  </span>
                </div>

                <div className="space-y-3 flex-1 overflow-y-auto">
                  {colTasks.length === 0 ? (
                    <div className="rounded-xl border border-dashed border-slate-200 p-6 text-center text-xs text-slate-400">
                      Không có việc
                    </div>
                  ) : (
                    colTasks.map((task) => (
                      <div
                        key={task.id}
                        onClick={() => handleOpenDetail(task)}
                        className="rounded-xl border border-slate-200 bg-white p-3.5 shadow-2xs hover:shadow-xs transition-shadow cursor-pointer space-y-2"
                      >
                        <div className="flex items-center justify-between">
                          <TaskPriorityBadge priority={task.priority} />
                          <span className="text-[11px] font-bold text-slate-900">
                            {formatVND(task.budgetAmount)}
                          </span>
                        </div>
                        <h4 className="font-bold text-xs text-slate-800 line-clamp-2">
                          {task.title}
                        </h4>
                        <div className="text-[11px] text-slate-400 flex items-center gap-1">
                          <MapPin className="size-3 shrink-0" />
                          <span className="truncate">{task.addressLine}</span>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* TAB 4: CALENDAR */}
      {activeTab === "calendar" && (
        <Card className="border-slate-200 bg-white">
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <CalendarIcon className="size-5 text-emerald-600" />
              Lịch trình các công việc theo mốc thời gian
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="divide-y divide-slate-100">
              {tasks.map((task) => (
                <div
                  key={task.id}
                  onClick={() => handleOpenDetail(task)}
                  className="py-3.5 flex items-center justify-between gap-4 hover:bg-slate-50 px-3 rounded-xl cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="flex size-10 shrink-0 flex-col items-center justify-center rounded-xl bg-emerald-50 text-emerald-800 font-bold text-xs border border-emerald-100">
                      <span>{new Date(task.scheduledAt).getDate()}</span>
                      <span className="text-[9px] uppercase">Th{new Date(task.scheduledAt).getMonth() + 1}</span>
                    </div>
                    <div>
                      <div className="font-bold text-sm text-slate-900">{task.title}</div>
                      <div className="text-xs text-slate-500">
                        {formatDate(task.scheduledAt)} • {task.serviceName}
                      </div>
                    </div>
                  </div>
                  <TaskStatusBadge status={task.status} />
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* TAB 5: SETTINGS & PROFILE */}
      {activeTab === "settings" && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card className="border-slate-200 bg-white">
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <User className="size-4 text-emerald-600" />
                Thông tin tài khoản
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4 text-sm">
              <div>
                <label className="text-xs font-semibold text-slate-500 block mb-1">
                  Họ và tên
                </label>
                <div className="font-bold text-slate-900">{userName}</div>
              </div>
              <div>
                <label className="text-xs font-semibold text-slate-500 block mb-1">
                  Vai trò tài khoản
                </label>
                <div className="inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-bold text-emerald-800 border border-emerald-200">
                  Customer (Khách hàng)
                </div>
              </div>
              <div>
                <label className="text-xs font-semibold text-slate-500 block mb-1">
                  Địa chỉ mặc định
                </label>
                <div className="font-medium text-slate-800">
                  Số 45 Đường D2, Phường 25, Quận Bình Thạnh, TP. Hồ Chí Minh
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="border-slate-200 bg-white">
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <ShieldCheck className="size-4 text-emerald-600" />
                Bảo mật & Phiên đăng nhập
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-xs text-slate-600 leading-relaxed">
              <p>
                Phiên làm việc sử dụng chuẩn xác thực JWT và Refresh Token tự động luân phiên, bảo vệ tuyệt đối dữ liệu cá nhân của bạn.
              </p>
              <div className="pt-2">
                <span className="inline-flex items-center gap-1.5 text-emerald-700 font-semibold bg-emerald-50 px-2.5 py-1 rounded-lg">
                  <CheckCircle2 className="size-3.5" />
                  Bảo vệ 2 lớp đang kích hoạt
                </span>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
