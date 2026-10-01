"use client";

import { useState } from "react";
import { Dialog, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useTasks } from "./task-context";
import type { TaskPriority } from "./types";
import { Sparkles, Calendar, MapPin, DollarSign } from "lucide-react";

interface CreateTaskModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

const SERVICES = [
  { name: "Dọn dẹp nhà cửa", slug: "cleaning", category: "Gia đình & Vệ sinh", defaultBudget: 350000 },
  { name: "Lắp ráp nội thất", slug: "assembly", category: "Kỹ thuật & Sửa chữa", defaultBudget: 280000 },
  { name: "Chuyển nhà & Đồ đạc", slug: "moving", category: "Vận chuyển", defaultBudget: 450000 },
  { name: "Sửa chữa điện nước", slug: "handyman", category: "Kỹ thuật & Sửa chữa", defaultBudget: 250000 },
  { name: "Mua sắm hộ", slug: "shopping", category: "Tiện ích hàng ngày", defaultBudget: 150000 },
  { name: "Giao nhận hàng cồng kềnh", slug: "delivery", category: "Vận chuyển", defaultBudget: 200000 },
];

export function CreateTaskModal({ open, onOpenChange }: CreateTaskModalProps) {
  const { createTask } = useTasks();

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [selectedService, setSelectedService] = useState(SERVICES[0]);
  const [priority, setPriority] = useState<TaskPriority>("MEDIUM");
  const [budget, setBudget] = useState(SERVICES[0].defaultBudget.toString());
  const [address, setAddress] = useState("Số 45 Đường D2, Phường 25, Quận Bình Thạnh");
  const [city] = useState("TP. Hồ Chí Minh");
  const [scheduledDate, setScheduledDate] = useState(() => {
    const d = new Date();
    d.setHours(d.getHours() + 4);
    return d.toISOString().slice(0, 16);
  });
  const [duration] = useState(120);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) {
      setError("Vui lòng nhập tiêu đề công việc.");
      return;
    }
    const numBudget = parseInt(budget.replace(/\D/g, ""), 10);
    if (isNaN(numBudget) || numBudget < 50000) {
      setError("Ngân sách tối thiểu là 50.000 VNĐ.");
      return;
    }

    createTask({
      title: title.trim(),
      description: description.trim() || `Yêu cầu dịch vụ ${selectedService.name} tại ${address}.`,
      serviceName: selectedService.name,
      serviceSlug: selectedService.slug,
      categoryName: selectedService.category,
      priority,
      budgetAmount: numBudget,
      addressLine: address.trim(),
      city,
      scheduledAt: new Date(scheduledDate).toISOString(),
      estimatedDurationMinutes: duration,
    });

    // Reset and close
    setTitle("");
    setDescription("");
    setError(null);
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange} className="max-w-xl">
      <form onSubmit={handleSubmit}>
        <DialogHeader>
          <div className="flex items-center gap-2">
            <div className="flex size-8 items-center justify-center rounded-lg bg-emerald-100 text-emerald-700">
              <Sparkles className="size-4" />
            </div>
            <div>
              <DialogTitle>Đăng yêu cầu công việc mới</DialogTitle>
              <DialogDescription>
                Kết nối nhanh chóng với các Tasker có tay nghề và lý lịch minh bạch.
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        {error && (
          <div className="mb-4 rounded-xl bg-rose-50 p-3 text-xs text-rose-700 font-medium">
            {error}
          </div>
        )}

        <div className="space-y-4 py-2">
          <div>
            <label className="mb-1.5 block text-xs font-semibold text-slate-700">
              Tiêu đề công việc *
            </label>
            <Input
              placeholder="VD: Dọn dẹp căn hộ 2 phòng ngủ chiều thứ 7"
              value={title}
              onChange={(e) => {
                setTitle(e.target.value);
                if (error) setError(null);
              }}
              autoFocus
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="mb-1.5 block text-xs font-semibold text-slate-700">
                Loại dịch vụ
              </label>
              <select
                className="flex h-10 w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 shadow-xs focus:border-emerald-600 focus:outline-none"
                value={selectedService.slug}
                onChange={(e) => {
                  const s = SERVICES.find((item) => item.slug === e.target.value);
                  if (s) {
                    setSelectedService(s);
                    setBudget(s.defaultBudget.toString());
                  }
                }}
              >
                {SERVICES.map((s) => (
                  <option key={s.slug} value={s.slug}>
                    {s.name}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="mb-1.5 block text-xs font-semibold text-slate-700">
                Mức độ ưu tiên
              </label>
              <select
                className="flex h-10 w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 shadow-xs focus:border-emerald-600 focus:outline-none"
                value={priority}
                onChange={(e) => setPriority(e.target.value as TaskPriority)}
              >
                <option value="LOW">Thấp (Linh hoạt)</option>
                <option value="MEDIUM">Trung bình</option>
                <option value="HIGH">Cao</option>
                <option value="URGENT">Khẩn cấp (Cần gấp)</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="mb-1.5 flex items-center gap-1.5 text-xs font-semibold text-slate-700">
                <DollarSign className="size-3.5 text-slate-400" />
                Ngân sách dự kiến (VNĐ) *
              </label>
              <Input
                type="text"
                placeholder="VD: 350000"
                value={budget}
                onChange={(e) => setBudget(e.target.value)}
              />
            </div>

            <div>
              <label className="mb-1.5 flex items-center gap-1.5 text-xs font-semibold text-slate-700">
                <Calendar className="size-3.5 text-slate-400" />
                Thời gian thực hiện *
              </label>
              <Input
                type="datetime-local"
                value={scheduledDate}
                onChange={(e) => setScheduledDate(e.target.value)}
              />
            </div>
          </div>

          <div>
            <label className="mb-1.5 flex items-center gap-1.5 text-xs font-semibold text-slate-700">
              <MapPin className="size-3.5 text-slate-400" />
              Địa chỉ công việc
            </label>
            <Input
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              placeholder="Nhập địa chỉ cụ thể..."
            />
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-semibold text-slate-700">
              Mô tả chi tiết / Ghi chú cho Tasker
            </label>
            <textarea
              rows={2}
              className="w-full rounded-xl border border-slate-200 bg-white p-3 text-sm text-slate-900 shadow-xs focus:border-emerald-600 focus:outline-none"
              placeholder="VD: Nhà có thú cưng, xin mang theo găng tay và dụng cụ..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
          </div>
        </div>

        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
          >
            Hủy
          </Button>
          <Button
            type="submit"
            className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold"
          >
            Đăng việc ngay
          </Button>
        </DialogFooter>
      </form>
    </Dialog>
  );
}
