'use client';

import React, { useMemo, useState } from 'react';
import {
  Users,
  Search,
  Award,
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
} from 'lucide-react';
import PartnerDetailModal from './PartnerDetailModal';
import { partnerStatusLabels } from './PartnerChecks';
import './partner-admin.css';

type PartnerAdminProps = {
  partners: any[];
  loading?: boolean;
  onRefresh?: () => Promise<void>;
  onUpdatePartner?: (id: string, body: any) => Promise<void>;
  onAction?: (item: any, action: string) => void;
  onNavigate?: (route: string) => void;
  saving?: boolean;
  onEditPartner?: (partner: any) => void;
};

export default function PartnerAdmin({
  partners,
  loading,
  onRefresh,
  onUpdatePartner,
  onAction,
  onNavigate,
  saving,
  onEditPartner,
}: PartnerAdminProps) {
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [kycFilter, setKycFilter] = useState('ALL');
  const [sortBy, setSortBy] = useState<'created' | 'name' | 'jobs' | 'standards'>('created');
  const [selectedPartner, setSelectedPartner] = useState<any | null>(null);
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
  const totalCount = partners.length;
  const activeCount = partners.filter((p) => p.status === 'ACTIVE').length;
  const suspendedCount = partners.filter((p) => p.status === 'SUSPENDED').length;
  const kycApprovedCount = partners.filter((p) => p.kyc === 'APPROVED').length;
  const pendingReviewCount = partners.filter((p) =>
    ['PENDING_REVIEW', 'PRELIMINARY_REVIEW', 'FINAL_REVIEW', 'ACTION_REQUIRED'].includes(p.recruitment_status)
  ).length;
  const totalCompletedJobs = partners.reduce((sum, p) => sum + Number(p.completed_jobs || 0), 0);

  // Filter & Search Logic
  const filteredPartners = useMemo(() => {
    let list = [...partners];

    // Status filter
    if (statusFilter !== 'ALL') {
      if (statusFilter === 'ACTIVE') {
        list = list.filter((p) => p.status === 'ACTIVE');
      } else if (statusFilter === 'SUSPENDED') {
        list = list.filter((p) => p.status === 'SUSPENDED');
      } else if (statusFilter === 'REVIEWING') {
        list = list.filter((p) =>
          ['PENDING_REVIEW', 'PRELIMINARY_REVIEW', 'FINAL_REVIEW'].includes(p.recruitment_status)
        );
      } else if (statusFilter === 'ACTION_REQUIRED') {
        list = list.filter((p) =>
          ['ACTION_REQUIRED', 'PROFILE_INCOMPLETE', 'EXAM_REQUIRED', 'EXAM_FAILED'].includes(p.recruitment_status)
        );
      } else if (statusFilter === 'APPROVED') {
        list = list.filter((p) => ['APPROVED', 'ACTIVE'].includes(p.recruitment_status));
      }
    }

    // KYC filter
    if (kycFilter !== 'ALL') {
      list = list.filter((p) => p.kyc === kycFilter);
    }

    // Text search query
    if (query.trim()) {
      const q = query.trim().toLowerCase();
      list = list.filter((p) => {
        const name = String(p.name || '').toLowerCase();
        const phone = String(p.phone || '').toLowerCase();
        const email = String(p.email || '').toLowerCase();
        const id = String(p.id || '').toLowerCase();
        return name.includes(q) || phone.includes(q) || email.includes(q) || id.includes(q);
      });
    }

    // Sorting
    list.sort((a, b) => {
      if (sortBy === 'name') {
        return String(a.name || '').localeCompare(String(b.name || ''));
      }
      if (sortBy === 'jobs') {
        return Number(b.completed_jobs || 0) - Number(a.completed_jobs || 0);
      }
      if (sortBy === 'standards') {
        const countA = Object.values(a.partner_checks || {}).filter(Boolean).length;
        const countB = Object.values(b.partner_checks || {}).filter(Boolean).length;
        return countB - countA;
      }
      // default: created
      return String(b.created || '').localeCompare(String(a.created || ''));
    });

    return list;
  }, [partners, statusFilter, kycFilter, query, sortBy]);

  // CSV Export
  const exportCsv = () => {
    const headers = [
      'ID',
      'Họ và tên',
      'Số điện thoại',
      'Email',
      'Trạng thái tài khoản',
      'Trạng thái tuyển dụng',
      'KYC',
      'Việc đã nhận',
      'Việc hoàn tất',
      'Ngày đăng ký',
    ];

    const rows = filteredPartners.map((p) => [
      `"${p.id}"`,
      `"${(p.name || '').replace(/"/g, '""')}"`,
      `"${p.phone || ''}"`,
      `"${p.email || ''}"`,
      `"${p.status || ''}"`,
      `"${partnerStatusLabels[p.recruitment_status] || p.recruitment_status || ''}"`,
      `"${p.kyc || ''}"`,
      p.accepted_jobs || 0,
      p.completed_jobs || 0,
      `"${p.created || ''}"`,
    ]);

    const csvContent = '\uFEFF' + [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `taskly-partners-${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="partner-admin-page">
      {/* 2. KPI Metrics Grid */}
      <div className="partner-kpi-grid">
        <div className="partner-kpi-card">
          <div className="partner-kpi-top">
            <span className="partner-kpi-label">Tổng số Đối tác</span>
            <div className="partner-kpi-icon blue"><Users size={19} /></div>
          </div>
          <strong className="partner-kpi-val">{totalCount}</strong>
          <span className="partner-kpi-sub">Hồ sơ đối tác đã ghi nhận</span>
        </div>

        <div className="partner-kpi-card">
          <div className="partner-kpi-top">
            <span className="partner-kpi-label">Đang hoạt động</span>
            <div className="partner-kpi-icon green"><CheckCircle2 size={19} /></div>
          </div>
          <strong className="partner-kpi-val" style={{ color: '#059669' }}>{activeCount}</strong>
          <span className="partner-kpi-sub">
            <span className="live-pulse-dot" /> Sẵn sàng nhận việc
          </span>
        </div>

        <div className="partner-kpi-card">
          <div className="partner-kpi-top">
            <span className="partner-kpi-label">Chờ duyệt / Bổ sung</span>
            <div className="partner-kpi-icon amber"><AlertTriangle size={19} /></div>
          </div>
          <strong className="partner-kpi-val" style={{ color: '#d97706' }}>{pendingReviewCount}</strong>
          <span className="partner-kpi-sub">Cần admin rà soát & duyệt</span>
        </div>

        <div className="partner-kpi-card">
          <div className="partner-kpi-top">
            <span className="partner-kpi-label">Đã duyệt KYC</span>
            <div className="partner-kpi-icon purple"><ShieldCheck size={19} /></div>
          </div>
          <strong className="partner-kpi-val" style={{ color: '#7c3aed' }}>{kycApprovedCount}</strong>
          <span className="partner-kpi-sub">CCCD định danh hợp lệ</span>
        </div>

        <div className="partner-kpi-card">
          <div className="partner-kpi-top">
            <span className="partner-kpi-label">Tổng việc hoàn tất</span>
            <div className="partner-kpi-icon green"><Briefcase size={19} /></div>
          </div>
          <strong className="partner-kpi-val">{totalCompletedJobs}</strong>
          <span className="partner-kpi-sub">Đơn hàng đối tác đã phục vụ</span>
        </div>
      </div>

      {/* 3. Filter Toolbar & Search */}
      <div className="partner-toolbar">
        <div className="partner-toolbar-top">
          <div className="partner-search-box">
            <Search size={16} color="#64748b" />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Tìm theo tên, số điện thoại, email hoặc ID đối tác..."
            />
            {query && (
              <button
                onClick={() => setQuery('')}
                style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 2, color: '#94a3b8' }}
              >
                <X size={15} />
              </button>
            )}
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span className="partner-toolbar-counts">
              Hiển thị <strong>{filteredPartners.length}</strong> / {totalCount} đối tác
            </span>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <SlidersHorizontal size={14} color="#64748b" />
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as any)}
                style={{
                  padding: '7px 12px',
                  borderRadius: 10,
                  border: '1px solid #e2e8f0',
                  fontSize: 12.5,
                  fontWeight: 600,
                  color: '#334155',
                  background: '#ffffff',
                  outline: 'none',
                  cursor: 'pointer',
                }}
              >
                <option value="created">Mới tham gia nhất</option>
                <option value="name">Tên (A → Z)</option>
                <option value="jobs">Nhiều việc hoàn tất nhất</option>
                <option value="standards">Tiến độ tiêu chuẩn cao nhất</option>
              </select>
            </div>
          </div>
        </div>

        {/* Filter Pills */}
        <div className="partner-filter-pills">
          <button
            className={`partner-pill-btn ${statusFilter === 'ALL' ? 'active' : ''}`}
            onClick={() => setStatusFilter('ALL')}
          >
            Tất cả <small>{totalCount}</small>
          </button>
          <button
            className={`partner-pill-btn ${statusFilter === 'ACTIVE' ? 'active' : ''}`}
            onClick={() => setStatusFilter('ACTIVE')}
          >
            ● Đang hoạt động <small>{activeCount}</small>
          </button>
          <button
            className={`partner-pill-btn ${statusFilter === 'REVIEWING' ? 'active' : ''}`}
            onClick={() => setStatusFilter('REVIEWING')}
          >
            Chờ thẩm định <small>{pendingReviewCount}</small>
          </button>
          <button
            className={`partner-pill-btn ${statusFilter === 'ACTION_REQUIRED' ? 'active' : ''}`}
            onClick={() => setStatusFilter('ACTION_REQUIRED')}
          >
            Cần bổ sung hồ sơ
          </button>
          <button
            className={`partner-pill-btn ${statusFilter === 'SUSPENDED' ? 'active' : ''}`}
            onClick={() => setStatusFilter('SUSPENDED')}
          >
            Tạm ngưng <small>{suspendedCount}</small>
          </button>
        </div>
      </div>

      {/* 4. Table Panel */}
      <div className="partner-table-panel">
        <div className="partner-table-responsive">
          <table className="partner-table">
            <thead>
              <tr>
                <th>Đối tác</th>
                <th>Liên hệ</th>
                <th>Trạng thái tài khoản</th>
                <th>Tiến trình hồ sơ</th>
                <th>Định danh KYC</th>
                <th>Hiệu suất việc</th>
                <th>Tiêu chuẩn thẩm định</th>
                <th style={{ textAlign: 'right' }}>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {filteredPartners.map((item) => {
                const checks = item.partner_checks || {};
                const passedCount = Object.values(checks).filter(Boolean).length;
                const totalChecks = 14;
                const checksPercent = Math.round((passedCount / totalChecks) * 100);

                const recLabel = partnerStatusLabels[item.recruitment_status] || item.recruitment_status || 'Chưa đăng ký';
                const isSuspended = item.status === 'SUSPENDED';

                return (
                  <tr key={item.id}>
                    {/* Partner Name & Avatar */}
                    <td>
                      <div className="partner-user-cell">
                        <div className="partner-avatar">
                          {item.avatar ? <img src={item.avatar} alt={`Ảnh đại diện ${item.name || 'Partner'}`} style={{width:'100%',height:'100%',objectFit:'cover',borderRadius:'inherit'}} onError={e=>{e.currentTarget.style.display='none'}}/> : String(item.name || 'P').slice(0, 1).toUpperCase()}
                        </div>
                        <div className="partner-user-info">
                          <span className="partner-user-name">{item.name || 'Chưa đặt tên'}</span>
                          <span className="partner-user-meta">
                          </span>
                        </div>
                      </div>
                    </td>

                    {/* Contact */}
                    <td>
                      <div className="partner-contact-cell">
                        <span className="partner-contact-phone">
                          <Phone size={12} color="#059669" /> {item.phone || '—'}
                        </span>
                        <span className="partner-contact-email">
                          <Mail size={12} color="#64748b" /> {item.email || '—'}
                        </span>
                      </div>
                    </td>

                    {/* Status */}
                    <td>
                      <span className={`partner-badge ${item.status === 'ACTIVE' ? 'active' : 'suspended'}`}>
                        {item.status === 'ACTIVE' ? '● Hoạt động' : 'Tạm ngưng'}
                      </span>
                    </td>

                    {/* Recruitment Status */}
                    <td>
                      <span
                        className="partner-badge info"
                        title={item.recruitment_status}
                      >
                        {recLabel}
                      </span>
                    </td>

                    {/* KYC */}
                    <td>
                      <span className={`partner-badge ${item.kyc === 'APPROVED' ? 'active' : item.kyc === 'SUBMITTED' ? 'pending' : 'neutral'}`}>
                        {item.kyc === 'APPROVED' ? '✓ Đã duyệt' : item.kyc === 'SUBMITTED' ? 'Chờ duyệt' : 'Chưa nộp'}
                      </span>
                    </td>

                    {/* Jobs */}
                    <td>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                        <span style={{ fontSize: 13, fontWeight: 700, color: '#0f172a' }}>
                          {item.completed_jobs || 0} việc hoàn tất
                        </span>
                        <span style={{ fontSize: 11.5, color: '#64748b' }}>
                          Đã nhận: {item.accepted_jobs || 0}
                        </span>
                      </div>
                    </td>

                    {/* Standards Progress */}
                    <td>
                      <div className="partner-progress-col">
                        <div className="partner-progress-text">
                          <span>{passedCount}/{totalChecks} đạt</span>
                          <span>{checksPercent}%</span>
                        </div>
                        <div className="partner-progress-bar">
                          <div
                            className={`partner-progress-fill ${checksPercent < 100 ? 'incomplete' : ''}`}
                            style={{ width: `${checksPercent}%` }}
                          />
                        </div>
                      </div>
                    </td>

                    {/* Actions */}
                    <td style={{ textAlign: 'right' }}>
                      <div className="partner-actions-cell" style={{ justifyContent: 'flex-end' }}>
                        <button
                          className="partner-view-btn"
                          onClick={() => setSelectedPartner(item)}
                          title="Xem chi tiết toàn diện đối tác"
                        >
                          Xem chi tiết <ChevronRight size={14} />
                        </button>

                        {item.recruitment_status === 'ACTIVE' && item.application_id && onAction && (
                          <button
                            className="partner-suspend-btn"
                            disabled={saving}
                            onClick={() => onAction(item, 'SUSPEND_TASKER')}
                            title="Tạm ngưng để kiểm tra tài khoản"
                          >
                            Tạm ngưng
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}

              {filteredPartners.length === 0 && (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: '48px 24px', color: '#94a3b8' }}>
                    <Users size={36} style={{ margin: '0 auto 12px', opacity: 0.4 }} />
                    <strong style={{ display: 'block', fontSize: 15, color: '#475569', marginBottom: 4 }}>
                      Không tìm thấy đối tác nào phù hợp
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

        <div className="partner-table-footer">
          <span>
            Hiển thị <strong>{filteredPartners.length}</strong> / {totalCount} đối tác TaskLy
          </span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Sparkles size={13} color="#059669" /> Dữ liệu trực tiếp từ máy chủ
          </span>
        </div>
      </div>

      {/* 5. Partner Detail Modal */}
      {selectedPartner && (
        <PartnerDetailModal
          onSaved={() => {onRefresh?.();}}
          partner={partners.find((p) => p.id === selectedPartner.id) || selectedPartner}
          onClose={() => setSelectedPartner(null)}
          onUpdatePartner={onUpdatePartner}
          onAction={onAction}
          onEditPartner={onEditPartner}
          saving={saving}
        />
      )}
    </div>
  );
}
