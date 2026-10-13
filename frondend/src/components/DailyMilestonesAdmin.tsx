'use client';

import React, { useEffect, useMemo, useState } from 'react';
import {
  Award,
  Plus,
  RefreshCw,
  RotateCcw,
  Smartphone,
  CheckCircle2,
  AlertCircle,
  Edit3,
  Trash2,
  Power,
  Sparkles,
  Zap,
  TrendingUp,
  Clock,
  Layers,
  Search,
  X,
  Check,
} from 'lucide-react';
import CataloguePopup from './CataloguePopup';
import './daily-milestones.css';

export type DailyMilestone = {
  id: string;
  min_orders: number;
  orders: string;
  bonus: string;
  bonus_amount: number;
  icon: string;
  badge: string;
  perk: string;
  color: string;
  bgColor: string;
  borderColor: string;
  active: boolean;
  display_order: number;
  updated_at?: string;
};

const COLOR_THEMES = [
  {
    name: 'Xanh dương (Khởi động)',
    color: '#2563EB',
    bgColor: '#EFF6FF',
    borderColor: '#BFDBFE',
  },
  {
    name: 'Xanh ngọc (Tăng tốc)',
    color: '#059669',
    bgColor: '#ECFDF5',
    borderColor: '#A7F3D0',
  },
  {
    name: 'Vàng cam (Chuyên cần)',
    color: '#D97706',
    bgColor: '#FFFBEB',
    borderColor: '#FDE68A',
  },
  {
    name: 'Tím đậm (Siêu Tasker)',
    color: '#7C3AED',
    bgColor: '#F5F3FF',
    borderColor: '#DDD6FE',
  },
  {
    name: 'Đỏ hồng (Chiến binh)',
    color: '#E11D48',
    bgColor: '#FFF1F2',
    borderColor: '#FECDD3',
  },
  {
    name: 'Lam ngọc (Chuyên nghiệp)',
    color: '#0891B2',
    bgColor: '#ECFEFF',
    borderColor: '#A5F3FC',
  },
];

const PRESET_BADGES = [
  'Khởi động',
  'Tăng tốc',
  'Chuyên cần',
  'Siêu Tasker',
  'Chiến binh',
  'Đỉnh cao',
  'Huyền thoại',
  'Top 1%',
];

const PRESET_EMOJIS = ['🛵', '⚡', '🎯', '👑', '🚀', '🏆', '⭐', '🔥', '💎', '🚲', '🚗', '🥇', '🎖️', '🛡️', '💼'];

function formatVnd(amount: number): string {
  return '+' + amount.toLocaleString('vi-VN') + 'đ';
}

export default function DailyMilestonesAdmin() {
  const [milestones, setMilestones] = useState<DailyMilestone[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [toast, setToast] = useState('');
  const [filter, setFilter] = useState<'ALL' | 'ACTIVE' | 'INACTIVE'>('ALL');
  const [search, setSearch] = useState('');

  // Form edit / create state
  const [editingItem, setEditingItem] = useState<Partial<DailyMilestone> | null>(null);
  const [isNew, setIsNew] = useState(false);
  const [deletingItem, setDeletingItem] = useState<DailyMilestone | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(''), 3500);
  };

  async function loadMilestones() {
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/admin/partner-milestones', { cache: 'no-store' });
      const data = await res.json();
      if (!res.ok || !data.success) {
        throw new Error(data.error || 'Không thể tải danh sách mốc thưởng.');
      }
      setMilestones(data.data || []);
    } catch (err: any) {
      setError(err?.message || 'Lỗi kết nối máy chủ.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadMilestones();
  }, []);

  // Filtered milestones
  const filteredMilestones = useMemo(() => {
    return milestones.filter((item) => {
      if (filter === 'ACTIVE' && !item.active) return false;
      if (filter === 'INACTIVE' && item.active) return false;
      if (search.trim()) {
        const q = search.toLowerCase();
        return (
          item.orders.toLowerCase().includes(q) ||
          item.badge.toLowerCase().includes(q) ||
          item.perk.toLowerCase().includes(q) ||
          item.bonus.toLowerCase().includes(q)
        );
      }
      return true;
    });
  }, [milestones, filter, search]);

  // KPI calculations
  const activeCount = useMemo(() => milestones.filter((m) => m.active).length, [milestones]);
  const totalMaxBonus = useMemo(() => {
    return milestones
      .filter((m) => m.active)
      .reduce((sum, m) => sum + (m.bonus_amount || 0), 0);
  }, [milestones]);
  const topTier = useMemo(() => {
    const active = milestones.filter((m) => m.active);
    if (!active.length) return null;
    return active.reduce((prev, curr) => (curr.min_orders > prev.min_orders ? curr : prev));
  }, [milestones]);

  // Toggle active status
  async function toggleActive(item: DailyMilestone) {
    const nextState = !item.active;
    try {
      const res = await fetch('/api/admin/partner-milestones', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: item.id, active: nextState }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) throw new Error(data.error || 'Không thể cập nhật trạng thái.');
      setMilestones((prev) =>
        prev.map((m) => (m.id === item.id ? { ...m, active: nextState } : m))
      );
      showToast(`Đã ${nextState ? 'kích hoạt' : 'tạm ngưng'} mốc "${item.orders}"`);
    } catch (err: any) {
      alert(err.message || 'Lỗi cập nhật');
    }
  }

  // Save edit / create
  async function handleSaveItem(e: React.FormEvent) {
    e.preventDefault();
    if (!editingItem) return;

    if (!editingItem.orders || !editingItem.orders.trim()) {
      alert('Vui lòng nhập nhãn mốc đơn (ví dụ: 3 đơn / ngày).');
      return;
    }
    if ((editingItem.bonus_amount ?? 0) <= 0) {
      alert('Vui lòng nhập mức tiền thưởng lớn hơn 0.');
      return;
    }

    setSubmitting(true);
    try {
      const payload = {
        ...editingItem,
        bonus: formatVnd(Number(editingItem.bonus_amount || 0)),
      };

      const res = await fetch('/api/admin/partner-milestones', {
        method: isNew ? 'POST' : 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok || !data.success) throw new Error(data.error || 'Không thể lưu mốc thưởng.');

      setMilestones(data.data);
      setEditingItem(null);
      showToast(isNew ? 'Đã thêm mốc thưởng mới thành công!' : 'Đã cập nhật mốc thưởng thành công!');
    } catch (err: any) {
      alert(err.message || 'Lỗi lưu dữ liệu.');
    } finally {
      setSubmitting(false);
    }
  }

  // Delete item
  async function handleDeleteConfirm() {
    if (!deletingItem) return;
    setSubmitting(true);
    try {
      const res = await fetch(`/api/admin/partner-milestones?id=${deletingItem.id}`, {
        method: 'DELETE',
      });
      const data = await res.json();
      if (!res.ok || !data.success) throw new Error(data.error || 'Không thể xóa mốc thưởng.');
      setMilestones(data.data);
      setDeletingItem(null);
      showToast('Đã xóa mốc thưởng thành công!');
    } catch (err: any) {
      alert(err.message || 'Lỗi xóa mốc.');
    } finally {
      setSubmitting(false);
    }
  }


  // Open modal for new item
  function openCreateModal() {
    const nextOrder = milestones.length + 1;
    setIsNew(true);
    setEditingItem({
      min_orders: nextOrder * 2,
      orders: `${nextOrder * 2} đơn / ngày`,
      bonus_amount: 50000,
      bonus: '+50.000đ',
      icon: '🛵',
      badge: 'Khởi động',
      perk: 'Hỗ trợ xăng xe • Kích hoạt ưu tiên nhận đơn gần',
      color: '#2563EB',
      bgColor: '#EFF6FF',
      borderColor: '#BFDBFE',
      active: true,
      display_order: nextOrder,
    });
  }

  // Open modal for editing
  function openEditModal(item: DailyMilestone) {
    setIsNew(false);
    setEditingItem({ ...item });
  }

  return (
    <div className="milestones-page">
      {/* 1. HEADER SECTION */}
      <div className="milestones-header-card">
        <div className="milestones-header-main">
          <div className="milestones-header-title-row">
            <h1>Thưởng mốc đơn mỗi ngày</h1>
            <span className="milestones-wallet-badge">
              <Sparkles size={13} />
              Cấu hình từ máy chủ
            </span>
          </div>
          <p className="milestones-header-desc">
            Chính sách thưởng nóng và phúc lợi nâng hạng khi Đối tác Tasker hoàn thành số đơn tích lũy trong ngày.
            Các mốc đã bật được công bố trên ứng dụng Partner và lưu trong cơ sở dữ liệu.
          </p>
        </div>

        <div className="milestones-header-actions">
          <button
            type="button"
            className="btn btn-outline"
            onClick={loadMilestones}
            disabled={loading}
            title="Tải lại dữ liệu từ máy chủ"
          >
            <RefreshCw size={15} className={loading ? 'animate-spin' : ''} />
            Tải lại
          </button>

          <button
            type="button"
            className="btn btn-primary"
            onClick={openCreateModal}
          >
            <Plus size={16} />
            Thêm mốc thưởng
          </button>
        </div>
      </div>

      {/* 2. KPI METRICS CARDS */}
      <div className="milestones-kpi-grid">
        <div className="milestone-kpi-card">
          <div className="milestone-kpi-icon emerald">
            <Award size={22} />
          </div>
          <div className="milestone-kpi-content">
            <span className="milestone-kpi-label">Mốc đang áp dụng</span>
            <strong className="milestone-kpi-value">{activeCount} / {milestones.length}</strong>
            <span className="milestone-kpi-sub">Đang hiển thị trên app Đối tác</span>
          </div>
        </div>

        <div className="milestone-kpi-card">
          <div className="milestone-kpi-icon blue">
            <TrendingUp size={22} />
          </div>
          <div className="milestone-kpi-content">
            <span className="milestone-kpi-label">Thưởng tối đa / ngày</span>
            <strong className="milestone-kpi-value">+{totalMaxBonus.toLocaleString('vi-VN')}đ</strong>
            <span className="milestone-kpi-sub">Tích lũy tối đa cho Top Tasker</span>
          </div>
        </div>

        <div className="milestone-kpi-card">
          <div className="milestone-kpi-icon purple">
            <Zap size={22} />
          </div>
          <div className="milestone-kpi-content">
            <span className="milestone-kpi-label">Mốc cao nhất</span>
            <strong className="milestone-kpi-value" style={{ fontSize: 16 }}>
              {topTier ? `${topTier.orders}` : 'Chưa có mốc'}
            </strong>
            <span className="milestone-kpi-sub">
              {topTier ? `Huy hiệu ${topTier.badge}` : 'Chưa thiết lập'}
            </span>
          </div>
        </div>

        <div className="milestone-kpi-card">
          <div className="milestone-kpi-icon amber">
            <Clock size={22} />
          </div>
          <div className="milestone-kpi-content">
            <span className="milestone-kpi-label">Nguồn dữ liệu</span>
            <strong className="milestone-kpi-value" style={{ fontSize: 16 }}>Máy chủ</strong>
            <span className="milestone-kpi-sub">Đồng bộ với ứng dụng Partner</span>
          </div>
        </div>
      </div>

      {/* 3. TOOLBAR */}
      <div className="milestones-toolbar">
        <div className="milestones-toolbar-left">
          <div className="inline-search" style={{ minWidth: 260 }}>
            <Search size={16} />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Tìm theo số đơn, huy hiệu, quyền lợi..."
            />
          </div>

          <div style={{ display: 'flex', gap: 6 }}>
            <button
              type="button"
              className={`milestones-filter-chip ${filter === 'ALL' ? 'active' : ''}`}
              onClick={() => setFilter('ALL')}
            >
              Tất cả ({milestones.length})
            </button>
            <button
              type="button"
              className={`milestones-filter-chip ${filter === 'ACTIVE' ? 'active' : ''}`}
              onClick={() => setFilter('ACTIVE')}
            >
              Đang bật ({milestones.filter((m) => m.active).length})
            </button>
            <button
              type="button"
              className={`milestones-filter-chip ${filter === 'INACTIVE' ? 'active' : ''}`}
              onClick={() => setFilter('INACTIVE')}
            >
              Tạm tắt ({milestones.filter((m) => !m.active).length})
            </button>
          </div>
        </div>

        <div className="milestones-toolbar-right">
          <span style={{ fontSize: 12, color: '#64748b' }}>
            Hiển thị <b>{filteredMilestones.length}</b> mốc thưởng
          </span>
        </div>
      </div>

      {/* 4. WORKSPACE: CARDS & MOBILE PREVIEW */}
      <div className="milestones-workspace">
        {/* Left Column: List of Milestone Cards */}
        <div className="milestones-list">
          {loading ? (
            <div className="milestones-empty">
              <RefreshCw size={28} className="animate-spin text-emerald-600" />
              <p>Đang tải danh sách mốc thưởng đối tác từ máy chủ…</p>
            </div>
          ) : filteredMilestones.length === 0 ? (
            <div className="milestones-empty">
              <div className="milestones-empty-icon">
                <Layers size={28} />
              </div>
              <h3 style={{ margin: 0, fontSize: 15, fontWeight: 800, color: '#1e293b' }}>
                Không tìm thấy mốc thưởng nào
              </h3>
              <p style={{ margin: 0, fontSize: 12.5 }}>
                Thử thay đổi từ khóa tìm kiếm hoặc nhấn &quot;Thêm mốc thưởng&quot; để tạo chính sách mới.
              </p>
              <button
                type="button"
                className="btn btn-primary"
                onClick={openCreateModal}
                style={{ marginTop: 8 }}
              >
                <Plus size={15} /> Thêm mốc thưởng ngay
              </button>
            </div>
          ) : (
            filteredMilestones.map((item) => (
              <div
                key={item.id}
                className={`milestone-card ${!item.active ? 'inactive' : ''}`}
              >
                <div className="milestone-card-main">
                  {/* Icon Box */}
                  <div
                    className="milestone-icon-box"
                    style={{
                      background: item.bgColor || '#EFF6FF',
                      borderColor: item.borderColor || '#BFDBFE',
                    }}
                  >
                    <span>{item.icon}</span>
                  </div>

                  {/* Details */}
                  <div className="milestone-details">
                    <div className="milestone-title-row">
                      <span className="milestone-orders-title">{item.orders}</span>
                      <span
                        className="milestone-badge-pill"
                        style={{
                          background: item.bgColor || '#EFF6FF',
                          color: item.color || '#2563EB',
                        }}
                      >
                        {item.badge}
                      </span>
                      <span
                        className={`milestone-status-chip ${item.active ? 'active' : 'inactive'}`}
                      >
                        {item.active ? '● Đang áp dụng' : '○ Tạm ẩn'}
                      </span>
                    </div>

                    <p className="milestone-perk-desc" title={item.perk}>
                      {item.perk || 'Chưa thiết lập mô tả quyền lợi.'}
                    </p>
                  </div>
                </div>

                {/* Right Aside */}
                <div className="milestone-card-aside">
                  <div className="milestone-bonus-chip">
                    {item.bonus || formatVnd(item.bonus_amount || 0)}
                  </div>

                  <div className="milestone-actions">
                    <button
                      type="button"
                      className={`milestone-icon-btn active-toggle ${item.active ? '' : 'off'}`}
                      onClick={() => toggleActive(item)}
                      title={item.active ? 'Nhấn để tạm tắt mốc này' : 'Nhấn để kích hoạt mốc này'}
                    >
                      <Power size={14} />
                    </button>

                    <button
                      type="button"
                      className="milestone-icon-btn"
                      onClick={() => openEditModal(item)}
                      title="Chỉnh sửa mốc thưởng"
                    >
                      <Edit3 size={14} />
                    </button>

                    <button
                      type="button"
                      className="milestone-icon-btn delete"
                      onClick={() => setDeletingItem(item)}
                      title="Xóa mốc thưởng"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>

      </div>

      {/* 5. EDIT / CREATE MODAL */}
      {editingItem && (
        <CataloguePopup
          title={isNew ? 'Thêm mốc thưởng mới' : 'Chỉnh sửa mốc thưởng'}
          eyebrow="CHÍNH SÁCH ĐỐI TÁC • TASKLY OPERATIONS"
          busy={submitting}
          onClose={() => setEditingItem(null)}
        >
          <form onSubmit={handleSaveItem} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="milestone-form-grid">
              {/* Số đơn */}
              <div className="milestone-field-group">
                <label>Số đơn tối thiểu đạt mốc (*)</label>
                <input
                  type="number"
                  min={1}
                  max={100}
                  required
                  value={editingItem.min_orders ?? 3}
                  onChange={(e) => {
                    const val = Number(e.target.value);
                    setEditingItem((prev) => ({
                      ...prev,
                      min_orders: val,
                      orders: prev?.orders && !prev.orders.includes('+') ? `${val} đơn / ngày` : prev?.orders || `${val} đơn / ngày`,
                    }));
                  }}
                />
                <span className="milestone-field-hint">Hệ thống đếm số đơn hoàn tất trong ngày</span>
              </div>

              {/* Nhãn hiển thị số đơn */}
              <div className="milestone-field-group">
                <label>Nhãn hiển thị trên app (*)</label>
                <input
                  type="text"
                  required
                  value={editingItem.orders || ''}
                  onChange={(e) => setEditingItem((prev) => ({ ...prev, orders: e.target.value }))}
                  placeholder="Ví dụ: 3 đơn / ngày hoặc 10+ đơn / ngày"
                />
                <span className="milestone-field-hint">Dòng chữ tiêu đề mốc đối tác nhìn thấy</span>
              </div>

              {/* Tiền thưởng */}
              <div className="milestone-field-group">
                <label>Mức tiền thưởng cộng ví (VNĐ) (*)</label>
                <input
                  type="number"
                  min={1}
                  step={1}
                  required
                  value={editingItem.bonus_amount ?? 30000}
                  onChange={(e) => {
                    const val = Number(e.target.value);
                    setEditingItem((prev) => ({
                      ...prev,
                      bonus_amount: val,
                      bonus: formatVnd(val),
                    }));
                  }}
                />
                <span className="milestone-field-hint">
                  Hiển thị: <b>{formatVnd(Number(editingItem.bonus_amount || 0))}</b>
                </span>
              </div>

              {/* Tên danh hiệu / Badge */}
              <div className="milestone-field-group">
                <label>Tên huy hiệu / Danh hiệu (*)</label>
                <input
                  type="text"
                  required
                  value={editingItem.badge || ''}
                  onChange={(e) => setEditingItem((prev) => ({ ...prev, badge: e.target.value }))}
                  placeholder="Ví dụ: Khởi động, Tăng tốc, Siêu Tasker..."
                />
                <div className="milestone-badge-presets">
                  {PRESET_BADGES.map((b) => (
                    <button
                      key={b}
                      type="button"
                      className="milestone-preset-chip"
                      onClick={() => setEditingItem((prev) => ({ ...prev, badge: b }))}
                    >
                      {b}
                    </button>
                  ))}
                </div>
              </div>

              {/* Biểu tượng Icon */}
              <div className="milestone-field-group milestone-field-full">
                <label>Biểu tượng mốc (Emoji Icon)</label>
                <div className="milestone-emoji-bar">
                  {PRESET_EMOJIS.map((emoji) => (
                    <button
                      key={emoji}
                      type="button"
                      className={`milestone-emoji-btn ${editingItem.icon === emoji ? 'selected' : ''}`}
                      onClick={() => setEditingItem((prev) => ({ ...prev, icon: emoji }))}
                    >
                      {emoji}
                    </button>
                  ))}
                  <input
                    type="text"
                    value={editingItem.icon || ''}
                    onChange={(e) => setEditingItem((prev) => ({ ...prev, icon: e.target.value }))}
                    placeholder="Emoji khác"
                    style={{ width: 100, padding: '4px 8px', fontSize: 13 }}
                  />
                </div>
              </div>

              {/* Bộ màu sắc Theme */}
              <div className="milestone-field-group milestone-field-full">
                <label>Tông màu giao diện hiển thị</label>
                <div className="milestone-theme-bar">
                  {COLOR_THEMES.map((th) => (
                    <button
                      key={th.name}
                      type="button"
                      className={`milestone-theme-btn ${editingItem.color === th.color ? 'selected' : ''}`}
                      style={{
                        background: th.bgColor,
                        color: th.color,
                        borderColor: editingItem.color === th.color ? th.color : th.borderColor,
                      }}
                      onClick={() =>
                        setEditingItem((prev) => ({
                          ...prev,
                          color: th.color,
                          bgColor: th.bgColor,
                          borderColor: th.borderColor,
                        }))
                      }
                    >
                      <span style={{ fontSize: 14 }}>{editingItem.icon || '●'}</span>
                      {th.name}
                    </button>
                  ))}
                </div>
              </div>

              {/* Quyền lợi / Mô tả phúc lợi */}
              <div className="milestone-field-group milestone-field-full">
                <label>Quyền lợi & Phúc lợi mở rộng (Perks) (*)</label>
                <textarea
                  rows={2}
                  required
                  value={editingItem.perk || ''}
                  onChange={(e) => setEditingItem((prev) => ({ ...prev, perk: e.target.value }))}
                  placeholder="Ví dụ: Hỗ trợ tiền xăng xe • Tự động kích hoạt Bảo hiểm tai nạn ngày"
                />
                <span className="milestone-field-hint">
                  Dùng dấu chấm tròn &quot;•&quot; để ngăn cách các quyền lợi
                </span>
              </div>

              {/* Thứ tự & Trạng thái */}
              <div className="milestone-field-group">
                <label>Thứ tự hiển thị (Ưu tiên)</label>
                <input
                  type="number"
                  min={1}
                  value={editingItem.display_order ?? 1}
                  onChange={(e) => setEditingItem((prev) => ({ ...prev, display_order: Number(e.target.value) }))}
                />
              </div>

              <div className="milestone-field-group" style={{ justifyContent: 'center' }}>
                <label className="milestone-switch-row">
                  <input
                    type="checkbox"
                    checked={editingItem.active !== false}
                    onChange={(e) => setEditingItem((prev) => ({ ...prev, active: e.target.checked }))}
                  />
                  <span style={{ fontSize: 13, fontWeight: 700, color: '#1e293b' }}>
                    Kích hoạt áp dụng trên app Đối tác
                  </span>
                </label>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 10 }}>
              <button
                type="button"
                className="btn btn-outline"
                disabled={submitting}
                onClick={() => setEditingItem(null)}
              >
                Hủy bỏ
              </button>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={submitting}
              >
                <Check size={16} />
                {submitting ? 'Đang lưu…' : isNew ? 'Thêm mốc' : 'Lưu thay đổi'}
              </button>
            </div>
          </form>
        </CataloguePopup>
      )}

      {/* 6. DELETE CONFIRMATION POPUP */}
      {deletingItem && (
        <CataloguePopup
          title="Xác nhận xóa mốc thưởng?"
          eyebrow="CẢNH BÁO QUẢN TRỊ"
          compact
          busy={submitting}
          onClose={() => setDeletingItem(null)}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <p style={{ margin: 0, fontSize: 13, color: '#334155', lineHeight: 1.5 }}>
              Bạn có chắc chắn muốn xóa mốc thưởng <b>&quot;{deletingItem.orders}&quot;</b> ({deletingItem.badge} - {deletingItem.bonus}) không?
              Hành động này sẽ gỡ bỏ mốc khỏi ứng dụng đối tác.
            </p>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
              <button
                type="button"
                className="btn btn-outline"
                disabled={submitting}
                onClick={() => setDeletingItem(null)}
              >
                Hủy
              </button>
              <button
                type="button"
                className="btn btn-primary"
                style={{ background: '#dc2626', borderColor: '#dc2626' }}
                disabled={submitting}
                onClick={handleDeleteConfirm}
              >
                {submitting ? 'Đang xóa…' : 'Xóa mốc này'}
              </button>
            </div>
          </div>
        </CataloguePopup>
      )}

      {/* 7. TOAST NOTIFICATION */}
      {toast && (
        <div className="toast">
          <CheckCircle2 size={18} />
          {toast}
        </div>
      )}
    </div>
  );
}
