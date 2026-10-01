"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import type { CreateTaskInput, Task, TaskStatus } from "./types";

const INITIAL_TASKS: Task[] = [
  {
    id: "tsk-001",
    title: "Dọn dẹp căn hộ 2 phòng ngủ cuối tuần",
    description: "Lau dọn sàn, hút bụi thảm, vệ sinh 2 phòng tắm và lau ban công sạch sẽ.",
    serviceName: "Dọn dẹp nhà cửa",
    serviceSlug: "cleaning",
    categoryName: "Gia đình & Vệ sinh",
    status: "IN_PROGRESS",
    priority: "HIGH",
    budgetAmount: 350000,
    currency: "VND",
    addressLine: "Tòa S2.05 VinHomes Grand Park, Đường Nguyễn Xiển",
    city: "TP. Hồ Chí Minh",
    scheduledAt: new Date(Date.now() + 2 * 3600 * 1000).toISOString(),
    estimatedDurationMinutes: 180,
    taskerName: "Nguyễn Văn Hùng",
    taskerAvatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80",
    taskerRating: 4.9,
    taskerPhone: "0901234567",
    customerNotes: "Có mang theo dụng cụ tẩy rửa chuyên dụng.",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24).toISOString(),
    updatedAt: new Date(Date.now() - 3600 * 1000 * 2).toISOString(),
  },
  {
    id: "tsk-002",
    title: "Lắp ráp bàn làm việc IKEA và kệ sách",
    description: "Cần lắp 1 bàn làm việc chữ L và 1 kệ sách 4 tầng, đã có sẵn sơ đồ hướng dẫn.",
    serviceName: "Lắp ráp nội thất",
    serviceSlug: "assembly",
    categoryName: "Kỹ thuật & Sửa chữa",
    status: "ACCEPTED",
    priority: "MEDIUM",
    budgetAmount: 280000,
    currency: "VND",
    addressLine: "Số 45 Đường D2, Phường 25, Quận Bình Thạnh",
    city: "TP. Hồ Chí Minh",
    scheduledAt: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
    estimatedDurationMinutes: 120,
    taskerName: "Trần Minh Quân",
    taskerAvatar: "https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=150&q=80",
    taskerRating: 5.0,
    taskerPhone: "0918765432",
    createdAt: new Date(Date.now() - 3600 * 1000 * 48).toISOString(),
    updatedAt: new Date(Date.now() - 3600 * 1000 * 5).toISOString(),
  },
  {
    id: "tsk-003",
    title: "Vận chuyển đồ đạc phòng trọ sang chỗ ở mới",
    description: "Khoảng 5 thùng carton, 1 vali quần áo và 1 quạt cây. Quãng đường di chuyển 4km.",
    serviceName: "Chuyển nhà & Đồ đạc",
    serviceSlug: "moving",
    categoryName: "Vận chuyển",
    status: "MATCHING",
    priority: "URGENT",
    budgetAmount: 420000,
    currency: "VND",
    addressLine: "128/6 Trần Hưng Đạo, Phường 7, Quận 5",
    city: "TP. Hồ Chí Minh",
    scheduledAt: new Date(Date.now() + 48 * 3600 * 1000).toISOString(),
    estimatedDurationMinutes: 150,
    createdAt: new Date(Date.now() - 3600 * 1000 * 12).toISOString(),
    updatedAt: new Date(Date.now() - 3600 * 1000 * 12).toISOString(),
  },
  {
    id: "tsk-004",
    title: "Sửa vòi nước rò rỉ và thay ổ cắm điện phòng khách",
    description: "Vòi bồn rửa bát bị rỉ nước liên tục, ổ cắm đôi bị lỏng chập chờn.",
    serviceName: "Sửa chữa điện nước",
    serviceSlug: "handyman",
    categoryName: "Kỹ thuật & Sửa chữa",
    status: "COMPLETED",
    priority: "HIGH",
    budgetAmount: 250000,
    currency: "VND",
    addressLine: "Căn hộ A12-04 Sunrise City, Quận 7",
    city: "TP. Hồ Chí Minh",
    scheduledAt: new Date(Date.now() - 72 * 3600 * 1000).toISOString(),
    estimatedDurationMinutes: 90,
    taskerName: "Lê Hoàng Phúc",
    taskerAvatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80",
    taskerRating: 4.8,
    createdAt: new Date(Date.now() - 3600 * 1000 * 96).toISOString(),
    updatedAt: new Date(Date.now() - 3600 * 1000 * 70).toISOString(),
  },
];

interface TaskContextType {
  tasks: Task[];
  createTask: (input: CreateTaskInput) => Task;
  updateTaskStatus: (id: string, newStatus: TaskStatus) => void;
  deleteTask: (id: string) => void;
  stats: {
    total: number;
    active: number;
    completed: number;
    totalSpent: number;
  };
}

const TaskContext = createContext<TaskContextType | null>(null);

const STORAGE_KEY = "taskly_customer_tasks";

export function TaskProvider({ children }: { children: ReactNode }) {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [isInitialized, setIsInitialized] = useState(false);

  useEffect(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        setTasks(JSON.parse(stored));
      } else {
        setTasks(INITIAL_TASKS);
        localStorage.setItem(STORAGE_KEY, JSON.stringify(INITIAL_TASKS));
      }
    } catch {
      setTasks(INITIAL_TASKS);
    }
    setIsInitialized(true);
  }, []);

  const saveTasks = (newTasks: Task[]) => {
    setTasks(newTasks);
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(newTasks));
    } catch {
      // ignore storage error
    }
  };

  const createTask = (input: CreateTaskInput): Task => {
    const newTask: Task = {
      id: `tsk-${Date.now().toString().slice(-4)}`,
      title: input.title,
      description: input.description,
      serviceName: input.serviceName,
      serviceSlug: input.serviceSlug,
      categoryName: input.categoryName,
      status: "POSTED",
      priority: input.priority,
      budgetAmount: input.budgetAmount,
      currency: "VND",
      addressLine: input.addressLine,
      city: input.city,
      scheduledAt: input.scheduledAt,
      estimatedDurationMinutes: input.estimatedDurationMinutes,
      customerNotes: input.customerNotes,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    const updated = [newTask, ...tasks];
    saveTasks(updated);
    return newTask;
  };

  const updateTaskStatus = (id: string, newStatus: TaskStatus) => {
    const updated = tasks.map((t) =>
      t.id === id ? { ...t, status: newStatus, updatedAt: new Date().toISOString() } : t,
    );
    saveTasks(updated);
  };

  const deleteTask = (id: string) => {
    const updated = tasks.filter((t) => t.id !== id);
    saveTasks(updated);
  };

  const stats = {
    total: tasks.length,
    active: tasks.filter((t) =>
      ["POSTED", "MATCHING", "ACCEPTED", "IN_PROGRESS"].includes(t.status),
    ).length,
    completed: tasks.filter((t) => ["COMPLETED", "PAID"].includes(t.status)).length,
    totalSpent: tasks
      .filter((t) => ["COMPLETED", "PAID"].includes(t.status))
      .reduce((sum, t) => sum + t.budgetAmount, 0),
  };

  return (
    <TaskContext.Provider
      value={{
        tasks: isInitialized ? tasks : INITIAL_TASKS,
        createTask,
        updateTaskStatus,
        deleteTask,
        stats,
      }}
    >
      {children}
    </TaskContext.Provider>
  );
}

export function useTasks() {
  const context = useContext(TaskContext);
  if (!context) {
    throw new Error("useTasks must be used within a TaskProvider");
  }
  return context;
}
