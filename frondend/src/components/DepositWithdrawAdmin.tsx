'use client';

import React, { useState, useEffect, useMemo } from 'react';
import {
  ArrowDownLeft,
  ArrowUpRight,
  Wallet,
  CreditCard,
  Building2,
  CheckCircle2,
  Clock,
  AlertTriangle,
  XCircle,
  Search,
  Filter,
  Plus,
  Download,
  RefreshCw,
  Copy,
  ExternalLink,
  ShieldCheck,
  Eye,
  Settings2,
  QrCode,
  SlidersHorizontal,
  X,
  Check,
  RotateCcw,
  Sparkles,
  Layers,
  Banknote,
  TrendingUp,
} from 'lucide-react';
import './deposit-withdraw-admin.css';

export type TransactionType = 'DEPOSIT' | 'WITHDRAWAL';
export type TransactionStatus = 'PENDING' | 'APPROVED' | 'COMPLETED' | 'PAID' | 'REJECTED' | 'FAILED';

export interface FinanceTransaction {
  id: string;
  backendId?: string;
  source?: 'PARTNER_WALLET' | 'CUSTOMER_REFUND';
  type: TransactionType;
  category: 'CUSTOMER_TOPUP' | 'PARTNER_DEPOSIT' | 'BOOKING_ESCROW' | 'PARTNER_PAYOUT' | 'CUSTOMER_REFUND';
  amount: number;
  fee?: number;
  status: TransactionStatus;
  userId: string;
  userName: string;
  userPhone: string;
  userRole: 'CUSTOMER' | 'PARTNER';
  method: string;
  bankName?: string;
  accountNumber?: string;
  accountName?: string;
  createdAt: string;
  completedAt?: string;
  refCode?: string;
  note?: string;
  taskId?: string;
}

export interface FinanceConfig {
  minDeposit: number;
  maxDeposit: number;
  minWithdraw: number;
  maxWithdrawDaily: number;
  withdrawFeePercent: number;
  autoApproveUnder: number;
  bankName: string;
  bankAccount: string;
  accountOwner: string;
  qrPrefix: string;
}

const DEFAULT_CONFIG: FinanceConfig = {
  minDeposit: 50000,
  maxDeposit: 50000000,
  minWithdraw: 100000,
  maxWithdrawDaily: 20000000,
  withdrawFeePercent: 0,
  autoApproveUnder: 500000,
  bankName: 'Vietcombank - CN Tân Bình TP.HCM',
  bankAccount: '0988889999',
  accountOwner: 'CONG TY CO PHAN TASKLY VIET NAM',
  qrPrefix: 'TASKLY NAP',
};


function formatVnd(amount: number): string {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount);
}

function formatDate(dateStr: string): string {
  if (!dateStr) return '—';
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return dateStr;
    return d.toLocaleString('vi-VN', {
      hour: '2-digit',
      minute: '2-digit',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    });
  } catch {
    return dateStr;
  }
}

interface DepositWithdrawAdminProps {
  role: 'CUSTOMER' | 'PARTNER';
  db: Record<string, any>;
  customers?: any[];
  partners?: any[];
  initialTab?: 'ALL' | 'DEPOSIT' | 'WITHDRAWAL' | 'CONFIG';
  onNotify?: (msg: string) => void;
  onRefreshParent?: () => void;
}

export default function DepositWithdrawAdmin({
  role,
  db,
  customers = [],
  partners = [],
  initialTab = 'ALL',
  onNotify,
  onRefreshParent,
}: DepositWithdrawAdminProps) {
  // Tabs: 'ALL' | 'DEPOSIT' | 'WITHDRAWAL' | 'CONFIG'
  const [activeTab, setActiveTab] = useState<'ALL' | 'DEPOSIT' | 'WITHDRAWAL' | 'CONFIG'>(initialTab);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const roleFilter = role;

  // Transactions & Config state
  const [transactions, setTransactions] = useState<FinanceTransaction[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [config, setConfig] = useState<FinanceConfig>(DEFAULT_CONFIG);
  const [loading, setLoading] = useState(false);

  // Modals state
  const [selectedTx, setSelectedTx] = useState<FinanceTransaction | null>(null);
  const [approvalModalTx, setApprovalModalTx] = useState<FinanceTransaction | null>(null);
  const [approvalRefCode, setApprovalRefCode] = useState('');
  const [approvalNote, setApprovalNote] = useState('');

  const [rejectModalTx, setRejectModalTx] = useState<FinanceTransaction | null>(null);
  const [rejectReason, setRejectReason] = useState('Thông tin tài khoản ngân hàng không khớp');
  const [rejectNote, setRejectNote] = useState('');

  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [newTxType, setNewTxType] = useState<TransactionType>('DEPOSIT');
  const [newTxUserRole, setNewTxUserRole] = useState<'CUSTOMER' | 'PARTNER'>(role);
  const [newTxUserId, setNewTxUserId] = useState('');
  const [newTxAmount, setNewTxAmount] = useState('200000');
  const [newTxMethod, setNewTxMethod] = useState('VietQR Chuyển khoản 24/7');
  const [newTxBankName, setNewTxBankName] = useState('Vietcombank');
  const [newTxBankAccount, setNewTxBankAccount] = useState('');
  const [newTxAccountName, setNewTxAccountName] = useState('');
  const [newTxNote, setNewTxNote] = useState('Admin hỗ trợ tạo giao dịch thủ công');

  const [configSaving, setConfigSaving] = useState(false);
  const [createSaving, setCreateSaving] = useState(false);
  const [manualRequestId, setManualRequestId] = useState<string | null>(null);
  useEffect(() => {
    fetch('/api/admin/wallet-config', { cache: 'no-store' }).then(async response => {
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(typeof result.error === 'string' ? result.error : 'Không thể tải cấu hình');
      setConfig(result.data);
    }).catch(error => onNotify?.(error.message));
  }, []);

  // Helper to find person info
  const allUsers = useMemo(() => {
    const list: Array<{ id: string; name: string; phone: string; role: 'CUSTOMER' | 'PARTNER'; bank?: string; account?: string }> = [];
    const sourceCustomers = customers.length ? customers : db.customers || [];
    const sourcePartners = partners.length ? partners : db.partners || [];

    sourceCustomers.forEach((c: any) => {
      list.push({
        id: c.id,
        name: c.name || c.full_name || 'Khách hàng TaskLy',
        phone: c.phone || '—',
        role: 'CUSTOMER',
      });
    });

    sourcePartners.forEach((p: any) => {
      list.push({
        id: p.id,
        name: p.name || p.full_name || 'Đối tác Tasker',
        phone: p.phone || '—',
        role: 'PARTNER',
        bank: p.bank || 'MB Bank',
        account: p.account || '•••• ' + (p.id.slice(-4) || '8888'),
      });
    });

    return list;
  }, [customers, partners, db]);

  // Initial Seed & Hydration
  const loadTransactions = async () => {
    setLoading(true);
    try {
      const response = await fetch(`/api/admin/partner-wallet-transactions?role=${role}`, { cache: 'no-store' });
      const json = await response.json();
      if (!response.ok || !json.success) throw new Error(typeof json.error === 'string' ? json.error : json.error?.message || 'Không thể tải giao dịch');
      const list: FinanceTransaction[] = json.data.map((tx: any) => {
        const user = allUsers.find(u => u.id === tx.user_id);
        return {
          id: tx.id, backendId: tx.id, source: 'PARTNER_WALLET',
          type: tx.type, category: tx.type === 'DEPOSIT' ? (tx.user_role === 'CUSTOMER' ? 'CUSTOMER_TOPUP' : 'PARTNER_DEPOSIT') : (tx.user_role === 'CUSTOMER' ? 'CUSTOMER_REFUND' : 'PARTNER_PAYOUT'),
          amount: Number(tx.amount), fee: Number(tx.fee || 0), status: tx.status,
          userId: tx.user_id, userName: tx.user_name || user?.name || tx.account_name || tx.user_id,
          userPhone: tx.user_phone || user?.phone || '', userRole: tx.user_role || 'PARTNER',
          method: tx.method || (tx.type === 'DEPOSIT' ? 'Nạp ví' : 'Chuyển khoản ngân hàng'),
          bankName: tx.bank_name, accountName: tx.account_name, accountNumber: tx.account_number,
          createdAt: tx.created_at, completedAt: tx.completed_at, refCode: tx.reference_code, note: tx.note,
        };
      });
      const refunds = await fetch('/api/admin/refund-withdrawals', { cache: 'no-store' });
      if (role === 'CUSTOMER' && refunds.ok) {
        const result = await refunds.json();
        if (result.success && Array.isArray(result.data)) result.data.forEach((tx: any) => {
          const user = allUsers.find(u => u.id === tx.customer_id);
          list.push({ id: tx.id, backendId: tx.id, source: 'CUSTOMER_REFUND', type: 'WITHDRAWAL', category: 'CUSTOMER_REFUND', amount: Number(tx.amount), fee: Number(tx.fee || 0), status: tx.status, userId: tx.customer_id, userName: user?.name || tx.account_name || tx.customer_id, userPhone: user?.phone || '', userRole: 'CUSTOMER', method: 'Chuyển khoản hoàn tiền', bankName: tx.bank_name, accountName: tx.account_name, accountNumber: tx.account_number, createdAt: tx.created_at });
        });
      }
      setTransactions(list.filter(tx => tx.userRole === role));
      setLoadError(null);
    } catch (error) {
      setLoadError(error instanceof Error ? error.message : 'Không thể tải giao dịch');
      onNotify?.(error instanceof Error ? error.message : 'Không thể tải giao dịch');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadTransactions();
    const timer = setInterval(() => void loadTransactions(), 15000);
    return () => clearInterval(timer);
  }, []);

  // KPI Calculations
  const stats = useMemo(() => {
    const totalDeposits = transactions
      .filter(t => t.type === 'DEPOSIT' && ['COMPLETED', 'PAID'].includes(t.status))
      .reduce((sum, t) => sum + t.amount, 0);

    const totalWithdrawals = transactions
      .filter(t => t.type === 'WITHDRAWAL' && ['COMPLETED', 'PAID'].includes(t.status))
      .reduce((sum, t) => sum + t.amount, 0);

    const pendingWithdrawals = transactions.filter(
      t => t.type === 'WITHDRAWAL' && t.status === 'PENDING'
    );

    const pendingWithdrawAmount = pendingWithdrawals.reduce((sum, t) => sum + t.amount, 0);

    const activeEscrow = transactions
      .filter(t => t.category === 'BOOKING_ESCROW' && t.status !== 'REJECTED')
      .reduce((sum, t) => sum + t.amount, 0);

    return {
      totalDeposits,
      totalWithdrawals,
      pendingCount: pendingWithdrawals.length,
      pendingWithdrawAmount,
      activeEscrow,
      totalTxCount: transactions.length,
      depositCount: transactions.filter(t => t.type === 'DEPOSIT').length,
      withdrawalCount: transactions.filter(t => t.type === 'WITHDRAWAL').length,
    };
  }, [transactions]);

  // Filtered List
  const filteredTransactions = useMemo(() => {
    return transactions.filter(t => {
      // Tab filter
      if (activeTab === 'DEPOSIT' && t.type !== 'DEPOSIT') return false;
      if (activeTab === 'WITHDRAWAL' && t.type !== 'WITHDRAWAL') return false;

      // Status filter
      if (statusFilter !== 'ALL' && t.status !== statusFilter) return false;

      // Role filter
      if (t.userRole !== roleFilter) return false;

      // Search Query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const match =
          t.id.toLowerCase().includes(q) ||
          t.userName.toLowerCase().includes(q) ||
          t.userPhone.includes(q) ||
          (t.accountNumber && t.accountNumber.includes(q)) ||
          (t.bankName && t.bankName.toLowerCase().includes(q)) ||
          (t.refCode && t.refCode.toLowerCase().includes(q)) ||
          (t.note && t.note.toLowerCase().includes(q));
        if (!match) return false;
      }

      return true;
    });
  }, [transactions, activeTab, statusFilter, roleFilter, searchQuery]);

  const [saving, setSaving] = useState(false);
  const updateStatus = async (tx: FinanceTransaction, status: string, note?: string, referenceCode?: string) => {
    if (saving) return false;
    setSaving(true);
    try {
      const response = await fetch(tx.source === 'PARTNER_WALLET' ? '/api/admin/partner-wallet-transactions' : '/api/admin/refund-withdrawals', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: tx.backendId, status, note, referenceCode }),
      });
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(typeof result.error === 'string' ? result.error : result.error?.message || 'Không thể cập nhật giao dịch');
      await loadTransactions();
      setSelectedTx(null);
      onNotify?.(status === 'PAID' ? 'Đã xác nhận chuyển tiền.' : status === 'APPROVED' ? (tx.type === 'DEPOSIT' ? 'Đã xác nhận nhận tiền và cộng số dư customer.' : 'Đã duyệt. Đang chờ chuyển tiền.') : 'Đã từ chối yêu cầu.');
      return true;
    } catch (error) {
      onNotify?.(error instanceof Error ? error.message : 'Không thể cập nhật giao dịch');
      return false;
    } finally { setSaving(false); }
  };
  const handleApproveWithdrawal = async (tx: FinanceTransaction) => {
    if (!approvalRefCode.trim()) { onNotify?.('Nhập mã giao dịch chuyển khoản.'); return; }
    if (await updateStatus(tx, 'PAID', approvalNote.trim(), approvalRefCode.trim())) {
      setApprovalModalTx(null); setApprovalRefCode(''); setApprovalNote('');
    }
  };
  const handleRejectWithdrawal = async (tx: FinanceTransaction) => {
    if (await updateStatus(tx, 'REJECTED', `${rejectReason} ${rejectNote}`.trim())) {
      setRejectModalTx(null); setRejectNote('');
    }
  };

  const handleCreateManualTx = async () => {
    const amount = Number(newTxAmount);
    if (!allUsers.some(user => user.id === newTxUserId && user.role === newTxUserRole) || !Number.isSafeInteger(amount) || amount <= 0) {
      onNotify?.('Chọn người dùng và nhập số tiền hợp lệ.'); return;
    }
    if (createSaving) return;
    const requestId = manualRequestId || crypto.randomUUID();
    setManualRequestId(requestId);
    setCreateSaving(true);
    try {
      const response = await fetch('/api/admin/partner-wallet-transactions', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'CREATE', requestId, userId: newTxUserId, userRole: newTxUserRole, type: newTxType, amount, method: newTxMethod, bankName: newTxBankName, accountName: newTxAccountName, accountNumber: newTxBankAccount, note: newTxNote }),
      });
      const result = await response.json();
      if (!response.ok || !result.success) {
        if (response.status >= 400 && response.status < 500) setManualRequestId(null);
        throw new Error(typeof result.error === 'string' ? result.error : 'Không thể tạo giao dịch');
      }
      await loadTransactions(); setCreateModalOpen(false); setManualRequestId(null);
      onNotify?.(newTxType === 'DEPOSIT' ? 'Đã nạp tiền và lưu giao dịch.' : 'Đã tạo yêu cầu rút tiền chờ duyệt.');
    } catch (error) { onNotify?.(error instanceof Error ? error.message : 'Không thể tạo giao dịch'); }
    finally { setCreateSaving(false); }
  };

  const handleSaveConfig = async () => {
    if (configSaving) return;
    setConfigSaving(true);
    try {
      const response = await fetch('/api/admin/wallet-config', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(config) });
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(typeof result.error === 'string' ? result.error : 'Không thể lưu cấu hình');
      setConfig(result.data); onNotify?.('Đã lưu cấu hình nạp/rút tiền.');
    } catch (error) { onNotify?.(error instanceof Error ? error.message : 'Không thể lưu cấu hình'); }
    finally { setConfigSaving(false); }
  };

  // ACTION: Export CSV
  const handleExportCsv = () => {
    const headers = ['Mã GD', 'Loại', 'Nghiệp vụ', 'Người thực hiện', 'Vai trò', 'Số điện thoại', 'Số tiền (VNĐ)', 'Phí (VNĐ)', 'Tiền nhận (VNĐ)', 'Phương thức', 'Ngân hàng', 'Số tài khoản', 'Chủ tài khoản', 'Trạng thái', 'Mã tham chiếu', 'Thời gian tạo', 'Ghi chú'];
    const rows = filteredTransactions.map(t => [
      t.id,
      t.type === 'DEPOSIT' ? 'Nạp tiền' : 'Rút tiền',
      t.category,
      t.userName,
      t.userRole === 'CUSTOMER' ? 'Khách hàng' : 'Đối tác',
      t.userPhone,
      t.amount,
      t.fee || 0,
      t.amount - (t.fee || 0),
      t.method,
      t.bankName || '',
      t.accountNumber || '',
      t.accountName || '',
      t.status,
      t.refCode || '',
      formatDate(t.createdAt),
      t.note || '',
    ]);

    const csvContent =
      '\uFEFF' +
      [headers, ...rows]
        .map(row => row.map(val => `"${String(val).replace(/"/g, '""')}"`).join(','))
        .join('\r\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `TaskLy_Nap_Rut_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    onNotify?.('Đã xuất báo cáo CSV thành công.');
  };

  // Copy helper
  const copyText = (txt: string, label: string) => {
    navigator.clipboard.writeText(txt);
    onNotify?.(`Đã sao chép ${label}: ${txt}`);
  };

  return (
    <div className="dwa-container">
      <h2>Nạp &amp; Rút tiền — {role === 'PARTNER' ? 'Partner' : 'Customer'}</h2>
      {loadError && <div role="alert" className="notice">
        {loadError} <button className="btn btn-outline" onClick={() => void loadTransactions()}>Tải lại dữ liệu</button>
      </div>}
      {/* 1. EXECUTIVE FINANCIAL SUMMARY CARDS */}
      <div className="dwa-kpi-grid">
        <div
          className={`dwa-kpi-card ${activeTab === 'DEPOSIT' ? 'active' : ''}`}
          onClick={() => {
            setActiveTab('DEPOSIT');
            setStatusFilter('ALL');
          }}
        >
          <div className="dwa-kpi-header">
            <span className="dwa-kpi-title">Tổng tiền nạp vào</span>
            <div className="dwa-kpi-icon green">
              <ArrowDownLeft size={20} />
            </div>
          </div>
          <div className="dwa-kpi-value">{formatVnd(stats.totalDeposits)}</div>
          <div className="dwa-kpi-sub">
            <span className="dwa-kpi-badge success">
              <TrendingUp size={12} style={{ marginRight: 3 }} /> Thành công
            </span>
            <span>{stats.depositCount} giao dịch nạp</span>
          </div>
        </div>

        <div
          className={`dwa-kpi-card ${activeTab === 'WITHDRAWAL' ? 'active' : ''}`}
          onClick={() => {
            setActiveTab('WITHDRAWAL');
            setStatusFilter('ALL');
          }}
        >
          <div className="dwa-kpi-header">
            <span className="dwa-kpi-title">Tổng tiền rút đã chi</span>
            <div className="dwa-kpi-icon blue">
              <ArrowUpRight size={20} />
            </div>
          </div>
          <div className="dwa-kpi-value">{formatVnd(stats.totalWithdrawals)}</div>
          <div className="dwa-kpi-sub">
            <span>Đã giải ngân cho Đối tác & Khách hàng</span>
          </div>
        </div>

        <div
          className="dwa-kpi-card"
          style={{ background: stats.pendingCount > 0 ? '#FFFBEB' : '#FFFFFF', borderColor: stats.pendingCount > 0 ? '#FDE68A' : '#E2E8F0' }}
          onClick={() => {
            setActiveTab('WITHDRAWAL');
            setStatusFilter('PENDING');
          }}
        >
          <div className="dwa-kpi-header">
            <span className="dwa-kpi-title" style={{ color: stats.pendingCount > 0 ? '#B45309' : '#64748B' }}>
              Yêu cầu rút chờ duyệt
            </span>
            <div className="dwa-kpi-icon amber">
              <Clock size={20} />
            </div>
          </div>
          <div className="dwa-kpi-value" style={{ color: stats.pendingCount > 0 ? '#D97706' : '#0F172A' }}>
            {stats.pendingCount} lệnh
          </div>
          <div className="dwa-kpi-sub">
            {stats.pendingCount > 0 ? (
              <span className="dwa-kpi-badge alert">Cần xử lý: {formatVnd(stats.pendingWithdrawAmount)}</span>
            ) : (
              <span className="dwa-kpi-badge success">Tất cả đã được giải ngân</span>
            )}
          </div>
        </div>

        <div className="dwa-kpi-card">
          <div className="dwa-kpi-header">
            <span className="dwa-kpi-title">Số dư ký quỹ & Escrow</span>
            <div className="dwa-kpi-icon purple">
              <ShieldCheck size={20} />
            </div>
          </div>
          <div className="dwa-kpi-value">{formatVnd(stats.activeEscrow)}</div>
          <div className="dwa-kpi-sub">
            <span>Tiền cọc giữ cho các đơn hàng đang làm</span>
          </div>
        </div>
      </div>

      {/* 2. NAVIGATION BAR & TAB BUTTONS */}
      <div className="dwa-nav-bar">
        <div className="dwa-tabs">
          <button
            className={`dwa-tab-btn ${activeTab === 'ALL' ? 'active' : ''}`}
            onClick={() => setActiveTab('ALL')}
          >
            <Layers size={17} />
            <span>Tất cả giao dịch</span>
            <span className="dwa-tab-count">{stats.totalTxCount}</span>
          </button>

          <button
            className={`dwa-tab-btn ${activeTab === 'DEPOSIT' ? 'active' : ''}`}
            onClick={() => setActiveTab('DEPOSIT')}
          >
            <ArrowDownLeft size={17} color="#059669" />
            <span>Quản lý Nạp tiền</span>
            <span className="dwa-tab-count">{stats.depositCount}</span>
          </button>

          <button
            className={`dwa-tab-btn ${activeTab === 'WITHDRAWAL' ? 'active' : ''}`}
            onClick={() => setActiveTab('WITHDRAWAL')}
          >
            <ArrowUpRight size={17} color="#2563EB" />
            <span>Quản lý Rút tiền</span>
            {stats.pendingCount > 0 && <span className="dwa-tab-count alert">{stats.pendingCount} chờ duyệt</span>}
          </button>

          <button
            className={`dwa-tab-btn ${activeTab === 'CONFIG' ? 'active' : ''}`}
            onClick={() => setActiveTab('CONFIG')}
          >
            <Settings2 size={17} />
            <span>Cấu hình & Hạn mức</span>
          </button>
        </div>

        <div className="dwa-filter-group">
          <button className="dwa-btn dwa-btn-outline" onClick={loadTransactions} disabled={loading} title="Làm mới dữ liệu">
            <RefreshCw size={15} className={loading ? 'animate-spin' : ''} />
            <span>Làm mới</span>
          </button>
          <button className="dwa-btn dwa-btn-outline" onClick={handleExportCsv} title="Tải file Excel/CSV">
            <Download size={15} />
            <span>Xuất CSV</span>
          </button>
          <button className="dwa-btn dwa-btn-primary" onClick={() => { setManualRequestId(null); setCreateModalOpen(true); }}>
            <Plus size={16} />
            <span>Tạo lệnh Nạp / Rút</span>
          </button>
        </div>
      </div>

      {/* 3. TAB CONTENT: CONFIGURATION VIEW */}
      {activeTab === 'CONFIG' ? (
        <div className="dwa-config-grid">
          <div className="dwa-card">
            <div className="dwa-card-header">
              <SlidersHorizontal size={20} color="#2563EB" />
              <h3>Hạn mức giao dịch Nạp & Rút</h3>
            </div>

            <div className="dwa-form-row">
              <label>Số tiền nạp tối thiểu (VNĐ)</label>
              <input
                type="number"
                value={config.minDeposit}
                onChange={e => setConfig({ ...config, minDeposit: Number(e.target.value) })}
              />
              <span className="dwa-hint">Mặc định: 50.000 đ</span>
            </div>

            <div className="dwa-form-row">
              <label>Số tiền nạp tối đa mỗi lần (VNĐ)</label>
              <input
                type="number"
                value={config.maxDeposit}
                onChange={e => setConfig({ ...config, maxDeposit: Number(e.target.value) })}
              />
              <span className="dwa-hint">Mặc định: 50.000.000 đ</span>
            </div>

            <div className="dwa-form-row">
              <label>Số tiền rút tối thiểu (VNĐ)</label>
              <input
                type="number"
                value={config.minWithdraw}
                onChange={e => setConfig({ ...config, minWithdraw: Number(e.target.value) })}
              />
              <span className="dwa-hint">Mặc định: 100.000 đ</span>
            </div>

            <div className="dwa-form-row">
              <label>Hạn mức rút tối đa trong ngày (VNĐ)</label>
              <input
                type="number"
                value={config.maxWithdrawDaily}
                onChange={e => setConfig({ ...config, maxWithdrawDaily: Number(e.target.value) })}
              />
              <span className="dwa-hint">Mặc định: 20.000.000 đ</span>
            </div>

            <div className="dwa-form-row">
              <label>Phí rút tiền (%)</label>
              <input
                type="number"
                value={config.withdrawFeePercent}
                onChange={e => setConfig({ ...config, withdrawFeePercent: Number(e.target.value) })}
              />
              <span className="dwa-hint">Nhập 0 nếu miễn phí rút tiền</span>
            </div>

            <button className="dwa-btn dwa-btn-primary" style={{ marginTop: 12 }} disabled={configSaving} onClick={handleSaveConfig}>
              <Check size={16} /> Lưu cài đặt hạn mức
            </button>
          </div>

          <div className="dwa-card">
            <div className="dwa-card-header">
              <Building2 size={20} color="#059669" />
              <h3>Tài khoản ngân hàng thụ hưởng nhận nạp</h3>
            </div>

            <div className="dwa-form-row">
              <label>Tên ngân hàng & Chi nhánh</label>
              <input
                type="text"
                value={config.bankName}
                onChange={e => setConfig({ ...config, bankName: e.target.value })}
              />
            </div>

            <div className="dwa-form-row">
              <label>Số tài khoản thụ hưởng TaskLy</label>
              <input
                type="text"
                value={config.bankAccount}
                onChange={e => setConfig({ ...config, bankAccount: e.target.value })}
              />
            </div>

            <div className="dwa-form-row">
              <label>Tên chủ tài khoản (In hoa)</label>
              <input
                type="text"
                value={config.accountOwner}
                onChange={e => setConfig({ ...config, accountOwner: e.target.value })}
              />
            </div>

            <div className="dwa-form-row">
              <label>Tiền tố nội dung nạp (Cú pháp tự động)</label>
              <input
                type="text"
                value={config.qrPrefix}
                onChange={e => setConfig({ ...config, qrPrefix: e.target.value })}
              />
              <span className="dwa-hint">Ví dụ: TASKLY NAP [MÃ_USER]</span>
            </div>

            <div className="dwa-vietqr-preview">
              <div className="dwa-qr-box">
                <QrCode size={100} color="#0f172a" />
              </div>
              <b>Thông tin tài khoản nhận nạp</b>
              <small style={{ color: '#64748b', marginTop: 4 }}>
                Số tài khoản nhận nạp: {config.bankAccount} và nội dung nạp tiền
              </small>
            </div>

            <button className="dwa-btn dwa-btn-success" style={{ marginTop: 16 }} disabled={configSaving} onClick={handleSaveConfig}>
              <Check size={16} /> Cập nhật tài khoản thụ hưởng
            </button>
          </div>
        </div>
      ) : (
        /* 4. TRANSACTION LIST VIEW (ALL / DEPOSIT / WITHDRAWAL) */
        <>
          {/* TOOLBAR */}
          <div className="dwa-toolbar">
            <div className="dwa-search-box">
              <Search size={18} color="#64748b" />
              <input
                type="text"
                placeholder="Tìm mã GD, tên người dùng, SĐT, số tài khoản, mã tham chiếu..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
              />
              {searchQuery && (
                <button
                  style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: '#94a3b8' }}
                  onClick={() => setSearchQuery('')}
                >
                  <X size={16} />
                </button>
              )}
            </div>

            <div className="dwa-filter-group">
              <select className="dwa-select" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
                <option value="ALL">Tất cả trạng thái</option>
                <option value="PENDING">Chờ duyệt (PENDING)</option>
                <option value="APPROVED">Đã duyệt • Chờ chuyển tiền</option>
                <option value="PAID">Đã chuyển tiền</option>
                <option value="COMPLETED">Thành công (COMPLETED)</option>
                <option value="REJECTED">Từ chối (REJECTED)</option>
              </select>

              <span>{role === 'PARTNER' ? 'Đối tác Partner' : 'Khách hàng Customer'}</span>
            </div>
          </div>

          {/* TABLE SECTION */}
          <div className="dwa-table-panel">
            <div className="dwa-table-responsive">
              <table className="dwa-table">
                <thead>
                  <tr>
                    <th>Mã & Nghiệp vụ</th>
                    <th>Người thực hiện</th>
                    <th>Số tiền</th>
                    <th>Kênh / Ngân hàng</th>
                    <th>Thời gian</th>
                    <th>Trạng thái</th>
                    <th style={{ textAlign: 'right' }}>Thao tác</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredTransactions.map(tx => {
                    const isDeposit = tx.type === 'DEPOSIT';
                    return (
                      <tr key={tx.id}>
                        {/* 1. Mã & Loại */}
                        <td>
                          <div className="dwa-cell-id">
                            <div className={`dwa-type-badge ${isDeposit ? 'deposit' : 'withdrawal'}`}>
                              {isDeposit ? <ArrowDownLeft size={17} /> : <ArrowUpRight size={17} />}
                            </div>
                            <div className="dwa-id-meta">
                              <span className="dwa-id-text">{tx.id}</span>
                              <span className="dwa-id-type">
                                {tx.category === 'CUSTOMER_TOPUP'
                                  ? 'Nạp ví khách hàng'
                                  : tx.category === 'PARTNER_DEPOSIT'
                                  ? 'Ký quỹ đối tác'
                                  : tx.category === 'BOOKING_ESCROW'
                                  ? 'Cọc giữ tiền đơn hàng'
                                  : tx.category === 'PARTNER_PAYOUT'
                                  ? 'Rút thu nhập Tasker'
                                  : 'Rút số dư hoàn tiền'}
                              </span>
                            </div>
                          </div>
                        </td>

                        {/* 2. Người thực hiện */}
                        <td>
                          <div className="dwa-cell-user">
                            <div className="dwa-user-avatar">
                              {tx.userName.slice(0, 1).toUpperCase()}
                            </div>
                            <div className="dwa-user-info">
                              <span className="dwa-user-name">
                                {tx.userName}
                                <span className={`dwa-role-tag ${tx.userRole === 'CUSTOMER' ? 'customer' : 'partner'}`}>
                                  {tx.userRole === 'CUSTOMER' ? 'Customer' : 'Partner'}
                                </span>
                              </span>
                              <span className="dwa-user-sub">{tx.userPhone}</span>
                            </div>
                          </div>
                        </td>

                        {/* 3. Số tiền */}
                        <td>
                          <span className={`dwa-amount ${isDeposit ? 'positive' : 'negative'}`}>
                            {isDeposit ? `+ ${formatVnd(tx.amount)}` : `- ${formatVnd(tx.amount)}`}
                          </span>
                        </td>

                        {/* 4. Ngân hàng / Kênh */}
                        <td>
                          <div className="dwa-bank-info">
                            <span className="dwa-bank-name">{tx.bankName || tx.method}</span>
                            {tx.accountNumber && (
                              <span className="dwa-bank-account">{tx.accountNumber}</span>
                            )}
                            {tx.accountName && (
                              <span className="dwa-bank-owner">{tx.accountName}</span>
                            )}
                          </div>
                        </td>

                        {/* 5. Thời gian */}
                        <td>
                          <span style={{ fontSize: 12, color: '#475569' }}>
                            {formatDate(tx.createdAt)}
                          </span>
                        </td>

                        {/* 6. Trạng thái */}
                        <td>
                          <span
                            className={`dwa-status ${
                              ['PENDING', 'APPROVED'].includes(tx.status)
                                ? 'pending'
                                : tx.status === 'COMPLETED' || tx.status === 'PAID'
                                ? 'completed'
                                : 'rejected'
                            }`}
                          >
                            {tx.status === 'PENDING' && <Clock size={12} />}
                            {tx.status === 'COMPLETED' || tx.status === 'PAID' ? <CheckCircle2 size={12} /> : null}
                            {tx.status === 'REJECTED' || tx.status === 'FAILED' ? <XCircle size={12} /> : null}
                            {tx.status === 'PAID' ? 'Đã chuyển tiền' : tx.status === 'APPROVED' ? 'Đã duyệt • Chờ chuyển tiền' : tx.status === 'PENDING'
                              ? (tx.type === 'DEPOSIT' ? 'Chờ xác nhận nhận tiền' : 'Chờ duyệt chi')
                              : tx.status === 'COMPLETED'
                              ? 'Thành công'
                              : 'Đã từ chối'}
                          </span>
                        </td>

                        {/* 7. Thao tác */}
                        <td>
                          <div className="dwa-actions-cell" style={{ justifyContent: 'flex-end' }}>
                            {tx.source === 'PARTNER_WALLET' && tx.status === 'PENDING' && <><button disabled={saving} className="dwa-btn dwa-btn-success dwa-btn-sm" onClick={() => void updateStatus(tx, 'APPROVED')}>{tx.type === 'DEPOSIT' ? 'Xác nhận đã nhận tiền' : 'Duyệt yêu cầu'}</button><button disabled={saving} className="dwa-btn dwa-btn-danger dwa-btn-sm" onClick={() => setRejectModalTx(tx)}>Từ chối</button></>}
                            {tx.source === 'PARTNER_WALLET' && tx.status === 'APPROVED' && <><button disabled={saving} className="dwa-btn dwa-btn-success dwa-btn-sm" onClick={() => { setApprovalModalTx(tx); setApprovalRefCode(''); }}>Xác nhận đã chuyển tiền</button><button disabled={saving} className="dwa-btn dwa-btn-danger dwa-btn-sm" onClick={() => setRejectModalTx(tx)}>Từ chối</button></>}
                            {tx.source !== 'PARTNER_WALLET' && tx.type === 'WITHDRAWAL' && tx.status === 'PENDING' ? (
                              <>
                                <button
                                  className="dwa-btn dwa-btn-success dwa-btn-sm"
                                  onClick={() => {
                                    setApprovalModalTx(tx);
                                    setApprovalRefCode(`FT${Date.now().toString().slice(-8)}`);
                                  }}
                                  title="Duyệt chi & Chuyển khoản"
                                >
                                  <Check size={14} /> Duyệt chi
                                </button>
                                <button
                                  className="dwa-btn dwa-btn-danger dwa-btn-sm"
                                  onClick={() => setRejectModalTx(tx)}
                                  title="Từ chối yêu cầu rút"
                                >
                                  <X size={14} /> Từ chối
                                </button>
                              </>
                            ) : null}

                            <button
                              className="dwa-btn dwa-btn-outline dwa-btn-sm"
                              onClick={() => setSelectedTx(tx)}
                              title="Xem chi tiết phiếu giao dịch"
                            >
                              <Eye size={14} /> Chi tiết
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}

                  {filteredTransactions.length === 0 && (
                    <tr>
                      <td colSpan={7}>
                        <div className="dwa-empty-state">
                          <div className="dwa-empty-icon">
                            <Search size={24} />
                          </div>
                          <b style={{ color: '#0F172A', fontSize: 15 }}>Không tìm thấy giao dịch phù hợp</b>
                          <p style={{ margin: 0, fontSize: 13 }}>
                            Hãy thử đổi từ khóa tìm kiếm hoặc làm mới bộ lọc trạng thái.
                          </p>
                        </div>
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            <div className="dwa-table-footer">
              <span>
                Hiển thị <b>{filteredTransactions.length}</b> / {transactions.length} giao dịch
              </span>
              <span>Hệ thống đối soát tài chính TaskLy Hub 24/7</span>
            </div>
          </div>
        </>
      )}

      {/* =========================================================================
          MODAL 1: ELECTRONIC TRANSACTION RECEIPT (CHI TIẾT PHIẾU THU / CHI)
          ========================================================================= */}
      {selectedTx && (
        <div className="dwa-modal-backdrop" onClick={() => setSelectedTx(null)}>
          <div className="dwa-modal" onClick={e => e.stopPropagation()}>
            <div className="dwa-modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div
                  className={`dwa-type-badge ${selectedTx.type === 'DEPOSIT' ? 'deposit' : 'withdrawal'}`}
                  style={{ width: 36, height: 36 }}
                >
                  {selectedTx.type === 'DEPOSIT' ? <ArrowDownLeft size={20} /> : <ArrowUpRight size={20} />}
                </div>
                <div>
                  <h2 style={{ fontSize: 17 }}>
                    {selectedTx.type === 'DEPOSIT' ? 'PHIẾU THU TIỀN ĐIỆN TỬ' : 'PHIẾU CHI TIỀN ĐIỆN TỬ'}
                  </h2>
                  <small style={{ color: '#64748b' }}>Mã tham chiếu: {selectedTx.id}</small>
                </div>
              </div>
              <button
                style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: '#64748b' }}
                onClick={() => setSelectedTx(null)}
              >
                <X size={20} />
              </button>
            </div>

            <div className="dwa-modal-body">
              {/* BIG AMOUNT HEADER */}
              <div
                style={{
                  textAlign: 'center',
                  padding: '20px',
                  background: selectedTx.type === 'DEPOSIT' ? '#ECFDF5' : '#EFF6FF',
                  borderRadius: 14,
                  border: `1px solid ${selectedTx.type === 'DEPOSIT' ? '#A7F3D0' : '#BFDBFE'}`,
                }}
              >
                <small style={{ color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>
                  Số tiền giao dịch
                </small>
                <div
                  style={{
                    fontSize: 28,
                    fontWeight: 900,
                    color: selectedTx.type === 'DEPOSIT' ? '#059669' : '#2563EB',
                    marginTop: 4,
                  }}
                >
                  {formatVnd(selectedTx.amount)}
                </div>
                {selectedTx.type === 'WITHDRAWAL' && <div>Phí: {formatVnd(selectedTx.fee || 0)} • Tiền chuyển: {formatVnd(selectedTx.amount - (selectedTx.fee || 0))}</div>}
                <div style={{ marginTop: 8 }}>
                  <span
                    className={`dwa-status ${
                      ['PENDING', 'APPROVED'].includes(selectedTx.status)
                        ? 'pending'
                        : selectedTx.status === 'COMPLETED' || selectedTx.status === 'PAID'
                        ? 'completed'
                        : 'rejected'
                    }`}
                  >
                    {selectedTx.status === 'PAID' ? 'Đã chuyển tiền' : selectedTx.status === 'APPROVED' ? 'Đã duyệt • Chờ chuyển tiền' : selectedTx.status === 'PENDING'
                      ? 'Chờ duyệt chi'
                      : selectedTx.status === 'COMPLETED'
                      ? 'Giao dịch thành công'
                      : 'Giao dịch bị từ chối'}
                  </span>
                </div>
              </div>

              {/* RECEIPT DETAILS */}
              <div className="dwa-receipt-box">
                <div className="dwa-receipt-row">
                  <span className="dwa-receipt-label">Loại giao dịch</span>
                  <span className="dwa-receipt-value">
                    {selectedTx.category === 'CUSTOMER_TOPUP'
                      ? 'Nạp tiền ví khách hàng'
                      : selectedTx.category === 'PARTNER_DEPOSIT'
                      ? 'Nạp tiền ký quỹ đối tác'
                      : selectedTx.category === 'BOOKING_ESCROW'
                      ? 'Tiền đặt cọc đơn hàng'
                      : selectedTx.category === 'PARTNER_PAYOUT'
                      ? 'Rút tiền thu nhập đối tác'
                      : 'Rút số dư hoàn tiền khách hàng'}
                  </span>
                </div>

                <div className="dwa-receipt-row">
                  <span className="dwa-receipt-label">Người thực hiện</span>
                  <span className="dwa-receipt-value">
                    {selectedTx.userName} ({selectedTx.userRole})
                  </span>
                </div>

                <div className="dwa-receipt-row">
                  <span className="dwa-receipt-label">Số điện thoại</span>
                  <span className="dwa-receipt-value">{selectedTx.userPhone}</span>
                </div>

                {selectedTx.bankName && (
                  <>
                    <div className="dwa-receipt-row">
                      <span className="dwa-receipt-label">Ngân hàng thụ hưởng</span>
                      <span className="dwa-receipt-value">{selectedTx.bankName}</span>
                    </div>

                    <div className="dwa-receipt-row">
                      <span className="dwa-receipt-label">Số tài khoản</span>
                      <span className="dwa-receipt-value">
                        {selectedTx.accountNumber}{' '}
                        <button
                          className="dwa-copy-btn"
                          title="Sao chép STK"
                          onClick={() => copyText(selectedTx.accountNumber || '', 'Số tài khoản')}
                        >
                          <Copy size={13} />
                        </button>
                      </span>
                    </div>

                    <div className="dwa-receipt-row">
                      <span className="dwa-receipt-label">Tên chủ tài khoản</span>
                      <span className="dwa-receipt-value">{selectedTx.accountName || selectedTx.userName}</span>
                    </div>
                  </>
                )}

                <div className="dwa-receipt-row">
                  <span className="dwa-receipt-label">Phương thức thanh toán</span>
                  <span className="dwa-receipt-value">{selectedTx.method}</span>
                </div>

                {selectedTx.refCode && (
                  <div className="dwa-receipt-row">
                    <span className="dwa-receipt-label">Mã giao dịch ngân hàng</span>
                    <span className="dwa-receipt-value">
                      {selectedTx.refCode}{' '}
                      <button
                        className="dwa-copy-btn"
                        title="Sao chép mã"
                        onClick={() => copyText(selectedTx.refCode || '', 'Mã tham chiếu')}
                      >
                        <Copy size={13} />
                      </button>
                    </span>
                  </div>
                )}

                <div className="dwa-receipt-row">
                  <span className="dwa-receipt-label">Thời gian tạo</span>
                  <span className="dwa-receipt-value">{formatDate(selectedTx.createdAt)}</span>
                </div>

                {selectedTx.completedAt && (
                  <div className="dwa-receipt-row">
                    <span className="dwa-receipt-label">Thời gian hoàn tất</span>
                    <span className="dwa-receipt-value">{formatDate(selectedTx.completedAt)}</span>
                  </div>
                )}

                {selectedTx.note && (
                  <div style={{ marginTop: 4, paddingTop: 8, borderTop: '1px dashed #e2e8f0', fontSize: 12.5 }}>
                    <span style={{ color: '#64748b' }}>Ghi chú:</span>
                    <p style={{ margin: '4px 0 0', color: '#1e293b', fontStyle: 'italic' }}>{selectedTx.note}</p>
                  </div>
                )}
              </div>
            </div>

            <div className="dwa-modal-footer">
              {selectedTx.source !== 'PARTNER_WALLET' && selectedTx.type === 'WITHDRAWAL' && selectedTx.status === 'PENDING' && (
                <>
                  <button
                    className="dwa-btn dwa-btn-danger"
                    onClick={() => {
                      setRejectModalTx(selectedTx);
                      setSelectedTx(null);
                    }}
                  >
                    <X size={15} /> Từ chối
                  </button>
                  <button
                    className="dwa-btn dwa-btn-success"
                    onClick={() => {
                      setApprovalModalTx(selectedTx);
                      setApprovalRefCode(`FT${Date.now().toString().slice(-8)}`);
                      setSelectedTx(null);
                    }}
                  >
                    <Check size={15} /> Phê duyệt & Chi tiền
                  </button>
                </>
              )}
              <button className="dwa-btn dwa-btn-outline" onClick={() => setSelectedTx(null)}>
                Đóng
              </button>
            </div>
          </div>
        </div>
      )}

      {/* =========================================================================
          MODAL 2: PHÊ DUYỆT RÚT TIỀN (APPROVAL CONFIRMATION)
          ========================================================================= */}
      {approvalModalTx && (
        <div className="dwa-modal-backdrop" onClick={() => setApprovalModalTx(null)}>
          <div className="dwa-modal" onClick={e => e.stopPropagation()}>
            <div className="dwa-modal-header">
              <h2 style={{ fontSize: 17, display: 'flex', alignItems: 'center', gap: 8, color: '#047857' }}>
                <CheckCircle2 size={20} color="#059669" /> Xác nhận phê duyệt & Giải ngân
              </h2>
              <button
                style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: '#64748b' }}
                onClick={() => setApprovalModalTx(null)}
              >
                <X size={20} />
              </button>
            </div>

            <div className="dwa-modal-body">
              <div style={{ background: '#F8FAFC', border: '1px solid #E2E8F0', borderRadius: 12, padding: 14 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                  <span style={{ color: '#64748B' }}>Người thụ hưởng:</span>
                  <b>{approvalModalTx.userName} ({approvalModalTx.userRole})</b>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                  <span style={{ color: '#64748B' }}>Ngân hàng & STK:</span>
                  <b>{approvalModalTx.bankName} - {approvalModalTx.accountNumber}</b>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: '#64748B' }}>Số tiền chuyển khoản:</span>
                  <b style={{ color: '#2563EB', fontSize: 16 }}>{formatVnd(approvalModalTx.amount - (approvalModalTx.fee || 0))} (phí {formatVnd(approvalModalTx.fee || 0)})</b>
                </div>
              </div>

              <div className="dwa-form-row">
                <label>Mã tham chiếu ngân hàng / Ủy nhiệm chi (FT Code)</label>
                <input
                  type="text"
                  placeholder="Ví dụ: FT26101388912..."
                  value={approvalRefCode}
                  onChange={e => setApprovalRefCode(e.target.value)}
                />
                <span className="dwa-hint">Mã xác nhận chuyển khoản thực tế từ App ngân hàng</span>
              </div>

              <div className="dwa-form-row">
                <label>Ghi chú xét duyệt (Không bắt buộc)</label>
                <input
                  type="text"
                  placeholder="Ghi chú đối soát hoặc nhân viên duyệt..."
                  value={approvalNote}
                  onChange={e => setApprovalNote(e.target.value)}
                />
              </div>
            </div>

            <div className="dwa-modal-footer">
              <button className="dwa-btn dwa-btn-outline" onClick={() => setApprovalModalTx(null)}>
                Hủy bỏ
              </button>
              <button
                className="dwa-btn dwa-btn-success"
                disabled={saving}
                onClick={() => handleApproveWithdrawal(approvalModalTx)}
              >
                <Check size={16} /> Xác nhận đã chuyển khoản
              </button>
            </div>
          </div>
        </div>
      )}

      {/* =========================================================================
          MODAL 3: TỪ CHỐI RÚT TIỀN (REJECT CONFIRMATION)
          ========================================================================= */}
      {rejectModalTx && (
        <div className="dwa-modal-backdrop" onClick={() => setRejectModalTx(null)}>
          <div className="dwa-modal" onClick={e => e.stopPropagation()}>
            <div className="dwa-modal-header">
              <h2 style={{ fontSize: 17, display: 'flex', alignItems: 'center', gap: 8, color: '#DC2626' }}>
                <AlertTriangle size={20} color="#DC2626" /> Từ chối yêu cầu rút tiền
              </h2>
              <button
                style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: '#64748b' }}
                onClick={() => setRejectModalTx(null)}
              >
                <X size={20} />
              </button>
            </div>

            <div className="dwa-modal-body">
              <p style={{ margin: 0, fontSize: 13.5, color: '#475569', lineHeight: 1.5 }}>
                Bạn đang từ chối yêu cầu rút số tiền <b>{formatVnd(rejectModalTx.amount)}</b> của{' '}
                <b>{rejectModalTx.userName}</b>. Số tiền này sẽ được hoàn trả lại vào số dư ví của người dùng.
              </p>

              <div className="dwa-form-row">
                <label>Lý do từ chối chính</label>
                <select value={rejectReason} onChange={e => setRejectReason(e.target.value)}>
                  <option value="Thông tin tài khoản ngân hàng không khớp">Thông tin tài khoản ngân hàng không khớp</option>
                  <option value="Số tài khoản không chính chủ theo CCCD">Số tài khoản không chính chủ theo CCCD</option>
                  <option value="Chưa đạt hạn mức tối thiểu cho phép rút">Chưa đạt hạn mức tối thiểu cho phép rút</option>
                  <option value="Tài khoản đang bị tạm ngưng để kiểm tra">Tài khoản đang bị tạm ngưng để kiểm tra</option>
                  <option value="Khác">Lý do khác...</option>
                </select>
              </div>

              <div className="dwa-form-row">
                <label>Ghi chú chi tiết cho người dùng</label>
                <textarea
                  rows={3}
                  placeholder="Ghi rõ lý do để người dùng biết và cập nhật lại thông tin..."
                  value={rejectNote}
                  onChange={e => setRejectNote(e.target.value)}
                />
              </div>
            </div>

            <div className="dwa-modal-footer">
              <button className="dwa-btn dwa-btn-outline" onClick={() => setRejectModalTx(null)}>
                Hủy bỏ
              </button>
              <button
                className="dwa-btn dwa-btn-danger"
                onClick={() => handleRejectWithdrawal(rejectModalTx)}
              >
                <X size={16} /> Xác nhận từ chối
              </button>
            </div>
          </div>
        </div>
      )}

      {/* =========================================================================
          MODAL 4: TẠO GIAO DỊCH NẠP / RÚT THỦ CÔNG (CREATE MANUAL TRANSACTION)
          ========================================================================= */}
      {createModalOpen && (
        <div className="dwa-modal-backdrop" onClick={() => setCreateModalOpen(false)}>
          <div className="dwa-modal" onClick={e => e.stopPropagation()}>
            <div className="dwa-modal-header">
              <h2 style={{ fontSize: 17, display: 'flex', alignItems: 'center', gap: 8 }}>
                <Plus size={20} color="#2563EB" /> Tạo lệnh Nạp / Rút thủ công
              </h2>
              <button
                style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: '#64748b' }}
                onClick={() => setCreateModalOpen(false)}
              >
                <X size={20} />
              </button>
            </div>

            <div className="dwa-modal-body">
              {/* Type Switch */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                <button
                  type="button"
                  className={`dwa-btn ${newTxType === 'DEPOSIT' ? 'dwa-btn-success' : 'dwa-btn-outline'}`}
                  style={{ justifyContent: 'center' }}
                  onClick={() => setNewTxType('DEPOSIT')}
                >
                  <ArrowDownLeft size={16} /> Nạp tiền (Cộng ví)
                </button>
                <button
                  type="button"
                  className={`dwa-btn ${newTxType === 'WITHDRAWAL' ? 'dwa-btn-primary' : 'dwa-btn-outline'}`}
                  style={{ justifyContent: 'center' }}
                  onClick={() => setNewTxType('WITHDRAWAL')}
                >
                  <ArrowUpRight size={16} /> Rút tiền (Chờ duyệt)
                </button>
              </div>

              {/* User Selection */}
              <div className="dwa-form-row">
                <label>Đối tượng áp dụng</label>
                <div style={{ display: 'flex', gap: 16 }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 500, cursor: 'pointer' }}>
                    <input
                      type="radio"
                      name="role"
                      checked={newTxUserRole === 'CUSTOMER'}
                      disabled={role !== 'CUSTOMER'}
                      onChange={() => setNewTxUserRole('CUSTOMER')}
                    />
                    Khách hàng (Customer)
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 500, cursor: 'pointer' }}>
                    <input
                      type="radio"
                      name="role"
                      checked={newTxUserRole === 'PARTNER'}
                      disabled={role !== 'PARTNER'}
                      onChange={() => setNewTxUserRole('PARTNER')}
                    />
                    Đối tác (Partner / Tasker)
                  </label>
                </div>
              </div>

              <div className="dwa-form-row">
                <label>Chọn người dùng</label>
                <select value={newTxUserId} onChange={e => setNewTxUserId(e.target.value)}>
                  <option value="">— Chọn người dùng —</option>
                  {allUsers
                    .filter(u => u.role === newTxUserRole)
                    .map(u => (
                      <option key={u.id} value={u.id}>
                        {u.name} • {u.phone} ({u.id})
                      </option>
                    ))}
                </select>
              </div>

              {/* Amount */}
              <div className="dwa-form-row">
                <label>Số tiền giao dịch (VNĐ)</label>
                <input
                  type="number"
                  value={newTxAmount}
                  onChange={e => setNewTxAmount(e.target.value)}
                  placeholder="Nhập số tiền..."
                />
                <div style={{ display: 'flex', gap: 6, marginTop: 6, flexWrap: 'wrap' }}>
                  {['100000', '200000', '500000', '1000000', '2000000'].map(val => (
                    <button
                      key={val}
                      type="button"
                      className="dwa-btn dwa-btn-outline dwa-btn-sm"
                      onClick={() => setNewTxAmount(val)}
                    >
                      {formatVnd(Number(val))}
                    </button>
                  ))}
                </div>
              </div>

              {newTxType === 'WITHDRAWAL' && <>
                <div className="dwa-form-row"><label>Ngân hàng nhận tiền</label><input maxLength={100} value={newTxBankName} onChange={e => setNewTxBankName(e.target.value)} /></div>
                <div className="dwa-form-row"><label>Chủ tài khoản</label><input maxLength={150} value={newTxAccountName} onChange={e => setNewTxAccountName(e.target.value)} /></div>
                <div className="dwa-form-row"><label>Số tài khoản</label><input value={newTxBankAccount} onChange={e => setNewTxBankAccount(e.target.value)} /></div>
              </>}
              {/* Method */}
              <div className="dwa-form-row">
                <label>Phương thức giao dịch</label>
                <select value={newTxMethod} onChange={e => setNewTxMethod(e.target.value)}>
                  <option value="VietQR Chuyển khoản 24/7">VietQR Chuyển khoản 24/7</option>
                  <option value="Cổng VNPay">Cổng VNPay</option>
                  <option value="Ví MoMo">Ví MoMo</option>
                  <option value="Hoàn tiền trực tiếp TaskLy">Hoàn tiền trực tiếp TaskLy</option>
                  <option value="Tiền mặt trực tiếp">Tiền mặt trực tiếp</option>
                </select>
              </div>

              <div className="dwa-form-row">
                <label>Ghi chú / Nội dung giao dịch</label>
                <input
                  type="text"
                  value={newTxNote}
                  onChange={e => setNewTxNote(e.target.value)}
                  placeholder="Nhập lý do tạo lệnh..."
                />
              </div>
            </div>

            <div className="dwa-modal-footer">
              <button className="dwa-btn dwa-btn-outline" onClick={() => setCreateModalOpen(false)}>
                Hủy bỏ
              </button>
              <button className="dwa-btn dwa-btn-primary" disabled={createSaving} onClick={handleCreateManualTx}>
                <Check size={16} /> Tạo giao dịch ngay
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
