'use client';

import TaskChatHistory from './TaskChatHistory';
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  RefreshCw,
  X,
  Search,
  Copy,
  Check,
  Calendar,
  Clock,
  MapPin,
  User,
  ShieldCheck,
  AlertTriangle,
  CheckCircle2,
  FileText,
  ClipboardCheck,
  ChevronLeft,
  ChevronRight,
  Phone,
  Building2,
  Sparkles,
  Layers,
  Activity,
  ArrowUpRight,
  Info,
  DollarSign,
  AlertCircle,
  Eye,
  SlidersHorizontal,
  UserCheck,
  CalendarDays,
  ShieldAlert,
} from 'lucide-react';
import { STATUS } from '@/lib/domain.mjs';
import './task-admin.css';

type EligiblePartnerCandidate = {
  partnerId: string;
  fullName: string;
  email: string;
  skillMatch: boolean;
  areaMatch: boolean;
  scheduleEligible: boolean;
  reasonCode: string;
  message: string;
  earliestEligibleStartAt?: string;
  overallEligible: boolean;
};

type Selection = {
  name: string;
  description: string;
  fields: { label: string; value: unknown }[];
};

type EarlyStartRequest = {
  id: string;
  requested_start_at: string;
  proposed_end_at: string;
  reason?: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'CANCELLED' | 'EXPIRED';
  requested_at: string;
  expires_at?: string;
};

type Task = {
  platform_fee?: number;
  partner_net_amount?: number;
  id: string;
  title: string;
  description: string;
  service: string;
  customer: string;
  customer_id: string;
  partner: string;
  tasker_id?: string;
  status: string;
  address: string;
  city: string;
  scheduled_at: string;
  verified_actual_end_at?: string;
  original_scheduled_start_at?: string;
  original_scheduled_end_at?: string;
  approved_start_at?: string;
  expected_end_at?: string;
  accepted_at?: string;
  checked_in_at?: string;
  actual_started_at?: string;
  early_start_request_id?: string;
  early_start_request?: EarlyStartRequest;
  total: number | null;
  pending_booking?: boolean;
  currency: string;
  created_at: string;
  updated_at: string;
  selected_services?: Selection[];
  address_details?: Record<string, unknown>;
  duration_minutes?: number;
  notes?: string;
  latitude?: number;
  longitude?: number;
  quote?: {
    subtotal: number;
    platform_fee: number;
    total: number;
    expires_at: string;
  };
};

type Event = {
  status: string;
  actor: string;
  reason?: string;
  at: string;
};

type FilterTab = 'ALL' | 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'INCOMPLETE' | 'CANCELLED';

const STATUS_LABELS: Record<string, string> = {
  ...STATUS,
  INCOMPLETE: 'Chưa tạo đơn',
  DRAFT: 'Chưa tạo đơn',
  QUOTED: 'Đã báo giá · Chưa tạo đơn',
  POSTED: 'Đã đặt dịch vụ',
  MATCHING: 'Đang tìm Partner',
  ACCEPTED: 'Partner đã nhận việc',
  TASKER_ON_THE_WAY: 'Partner đang đến',
  ARRIVED: 'Partner đã đến',
  IN_PROGRESS: 'Partner đang làm',
  COMPLETED: 'Đã hoàn thành',
  PAID: 'Đã thanh toán',
  EXPIRED: 'Hết hạn',
  PENDING: 'Chờ duyệt',
};

const getStatusTone = (st: string): 'green' | 'blue' | 'amber' | 'purple' | 'red' | 'neutral' => {
  switch (st) {
    case 'COMPLETED':
    case 'PAID':
      return 'green';
    case 'IN_PROGRESS':
    case 'TASKER_ON_THE_WAY':
    case 'ARRIVED':
    case 'ACCEPTED':
      return 'blue';
    case 'POSTED':
    case 'MATCHING':
      return 'amber';
    case 'DRAFT':
    case 'QUOTED':
    case 'INCOMPLETE':
      return 'purple';
    case 'CANCELLED':
    case 'REFUNDED':
    case 'EXPIRED':
    case 'DISPUTED':
      return 'red';
    default:
      return 'neutral';
  }
};

const FILTER_TABS: { key: FilterTab; label: string }[] = [
  { key: 'ALL', label: 'Tất cả' },
  { key: 'PENDING', label: 'Chờ phân công' },
  { key: 'IN_PROGRESS', label: 'Đang thực hiện' },
  { key: 'COMPLETED', label: 'Hoàn thành' },
  { key: 'INCOMPLETE', label: 'Chưa tạo đơn' },
  { key: 'CANCELLED', label: 'Hủy / Khiếu nại' },
];

const matchesTab = (taskStatus: string, tab: FilterTab): boolean => {
  if (tab === 'ALL') return true;
  if (tab === 'PENDING') return ['POSTED', 'MATCHING'].includes(taskStatus);
  if (tab === 'IN_PROGRESS') return ['ACCEPTED', 'TASKER_ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS'].includes(taskStatus);
  if (tab === 'COMPLETED') return ['COMPLETED', 'PAID'].includes(taskStatus);
  if (tab === 'INCOMPLETE') return ['DRAFT', 'INCOMPLETE', 'QUOTED'].includes(taskStatus);
  if (tab === 'CANCELLED') return ['CANCELLED', 'DISPUTED', 'REFUNDED', 'EXPIRED'].includes(taskStatus);
  return true;
};

const formatDate = (value?: string): string => {
  if (!value) return 'Chưa hẹn lịch';
  try {
    const d = new Date(value);
    return d.toLocaleString('vi-VN', {
      timeZone: 'Asia/Ho_Chi_Minh',
      hour: '2-digit',
      minute: '2-digit',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    });
  } catch {
    return value;
  }
};

const formatTimeOnly = (value?: string): string => {
  if (!value) return '';
  try {
    const d = new Date(value);
    return d.toLocaleTimeString('vi-VN', {
      timeZone: 'Asia/Ho_Chi_Minh',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return value;
  }
};

const formatDuration = (minutes?: number): string => {
  if (!minutes || minutes <= 0) return '';
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h > 0 && m > 0) return `${h} giờ ${m} phút`;
  if (h > 0) return `${h} giờ`;
  return `${m} phút`;
};

const formatScheduleSlot = (scheduledAt?: string, durationMinutes?: number) => {
  if (!scheduledAt) {
    return {
      timeSlot: 'Chưa đặt giờ',
      dateStr: 'Chưa có ngày',
      durationStr: '',
    };
  }

  try {
    const start = new Date(scheduledAt);
    const startH = String(start.getHours()).padStart(2, '0');
    const startM = String(start.getMinutes()).padStart(2, '0');
    const startTimeStr = `${startH}:${startM}`;

    let timeSlot = startTimeStr;
    if (durationMinutes && durationMinutes > 0) {
      const end = new Date(start.getTime() + durationMinutes * 60 * 1000);
      const endH = String(end.getHours()).padStart(2, '0');
      const endM = String(end.getMinutes()).padStart(2, '0');
      timeSlot = `${startTimeStr} – ${endH}:${endM}`;
    }

    const day = String(start.getDate()).padStart(2, '0');
    const month = String(start.getMonth() + 1).padStart(2, '0');
    const year = start.getFullYear();
    const dateStr = `${day}/${month}/${year}`;

    const durationStr = formatDuration(durationMinutes);

    return {
      timeSlot,
      dateStr,
      durationStr,
    };
  } catch {
    return {
      timeSlot: scheduledAt,
      dateStr: '',
      durationStr: '',
    };
  }
};

const formatMoney = (amountVal: number | null | undefined, currency = 'VND'): string => {
  if (amountVal == null) return 'Chưa có giá';
  try {
    return new Intl.NumberFormat('vi-VN', {
      style: 'currency',
      currency: currency || 'VND',
    }).format(amountVal);
  } catch {
    return `${amountVal} ₫`;
  }
};

export default function TaskAdmin({ query }: { query: string }) {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [activeTab, setActiveTab] = useState<FilterTab>('ALL');
  const [detailedStatus, setDetailedStatus] = useState<string>('ALL');
  const [searchKeyword, setSearchKeyword] = useState<string>('');
  const [selected, setSelected] = useState<Task | null>(null);
  const [events, setEvents] = useState<Event[]>([]);
  const [historyError, setHistoryError] = useState('');
  const [historyLoading, setHistoryLoading] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Operations & Dispatching states
  const [assignModalOpen, setAssignModalOpen] = useState(false);
  const [eligiblePartners, setEligiblePartners] = useState<EligiblePartnerCandidate[]>([]);
  const [loadingPartners, setLoadingPartners] = useState(false);
  const [partnersError, setPartnersError] = useState('');
  const [selectedPartnerId, setSelectedPartnerId] = useState('');
  const [overrideConflict, setOverrideConflict] = useState(false);
  const [auditReason, setAuditReason] = useState('');
  const [assignSubmitting, setAssignSubmitting] = useState(false);
  const [assignError, setAssignError] = useState('');

  const [rescheduleModalOpen, setRescheduleModalOpen] = useState(false);
  const [rescheduleDateTime, setRescheduleDateTime] = useState('');
  const [rescheduleDuration, setRescheduleDuration] = useState(120);
  const [rescheduleReason, setRescheduleReason] = useState('');
  const [rescheduleSubmitting, setRescheduleSubmitting] = useState(false);
  const [rescheduleError, setRescheduleError] = useState('');

  const [verifyModalOpen, setVerifyModalOpen] = useState(false);
  const [verifyDateTime, setVerifyDateTime] = useState('');
  const [verifyNote, setVerifyNote] = useState('');
  const [verifySubmitting, setVerifySubmitting] = useState(false);
  const [verifyError, setVerifyError] = useState('');

  const [opsToast, setOpsToast] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  const toLocalInputDate = (dateVal?: string) => {
    const d = dateVal ? new Date(dateVal) : new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  };

  const showToast = (type: 'success' | 'error', message: string) => {
    setOpsToast({ type, message });
    setTimeout(() => setOpsToast(null), 5000);
  };

  const openAssignModal = async (task: Task) => {
    setAssignModalOpen(true);
    setSelectedPartnerId(task.tasker_id || '');
    setOverrideConflict(false);
    setAuditReason('');
    setAssignError('');
    setPartnersError('');
    setLoadingPartners(true);
    setEligiblePartners([]);
    try {
      const res = await fetch(`/api/admin/tasks/${task.id}/eligible-partners`, { cache: 'no-store' });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Không tải được danh sách Đối tác.');
      const list: EligiblePartnerCandidate[] = data.data || [];
      list.sort((a, b) => {
        if (a.overallEligible && !b.overallEligible) return -1;
        if (!a.overallEligible && b.overallEligible) return 1;
        if (a.scheduleEligible && !b.scheduleEligible) return -1;
        if (!a.scheduleEligible && b.scheduleEligible) return 1;
        return a.fullName.localeCompare(b.fullName);
      });
      setEligiblePartners(list);
    } catch (err) {
      setPartnersError((err as Error).message);
    } finally {
      setLoadingPartners(false);
    }
  };

  const handleAssignPartner = async () => {
    if (!selected || !selectedPartnerId) return;
    const chosen = eligiblePartners.find(p => p.partnerId === selectedPartnerId);
    if (chosen && (!chosen.scheduleEligible || (!chosen.overallEligible && !overrideConflict))) {
      setAssignError(chosen.scheduleEligible ? 'Đối tác chưa phù hợp kỹ năng hoặc khu vực. Chọn đối tác khác hoặc điều phối đặc biệt có lý do.' : 'Đối tác trùng lịch hoặc chưa đủ khoảng nghỉ. Vui lòng chọn đối tác khác hoặc đổi lịch đơn.');
      return;
    }
    if (overrideConflict && !auditReason.trim()) {
      setAssignError('Bắt buộc nhập lý do điều phối khẩn cấp để lưu Audit Log khi override quy tắc buffer.');
      return;
    }

    setAssignSubmitting(true);
    setAssignError('');
    try {
      const res = await fetch(`/api/admin/tasks/${selected.id}/assign`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          partnerId: selectedPartnerId,
          override: overrideConflict,
          auditReason: auditReason.trim(),
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Không thể phân công Đối tác.');
      setAssignModalOpen(false);
      showToast('success', 'Đã phân công Đối tác thành công.');
      void load(undefined, true);
    } catch (err) {
      setAssignError((err as Error).message);
    } finally {
      setAssignSubmitting(false);
    }
  };

  const [cancelSubmitting, setCancelSubmitting] = useState(false);
  const handleCancel = async () => {
    if (!selected || cancelSubmitting) return;
    const reason = window.prompt('Nhập lý do hủy đơn. Khách hàng và Partner sẽ được thông báo.');
    if (!reason?.trim()) return;
    if (!window.confirm('Xác nhận hủy đơn này? Khoản đã thanh toán sẽ được hoàn vào số dư hoàn tiền của khách hàng.')) return;
    setCancelSubmitting(true);
    try {
      const res = await fetch(`/api/admin/tasks/${selected.id}/cancel`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reason: reason.trim() }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Không thể hủy đơn.');
      showToast('success', 'Đã hủy đơn và gửi thông báo.');
      await load(undefined, true);
    } catch (err) {
      showToast('error', (err as Error).message);
    } finally { setCancelSubmitting(false); }
  };

  const openRescheduleModal = (task: Task) => {
    setRescheduleDateTime(toLocalInputDate(task.scheduled_at));
    setRescheduleDuration(task.duration_minutes || 120);
    setRescheduleReason('');
    setRescheduleError('');
    setRescheduleModalOpen(true);
  };

  const handleReschedule = async () => {
    if (!selected || !rescheduleDateTime) return;
    setRescheduleSubmitting(true);
    setRescheduleError('');
    try {
      const scheduledAtIso = new Date(rescheduleDateTime).toISOString();
      const res = await fetch(`/api/admin/tasks/${selected.id}/reschedule`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          scheduledAt: scheduledAtIso,
          durationMinutes: rescheduleDuration,
          reason: rescheduleReason.trim() || 'Admin cập nhật lịch',
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Không thể đổi lịch hẹn.');
      setRescheduleModalOpen(false);
      showToast('success', 'Đã cập nhật lịch hẹn thành công theo chuẩn buffer 60 phút.');
      void load(undefined, true);
    } catch (err) {
      setRescheduleError((err as Error).message);
    } finally {
      setRescheduleSubmitting(false);
    }
  };

  const openVerifyModal = (task: Task) => {
    setVerifyDateTime(toLocalInputDate());
    setVerifyNote('');
    setVerifyError('');
    setVerifyModalOpen(true);
  };

  const handleVerifyCompletion = async () => {
    if (!selected) return;
    setVerifySubmitting(true);
    setVerifyError('');
    try {
      const verifiedEndIso = verifyDateTime ? new Date(verifyDateTime).toISOString() : new Date().toISOString();
      const res = await fetch(`/api/admin/tasks/${selected.id}/verify-completion`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          verifiedActualEndAt: verifiedEndIso,
          note: verifyNote.trim() || 'Xác thực hoàn thành thực tế',
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Không thể xác thực hoàn thành.');
      setVerifyModalOpen(false);
      showToast('success', 'Đã xác thực hoàn thành sớm và cập nhật mốc buffer 60 phút.');
      void load(undefined, true);
    } catch (err) {
      setVerifyError((err as Error).message);
    } finally {
      setVerifySubmitting(false);
    }
  };

  // Pagination
  const [page, setPage] = useState<number>(1);
  const [pageSize, setPageSize] = useState<number>(10);

  const load = useCallback(async (signal?: AbortSignal, quiet = false) => {
    if (!quiet) { setLoading(true); setError(''); }
    try {
      const response = await fetch('/api/admin/tasks', { cache: 'no-store', signal });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Không tải được danh sách công việc.');
      const updated: Task[] = (data.tasks || []).map((task: Task) => task.pending_booking ? { ...task, status: task.quote ? 'QUOTED' : 'INCOMPLETE' } : task);
      setTasks(updated);
      // Consume a linked task once so refresh or reopening this page cannot reopen it.
      const url = new URL(window.location.href);
      const linkedTaskId = !quiet ? url.searchParams.get('taskId') : null;
      if (linkedTaskId) {
        url.searchParams.delete('taskId');
        window.history.replaceState(window.history.state, '', url.toString());
      }
      setSelected(current => current
        ? updated.find(task => task.id === current.id) || null
        : linkedTaskId ? updated.find(task => task.id === linkedTaskId) || null : null);
    } catch (e) {
      if (!signal?.aborted) {
        if (!quiet) setTasks([]);
        setError((e as Error).message);
      }
    } finally {
      if (!signal?.aborted) setLoading(false);
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    void load(controller.signal);
    const refresh = () => { if (document.visibilityState === 'visible') void load(controller.signal, true); };
    const timer = setInterval(refresh, 10000);
    window.addEventListener('focus', refresh);
    return () => { controller.abort(); clearInterval(timer); window.removeEventListener('focus', refresh); };
  }, [load]);

  // Load status history when a task is selected
  useEffect(() => {
    if (!selected) return;
    if (selected.pending_booking) {
      setEvents([]);
      setHistoryError('');
      setHistoryLoading(false);
      return;
    }
    const controller = new AbortController();
    setEvents([]);
    setHistoryError('');
    setHistoryLoading(true);

    void (async () => {
      try {
        const response = await fetch(`/api/admin/tasks/${selected.id}/history`, {
          cache: 'no-store',
          signal: controller.signal,
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Không tải được lịch sử trạng thái.');
        setEvents(data.history || []);
      } catch (e) {
        if (!controller.signal.aborted) setHistoryError((e as Error).message);
      } finally {
        if (!controller.signal.aborted) setHistoryLoading(false);
      }
    })();

    return () => controller.abort();
  }, [selected]);

  // Copy helper
  const handleCopy = (text: string, e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    navigator.clipboard.writeText(text);
    setCopiedId(text);
    setTimeout(() => setCopiedId(null), 2000);
  };

  // Summary counts for KPI cards
  const stats = useMemo(() => {
    const total = tasks.length;
    const pending = tasks.filter((t) => ['POSTED', 'MATCHING'].includes(t.status)).length;
    const inProgress = tasks.filter((t) =>
      ['ACCEPTED', 'TASKER_ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS'].includes(t.status)
    ).length;
    const completed = tasks.filter((t) => ['COMPLETED', 'PAID'].includes(t.status)).length;
    const incomplete = tasks.filter((t) => ['DRAFT', 'INCOMPLETE', 'QUOTED'].includes(t.status)).length;
    const cancelled = tasks.filter((t) =>
      ['CANCELLED', 'DISPUTED', 'REFUNDED', 'EXPIRED'].includes(t.status)
    ).length;
    return { total, pending, inProgress, completed, incomplete, cancelled };
  }, [tasks]);

  // Effective search query combining topbar query and local searchKeyword
  const effectiveQuery = useMemo(() => {
    const parts = [query.trim(), searchKeyword.trim()].filter(Boolean);
    return parts.join(' ').toLowerCase();
  }, [query, searchKeyword]);

  // Filter tasks
  const filteredTasks = useMemo(() => {
    return tasks.filter((task) => {
      // Tab filter
      if (!matchesTab(task.status, activeTab)) return false;

      // Detailed status dropdown filter
      if (detailedStatus !== 'ALL' && task.status !== detailedStatus) return false;

      // Query filter
      if (effectiveQuery) {
        const searchable = [
          task.id,
          `#${task.id.slice(0, 8)}`,
          task.title,
          task.service,
          task.customer,
          task.customer_id,
          task.partner,
          task.tasker_id,
          task.address,
          task.city,
          task.notes,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();

        const words = effectiveQuery.split(/\s+/);
        if (!words.every((w) => searchable.includes(w))) return false;
      }

      return true;
    });
  }, [tasks, activeTab, detailedStatus, effectiveQuery]);

  // Reset page when filters change
  useEffect(() => {
    setPage(1);
  }, [activeTab, detailedStatus, effectiveQuery, pageSize]);

  // Paginated tasks
  const totalPages = Math.max(1, Math.ceil(filteredTasks.length / pageSize));
  const paginatedTasks = useMemo(() => {
    const start = (page - 1) * pageSize;
    return filteredTasks.slice(start, start + pageSize);
  }, [filteredTasks, page, pageSize]);

  // Status Stepper Calculation for Selected Task
  const stepperInfo = useMemo(() => {
    if (!selected) return null;
    const st = selected.status;
    const isCancelled = ['CANCELLED', 'DISPUTED', 'REFUNDED', 'EXPIRED'].includes(st);

    const positions: Record<string, number> = {
      DRAFT: 0, INCOMPLETE: 0, QUOTED: 0,
      POSTED: 1, MATCHING: 1, ACCEPTED: 2,
      TASKER_ON_THE_WAY: 3, ARRIVED: 4, IN_PROGRESS: 5,
      COMPLETED: 6, PAID: 7,
    };
    const currentStep = positions[st] ?? 0;
    const steps = [
      { id: 0, label: st === 'QUOTED' ? 'Đã báo giá' : 'Chưa tạo đơn' },
      { id: 1, label: 'Đã đặt' },
      { id: 2, label: 'Đã nhận' },
      { id: 3, label: 'Đang đến' },
      { id: 4, label: 'Đã đến' },
      { id: 5, label: 'Đang làm' },
      { id: 6, label: 'Hoàn thành' },
      { id: 7, label: 'Đã thanh toán' },
    ];

    return { steps, currentStep, isCancelled };
  }, [selected]);

  return (
    <div className="task-admin-wrap">
      {/* 1. KPI SUMMARY STATS CARDS */}
      <div className="task-kpi-grid">
        <button
          type="button"
          className={`task-kpi-card ${activeTab === 'ALL' ? 'active' : ''}`}
          onClick={() => {
            setActiveTab('ALL');
            setDetailedStatus('ALL');
          }}
        >
          <div className="task-kpi-icon-wrap emerald">
            <ClipboardCheck size={22} />
          </div>
          <div className="task-kpi-info">
            <span className="task-kpi-label">Tổng công việc</span>
            <span className="task-kpi-count">{stats.total}</span>
          </div>
        </button>

        <button
          type="button"
          className={`task-kpi-card ${activeTab === 'PENDING' ? 'active' : ''}`}
          onClick={() => {
            setActiveTab('PENDING');
            setDetailedStatus('ALL');
          }}
        >
          <div className="task-kpi-icon-wrap amber">
            <Clock size={22} />
          </div>
          <div className="task-kpi-info">
            <span className="task-kpi-label">Chờ phân công</span>
            <span className="task-kpi-count">{stats.pending}</span>
          </div>
        </button>

        <button
          type="button"
          className={`task-kpi-card ${activeTab === 'IN_PROGRESS' ? 'active' : ''}`}
          onClick={() => {
            setActiveTab('IN_PROGRESS');
            setDetailedStatus('ALL');
          }}
        >
          <div className="task-kpi-icon-wrap blue">
            <Activity size={22} />
          </div>
          <div className="task-kpi-info">
            <span className="task-kpi-label">Đang thực hiện</span>
            <span className="task-kpi-count">{stats.inProgress}</span>
          </div>
        </button>

        <button
          type="button"
          className={`task-kpi-card ${activeTab === 'COMPLETED' ? 'active' : ''}`}
          onClick={() => {
            setActiveTab('COMPLETED');
            setDetailedStatus('ALL');
          }}
        >
          <div className="task-kpi-icon-wrap emerald">
            <CheckCircle2 size={22} />
          </div>
          <div className="task-kpi-info">
            <span className="task-kpi-label">Đã hoàn tất</span>
            <span className="task-kpi-count">{stats.completed}</span>
          </div>
        </button>

        <button
          type="button"
          className={`task-kpi-card ${activeTab === 'INCOMPLETE' ? 'active' : ''}`}
          onClick={() => {
            setActiveTab('INCOMPLETE');
            setDetailedStatus('ALL');
          }}
        >
          <div className="task-kpi-icon-wrap purple">
            <FileText size={22} />
          </div>
          <div className="task-kpi-info">
            <span className="task-kpi-label">Chưa tạo đơn</span>
            <span className="task-kpi-count">{stats.incomplete}</span>
          </div>
        </button>

        <button
          type="button"
          className={`task-kpi-card ${activeTab === 'CANCELLED' ? 'active' : ''}`}
          onClick={() => {
            setActiveTab('CANCELLED');
            setDetailedStatus('ALL');
          }}
        >
          <div className="task-kpi-icon-wrap red">
            <AlertTriangle size={22} />
          </div>
          <div className="task-kpi-info">
            <span className="task-kpi-label">Hủy / Khiếu nại</span>
            <span className="task-kpi-count">{stats.cancelled}</span>
          </div>
        </button>
      </div>

      {/* 2. TOOLBAR & FILTER TABS */}
      <div className="task-toolbar-card">
        <div className="task-toolbar-top">
          {/* Search Box */}
          <div className="task-search-box">
            <Search size={17} />
            <input
              type="text"
              value={searchKeyword}
              onChange={(e) => setSearchKeyword(e.target.value)}
              placeholder="Tìm theo mã đơn, dịch vụ, khách hàng, thợ, địa chỉ..."
              aria-label="Tìm kiếm công việc"
            />
            {searchKeyword && (
              <button
                type="button"
                className="task-clear-btn"
                onClick={() => setSearchKeyword('')}
                title="Xóa tìm kiếm"
              >
                <X size={15} />
              </button>
            )}
          </div>

          {/* Action Toolbar */}
          <div className="task-toolbar-actions">
            {/* Detailed Status Select */}
            <select
              aria-label="Lọc trạng thái cụ thể"
              className="task-select"
              value={detailedStatus}
              onChange={(e) => setDetailedStatus(e.target.value)}
            >
              <option value="ALL">Mọi trạng thái chi tiết</option>
              {Object.keys(STATUS_LABELS).map((val) => (
                <option key={val} value={val}>
                  {STATUS_LABELS[val] || val}
                </option>
              ))}
            </select>

            {/* Page Size Select */}
            <select
              aria-label="Số dòng mỗi trang"
              className="task-select"
              value={pageSize}
              onChange={(e) => setPageSize(Number(e.target.value))}
            >
              <option value={10}>10 dòng / trang</option>
              <option value={25}>25 dòng / trang</option>
              <option value={50}>50 dòng / trang</option>
            </select>

            {/* Refresh Button */}
            <button
              type="button"
              className="btn btn-outline"
              disabled={loading}
              onClick={() => void load()}
              title="Tải lại danh sách"
            >
              <RefreshCw size={15} className={loading ? 'animate-spin' : ''} />
              Tải lại
            </button>
          </div>
        </div>

        {/* Category Filter Pills */}
        <div className="task-filter-pills" role="tablist" aria-label="Phân nhóm trạng thái">
          {FILTER_TABS.map((tab) => {
            const count =
              tab.key === 'ALL'
                ? stats.total
                : tab.key === 'PENDING'
                ? stats.pending
                : tab.key === 'IN_PROGRESS'
                ? stats.inProgress
                : tab.key === 'COMPLETED'
                ? stats.completed
                : tab.key === 'INCOMPLETE'
                ? stats.incomplete
                : stats.cancelled;

            return (
              <button
                key={tab.key}
                type="button"
                role="tab"
                aria-selected={activeTab === tab.key}
                className={`task-filter-pill ${activeTab === tab.key ? 'active' : ''}`}
                onClick={() => {
                  setActiveTab(tab.key);
                  setDetailedStatus('ALL');
                }}
              >
                <span>{tab.label}</span>
                <span className="task-filter-pill-count">{count}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Error Notice */}
      {error && (
        <div className="api-error" role="alert">
          <AlertCircle size={16} />
          <span>{error}</span>
        </div>
      )}

      {/* 3. MAIN TASKS TABLE */}
      <div className="task-table-card">
        <div className="task-table-responsive">
          <table className="task-main-table">
            <thead>
              <tr>
                <th>Mã đơn</th>
                <th>Dịch vụ</th>
                <th>Khách hàng</th>
                <th>Đối tác nhận</th>
                <th>Lịch hẹn</th>
                <th>Địa điểm</th>
                <th>Giá trị</th>
                <th>Trạng thái</th>
                <th style={{ textAlign: 'right' }}>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={9}>
                    <div className="task-empty-state">
                      <RefreshCw size={24} className="animate-spin text-emerald-600" />
                      <p>Đang tải danh sách công việc từ máy chủ TaskLy…</p>
                    </div>
                  </td>
                </tr>
              ) : paginatedTasks.length > 0 ? (
                paginatedTasks.map((task) => {
                  const tone = getStatusTone(task.status);
                  const customerInitial = (task.customer || 'C').charAt(0).toUpperCase();
                  const partnerInitial = task.partner ? task.partner.charAt(0).toUpperCase() : '?';

                  return (
                    <tr key={task.id}>
                      <td>
                        <button type="button" className="task-order-code" title={`Sao chép mã đơn #${task.id.slice(0, 8).toUpperCase()}`} onClick={e => handleCopy(`#${task.id.slice(0, 8).toUpperCase()}`, e)}>
                          #{task.id.slice(0, 8).toUpperCase()}
                          {copiedId === `#${task.id.slice(0, 8).toUpperCase()}` ? <Check size={13} /> : <Copy size={13} />}
                        </button>
                      </td>
                      {/* Cột 1: Dịch vụ */}
                      <td>
                        <div className="task-cell-service">
                          <span className="task-service-name">
                            {task.service || task.title || 'Dịch vụ TaskLy'}
                          </span>
                        </div>
                      </td>

                      {/* Cột 2: Khách hàng */}
                      <td>
                        <div className="task-cell-user">
                          <div className="task-user-avatar customer">{customerInitial}</div>
                          <div className="task-user-meta">
                            <span className="task-user-name">
                              {task.customer || 'Khách hàng'}
                            </span>
                            <span className="task-user-sub">Customer</span>
                          </div>
                        </div>
                      </td>

                      {/* Cột 3: Đối tác */}
                      <td>
                        <div className="task-cell-user">
                          <div
                            className={`task-user-avatar ${task.partner ? 'partner' : 'unassigned'}`}
                          >
                            {partnerInitial}
                          </div>
                          <div className="task-user-meta">
                            <span className="task-user-name">
                              {task.partner || 'Chưa phân công'}
                            </span>
                            <span className="task-user-sub">
                              {task.partner ? 'Đối tác nhận việc' : 'Đang tìm thợ'}
                            </span>
                          </div>
                        </div>
                      </td>

                      {/* Cột 4: Lịch hẹn */}
                      <td>
                        {(() => {
                          const slot = formatScheduleSlot(task.scheduled_at, task.duration_minutes);
                          return (
                            <div className="task-cell-time">
                              <div className="task-time-slot">
                                <Clock size={12} style={{ color: '#0b9879', flexShrink: 0 }} />
                                <span>{slot.timeSlot}</span>
                              </div>
                              <div className="task-date-sub">
                                <Calendar size={11} style={{ flexShrink: 0 }} />
                                <span>{slot.dateStr}</span>
                                {slot.durationStr ? (
                                  <span className="task-duration-chip">
                                    {slot.durationStr}
                                  </span>
                                ) : null}
                              </div>
                              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, marginTop: 4 }}>
                                {task.approved_start_at && (
                                  <span style={{ fontSize: 10, background: '#ecfdf5', color: '#065f46', border: '1px solid #a7f3d0', borderRadius: 4, padding: '1px 5px', fontWeight: 600 }}>
                                    Duyệt sớm: {formatTimeOnly(task.approved_start_at)}
                                  </span>
                                )}
                                {task.checked_in_at && (
                                  <span style={{ fontSize: 10, background: '#eff6ff', color: '#1e40af', border: '1px solid #bfdbfe', borderRadius: 4, padding: '1px 5px', fontWeight: 600 }}>
                                    Đã đến: {formatTimeOnly(task.checked_in_at)}
                                  </span>
                                )}
                                {task.actual_started_at && (
                                  <span style={{ fontSize: 10, background: '#f5f3ff', color: '#5b21b6', border: '1px solid #ddd6fe', borderRadius: 4, padding: '1px 5px', fontWeight: 600 }}>
                                    Làm thật: {formatTimeOnly(task.actual_started_at)}
                                  </span>
                                )}
                                {task.early_start_request && task.early_start_request.status === 'PENDING' && (
                                  <span style={{ fontSize: 10, background: '#fef3c7', color: '#92400e', border: '1px solid #fde68a', borderRadius: 4, padding: '1px 5px', fontWeight: 600 }}>
                                    Xin sớm: {formatTimeOnly(task.early_start_request.requested_start_at)} (Chờ khách)
                                  </span>
                                )}
                                {task.early_start_request && task.early_start_request.status === 'REJECTED' && (
                                  <span style={{ fontSize: 10, background: '#fee2e2', color: '#991b1b', border: '1px solid #fecaca', borderRadius: 4, padding: '1px 5px', fontWeight: 600 }}>
                                    Xin sớm: Khách từ chối
                                  </span>
                                )}
                                {task.early_start_request && task.early_start_request.status === 'EXPIRED' && (
                                  <span style={{ fontSize: 10, background: '#f1f5f9', color: '#64748b', border: '1px solid #e2e8f0', borderRadius: 4, padding: '1px 5px', fontWeight: 600 }}>
                                    Xin sớm: Đã hết hạn
                                  </span>
                                )}
                              </div>
                            </div>
                          );
                        })()}
                      </td>

                      {/* Cột 5: Địa điểm */}
                      <td>
                        <div
                          className="task-cell-address"
                          title={[task.address, task.city].filter(Boolean).join(', ')}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                            <MapPin size={13} style={{ flexShrink: 0, color: '#94a3b8' }} />
                            <span>{task.address || task.city || 'Chưa cung cấp'}</span>
                          </div>
                        </div>
                      </td>

                      {/* Cột 6: Giá trị */}
                      <td>
                        <span className={`task-cell-amount ${(task.pending_booking ? task.quote?.total : task.total) == null ? 'quote-pending' : ''}`}>
                          {formatMoney(task.pending_booking ? task.quote?.total : task.total, task.currency)}
                        </span>
                      </td>

                      {/* Cột 7: Trạng thái */}
                      <td>
                        <span className={`task-status-pill ${tone}`}>
                          <span className="task-status-dot" />
                          {STATUS_LABELS[task.status] || task.status}
                        </span>
                      </td>

                      {/* Cột 8: Thao tác */}
                      <td style={{ textAlign: 'right' }}>
                        <button
                          type="button"
                          className="task-btn-detail"
                          onClick={() => setSelected(task)}
                        >
                          <Eye size={13} />
                          Chi tiết
                        </button>
                      </td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td colSpan={9}>
                    <div className="task-empty-state">
                      <div className="task-empty-icon">
                        <Search size={26} />
                      </div>
                      <h3>Không tìm thấy công việc phù hợp</h3>
                      <p>
                        Thử điều chỉnh từ khóa tìm kiếm hoặc bấm &quot;Tất cả&quot; để xem toàn bộ danh sách.
                      </p>
                      {(activeTab !== 'ALL' || detailedStatus !== 'ALL' || effectiveQuery) && (
                        <button
                          type="button"
                          className="btn btn-ghost"
                          onClick={() => {
                            setActiveTab('ALL');
                            setDetailedStatus('ALL');
                            setSearchKeyword('');
                          }}
                        >
                          Đặt lại bộ lọc
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* 4. PAGINATION FOOTER */}
        {!loading && filteredTasks.length > 0 && (
          <div className="task-pagination">
            <span>
              Hiển thị <strong>{(page - 1) * pageSize + 1}</strong> –{' '}
              <strong>{Math.min(page * pageSize, filteredTasks.length)}</strong> trong tổng số{' '}
              <strong>{filteredTasks.length}</strong> công việc
            </span>

            <div className="task-pagination-controls">
              <button
                type="button"
                className="task-page-btn"
                disabled={page <= 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
              >
                <ChevronLeft size={14} /> Trước
              </button>

              <span style={{ padding: '0 8px', fontWeight: 700, fontSize: 12 }}>
                Trang {page} / {totalPages}
              </span>

              <button
                type="button"
                className="task-page-btn"
                disabled={page >= totalPages}
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              >
                Sau <ChevronRight size={14} />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* ------------------------------------------------------------------
          5. TASK DETAIL DRAWER (Trang chi tiết công việc chuẩn hiện đại)
         ------------------------------------------------------------------ */}
      {selected && (
        <div
          className="task-drawer-backdrop"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) setSelected(null);
          }}
        >
          <div className="task-drawer-container">
            {/* Drawer Header */}
            <div className="task-drawer-header">
              <div className="task-drawer-title-area">
                <span className="task-drawer-eyebrow">
                  <Sparkles size={13} />
                  CHI TIẾT CÔNG VIỆC • TASKLY OPERATIONS
                </span>
                <h2>{selected.title || selected.service || 'Chi tiết đơn đặt dịch vụ'}</h2>

                <div className="task-drawer-meta-row">
                  <button type="button" className="task-order-code" title="Sao chép mã đơn" onClick={() => handleCopy(`#${selected.id.slice(0, 8).toUpperCase()}`)}>
                    #{selected.id.slice(0, 8).toUpperCase()}
                    {copiedId === `#${selected.id.slice(0, 8).toUpperCase()}` ? <Check size={13} /> : <Copy size={13} />}
                  </button>
                  {/* Trạng thái */}
                  <span className={`task-status-pill ${getStatusTone(selected.status)}`}>
                    <span className="task-status-dot" />
                    {STATUS_LABELS[selected.status] || selected.status}
                  </span>
                </div>
              </div>

              <button
                type="button"
                className="task-drawer-close-btn"
                aria-label="Đóng chi tiết"
                onClick={() => setSelected(null)}
              >
                <X size={18} />
              </button>
            </div>

            {/* Lifecycle Stepper Bar */}
            {stepperInfo && (
              <div className="task-stepper-wrap">
                <div className="task-stepper">
                  <div className="task-stepper-line">
                    <div
                      className="task-stepper-fill"
                      style={{
                        width: `${Math.min(100, Math.max(0, (stepperInfo.currentStep / (stepperInfo.steps.length - 1)) * 100))}%`,
                      }}
                    />
                  </div>

                  {stepperInfo.steps.map((st) => {
                    const isDone = st.id < stepperInfo.currentStep;
                    const isCurr = st.id === stepperInfo.currentStep;
                    return (
                      <div
                        key={st.id}
                        className={`task-stepper-step ${isDone ? 'completed' : ''} ${isCurr ? 'current' : ''} ${
                          stepperInfo.isCancelled && isCurr ? 'cancelled' : ''
                        }`}
                      >
                        <div className="task-stepper-node">
                          {isDone ? '✓' : st.id}
                        </div>
                        <span className="task-stepper-label">{st.label}</span>
                      </div>
                    );
                  })}
                </div>

                {selected.pending_booking && (
                  <div
                    style={{
                      marginTop: 12,
                      padding: '8px 12px',
                      background: '#f5f3ff',
                      border: '1px solid #ddd6fe',
                      borderRadius: 10,
                      fontSize: 11.5,
                      color: '#6b21a8',
                      display: 'flex',
                      alignItems: 'center',
                      gap: 8,
                    }}
                  >
                    <Info size={14} />
                    <span>
                      {selected.quote ? 'Customer đã lấy báo giá nhưng chưa xác nhận tạo đơn dịch vụ.' : 'Customer đang nhập thông tin, chưa tạo đơn dịch vụ và chưa có báo giá.'}
                    </span>
                  </div>
                )}
              </div>
            )}

            {/* Drawer Body Sections */}
            <div className="task-drawer-body">
              {opsToast && (
                <div className={`task-toast ${opsToast.type}`} role="alert">
                  {opsToast.type === 'success' ? <CheckCircle2 size={16} /> : <AlertCircle size={16} />}
                  <span>{opsToast.message}</span>
                </div>
              )}

              {/* SECTION 1: KHÁCH HÀNG & ĐỐI TÁC */}
              <div className="task-section-card">
                <div className="task-section-header">
                  <span className="task-section-title">
                    <div className="task-section-icon">
                      <User size={15} />
                    </div>
                    Các bên liên quan (Customer & Partner)
                  </span>
                </div>

                <div className="task-parties-grid">
                  {/* Khách hàng */}
                  <div className="task-party-box">
                    <div className="task-party-avatar customer">
                      {(selected.customer || 'C').charAt(0).toUpperCase()}
                    </div>
                    <div className="task-party-content">
                      <span className="task-party-role">Khách hàng đặt việc</span>
                      <strong className="task-party-name">
                        {selected.customer || 'Chưa cập nhật tên'}
                      </strong>
                      <span className="task-party-sub">Khách hàng TaskLy</span>
                      {selected.address_details?.recipient_phone != null && (
                        <div
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 6,
                            marginTop: 4,
                            fontSize: 11.5,
                            color: '#087d62',
                            fontWeight: 700,
                          }}
                        >
                          <Phone size={12} />
                          <span>{String(selected.address_details.recipient_phone)}</span>
                          <button
                            type="button"
                            onClick={() => handleCopy(String(selected.address_details?.recipient_phone))}
                            style={{
                              border: 'none',
                              background: 'transparent',
                              cursor: 'pointer',
                              color: '#94a3b8',
                              display: 'inline-flex',
                            }}
                            title="Sao chép SĐT"
                          >
                            <Copy size={11} />
                          </button>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Đối tác */}
                  <div className="task-party-box">
                    <div
                      className={`task-party-avatar ${
                        selected.partner ? 'partner' : 'matching'
                      }`}
                    >
                      {selected.partner ? selected.partner.charAt(0).toUpperCase() : '?'}
                    </div>
                    <div className="task-party-content">
                      <span className="task-party-role">Đối tác thực hiện</span>
                      <strong className="task-party-name">
                        {selected.partner || 'Chưa phân công đối tác'}
                      </strong>
                      <span className="task-party-sub">
                        {selected.partner
                          ? 'Đối tác đã tiếp nhận việc'
                          : selected.status === 'MATCHING'
                          ? 'Đang tìm kiếm đối tác trong khu vực'
                          : 'Chưa có đối tác tiếp nhận'}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Thanh điều phối và quản trị lịch trình */}
                {!selected.pending_booking && (
                  <div className="task-ops-bar">
                    <button type="button" className="task-ops-btn secondary"
                      style={{ color: '#dc2626' }} onClick={() => void handleCancel()}
                      disabled={cancelSubmitting || ['CANCELLED', 'REFUNDED', 'EXPIRED'].includes(selected.status)}>
                      <X size={14} />{cancelSubmitting ? 'Đang hủy…' : 'Hủy đơn'}
                    </button>

                    <button
                      type="button"
                      className="task-ops-btn primary"
                      onClick={() => void openAssignModal(selected)}
                      disabled={!['POSTED', 'MATCHING', 'ACCEPTED'].includes(selected.status)}
                    >
                      <UserCheck size={14} />
                      {selected.partner ? 'Điều phối lại / Đổi Partner' : 'Điều phối / Gán Partner'}
                    </button>

                    <button
                      type="button"
                      className="task-ops-btn secondary"
                      onClick={() => openRescheduleModal(selected)}
                      disabled={['COMPLETED', 'PAID', 'CANCELLED', 'REFUNDED'].includes(selected.status)}
                    >
                      <CalendarDays size={14} />
                      Đổi lịch hẹn (Buffer 60p)
                    </button>

                    {['ACCEPTED', 'TASKER_ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED'].includes(selected.status) && (
                      <button
                        type="button"
                        className="task-ops-btn accent"
                        onClick={() => openVerifyModal(selected)}
                      >
                        <CheckCircle2 size={14} />
                        {selected.verified_actual_end_at ? 'Cập nhật nghiệm thu sớm' : 'Xác thực hoàn thành sớm'}
                      </button>
                    )}
                  </div>
                )}

                {selected.verified_actual_end_at && (
                  <div className="task-verified-banner">
                    <CheckCircle2 size={16} style={{ flexShrink: 0, marginTop: 1 }} />
                    <div>
                      <strong>Đã xác thực hoàn thành sớm: {formatDate(selected.verified_actual_end_at)}</strong>
                      <div>
                        Hệ thống áp dụng thời điểm thực tế này làm căn cứ tính buffer 60 phút để giải phóng lịch cho Đối tác nhận việc tiếp theo sớm hơn.
                      </div>
                    </div>
                  </div>
                )}
              </div>

              {/* SECTION 2: DỊCH VỤ & YÊU CẦU CHI TIẾT */}
              <div className="task-section-card">
                <div className="task-section-header">
                  <span className="task-section-title">
                    <div className="task-section-icon">
                      <Layers size={15} />
                    </div>
                    Chi tiết Dịch vụ & Yêu cầu cụ thể
                  </span>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontSize: 14, fontWeight: 800, color: '#0f172a' }}>
                      {selected.service}
                    </span>
                    {selected.duration_minutes ? (
                      <span
                        style={{
                          fontSize: 11,
                          background: '#f1f5f9',
                          padding: '2px 8px',
                          borderRadius: 6,
                          color: '#475569',
                          fontWeight: 700,
                        }}
                      >
                        ⏱ {selected.duration_minutes / 60} giờ ({selected.duration_minutes} phút)
                      </span>
                    ) : null}
                  </div>

                  {selected.description && (
                    <p style={{ margin: 0, fontSize: 12.5, color: '#334155', lineHeight: 1.5 }}>
                      {selected.description}
                    </p>
                  )}

                  {/* Form động & Dịch vụ chi tiết */}
                  {selected.selected_services && selected.selected_services.length > 0 ? (
                    <div className="task-services-list">
                      {selected.selected_services.map((svc, idx) => (
                        <div key={idx} className="task-subservice-card">
                          <span className="task-subservice-name">{svc.name}</span>

                          {svc.fields && svc.fields.length > 0 && (
                            <div className="task-form-fields-grid">
                              {svc.fields.map((fld, fIdx) => (
                                <div key={fIdx} className="task-field-pill">
                                  <span className="task-field-label">{fld.label}:</span>
                                  <span className="task-field-val">
                                    {fld.value == null || fld.value === ''
                                      ? '—'
                                      : typeof fld.value === 'boolean'
                                      ? fld.value
                                        ? 'Có'
                                        : 'Không'
                                      : String(fld.value)}
                                  </span>
                                </div>
                              ))}
                            </div>
                          )}

                          {svc.description && (
                            <p
                              style={{
                                margin: 0,
                                fontSize: 11.5,
                                color: '#64748b',
                                fontStyle: 'italic',
                              }}
                            >
                              Ghi chú gói: {svc.description}
                            </p>
                          )}
                        </div>
                      ))}
                    </div>
                  ) : null}

                  {/* Ghi chú / Lưu ý cho thợ */}
                  {selected.notes && (
                    <div className="task-notes-box">
                      <AlertTriangle size={16} style={{ flexShrink: 0, marginTop: 2 }} />
                      <div>
                        <strong>Lưu ý từ khách hàng dành cho Đối tác:</strong>
                        <p style={{ margin: '4px 0 0 0', whiteSpace: 'pre-wrap' }}>
                          {selected.notes}
                        </p>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* SECTION 3: THỜI GIAN & ĐỊA CHỈ */}
              <div className="task-section-card">
                <div className="task-section-header">
                  <span className="task-section-title">
                    <div className="task-section-icon">
                      <MapPin size={15} />
                    </div>
                    Thời gian & Địa điểm thực hiện
                  </span>
                </div>

                {(() => {
                  const slot = formatScheduleSlot(selected.scheduled_at, selected.duration_minutes);
                  return (
                    <div className="task-info-grid">
                      <div className="task-info-tile">
                        <small>Khung giờ làm việc</small>
                        <strong style={{ color: '#087d62', fontSize: 13.5 }}>
                          {slot.timeSlot}
                        </strong>
                      </div>

                      <div className="task-info-tile">
                        <small>Ngày hẹn thực hiện</small>
                        <strong>{slot.dateStr}</strong>
                      </div>

                      <div className="task-info-tile">
                        <small>Thời lượng ước tính</small>
                        <strong>
                          {slot.durationStr || 'Theo khảo sát thực tế'}
                        </strong>
                      </div>

                  <div className="task-info-tile" style={{ gridColumn: '1 / -1' }}>
                    <small>Địa chỉ công việc</small>
                    <strong>
                      {selected.address_details
                        ? [
                            selected.address_details.address_line,
                            selected.address_details.ward,
                            selected.address_details.district,
                            selected.address_details.city,
                          ]
                            .filter(Boolean)
                            .join(', ') || selected.address
                        : [selected.address, selected.city].filter(Boolean).join(', ') || 'Chưa cung cấp'}
                    </strong>

                    {selected.address_details && (
                      <div
                        style={{
                          marginTop: 8,
                          display: 'flex',
                          flexWrap: 'wrap',
                          gap: 8,
                          fontSize: 11,
                          color: '#64748b',
                        }}
                      >
                        {selected.address_details.building_type ? (
                          <span style={{ background: '#f1f5f9', padding: '3px 8px', borderRadius: 6 }}>
                            Loại nhà: <b>{String(selected.address_details.building_type)}</b>
                          </span>
                        ) : null}

                        {selected.address_details.building_description ? (
                          <span style={{ background: '#f1f5f9', padding: '3px 8px', borderRadius: 6 }}>
                            Phòng/Tòa nhà: <b>{String(selected.address_details.building_description)}</b>
                          </span>
                        ) : null}

                        {selected.address_details.recipient_name ? (
                          <span style={{ background: '#f1f5f9', padding: '3px 8px', borderRadius: 6 }}>
                            Người liên hệ: <b>{String(selected.address_details.recipient_name)}</b>
                          </span>
                        ) : null}
                      </div>
                    )}
                  </div>

                  {/* Lifecycle Timing Grid */}
                  <div style={{ marginTop: 14, borderTop: '1px solid #f1f5f9', paddingTop: 14 }}>
                    <span style={{ fontSize: 12, fontWeight: 700, color: '#334155', display: 'flex', alignItems: 'center', gap: 6, marginBottom: 10 }}>
                      <Clock size={13} style={{ color: '#0b9879' }} />
                      Mốc thời gian vận hành (Độc lập & Bảo toàn lịch)
                    </span>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 8 }}>
                      <div style={{ background: '#f8fafc', padding: '8px 10px', borderRadius: 8, border: '1px solid #e2e8f0' }}>
                        <small style={{ color: '#64748b', fontSize: 11, display: 'block' }}>Giờ khách đặt gốc</small>
                        <strong style={{ fontSize: 12, color: '#0f172a' }}>{selected.original_scheduled_start_at ? formatDate(selected.original_scheduled_start_at) : slot.dateStr + ' ' + slot.timeSlot}</strong>
                      </div>
                      <div style={{ background: selected.approved_start_at ? '#ecfdf5' : '#f8fafc', padding: '8px 10px', borderRadius: 8, border: `1px solid ${selected.approved_start_at ? '#a7f3d0' : '#e2e8f0'}` }}>
                        <small style={{ color: selected.approved_start_at ? '#065f46' : '#64748b', fontSize: 11, display: 'block' }}>Khách duyệt làm sớm</small>
                        <strong style={{ fontSize: 12, color: selected.approved_start_at ? '#047857' : '#94a3b8' }}>{selected.approved_start_at ? formatDate(selected.approved_start_at) : 'Chưa có duyệt sớm'}</strong>
                      </div>
                      <div style={{ background: selected.accepted_at ? '#f0fdf4' : '#f8fafc', padding: '8px 10px', borderRadius: 8, border: `1px solid ${selected.accepted_at ? '#bbf7d0' : '#e2e8f0'}` }}>
                        <small style={{ color: '#64748b', fontSize: 11, display: 'block' }}>Thời điểm nhận đơn</small>
                        <strong style={{ fontSize: 12, color: selected.accepted_at ? '#15803d' : '#94a3b8' }}>{selected.accepted_at ? formatDate(selected.accepted_at) : '—'}</strong>
                      </div>
                      <div style={{ background: selected.checked_in_at ? '#eff6ff' : '#f8fafc', padding: '8px 10px', borderRadius: 8, border: `1px solid ${selected.checked_in_at ? '#bfdbfe' : '#e2e8f0'}` }}>
                        <small style={{ color: selected.checked_in_at ? '#1e40af' : '#64748b', fontSize: 11, display: 'block' }}>Thời điểm đến nơi (Check-in)</small>
                        <strong style={{ fontSize: 12, color: selected.checked_in_at ? '#1d4ed8' : '#94a3b8' }}>{selected.checked_in_at ? formatDate(selected.checked_in_at) : 'Chưa check-in'}</strong>
                      </div>
                      <div style={{ background: selected.actual_started_at ? '#f5f3ff' : '#f8fafc', padding: '8px 10px', borderRadius: 8, border: `1px solid ${selected.actual_started_at ? '#ddd6fe' : '#e2e8f0'}` }}>
                        <small style={{ color: selected.actual_started_at ? '#5b21b6' : '#64748b', fontSize: 11, display: 'block' }}>Bắt đầu làm thực tế</small>
                        <strong style={{ fontSize: 12, color: selected.actual_started_at ? '#6d28d9' : '#94a3b8' }}>{selected.actual_started_at ? formatDate(selected.actual_started_at) : 'Chưa bắt đầu'}</strong>
                      </div>
                      <div style={{ background: selected.verified_actual_end_at ? '#fefce8' : '#f8fafc', padding: '8px 10px', borderRadius: 8, border: `1px solid ${selected.verified_actual_end_at ? '#fef08a' : '#e2e8f0'}` }}>
                        <small style={{ color: '#64748b', fontSize: 11, display: 'block' }}>Nghiệm thu hoàn tất</small>
                        <strong style={{ fontSize: 12, color: selected.verified_actual_end_at ? '#a16207' : '#94a3b8' }}>{selected.verified_actual_end_at ? formatDate(selected.verified_actual_end_at) : '—'}</strong>
                      </div>
                    </div>
                  </div>

                  {/* Early Start Request Details if present */}
                  {selected.early_start_request && (
                    <div style={{ marginTop: 12, padding: '10px 12px', background: selected.early_start_request.status === 'PENDING' ? '#fffbeb' : selected.early_start_request.status === 'APPROVED' ? '#f0fdf4' : '#f8fafc', border: `1px solid ${selected.early_start_request.status === 'PENDING' ? '#fde68a' : selected.early_start_request.status === 'APPROVED' ? '#bbf7d0' : '#e2e8f0'}`, borderRadius: 8 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                        <span style={{ fontSize: 12, fontWeight: 700, color: '#0f172a' }}>
                          Yêu cầu xin bắt đầu sớm từ Đối tác
                        </span>
                        <span style={{ fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 6, background: selected.early_start_request.status === 'PENDING' ? '#fef3c7' : selected.early_start_request.status === 'APPROVED' ? '#dcfce7' : '#fee2e2', color: selected.early_start_request.status === 'PENDING' ? '#92400e' : selected.early_start_request.status === 'APPROVED' ? '#166534' : '#991b1b' }}>
                          {selected.early_start_request.status === 'PENDING' ? 'Đang chờ khách duyệt' : selected.early_start_request.status === 'APPROVED' ? 'Khách đã chấp thuận' : selected.early_start_request.status === 'REJECTED' ? 'Khách đã từ chối' : 'Hết hạn hiệu lực'}
                        </span>
                      </div>
                      <div style={{ fontSize: 11.5, color: '#334155', display: 'flex', flexDirection: 'column', gap: 3 }}>
                        <div>• Giờ đề nghị bắt đầu: <strong>{formatDate(selected.early_start_request.requested_start_at)}</strong> → Dự kiến kết thúc: <strong>{formatDate(selected.early_start_request.proposed_end_at)}</strong></div>
                        {selected.early_start_request.reason && <div>• Lý do: <i>{selected.early_start_request.reason}</i></div>}
                        <div style={{ color: '#64748b', fontSize: 11 }}>• Gửi lúc: {formatDate(selected.early_start_request.requested_at)}{selected.early_start_request.expires_at ? ` · Hết hạn: ${formatDate(selected.early_start_request.expires_at)}` : ''}</div>
                      </div>
                    </div>
                  )}
                </div>
              );
            })()}
          </div>

              {/* SECTION 4: BÁO GIÁ & TÀI CHÍNH */}
              <div className="task-section-card">
                <div className="task-section-header">
                  <span className="task-section-title">
                    <div className="task-section-icon">
                      <DollarSign size={15} />
                    </div>
                    Chi phí & Báo giá dịch vụ
                  </span>
                </div>

                {selected.quote ? (
                  <div className="task-quote-table">
                    <div className="task-quote-row">
                      <span>Phí dịch vụ cơ bản</span>
                      <span>{formatMoney(selected.quote.subtotal, selected.currency)}</span>
                    </div>

                    <div className="task-quote-row">
                      <span>Phí sàn (trừ từ Partner)</span>
                      <span>{formatMoney(selected.quote.platform_fee, selected.currency)}</span>
                    </div>

                    <div className="task-quote-row"><span>Partner thực nhận</span><span>{formatMoney(selected.quote.subtotal-selected.quote.platform_fee, selected.currency)}</span></div>
                    <div className="task-quote-row total">
                      <span>Tổng chi phí công việc</span>
                      <span className="task-quote-val">
                        {formatMoney(selected.quote.total, selected.currency)}
                      </span>
                    </div>

                    {selected.quote.expires_at && (
                      <div
                        style={{
                          marginTop: 8,
                          fontSize: 11,
                          color: '#94a3b8',
                          display: 'flex',
                          alignItems: 'center',
                          gap: 4,
                        }}
                      >
                        <Clock size={12} />
                        Báo giá có hiệu lực đến: {formatDate(selected.quote.expires_at)}
                      </div>
                    )}
                  </div>
                ) : (
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <span style={{ fontSize: 13, color: '#475569' }}>Customer thanh toán:<br/>Phí sàn: {formatMoney(selected.platform_fee, selected.currency)}<br/>Partner thực nhận: {formatMoney(selected.partner_net_amount, selected.currency)}</span>
                    <strong style={{ fontSize: 18, color: '#087d62', fontWeight: 900 }}>
                      {formatMoney(selected.total, selected.currency)}
                    </strong>
                  </div>
                )}
              </div>

              {!selected.pending_booking && <TaskChatHistory key={selected.id} taskId={selected.id} />}

              {/* SECTION 5: LỊCH SỬ THAY ĐỔI TRẠNG THÁI */}
              <div className="task-section-card">
                <div className="task-section-header">
                  <span className="task-section-title">
                    <div className="task-section-icon">
                      <Activity size={15} />
                    </div>
                    Lịch sử trạng thái công việc (Audit Log)
                  </span>
                </div>

                {historyLoading && (
                  <div style={{ padding: '16px 0', textAlign: 'center', color: '#64748b' }}>
                    <RefreshCw size={18} className="animate-spin inline-block text-emerald-600 mr-2" />
                    Đang tải nhật ký trạng thái…
                  </div>
                )}

                {historyError && (
                  <div className="api-error" role="alert">
                    <AlertCircle size={15} />
                    <span>{historyError}</span>
                  </div>
                )}

                {!historyLoading && !historyError && events.length > 0 ? (
                  <div className="task-timeline">
                    {events.map((ev, i) => (
                      <div key={i} className="task-timeline-item">
                        <div className="task-timeline-dot" />
                        <div className="task-timeline-header">
                          <span className="task-timeline-status">
                            {STATUS_LABELS[ev.status] || ev.status}
                          </span>
                          <span className="task-timeline-time">{formatDate(ev.at)}</span>
                        </div>
                        <span className="task-timeline-actor">
                          Thực hiện bởi: <strong>{ev.actor || 'Hệ thống'}</strong>
                        </span>
                        {ev.reason && (
                          <div className="task-timeline-reason">
                            Ghi chú: {ev.reason}
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                ) : null}

                {!historyLoading && !historyError && events.length === 0 && (
                  <p style={{ margin: 0, fontSize: 12, color: '#94a3b8', fontStyle: 'italic' }}>
                    Chưa có sự kiện trạng thái nào được ghi nhận.
                  </p>
                )}
              </div>
            </div>

            {/* Drawer Footer */}
            <div className="task-drawer-footer">
              <span className="task-drawer-footer-meta">
                Tạo ngày {formatDate(selected.created_at)} · Cập nhật{' '}
                {formatDate(selected.updated_at)}
              </span>

              <button
                type="button"
                className="btn btn-outline"
                onClick={() => setSelected(null)}
              >
                Đóng chi tiết
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ------------------------------------------------------------------
          MODAL 1: ĐIỀU PHỐI & PHÂN CÔNG PARTNER (VỚI KIỂM TRA BUFFER 60P)
         ------------------------------------------------------------------ */}
      {assignModalOpen && selected && (
        <div
          className="task-modal-backdrop"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget && !assignSubmitting) setAssignModalOpen(false);
          }}
        >
          <div className="task-modal-card">
            <div className="task-modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <UserCheck size={18} style={{ color: '#0b9879' }} />
                <h3>Điều phối & Phân công Đối tác</h3>
              </div>
              <button
                type="button"
                className="task-clear-btn"
                disabled={assignSubmitting}
                onClick={() => setAssignModalOpen(false)}
                title="Đóng modal"
              >
                <X size={18} />
              </button>
            </div>

            <div className="task-modal-body">
              <div style={{ fontSize: 12, color: '#475569', background: '#f8fafc', padding: '10px 14px', borderRadius: 10, border: '1px solid #e2e8f0' }}>
                <strong>Quy tắc phân công:</strong> Đối tác <strong>ACTIVE</strong> đang có việc vẫn có thể nhận thêm nếu không trùng lịch và đủ khoảng nghỉ, thời gian di chuyển. Hệ thống kiểm tra thêm kỹ năng và khu vực.
              </div>

              {loadingPartners && (
                <div style={{ padding: '24px 0', textAlign: 'center', color: '#64748b' }}>
                  <RefreshCw size={20} className="animate-spin inline-block text-emerald-600 mr-2" />
                  Đang quét danh sách Đối tác và kiểm tra lịch trình…
                </div>
              )}

              {partnersError && (
                <div className="api-error" role="alert">
                  <AlertCircle size={16} />
                  <span>{partnersError}</span>
                </div>
              )}

              {!loadingPartners && !partnersError && (
                <>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: 12, fontWeight: 700, color: '#334155' }}>
                      Danh sách Đối tác ({eligiblePartners.filter(p => p.overallEligible).length} đủ điều kiện / {eligiblePartners.length} tổng số)
                    </span>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: 10, maxHeight: 280, overflowY: 'auto' }}>
                    {eligiblePartners.length > 0 ? (
                      eligiblePartners.map((p) => {
                        const isSelected = selectedPartnerId === p.partnerId;
                        return (
                          <div
                            key={p.partnerId}
                            className={`task-partner-choice ${isSelected ? 'selected' : ''}`}
                            onClick={() => setSelectedPartnerId(p.partnerId)}
                          >
                            <div className="task-partner-choice-top">
                              <div className="task-partner-info">
                                <input
                                  type="radio"
                                  name="partnerChoice"
                                  checked={isSelected}
                                  onChange={() => setSelectedPartnerId(p.partnerId)}
                                />
                                <div>
                                  <strong style={{ fontSize: 13, color: '#0f172a' }}>{p.fullName}</strong>
                                  <span style={{ fontSize: 11, color: '#64748b', marginLeft: 8 }}>{p.email}</span>
                                </div>
                              </div>

                              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                                <span className={`task-badge-pill ${p.skillMatch ? 'green' : 'slate'}`}>
                                  {p.skillMatch ? 'Đúng kỹ năng' : 'Khác kỹ năng'}
                                </span>
                                <span className={`task-badge-pill ${p.areaMatch ? 'green' : 'slate'}`}>
                                  {p.areaMatch ? 'Đúng khu vực' : 'Ngoài khu vực'}
                                </span>
                                <span
                                  className={`task-badge-pill ${
                                    p.scheduleEligible
                                      ? 'green'
                                      : p.reasonCode === 'BUFFER_TOO_SHORT'
                                      ? 'amber'
                                      : 'red'
                                  }`}
                                >
                                  {p.scheduleEligible
                                    ? 'Đủ buffer 60p'
                                    : p.reasonCode === 'BUFFER_TOO_SHORT'
                                    ? 'Thiếu buffer 60p'
                                    : 'Trùng lịch'}
                                </span>
                              </div>
                            </div>

                            {!p.scheduleEligible && (
                              <div className="task-partner-warning-text">
                                <AlertTriangle size={13} style={{ flexShrink: 0 }} />
                                <span>{p.message}</span>
                                {p.earliestEligibleStartAt && (
                                  <span style={{ fontWeight: 700, marginLeft: 4 }}>
                                    (Sớm nhất từ {formatDate(p.earliestEligibleStartAt)})
                                  </span>
                                )}
                              </div>
                            )}
                          </div>
                        );
                      })
                    ) : (
                      <p style={{ margin: 0, fontSize: 12, color: '#94a3b8', fontStyle: 'italic', textAlign: 'center' }}>
                        Không có Đối tác ACTIVE nào trong hệ thống.
                      </p>
                    )}
                  </div>

                  {/* Override Box when chosen partner is not schedule eligible */}
                  {(() => {
                    const chosen = eligiblePartners.find(p => p.partnerId === selectedPartnerId);
                    if (chosen && chosen.scheduleEligible && !chosen.overallEligible) {
                      return (
                        <div className="task-override-box">
                          <strong>
                            <ShieldAlert size={16} />
                            Cảnh báo xung đột / Không đủ điều kiện: {chosen.message || 'Đối tác chưa thỏa mãn mọi điều kiện'}
                          </strong>
                          <p style={{ margin: 0, fontSize: 11.5, color: '#7f1d1d' }}>
                            Nếu Quản trị viên cần phân công khẩn cấp (Override quy tắc), vui lòng đánh dấu xác nhận và nhập lý do để ghi nhận vào Audit Log.
                          </p>
                          <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, fontWeight: 700, color: '#991b1b', cursor: 'pointer' }}>
                            <input
                              type="checkbox"
                              checked={overrideConflict}
                              onChange={(e) => setOverrideConflict(e.target.checked)}
                            />
                            Xác nhận ghi đè (Override) quy tắc buffer cho ca làm này
                          </label>
                          {overrideConflict && (
                            <textarea
                              rows={2}
                              value={auditReason}
                              onChange={(e) => setAuditReason(e.target.value)}
                              placeholder="Nhập lý do điều phối đặc biệt (bắt buộc để lưu vết lịch sử)…"
                            />
                          )}
                        </div>
                      );
                    }
                    return null;
                  })()}

                  {assignError && (
                    <div className="api-error" role="alert">
                      <AlertCircle size={15} />
                      <span>{assignError}</span>
                    </div>
                  )}
                </>
              )}
            </div>

            <div className="task-modal-footer">
              <button
                type="button"
                className="btn btn-outline"
                disabled={assignSubmitting}
                onClick={() => setAssignModalOpen(false)}
              >
                Hủy
              </button>
              <button
                type="button"
                className="btn btn-primary"
                disabled={
                  assignSubmitting ||
                  !selectedPartnerId ||
                  (() => {
                    const chosen = eligiblePartners.find(p => p.partnerId === selectedPartnerId);
                    if (chosen && !chosen.scheduleEligible) return true;
                    if (chosen && !chosen.overallEligible) {
                      return !overrideConflict || !auditReason.trim();
                    }
                    return !chosen || loadingPartners || !!partnersError;
                  })()
                }
                onClick={() => void handleAssignPartner()}
              >
                {assignSubmitting && <RefreshCw size={14} className="animate-spin mr-1" />}
                Xác nhận phân công
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ------------------------------------------------------------------
          MODAL 2: ĐỔI LỊCH HẸN & VALIDATE BUFFER 60 PHÚT
         ------------------------------------------------------------------ */}
      {rescheduleModalOpen && selected && (
        <div
          className="task-modal-backdrop"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget && !rescheduleSubmitting) setRescheduleModalOpen(false);
          }}
        >
          <div className="task-modal-card">
            <div className="task-modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <CalendarDays size={18} style={{ color: '#0b9879' }} />
                <h3>Đổi lịch hẹn công việc</h3>
              </div>
              <button
                type="button"
                className="task-clear-btn"
                disabled={rescheduleSubmitting}
                onClick={() => setRescheduleModalOpen(false)}
                title="Đóng modal"
              >
                <X size={18} />
              </button>
            </div>

            <div className="task-modal-body">
              <div style={{ fontSize: 12, color: '#475569', background: '#f8fafc', padding: '10px 14px', borderRadius: 10, border: '1px solid #e2e8f0' }}>
                Nếu đơn hàng đã có Đối tác nhận, hệ thống sẽ đối chiếu với lịch trước và sau của Đối tác đó, yêu cầu khoảng trống tối thiểu <strong>60 phút buffer</strong>.
              </div>

              <div className="task-form-group">
                <label>Thời gian bắt đầu mới:</label>
                <input
                  type="datetime-local"
                  value={rescheduleDateTime}
                  onChange={(e) => setRescheduleDateTime(e.target.value)}
                />
              </div>

              <div className="task-form-group">
                <label>Thời lượng ước tính (phút):</label>
                <input
                  type="number"
                  min={15}
                  step={15}
                  value={rescheduleDuration}
                  onChange={(e) => setRescheduleDuration(Number(e.target.value))}
                />
                <span className="task-form-hint">
                  Tương đương: {formatDuration(rescheduleDuration)}
                </span>
              </div>

              <div className="task-form-group">
                <label>Lý do thay đổi lịch:</label>
                <input
                  type="text"
                  placeholder="Khách hàng yêu cầu đổi giờ, thời tiết, phát sinh..."
                  value={rescheduleReason}
                  onChange={(e) => setRescheduleReason(e.target.value)}
                />
              </div>

              {rescheduleError && (
                <div className="api-error" role="alert">
                  <AlertCircle size={15} />
                  <span>{rescheduleError}</span>
                </div>
              )}
            </div>

            <div className="task-modal-footer">
              <button
                type="button"
                className="btn btn-outline"
                disabled={rescheduleSubmitting}
                onClick={() => setRescheduleModalOpen(false)}
              >
                Hủy
              </button>
              <button
                type="button"
                className="btn btn-primary"
                disabled={rescheduleSubmitting || !rescheduleDateTime}
                onClick={() => void handleReschedule()}
              >
                {rescheduleSubmitting && <RefreshCw size={14} className="animate-spin mr-1" />}
                Lưu lịch hẹn mới
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ------------------------------------------------------------------
          MODAL 3: XÁC THỰC HOÀN THÀNH SỚM HỢP LỆ (MỞ BUFFER SỚM)
         ------------------------------------------------------------------ */}
      {verifyModalOpen && selected && (
        <div
          className="task-modal-backdrop"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget && !verifySubmitting) setVerifyModalOpen(false);
          }}
        >
          <div className="task-modal-card">
            <div className="task-modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <CheckCircle2 size={18} style={{ color: '#0b9879' }} />
                <h3>Xác thực Hoàn thành Thực tế</h3>
              </div>
              <button
                type="button"
                className="task-clear-btn"
                disabled={verifySubmitting}
                onClick={() => setVerifyModalOpen(false)}
                title="Đóng modal"
              >
                <X size={18} />
              </button>
            </div>

            <div className="task-modal-body">
              <div style={{ fontSize: 12, color: '#065f46', background: '#ecfdf5', padding: '10px 14px', borderRadius: 10, border: '1px solid #a7f3d0' }}>
                <strong>Quy tắc giải phóng buffer:</strong> Đối tác chỉ bấm &quot;Tôi đã xong&quot; mà chưa đủ xác thực thì chưa được tự bỏ buffer. Khi Quản trị viên xác nhận hoàn thành thực tế tại đây, mốc thời gian này sẽ được hệ thống áp dụng để giải phóng buffer 60 phút, giúp Đối tác sớm nhận các công việc tiếp theo.
              </div>

              <div className="task-form-group">
                <label>Thời điểm hoàn thành thực tế:</label>
                <input
                  type="datetime-local"
                  value={verifyDateTime}
                  onChange={(e) => setVerifyDateTime(e.target.value)}
                />
              </div>

              <div className="task-form-group">
                <label>Ghi chú xác thực / Bằng chứng nghiệm thu:</label>
                <input
                  type="text"
                  placeholder="Khách hàng đã ký nghiệm thu, xác nhận qua điện thoại..."
                  value={verifyNote}
                  onChange={(e) => setVerifyNote(e.target.value)}
                />
              </div>

              {verifyError && (
                <div className="api-error" role="alert">
                  <AlertCircle size={15} />
                  <span>{verifyError}</span>
                </div>
              )}
            </div>

            <div className="task-modal-footer">
              <button
                type="button"
                className="btn btn-outline"
                disabled={verifySubmitting}
                onClick={() => setVerifyModalOpen(false)}
              >
                Hủy
              </button>
              <button
                type="button"
                className="btn btn-primary"
                disabled={verifySubmitting || !verifyDateTime}
                onClick={() => void handleVerifyCompletion()}
              >
                {verifySubmitting && <RefreshCw size={14} className="animate-spin mr-1" />}
                Xác nhận hoàn thành & Mở buffer
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
