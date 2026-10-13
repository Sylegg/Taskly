'use client';

import React, { useMemo, useState } from 'react';
import {
  Users,
  Search,
  Download,
  RefreshCw,
  Phone,
  Mail,
  CheckCircle2,
  AlertTriangle,
  ChevronRight,
  ShieldCheck,
  Check,
  X,
  Lock,
  Unlock,
  SlidersHorizontal,
  Briefcase,
  TrendingUp,
  Sparkles,
  ShoppingBag,
  Smartphone,
  Gift,
  Award,
} from 'lucide-react';
import CustomerDetailModal from './CustomerDetailModal';
import './customer-admin.css';

type CustomerAdminProps = {
  customers: any[];
  tasks?: any[];
  loading?: boolean;
  onRefresh?: () => Promise<void>;
  onUpdateCustomer?: (id: string, body: any) => Promise<void>;
  onAction?: (item: any, action: string) => void;
  onNavigate?: (route: string) => void;
  saving?: boolean;
  onEditCustomer?: (customer: any) => void;
  onSelectTask?: (taskId: string) => void;
};

export default function CustomerAdmin({
  customers,
  tasks = [],
  loading,
  onRefresh,
  onUpdateCustomer,
  onAction,
  onNavigate,
  saving,
  onEditCustomer,
  onSelectTask,
}: CustomerAdminProps) {
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [sortBy, setSortBy] = useState<'created' | 'name' | 'bookings'>('created');
  const [selectedCustomer, setSelectedCustomer] = useState<any | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const handleRefresh = async () => {
    if (!onRefresh || refreshing) return;
    setRefreshing(true);
    try {
      await onRefresh();
    } finally {
      setRefreshing(false);
    }
  };

  // KPI Calculations
  const totalCount = customers.length;
  const activeCount = customers.filter((c) => c.status === 'ACTIVE').length;
  const suspendedCount = customers.filter((c) => c.status === 'SUSPENDED').length;
  const withBookingsCount = customers.filter((c) => Number(c.bookings || 0) > 0).length;

  // Filter & Search Logic
  const filteredCustomers = useMemo(() => {
    let list = [...customers];

    // Status filter
    if (statusFilter !== 'ALL') {
      if (statusFilter === 'ACTIVE') {
        list = list.filter((c) => c.status === 'ACTIVE');
      } else if (statusFilter === 'SUSPENDED') {
        list = list.filter((c) => c.status === 'SUSPENDED');
      } else if (statusFilter === 'BOOKED') {
        list = list.filter((c) => Number(c.bookings || 0) > 0);
      } else if (statusFilter === 'NEW') {
        list = list.filter((c) => Number(c.bookings || 0) === 0);

      }
    }

    // Text search query
    if (query.trim()) {
      const q = query.trim().toLowerCase();
      list = list.filter((c) => {
        const name = String(c.name || '').toLowerCase();
        const phone = String(c.phone || '').toLowerCase();
        const email = String(c.email || '').toLowerCase();
        const id = String(c.id || '').toLowerCase();
        return name.includes(q) || phone.includes(q) || email.includes(q) || id.includes(q);
      });
    }

    // Sorting
    list.sort((a, b) => {
      if (sortBy === 'name') {
        return String(a.name || '').localeCompare(String(b.name || ''));
      }
      if (sortBy === 'bookings') {
        return Number(b.bookings || 0) - Number(a.bookings || 0);
      }
      // default: created desc
      const dateA = a.created ? new Date(a.created).getTime() : 0;
      const dateB = b.created ? new Date(b.created).getTime() : 0;
      return dateB - dateA;
    });

    return list;
  }, [customers, query, statusFilter, sortBy]);

  // CSV Export
  const exportCsv = () => {
    if (!customers.length) return;
    const headers = ['ID', 'Họ và tên', 'Số điện thoại', 'Email', 'Trạng thái', 'Số đơn đặt', 'Ngày tham gia'];
    const rows = filteredCustomers.map((c) => [
      c.id,
      `"${String(c.name || '').replace(/"/g, '""')}"`,
      `"${c.phone || ''}"`,
      `"${c.email || ''}"`,
      c.status === 'ACTIVE' ? 'Hoạt động' : 'Tạm ngưng',
      c.bookings || 0,
      c.created || '',
    ]);

    const csvContent = '\uFEFF' + [headers.join(','), ...rows.map((r) => r.join(','))].join('\r\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `taskly-customers-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="customer-admin-page">
      {/* 2. KPI Metrics Grid */}
      <div className="customer-kpi-grid">
        {/* KPI 1: Total */}
        <div className="customer-kpi-card">
          <div className="customer-kpi-top">
            <span className="customer-kpi-label">Tổng khách hàng</span>
            <div className="customer-kpi-icon blue">
              <Users size={18} />
            </div>
          </div>
          <div className="customer-kpi-value">{totalCount}</div>
          <div className="customer-kpi-sub">Tài khoản từ ứng dụng Customer</div>
        </div>

        {/* KPI 2: Active */}
        <div className="customer-kpi-card">
          <div className="customer-kpi-top">
            <span className="customer-kpi-label">Đang hoạt động</span>
            <div className="customer-kpi-icon emerald">
              <CheckCircle2 size={18} />
            </div>
          </div>
          <div className="customer-kpi-value">{activeCount}</div>
          <div className="customer-kpi-sub">
            <span className="customer-pulse-dot" /> Trạng thái ACTIVE bình thường
          </div>
        </div>

        {/* KPI 3: Booked */}
        <div className="customer-kpi-card">
          <div className="customer-kpi-top">
            <span className="customer-kpi-label">Có phát sinh đơn</span>
            <div className="customer-kpi-icon purple">
              <ShoppingBag size={18} />
            </div>
          </div>
          <div className="customer-kpi-value">{withBookingsCount}</div>
          <div className="customer-kpi-sub">
            Tỷ lệ {totalCount > 0 ? Math.round((withBookingsCount / totalCount) * 100) : 0}% khách đã đặt dịch vụ
          </div>
        </div>

        {/* KPI 5: Suspended */}
        <div className="customer-kpi-card">
          <div className="customer-kpi-top">
            <span className="customer-kpi-label">Tạm ngưng / Bị khóa</span>
            <div className="customer-kpi-icon rose">
              <AlertTriangle size={18} />
            </div>
          </div>
          <div className="customer-kpi-value">{suspendedCount}</div>
          <div className="customer-kpi-sub">Tài khoản bị giới hạn đăng nhập</div>
        </div>
      </div>

      {/* 3. Toolbar & Filters Card */}
      <div className="customer-toolbar-card">
        <div className="customer-toolbar-top">
          {/* Search Box */}
          <div className="customer-search-box">
            <Search size={16} className="customer-search-icon" />
            <input
              type="text"
              className="customer-search-input"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Tìm theo tên, SĐT, email hoặc ID khách hàng…"
            />
            {query && (
              <button className="customer-search-clear" onClick={() => setQuery('')} aria-label="Xóa tìm kiếm">
                <X size={14} />
              </button>
            )}
          </div>

          {/* Sort Dropdown */}
          <div className="customer-toolbar-filters">
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <SlidersHorizontal size={14} color="#64748b" />
              <select
                className="customer-select-filter"
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as any)}
              >
                <option value="created">Mới tham gia nhất</option>
                <option value="name">Tên (A-Z)</option>
                <option value="bookings">Nhiều đơn đặt nhất</option>
              </select>
            </div>
          </div>
        </div>

        {/* Status Filter Pills */}
        <div className="customer-pills-row">
          <button
            className={`customer-pill-btn ${statusFilter === 'ALL' ? 'active' : ''}`}
            onClick={() => setStatusFilter('ALL')}
          >
            Tất cả <small>{totalCount}</small>
          </button>
          <button
            className={`customer-pill-btn ${statusFilter === 'ACTIVE' ? 'active' : ''}`}
            onClick={() => setStatusFilter('ACTIVE')}
          >
            Đang hoạt động <small>{activeCount}</small>
          </button>
          <button
            className={`customer-pill-btn ${statusFilter === 'BOOKED' ? 'active' : ''}`}
            onClick={() => setStatusFilter('BOOKED')}
          >
            Đã từng đặt đơn <small>{withBookingsCount}</small>
          </button>
          <button
            className={`customer-pill-btn ${statusFilter === 'NEW' ? 'active' : ''}`}
            onClick={() => setStatusFilter('NEW')}
          >
            Khách mới chưa đặt <small>{totalCount - withBookingsCount}</small>
          </button>
          <button
            className={`customer-pill-btn ${statusFilter === 'SUSPENDED' ? 'active' : ''}`}
            onClick={() => setStatusFilter('SUSPENDED')}
          >
            Tạm ngưng <small>{suspendedCount}</small>
          </button>
        </div>
      </div>

      {/* 4. Table Panel */}
      <div className="customer-table-panel">
        <div className="customer-table-responsive">
          <table className="customer-table">
            <thead>
              <tr>
                <th>Khách hàng</th>
                <th>Liên hệ</th>
                <th>Trạng thái tài khoản</th>
                <th>Đơn dịch vụ</th>
                <th>Ngày tham gia</th>
                <th style={{ textAlign: 'right' }}>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {filteredCustomers.map((item) => {
                const bookingsCount = Number(item.bookings || 0);
                const isSuspended = item.status === 'SUSPENDED';

                return (
                  <tr key={item.id}>
                    {/* Customer Name & Avatar */}
                    <td>
                      <div className="customer-user-cell">
                        <div className="customer-avatar">
                          {String(item.name || 'C').slice(0, 1).toUpperCase()}
                        </div>
                        <div className="customer-user-info">
                          <span className="customer-user-name">{item.name || 'Chưa đặt tên'}</span>

                        </div>
                      </div>
                    </td>

                    {/* Contact */}
                    <td>
                      <div className="customer-contact-cell">
                        <span className="customer-contact-phone">
                          <Phone size={12} color="#059669" /> {item.phone || '—'}
                        </span>
                        <span className="customer-contact-email">
                          <Mail size={12} color="#64748b" /> {item.email || '—'}
                        </span>
                      </div>
                    </td>

                    {/* Status */}
                    <td>
                      <span className={`customer-badge ${item.status === 'ACTIVE' ? 'active' : 'suspended'}`}>
                        {item.status === 'ACTIVE' ? '● Hoạt động' : 'Tạm ngưng'}
                      </span>
                    </td>

                    {/* Bookings */}
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <span style={{ fontSize: 13.5, fontWeight: 750, color: '#0f172a' }}>
                          {bookingsCount} đơn
                        </span>
                        
                        {bookingsCount === 0 && <span className="customer-badge new">Mới</span>}
                      </div>
                    </td>

                    {/* Created Date */}
                    <td>
                      <span style={{ fontSize: 12.5, color: '#64748b' }}>
                        {item.created ? new Date(item.created).toLocaleDateString('vi-VN') : '—'}
                      </span>
                    </td>

                    {/* Actions */}
                    <td style={{ textAlign: 'right' }}>
                      <div className="customer-actions-cell" style={{ justifyContent: 'flex-end' }}>
                        <button
                          className="customer-view-btn"
                          onClick={() => setSelectedCustomer(item)}
                          title="Xem hồ sơ chi tiết và sổ địa chỉ"
                        >
                          Xem chi tiết <ChevronRight size={14} />
                        </button>

                        {onAction && ['ACTIVE', 'SUSPENDED'].includes(item.status) && (
                          <button
                            className="customer-lock-btn"
                            disabled={saving}
                            onClick={() => onAction(item, 'RESTRICT')}
                            title={isSuspended ? 'Mở khóa tài khoản khách hàng' : 'Khóa tài khoản khách hàng'}
                          >
                            {isSuspended ? <Unlock size={13} color="#059669" /> : <Lock size={13} color="#e11d48" />}
                            {isSuspended ? 'Mở khóa' : 'Khóa'}
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}

              {filteredCustomers.length === 0 && (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '48px 24px', color: '#94a3b8' }}>
                    <Users size={36} style={{ margin: '0 auto 12px', opacity: 0.4 }} />
                    <strong style={{ display: 'block', fontSize: 15, color: '#475569', marginBottom: 4 }}>
                      Không tìm thấy khách hàng nào phù hợp
                    </strong>
                    <span style={{ fontSize: 13 }}>
                      Hãy thử thay đổi từ khóa tìm kiếm hoặc bỏ bớt các bộ lọc trạng thái.
                    </span>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="customer-table-footer">
          <span>
            Hiển thị <strong>{filteredCustomers.length}</strong> / {totalCount} khách hàng TaskLy
          </span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Sparkles size={13} color="#2563eb" /> Dữ liệu trực tiếp từ máy chủ API
          </span>
        </div>
      </div>

      {/* 5. Customer Detail Modal */}
      {selectedCustomer && (
        <CustomerDetailModal
          customer={customers.find((c) => c.id === selectedCustomer.id) || selectedCustomer}
          tasks={tasks}
          onClose={() => setSelectedCustomer(null)}
          onUpdateCustomer={onUpdateCustomer}
          onAction={onAction}
          onEditCustomer={onEditCustomer}
          onSelectTask={onSelectTask}
          saving={saving}
        />
      )}
    </div>
  );
}
