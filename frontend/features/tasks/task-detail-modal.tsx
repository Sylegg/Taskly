"use client";

import { Dialog, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { TaskStatusBadge } from "./task-status-badge";
import { TaskPriorityBadge } from "./task-priority-badge";
import { useTasks } from "./task-context";
import type { Task } from "./types";
import {
  Calendar,
  MapPin,
  Clock,
  DollarSign,
  UserCheck,
  Star,
  CheckCircle,
  Phone,
  AlertTriangle,
} from "lucide-react";

interface TaskDetailModalProps {
  task: Task | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function TaskDetailModal({ task, open, onOpenChange }: TaskDetailModalProps) {
  const { updateTaskStatus, deleteTask } = useTasks();

  if (!task) return null;

  const formatVND = (amt: number) =>
    new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND" }).format(amt);

  const formatDate = (iso: string) => {
    try {
      const d = new Date(iso);
      return d.toLocaleString("vi-VN", {
        weekday: "short",
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      });
    } catch {
      return iso;
    }
  };

  const handleComplete = () => {
    updateTaskStatus(task.id, "COMPLETED");
    onOpenChange(false);
  };

  const handlePay = () => {
    updateTaskStatus(task.id, "PAID");
    onOpenChange(false);
  };

  const handleCancel = () => {
    if (confirm("Bạn có chắc chắn muốn hủy yêu cầu công việc này?")) {
      updateTaskStatus(task.id, "CANCELLED");
      onOpenChange(false);
    }
  };

  const handleDelete = () => {
    if (confirm("Xóa vĩnh viễn bản nháp này?")) {
      deleteTask(task.id);
      onOpenChange(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange} className="max-w-xl">
      <DialogHeader>
        <div className="flex flex-wrap items-center gap-2 mb-1">
          <TaskStatusBadge status={task.status} />
          <TaskPriorityBadge priority={task.priority} />
          <span className="text-xs font-semibold text-slate-400">#{task.id}</span>
        </div>
        <DialogTitle className="text-xl sm:text-2xl mt-1">{task.title}</DialogTitle>
        <DialogDescription className="text-emerald-700 font-medium text-xs">
          {task.serviceName} • {task.categoryName}
        </DialogDescription>
      </DialogHeader>

      <div className="space-y-4 py-2 text-sm text-slate-700">
        <p className="rounded-xl bg-slate-50 p-3.5 text-slate-600 leading-relaxed border border-slate-100">
          {task.description}
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div className="flex items-center gap-2.5 rounded-xl border border-slate-100 bg-white p-3 shadow-2xs">
            <DollarSign className="size-4 text-emerald-600 shrink-0" />
            <div>
              <div className="text-[11px] font-semibold text-slate-400">Ngân sách dự kiến</div>
              <div className="font-bold text-slate-900 text-base">
                {formatVND(task.budgetAmount)}
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2.5 rounded-xl border border-slate-100 bg-white p-3 shadow-2xs">
            <Clock className="size-4 text-emerald-600 shrink-0" />
            <div>
              <div className="text-[11px] font-semibold text-slate-400">Thời lượng ước tính</div>
              <div className="font-bold text-slate-900 text-base">
                {task.estimatedDurationMinutes} phút
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2.5 rounded-xl border border-slate-100 bg-white p-3 shadow-2xs">
            <Calendar className="size-4 text-emerald-600 shrink-0" />
            <div>
              <div className="text-[11px] font-semibold text-slate-400">Thời gian thực hiện</div>
              <div className="font-semibold text-slate-800 text-xs sm:text-sm">
                {formatDate(task.scheduledAt)}
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2.5 rounded-xl border border-slate-100 bg-white p-3 shadow-2xs">
            <MapPin className="size-4 text-emerald-600 shrink-0" />
            <div>
              <div className="text-[11px] font-semibold text-slate-400">Địa điểm</div>
              <div className="font-medium text-slate-800 text-xs line-clamp-2">
                {task.addressLine}, {task.city}
              </div>
            </div>
          </div>
        </div>

        {/* Tasker info if assigned */}
        {task.taskerName && (
          <div className="rounded-xl border border-emerald-100 bg-emerald-50/50 p-3.5">
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-emerald-800 flex items-center gap-1.5">
                <UserCheck className="size-3.5" />
                Tasker phụ trách
              </span>
              {task.taskerRating && (
                <span className="flex items-center gap-1 text-xs font-bold text-amber-700 bg-amber-100/70 px-2 py-0.5 rounded-full">
                  <Star className="size-3 fill-amber-500 text-amber-500" />
                  {task.taskerRating}
                </span>
              )}
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="size-10 rounded-full bg-emerald-200 flex items-center justify-center font-bold text-emerald-800">
                  {task.taskerName[0]}
                </div>
                <div>
                  <div className="font-bold text-slate-900">{task.taskerName}</div>
                  <div className="text-xs text-slate-500 flex items-center gap-1">
                    <Phone className="size-3" /> {task.taskerPhone ?? "0901234567"}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      <DialogFooter className="gap-2">
        {task.status === "IN_PROGRESS" && (
          <Button
            type="button"
            className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold gap-1.5"
            onClick={handleComplete}
          >
            <CheckCircle className="size-4" />
            Nghiệm thu công việc
          </Button>
        )}
        {task.status === "COMPLETED" && (
          <Button
            type="button"
            className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold gap-1.5"
            onClick={handlePay}
          >
            <DollarSign className="size-4" />
            Giải ngân & Đánh giá
          </Button>
        )}
        {["POSTED", "MATCHING"].includes(task.status) && (
          <Button
            type="button"
            variant="destructive"
            className="gap-1.5"
            onClick={handleCancel}
          >
            <AlertTriangle className="size-4" />
            Hủy yêu cầu
          </Button>
        )}
        {task.status === "DRAFT" && (
          <Button
            type="button"
            variant="destructive"
            onClick={handleDelete}
          >
            Xóa bản nháp
          </Button>
        )}
        <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
          Đóng
        </Button>
      </DialogFooter>
    </Dialog>
  );
}
