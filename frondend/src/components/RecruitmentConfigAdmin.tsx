'use client';

import { useEffect, useMemo, useState } from 'react';
import {
  Shirt, FileText, Calendar, CheckSquare, Gift, Plus,
  Edit3, RefreshCw, AlertCircle, CheckCircle2, Search,
  Eye, EyeOff, Package, Layers, Clock, MapPin,
  ShoppingBag, CreditCard, Building2, Phone, User,
  ChevronLeft, ChevronRight, DollarSign, X, Check, Copy
} from 'lucide-react';
import CataloguePopup from './CataloguePopup';
import RecruitmentSlaAdmin from './RecruitmentSlaAdmin';

type Row = Record<string, any>;

const modules = {
  uniforms: { label: 'Gói đồng phục', icon: Shirt },
  agreements: { label: 'Cam kết & chính sách', icon: FileText },
  'office-slots': { label: 'Lịch văn phòng', icon: Calendar },
  'document-checklist': { label: 'Checklist hồ sơ', icon: CheckSquare },
  benefits: { label: 'Phúc lợi Partner', icon: Gift },
};

const orderStatusLabels: Record<string, { label: string; class: string; icon: any }> = {
  RESERVED: { label: 'Đã đặt / Chờ nhận', class: 'reserved', icon: Package },
  HANDED_OVER: { label: 'Đã bàn giao', class: 'handed-over', icon: CheckCircle2 },
  CANCELLED: { label: 'Đã hủy', class: 'cancelled', icon: X },
  REFUNDED: { label: 'Đã hoàn trả', class: 'refunded', icon: RefreshCw },
};

const paymentStatusLabels: Record<string, { label: string; class: string; icon: any }> = {
  CANCELLED: { label: 'Không cần thanh toán', class: 'cancelled', icon: X },
  PAID: { label: 'Đã thanh toán', class: 'paid', icon: CheckCircle2 },
  PENDING: { label: 'Chờ thanh toán', class: 'pending', icon: Clock },
  WAIVED: { label: 'Miễn phí', class: 'waived', icon: Gift },
  FAILED: { label: 'Thất bại', class: 'failed', icon: AlertCircle },
  REFUNDED: { label: 'Đã hoàn tiền', class: 'refunded', icon: RefreshCw },
};

function effectivePaymentStatus(order: Row): string {
  return ['CANCELLED', 'REFUNDED'].includes(order.status) ? order.status : order.payment_status;
}

async function api(path: string, method = 'GET', body?: unknown) {
  const r = await fetch('/api/admin/recruitment/' + path, {
    method,
    cache: 'no-store',
    signal: AbortSignal.timeout(25000),
    headers: { 'Content-Type': 'application/json' },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const v = await r.json();
  if (!r.ok) throw new Error(v.error || 'Không thể lưu cấu hình tuyển dụng.');
  return v.data;
}

export default function RecruitmentConfigAdmin({ uniformOnly = false }: { uniformOnly?: boolean }) {
  const [module, setModule] = useState<keyof typeof modules>(uniformOnly ? 'uniforms' : 'agreements');
  const [uniformTab, setUniformTab] = useState<'packages' | 'orders'>('packages');
  const [uniformTypeFilter, setUniformTypeFilter] = useState<'ALL' | 'PACKAGE' | 'ITEM'>('ALL');

  const cleanPolicy = (str?: string) => {
    if (!str) return '';
    return str
      .replace(/\s*\[TYPE:(ITEM|PACKAGE)\]/gi, '')
      .replace(/\s*\[LOAI:(LE|GOI)\]/gi, '')
      .trim();
  };

  const isUniformItem = (item: Row) => {
    return (
      item.packageType === 'ITEM' ||
      (typeof item.policy === 'string' && (item.policy.includes('[TYPE:ITEM]') || item.policy.includes('[LOAI:LE]'))) ||
      (typeof item.description === 'string' && (item.description.includes('[TYPE:ITEM]') || item.description.includes('[LOAI:LE]'))) ||
      (Array.isArray(item.items) && item.items.some((it: Row) => it.type === 'ITEM' || it.packageType === 'ITEM'))
    );
  };
  const [items, setItems] = useState<Row[]>([]);
  const [editing, setEditing] = useState<Row | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [orders, setOrders] = useState<Row[]>([]);
  const [portraits, setPortraits] = useState<Record<string, string>>({});
  useEffect(() => {
    let cancelled = false;
    const applicationIds = [...new Set(orders.map(order => String(order.application_id)).filter(id => id && id !== 'undefined'))];
    void Promise.all(applicationIds.map(async id => {
      try {
        const images = await api(`applications/${id}/final-documents`);
        return [id, images[0]?.portrait || ''] as const;
      } catch { return [id, ''] as const; }
    })).then(entries => { if (!cancelled) setPortraits(Object.fromEntries(entries)); });
    return () => { cancelled = true; };
  }, [orders]);
  const [ordersError, setOrdersError] = useState('');
  const [orderSearch, setOrderSearch] = useState('');
  const [orderStatusFilter, setOrderStatusFilter] = useState('');
  const [orderPaymentFilter, setOrderPaymentFilter] = useState('');
  const [orderMethodFilter, setOrderMethodFilter] = useState('');
  const [orderPage, setOrderPage] = useState(0);
  const [orderPageSize, setOrderPageSize] = useState(10);
  const [selectedOrder, setSelectedOrder] = useState<Row | null>(null);
  const [copiedField, setCopiedField] = useState<string | null>(null);

  function copyToClipboard(text: string, fieldName: string) {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      void navigator.clipboard.writeText(text);
      setCopiedField(fieldName);
      setTimeout(() => {
        setCopiedField(prev => (prev === fieldName ? null : prev));
      }, 2000);
    }
  }

  async function load() {
    setBusy(true);
    setError('');
    try {
      const rows: Row[] = await api(module);
      setItems(module === 'uniforms' ? rows.filter(row => !(row.active === false && row.description === 'Cấu hình mẫu; Admin cần xác nhận nội dung gói' && ['Cơ bản DEMO', 'Tiêu chuẩn DEMO', 'Đầy đủ DEMO'].includes(row.name))) : rows);
      if (module === 'uniforms') {
        setOrdersError('');
        try {
          const ords = await api('uniform-orders');
          setOrders(Array.isArray(ords) ? ords : []);
        }
        catch (e) { setOrdersError((e as Error).message); }
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    void load();
  }, [module]);

  useEffect(() => {
    setOrderPage(0);
  }, [orderSearch, orderStatusFilter, orderPaymentFilter, orderMethodFilter, orderPageSize]);

  async function confirmOfficePayment(orderId: string) {
    if (!window.confirm('Xác nhận đã thu tiền mặt tại văn phòng cho đơn hàng này?')) return;
    setBusy(true);
    setError('');
    try {
      await api(`uniform-orders/${orderId}/confirm-office-payment`, 'POST');
      await load();
      if (selectedOrder?.id === orderId) {
        setSelectedOrder(prev => prev ? { ...prev, payment_status: 'PAID' } : null);
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function confirmHandover(orderId: string) {
    if (!window.confirm('Xác nhận đã bàn giao đồng phục cho đối tác?')) return;
    setBusy(true);
    setError('');
    try {
      await api(`uniform-orders/${orderId}/adjust`, 'POST', {
        action: 'HANDOVER',
        originalsReturned: false,
        reason: 'Đã bàn giao đồng phục trực tiếp cho đối tác tại văn phòng.',
        requestId: crypto.randomUUID(),
      });
      await load();
      if (selectedOrder?.id === orderId) {
        setSelectedOrder(prev => prev ? { ...prev, status: 'HANDED_OVER', handed_over_at: new Date().toISOString() } : null);
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  function create() {
    setEditing({
      id: crypto.randomUUID(),
      documentType: 'PARTNER_CONDUCT',
      version: module === 'agreements' ? 'demo-1' : 0,
      contentUrl: '',
      requiresActive: true,
      effectiveAt: new Date().toISOString(),
      name: '',
      description: '',
      price: 0,
      policy: '',
      imageUrl: '',
      items: [],
      active: true,
      packageType: 'PACKAGE',
      sizes: { S: 0, M: 0, L: 0, XL: 0 },
      address: '',
      startsAt: '',
      capacity: 1,
      label: '',
      required: true,
    });
  }

  async function save() {
    if (!editing) return;
    setBusy(true);
    setError('');
    try {
      let body: Row;
      if (module === 'agreements') {
        body = {
          documentType: editing.documentType,
          version: editing.version,
          contentUrl: editing.contentUrl,
          effectiveAt: new Date(editing.effectiveAt).toISOString(),
          active: editing.active,
        };
      } else if (module === 'uniforms') {
        const cleanedPolicy = cleanPolicy(editing.policy);
        const existingItems = editing.items || [];
        const finalItems = existingItems.length > 0
          ? existingItems.map((it: Row) => ({
              ...it,
              type: editing.packageType === 'ITEM' ? 'ITEM' : (it.type || 'PACKAGE'),
            }))
          : (editing.packageType === 'ITEM'
              ? [{ name: editing.name || 'Món lẻ', type: 'ITEM' }]
              : []);

        body = {
          name: editing.name,
          description: editing.description,
          price: Number(editing.price),
          policy: cleanedPolicy,
          active: editing.active,
          version: editing.version,
          sizes: editing.sizes || { S: 0, M: 0, L: 0, XL: 0 },
          imageUrl: editing.imageUrl || null,
          items: finalItems,
        };
      } else if (module === 'office-slots') {
        body = {
          name: editing.name,
          address: editing.address,
          startsAt: new Date(editing.startsAt).toISOString(),
          capacity: Number(editing.capacity),
          active: editing.active,
          version: editing.version,
        };
      } else if (module === 'benefits') {
        body = {
          name: editing.name,
          description: editing.description,
          contentUrl: editing.content_url ?? editing.contentUrl,
          requiresActive: editing.requires_active ?? editing.requiresActive,
          active: editing.active,
          version: editing.version,
        };
      } else {
        body = {
          label: editing.label,
          required: editing.required,
          active: editing.active,
        };
      }

      await api(module + '/' + editing.id, 'PUT', body);
      setEditing(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function toggleActive(item: Row) {
    setBusy(true);
    setError('');
    try {
      const updated = { ...item, active: !item.active };
      await api(module + '/' + item.id, 'PUT', updated);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const uniformTypeCounts = useMemo(() => {
    if (module !== 'uniforms') return { packages: 0, items: 0 };
    let pkgCount = 0;
    let itemCount = 0;
    for (const item of items) {
      if (isUniformItem(item)) itemCount++;
      else pkgCount++;
    }
    return { packages: pkgCount, items: itemCount };
  }, [items, module]);

  const filteredItems = useMemo(() => {
    let list = items;
    if (module === 'uniforms' && uniformTab === 'packages' && uniformTypeFilter !== 'ALL') {
      list = list.filter((item) => {
        const isItem = isUniformItem(item);
        return uniformTypeFilter === 'ITEM' ? isItem : !isItem;
      });
    }
    if (!searchQuery.trim()) return list;
    const q = searchQuery.toLowerCase();
    return list.filter((item) => {
      const name = (item.name || item.label || item.documentType || '').toLowerCase();
      const desc = (item.description || item.policy || item.address || '').toLowerCase();
      return name.includes(q) || desc.includes(q);
    });
  }, [items, searchQuery, module, uniformTab, uniformTypeFilter]);

  // Uniform Stats Calculations
  const totalStockAllSizes = useMemo(() => {
    if (module !== 'uniforms') return 0;
    return items.reduce((total: number, item) => {
      const sizes: Record<string, any> = item.sizes || {};
      const sum = Object.values(sizes).reduce<number>((a, b) => a + (Number(b) || 0), 0);
      return total + sum;
    }, 0);
  }, [items, module]);

  const salesStats = useMemo(() => {
    const totalOrders = orders.length;
    const paidOrders = orders.filter((o) => effectivePaymentStatus(o) === 'PAID');
    const totalRevenue = paidOrders.reduce((sum, o) => sum + (Number(o.price) || 0), 0);
    const pendingOrders = orders.filter((o) => effectivePaymentStatus(o) === 'PENDING');
    const handedOverOrders = orders.filter((o) => o.status === 'HANDED_OVER');
    return {
      totalOrders,
      totalRevenue,
      pendingOrdersCount: pendingOrders.length,
      handedOverCount: handedOverOrders.length,
    };
  }, [orders]);

  const filteredOrders = useMemo(() => {
    return orders.filter((order) => {
      if (orderStatusFilter && order.status !== orderStatusFilter) return false;
      if (orderPaymentFilter && effectivePaymentStatus(order) !== orderPaymentFilter) return false;
      if (orderMethodFilter && order.payment_method !== orderMethodFilter) return false;
      if (orderSearch.trim()) {
        const q = orderSearch.toLowerCase();
        const name = (order.partner_name || '').toLowerCase();
        const phone = (order.contact_phone || '').toLowerCase();
        const pkg = (order.package_name || '').toLowerCase();
        const id = (order.id || '').toLowerCase();
        const size = (order.size || '').toLowerCase();
        if (!name.includes(q) && !phone.includes(q) && !pkg.includes(q) && !id.includes(q) && !size.includes(q)) {
          return false;
        }
      }
      return true;
    });
  }, [orders, orderStatusFilter, orderPaymentFilter, orderMethodFilter, orderSearch]);

  const totalOrderPages = Math.max(1, Math.ceil(filteredOrders.length / orderPageSize));
  const pagedOrders = useMemo(() => {
    const start = orderPage * orderPageSize;
    return filteredOrders.slice(start, start + orderPageSize);
  }, [filteredOrders, orderPage, orderPageSize]);

  function uploadImage(file: File | undefined, index?: number) {
    if (!file) return;
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size > 2 * 1024 * 1024) { setError('Chọn ảnh JPG, PNG hoặc WebP tối đa 2 MB.'); return; }
    const reader = new FileReader();
    reader.onload = () => setEditing(prev => prev ? index === undefined ? { ...prev, imageUrl: String(reader.result) } : { ...prev, items: prev.items.map((item: Row, i: number) => i === index ? { ...item, imageUrl: String(reader.result) } : item) } : prev);
    reader.readAsDataURL(file);
  }
  const field = (key: string, label: string, type = 'text') => {
    const rawVal = editing?.[key] ?? '';
    const displayVal = key === 'policy' ? cleanPolicy(rawVal) : rawVal;
    return (
      <label className="modal-label" key={key}>
        {label}
        <input
          required
          type={type}
          disabled={busy}
          value={displayVal}
          onChange={(e) =>
            setEditing((v) =>
              v ? { ...v, [key]: type === 'number' ? Number(e.target.value) : e.target.value } : v
            )
          }
        />
      </label>
    );
  };

  return (
    <div className="recruitment-container">
      {!uniformOnly && <RecruitmentSlaAdmin />}

      {/* MODULE NAVIGATION (IF NOT UNIFORM ONLY) */}
      {!uniformOnly && (
        <div className="recruitment-toolbar">
          <div className="recruitment-toolbar-row">
            <div className="recruitment-region-chips">
              {(Object.keys(modules) as (keyof typeof modules)[]).map((key) => {
                const ModIcon = modules[key].icon;
                return (
                  <button
                    key={key}
                    type="button"
                    className={'region-chip ' + (module === key ? 'active' : '')}
                    onClick={() => {
                      setModule(key);
                      setEditing(null);
                    }}
                    style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
                  >
                    <ModIcon size={14} />
                    <span>{modules[key].label}</span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* 2-TAB SEGMENTED BAR FOR UNIFORMS */}
      {module === 'uniforms' && (
        <div className="uniform-tab-bar">
          <button
            type="button"
            className={`uniform-tab-item ${uniformTab === 'packages' ? 'active' : ''}`}
            onClick={() => setUniformTab('packages')}
          >
            <Shirt size={17} />
            <span>Gói đồng phục</span>
            <span className="uniform-tab-counter">{items.length}</span>
          </button>
          <button
            type="button"
            className={`uniform-tab-item ${uniformTab === 'orders' ? 'active' : ''}`}
            onClick={() => setUniformTab('orders')}
          >
            <ShoppingBag size={17} />
            <span>Lịch sử bán</span>
            <span className="uniform-tab-counter sales-counter">{orders.length}</span>
          </button>
        </div>
      )}

      {/* KPI METRICS FOR UNIFORMS */}
      {module === 'uniforms' && (
        uniformTab === 'packages' ? (
          <div className="recruitment-kpi-grid">
            <div className="recruitment-kpi-card emerald">
              <span className="kpi-label">Tổng gói trang bị</span>
              <span className="kpi-val">{items.length}</span>
            </div>
            <div className="recruitment-kpi-card blue">
              <span className="kpi-label">Đang áp dụng</span>
              <span className="kpi-val">{items.filter((i) => i.active).length}</span>
            </div>
            <div className="recruitment-kpi-card purple">
              <span className="kpi-label">Tổng tồn kho tất cả size</span>
              <span className="kpi-val">{totalStockAllSizes} bộ</span>
            </div>
            <div className="recruitment-kpi-card amber">
              <span className="kpi-label">Kích thước hỗ trợ</span>
              <span className="kpi-val">S, M, L, XL</span>
            </div>
          </div>
        ) : (
          <div className="recruitment-kpi-grid">
            <div className="recruitment-kpi-card blue">
              <span className="kpi-label">Tổng đơn đặt hàng</span>
              <span className="kpi-val">{salesStats.totalOrders}</span>
            </div>
            <div className="recruitment-kpi-card emerald">
              <span className="kpi-label">Doanh thu đã thu</span>
              <span className="kpi-val">{salesStats.totalRevenue.toLocaleString('vi-VN')} đ</span>
            </div>
            <div className="recruitment-kpi-card amber">
              <span className="kpi-label">Chờ thanh toán tại VP</span>
              <span className="kpi-val">{salesStats.pendingOrdersCount}</span>
            </div>
            <div className="recruitment-kpi-card purple">
              <span className="kpi-label">Đã bàn giao trang bị</span>
              <span className="kpi-val">{salesStats.handedOverCount}</span>
            </div>
          </div>
        )
      )}

      {/* TOOLBAR */}
      {module === 'uniforms' && uniformTab === 'orders' ? (
        <div className="recruitment-toolbar">
          <div className="recruitment-toolbar-row" style={{ flexWrap: 'wrap', gap: 10 }}>
            <div className="recruitment-search-input" style={{ minWidth: 260, flex: 1 }}>
              <Search size={16} color="#7b8e86" />
              <input
                type="text"
                placeholder="Tìm theo tên đối tác, SĐT, mã đơn, tên gói..."
                value={orderSearch}
                onChange={(e) => setOrderSearch(e.target.value)}
              />
            </div>

            <div className="uniform-sales-filters">
              <select
                className="uniform-select-filter"
                aria-label="Lọc trạng thái đơn hàng"
                value={orderStatusFilter}
                onChange={(e) => setOrderStatusFilter(e.target.value)}
              >
                <option value="">Tất cả trạng thái đơn</option>
                <option value="RESERVED">Đã đặt / Chờ nhận</option>
                <option value="HANDED_OVER">Đã bàn giao</option>
                <option value="CANCELLED">Đã hủy</option>
                <option value="REFUNDED">Đã hoàn trả</option>
              </select>

              <select
                className="uniform-select-filter"
                aria-label="Lọc trạng thái thanh toán"
                value={orderPaymentFilter}
                onChange={(e) => setOrderPaymentFilter(e.target.value)}
              >
                <option value="">Tất cả thanh toán</option>
                <option value="PAID">Đã thanh toán</option>
                <option value="PENDING">Chờ thanh toán</option>
                <option value="FAILED">Thất bại</option>
                <option value="WAIVED">Miễn phí</option>
                <option value="REFUNDED">Đã hoàn tiền</option>
              </select>

              <select
                className="uniform-select-filter"
                aria-label="Lọc hình thức thanh toán"
                value={orderMethodFilter}
                onChange={(e) => setOrderMethodFilter(e.target.value)}
              >
                <option value="">Tất cả hình thức TT</option>
                <option value="AT_OFFICE">Tiền mặt</option>
                <option value="ONLINE">Ngân hàng</option>
              </select>

              <button className="btn btn-outline" disabled={busy} onClick={() => void load()}>
                <RefreshCw size={15} /> Tải lại
              </button>
            </div>
          </div>
        </div>
      ) : (
        <div className="recruitment-toolbar">
          <div className="recruitment-toolbar-row" style={{ flexWrap: 'wrap', gap: 10 }}>
            <div className="recruitment-search-input" style={{ minWidth: 240, flex: 1 }}>
              <Search size={16} color="#7b8e86" />
              <input
                type="text"
                placeholder={`Tìm kiếm ${modules[module].label.toLowerCase()}...`}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>

            {module === 'uniforms' && uniformTab === 'packages' && (
              <div style={{ display: 'inline-flex', alignItems: 'center', background: '#f1f5f9', padding: 3, borderRadius: 8, gap: 2 }}>
                <button
                  type="button"
                  style={{
                    border: 'none',
                    padding: '6px 12px',
                    borderRadius: 6,
                    fontSize: 12.5,
                    fontWeight: uniformTypeFilter === 'ALL' ? 700 : 500,
                    background: uniformTypeFilter === 'ALL' ? '#ffffff' : 'transparent',
                    color: uniformTypeFilter === 'ALL' ? '#0f172a' : '#64748b',
                    boxShadow: uniformTypeFilter === 'ALL' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                    cursor: 'pointer',
                  }}
                  onClick={() => setUniformTypeFilter('ALL')}
                >
                  Tất cả ({items.length})
                </button>
                <button
                  type="button"
                  style={{
                    border: 'none',
                    padding: '6px 12px',
                    borderRadius: 6,
                    fontSize: 12.5,
                    fontWeight: uniformTypeFilter === 'PACKAGE' ? 700 : 500,
                    background: uniformTypeFilter === 'PACKAGE' ? '#ffffff' : 'transparent',
                    color: uniformTypeFilter === 'PACKAGE' ? '#0369a1' : '#64748b',
                    boxShadow: uniformTypeFilter === 'PACKAGE' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                    cursor: 'pointer',
                  }}
                  onClick={() => setUniformTypeFilter('PACKAGE')}
                >
                  📦 Gói đồng phục ({uniformTypeCounts.packages})
                </button>
                <button
                  type="button"
                  style={{
                    border: 'none',
                    padding: '6px 12px',
                    borderRadius: 6,
                    fontSize: 12.5,
                    fontWeight: uniformTypeFilter === 'ITEM' ? 700 : 500,
                    background: uniformTypeFilter === 'ITEM' ? '#ffffff' : 'transparent',
                    color: uniformTypeFilter === 'ITEM' ? '#b45309' : '#64748b',
                    boxShadow: uniformTypeFilter === 'ITEM' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                    cursor: 'pointer',
                  }}
                  onClick={() => setUniformTypeFilter('ITEM')}
                >
                  👕 Món lẻ ({uniformTypeCounts.items})
                </button>
              </div>
            )}

            <div className="table-actions">
              <button className="btn btn-outline" disabled={busy} onClick={() => void load()}>
                <RefreshCw size={15} /> Tải lại
              </button>
              <button className="btn btn-primary" disabled={busy} onClick={create}>
                <Plus size={16} /> Thêm {modules[module].label}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ERROR NOTICE */}
      {error && !editing && (
        <div className="notice catalogue-notice" role="alert" style={{ background: '#fef2f2', borderColor: '#fca5a5', color: '#991b1b' }}>
          <AlertCircle size={16} /> {error}
        </div>
      )}

      {/* UNIFORM MODULE CONTENT */}
      {module === 'uniforms' ? (
        uniformTab === 'packages' ? (
          filteredItems.length === 0 ? (
            <div className="recruitment-card-table" style={{ padding: '40px 20px', textAlign: 'center' }}>
              <Shirt size={40} color="#94a3b8" style={{ margin: '0 auto 12px' }} />
              <h3 style={{ margin: '0 0 6px', color: '#1e293b' }}>Chưa có gói đồng phục nào</h3>
              <p style={{ margin: 0, color: '#64748b', fontSize: 13 }}>
                Thêm gói đồng phục đầu tiên để đối tác có thể chọn gói và đăng ký kích thước.
              </p>
            </div>
          ) : (
            <div className="uniform-grid">
              {filteredItems.map((u) => {
                const isItem = isUniformItem(u);
                const sizes: Record<string, number> = u.sizes || {};
                const priceVnd = Number(u.price || 0).toLocaleString('vi-VN');
                const standardOrder = ['S', 'M', 'L', 'XL', 'XXL', '3XL'];
                const sortedSizes = Object.keys(sizes).sort((a, b) => {
                  const idxA = standardOrder.indexOf(a);
                  const idxB = standardOrder.indexOf(b);
                  if (idxA !== -1 && idxB !== -1) return idxA - idxB;
                  if (idxA !== -1) return -1;
                  if (idxB !== -1) return 1;
                  return a.localeCompare(b);
                });
                const totalStock = Object.values(sizes).reduce((acc, val) => acc + Number(val || 0), 0);

                return (
                  <div className="uniform-card-modern" key={u.id}>
                    {/* HEADER */}
                    <div className="uniform-card-head">
                      <div className="uniform-card-title-group">
                        <div className="uniform-card-icon-modern">
                          {u.imageUrl ? <img src={u.imageUrl} alt={u.name || 'Gói đồng phục'} style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 'inherit' }} /> : <Shirt size={20} />}
                        </div>
                        <div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                            <h3 className="uniform-card-title-modern" style={{ margin: 0 }}>{u.name || (isItem ? 'Món trang bị lẻ' : 'Gói đồng phục')}</h3>
                            {isItem ? (
                              <span style={{
                                padding: '2px 8px',
                                borderRadius: 12,
                                background: '#fffbeb',
                                color: '#b45309',
                                fontSize: 11,
                                fontWeight: 700,
                                border: '1px solid #fde68a',
                              }}>
                                👕 Món lẻ
                              </span>
                            ) : (
                              <span style={{
                                padding: '2px 8px',
                                borderRadius: 12,
                                background: '#f0fdf4',
                                color: '#15803d',
                                fontSize: 11,
                                fontWeight: 700,
                                border: '1px solid #bbf7d0',
                              }}>
                                📦 Gói combo
                              </span>
                            )}
                          </div>
                          <div className="uniform-card-meta" style={{ marginTop: 4, display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                            <span className={'status-pill-compact ' + (u.active ? 'open' : 'closed')}>
                              <span className="status-pill-dot" />
                              {u.active ? 'Đang kích hoạt' : 'Tạm dừng'}
                            </span>
                            <span style={{ fontSize: 11, color: isItem ? '#b45309' : '#0284c7', background: isItem ? '#fef3c7' : '#e0f2fe', padding: '1px 6px', borderRadius: 4, fontWeight: 600 }}>
                              {isItem ? 'Chỉ bán ngoài App' : 'Hiện trong chặng & ngoài App'}
                            </span>
                          </div>
                        </div>
                      </div>
                      <div className="uniform-price-badge">
                        {priceVnd} <span className="uniform-currency">đ</span>
                      </div>
                    </div>

                    {/* EQUIPMENT DESCRIPTION */}
                    <div className="uniform-desc-box">
                      <Package size={14} className="uniform-desc-icon" />
                      <span>{u.description || 'Chưa có mô tả thành phần trang bị.'}</span>
                    </div>

                    {/* SIZES INVENTORY ROW */}
                    <div className="uniform-inventory-container">
                      <div className="uniform-inventory-head">
                        <span className="uniform-inventory-label">Tồn kho các kích thước</span>
                        <span className={`uniform-stock-summary ${totalStock === 0 ? 'out' : totalStock < 10 ? 'low' : ''}`}>
                          Tổng: <strong>{totalStock}</strong> cái
                        </span>
                      </div>
                      <div className="uniform-size-pills-row">
                        {sortedSizes.length === 0 ? (
                          <span className="uniform-no-size">Chưa cấu hình kích thước</span>
                        ) : (
                          sortedSizes.map((s) => {
                            const count = Number(sizes[s] ?? 0);
                            const isLow = count > 0 && count < 5;
                            const isZero = count === 0;
                            return (
                              <div
                                className={`uniform-size-pill ${isZero ? 'pill-zero' : isLow ? 'pill-low' : 'pill-ok'}`}
                                key={s}
                                title={`Size ${s}: ${count} cái`}
                              >
                                <span className="size-label">Size {s}:</span>
                                <span className="size-value">{count} cái</span>
                              </div>
                            );
                          })
                        )}
                      </div>
                    </div>

                    {/* POLICY COMPACT */}
                    {cleanPolicy(u.policy) && (
                      <div className="uniform-policy-compact" title={cleanPolicy(u.policy)}>
                        <span className="policy-prefix">Chính sách:</span> {cleanPolicy(u.policy)}
                      </div>
                    )}

                    {/* FOOTER ACTIONS */}
                    <div className="uniform-actions-bar">
                      <button
                        type="button"
                        className="uniform-btn-toggle"
                        disabled={busy}
                        onClick={() => toggleActive(u)}
                      >
                        {u.active ? <EyeOff size={13} /> : <Eye size={13} />}
                        <span>{u.active ? 'Tạm ẩn' : 'Kích hoạt'}</span>
                      </button>

                      <button
                        type="button"
                        className="uniform-btn-edit"
                        disabled={busy}
                        onClick={() => {
                          const isItem = isUniformItem(u);
                          setEditing({
                            ...u,
                            packageType: isItem ? 'ITEM' : 'PACKAGE',
                            policy: (u.policy || '').replace(/\s*\[TYPE:(ITEM|PACKAGE)\]/g, '').trim(),
                          });
                        }}
                      >
                        <Edit3 size={13} />
                        <span>Chỉnh sửa</span>
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )
        ) : (
          /* SALES HISTORY TAB CONTENT */
          <div className="uniform-sales-card">
            {ordersError ? (
              <div className="notice catalogue-notice" role="alert" style={{ margin: 16, background: '#fef2f2', borderColor: '#fca5a5', color: '#991b1b' }}>
                <AlertCircle size={16} /> {ordersError}
              </div>
            ) : filteredOrders.length === 0 ? (
              <div className="uniform-empty-state">
                <div className="uniform-empty-icon">
                  <ShoppingBag size={28} />
                </div>
                <h4 className="uniform-empty-title">
                  {orders.length === 0 ? 'Chưa có đơn hàng bán đồng phục nào' : 'Không tìm thấy đơn hàng phù hợp'}
                </h4>
                <p className="uniform-empty-desc">
                  {orders.length === 0
                    ? 'Khi đối tác hoàn thành duyệt sơ bộ và đăng ký trang bị đồng phục, đơn hàng sẽ hiển thị tại đây.'
                    : 'Thử thay đổi từ khóa tìm kiếm hoặc điều chỉnh bộ lọc trạng thái để xem các đơn hàng khác.'}
                </p>
              </div>
            ) : (
              <>
                <div className="uniform-sales-table-wrap">
                  <table className="uniform-sales-table">
                    <thead>
                      <tr>
                        <th>Mã đơn & Ngày đặt</th>
                        <th>Đối tác (Partner)</th>
                        <th>Gói & Kích cỡ</th>
                        <th>Đơn giá</th>
                        <th>Hình thức TT</th>
                        <th>Thanh toán</th>
                        <th>Trạng thái đơn</th>
                        <th style={{ textAlign: 'right' }}>Thao tác</th>
                      </tr>
                    </thead>
                    <tbody>
                      {pagedOrders.map((order) => {
                        const orderStatusMeta = orderStatusLabels[order.status] || {
                          label: order.status,
                          class: 'reserved',
                          icon: Package,
                        };
                        const paymentStatusMeta = paymentStatusLabels[effectivePaymentStatus(order)] || {
                          label: order.payment_status,
                          class: 'pending',
                          icon: Clock,
                        };
                        const OrderIcon = orderStatusMeta.icon;
                        const PaymentIcon = paymentStatusMeta.icon;
                        const priceFormatted = Number(order.price || 0).toLocaleString('vi-VN');
                        const partnerInitial = (order.partner_name || 'P').trim().charAt(0).toUpperCase();
                        const isOfficePending = order.payment_method === 'AT_OFFICE' && order.payment_status === 'PENDING' && order.status === 'RESERVED';
                        const canHandover = order.status === 'RESERVED' && (order.payment_status === 'PAID' || order.payment_status === 'WAIVED');

                        return (
                          <tr key={order.id}>
                            <td>
                              <span className="order-id-badge">
                                #{(order.id || '').slice(0, 8).toUpperCase()}
                              </span>
                              <span className="order-time-text">
                                {order.created_at ? new Date(order.created_at).toLocaleString('vi-VN', { dateStyle: 'short', timeStyle: 'short' }) : '—'}
                              </span>
                            </td>
                            <td>
                              <div className="partner-user-cell">
                                <div className="partner-avatar-circle">{portraits[order.application_id] ? <img src={portraits[order.application_id]} alt={`Chân dung ${order.partner_name || 'đối tác'}`} style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: '50%' }} /> : partnerInitial}</div>
                                <div>
                                  <span className="partner-name-bold">{order.partner_name || 'Chưa cập nhật tên'}</span>
                                  {order.contact_phone && (
                                    <span className="partner-phone-sub">
                                      <Phone size={11} /> {order.contact_phone}
                                    </span>
                                  )}
                                </div>
                              </div>
                            </td>
                            <td>
                              <div className="order-package-title">{order.package_name || 'Gói đồng phục'}</div>
                              <span className="order-size-tag">Size {order.size || 'M'}</span>
                            </td>
                            <td>
                              <span className="order-price-val">{priceFormatted} đ</span>
                            </td>
                            <td>
                              {order.payment_method === 'AT_OFFICE' ? (
                                <span className="method-pill office">
                                  <Building2 size={12} /> Tiền mặt
                                </span>
                              ) : (
                                <span className="method-pill online">
                                  <CreditCard size={12} /> Ngân hàng
                                </span>
                              )}
                            </td>
                            <td>
                              <span className={`status-badge-modern ${paymentStatusMeta.class}`}>
                                <PaymentIcon size={12} />
                                {paymentStatusMeta.label}
                              </span>
                            </td>
                            <td>
                              <div>
                                <span className={`status-badge-modern ${orderStatusMeta.class}`}>
                                  <OrderIcon size={12} />
                                  {orderStatusMeta.label}
                                </span>
                                {order.handed_over_at && (
                                  <span className="order-time-text" style={{ marginTop: 2, fontSize: 11 }}>
                                    Đã giao: {new Date(order.handed_over_at).toLocaleDateString('vi-VN')}
                                  </span>
                                )}
                              </div>
                            </td>
                            <td style={{ textAlign: 'right' }}>
                              <div className="order-actions-cell" style={{ justifyContent: 'flex-end' }}>
                                {isOfficePending && (
                                  <button
                                    type="button"
                                    className="order-btn-action pay"
                                    disabled={busy}
                                    title="Xác nhận đã thu tiền mặt tại văn phòng"
                                    onClick={() => void confirmOfficePayment(order.id)}
                                  >
                                    <DollarSign size={13} /> Thu tiền
                                  </button>
                                )}
                                {canHandover && (
                                  <button
                                    type="button"
                                    className="order-btn-action handover"
                                    disabled={busy}
                                    title="Xác nhận đã bàn giao đồng phục cho đối tác"
                                    onClick={() => void confirmHandover(order.id)}
                                  >
                                    <Check size={13} /> Bàn giao
                                  </button>
                                )}
                                <button
                                  type="button"
                                  className="order-btn-action detail"
                                  disabled={busy}
                                  onClick={() => setSelectedOrder(order)}
                                >
                                  Chi tiết
                                </button>
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>

                {/* Pagination */}
                <div className="uniform-pagination-container">
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <span>
                      Hiển thị {filteredOrders.length === 0 ? 0 : orderPage * orderPageSize + 1} -{' '}
                      {Math.min((orderPage + 1) * orderPageSize, filteredOrders.length)} trên tổng số{' '}
                      <strong>{filteredOrders.length}</strong> đơn hàng
                    </span>
                    <select
                      className="uniform-select-filter"
                      style={{ minHeight: 32, padding: '4px 26px 4px 8px', fontSize: 12 }}
                      value={orderPageSize}
                      onChange={(e) => {
                        setOrderPageSize(Number(e.target.value));
                        setOrderPage(0);
                      }}
                    >
                      <option value={10}>10 đơn / trang</option>
                      <option value={20}>20 đơn / trang</option>
                      <option value={50}>50 đơn / trang</option>
                    </select>
                  </div>

                  <div className="uniform-page-buttons">
                    <button
                      type="button"
                      className="uniform-page-btn"
                      disabled={orderPage === 0 || busy}
                      onClick={() => setOrderPage((p) => Math.max(0, p - 1))}
                    >
                      <ChevronLeft size={14} /> Trước
                    </button>
                    <span style={{ fontWeight: 700, padding: '0 6px', color: '#1e293b' }}>
                      Trang {orderPage + 1} / {totalOrderPages}
                    </span>
                    <button
                      type="button"
                      className="uniform-page-btn"
                      disabled={orderPage + 1 >= totalOrderPages || busy}
                      onClick={() => setOrderPage((p) => p + 1)}
                    >
                      Sau <ChevronRight size={14} />
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>
        )
      ) : (
        /* TABLE VIEW FOR OTHER MODULES (AGREEMENTS, OFFICE SLOTS, BENEFITS, CHECKLIST) */
        <div className="recruitment-card-table">
          <table className="recruitment-table">
            <thead>
              <tr>
                <th>Tên / Nội dung</th>
                <th>Thông tin chi tiết</th>
                <th>Trạng thái & Phiên bản</th>
                <th>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {filteredItems.map((row) => (
                <tr key={row.id}>
                  <td>
                    <strong style={{ fontSize: 13, color: '#14241f' }}>
                      {row.name || row.label || row.documentType}
                    </strong>
                    {row.price != null && (
                      <span style={{ display: 'block', color: '#0b785f', fontWeight: 700, fontSize: 12, marginTop: 2 }}>
                        {Number(row.price).toLocaleString('vi-VN')} đ
                      </span>
                    )}
                  </td>
                  <td>
                    <span style={{ fontSize: 12, color: '#4b6359' }}>
                      {row.description || row.address || row.contentUrl || '—'}
                    </span>
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <span className={'status-pill ' + (row.active ? 'open' : 'closed')}>
                        <span className="status-pill-dot" />
                        {row.active ? 'Đang dùng' : 'Tạm ẩn'}
                      </span>
                      {row.version != null && <span className="area-city-badge">v{row.version}</span>}
                    </div>
                  </td>
                  <td>
                    {module !== 'agreements' ? (
                      <button
                        className="btn-icon-action"
                        disabled={busy}
                        onClick={() =>
                          setEditing({
                            ...row,
                            startsAt: row.starts_at
                              ? new Date(
                                  new Date(row.starts_at).getTime() -
                                    new Date(row.starts_at).getTimezoneOffset() * 60000
                                )
                                  .toISOString()
                                  .slice(0, 16)
                              : row.startsAt,
                          })
                        }
                      >
                        <Edit3 size={14} /> Sửa
                      </button>
                    ) : (
                      <button
                        className="btn-icon-action"
                        disabled={busy}
                        onClick={() => toggleActive(row)}
                      >
                        {row.active ? <EyeOff size={14} /> : <Eye size={14} />}
                        <span>{row.active ? 'Ẩn' : 'Bật'}</span>
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* ORDER DETAILS POPUP */}
      {selectedOrder && (
        <CataloguePopup
          title={`Chi tiết đơn hàng #${(selectedOrder.id || '').slice(0, 8).toUpperCase()}`}
          eyebrow="LỊCH SỬ BÁN ĐỒNG PHỤC · TASKLY"
          busy={busy}
          onClose={() => setSelectedOrder(null)}
        >
          <div className="order-details-container">
            {/* 1. TOP STATUS RIBBON */}
            <div className="order-status-ribbon">
              <div className="order-status-ribbon-left">
                <span className={`status-badge-modern ${orderStatusLabels[selectedOrder.status]?.class || 'reserved'}`}>
                  {(() => {
                    const StatusIcon = orderStatusLabels[selectedOrder.status]?.icon || Package;
                    return <StatusIcon size={13} />;
                  })()}
                  <span>{orderStatusLabels[selectedOrder.status]?.label || selectedOrder.status}</span>
                </span>

                <span className={`status-badge-modern ${paymentStatusLabels[effectivePaymentStatus(selectedOrder)]?.class || 'pending'}`}>
                  {(() => {
                    const PayIcon = paymentStatusLabels[effectivePaymentStatus(selectedOrder)]?.icon || CreditCard;
                    return <PayIcon size={13} />;
                  })()}
                  <span>
                    {paymentStatusLabels[effectivePaymentStatus(selectedOrder)]?.label || selectedOrder.payment_status}
                    {selectedOrder.payment_method === 'AT_OFFICE' ? ' (Tiền mặt)' : ' (Ngân hàng)'}
                  </span>
                </span>
              </div>

              <div className="order-status-ribbon-right">
                <span className="order-ribbon-price-label">Tổng thanh toán:</span>
                <span className="order-ribbon-price-val">
                  {Number(selectedOrder.price || 0) === 0 ? (
                    <span className="free-tag">Miễn phí 0 đ</span>
                  ) : (
                    `${Number(selectedOrder.price || 0).toLocaleString('vi-VN')} đ`
                  )}
                </span>
              </div>
            </div>

            {/* 2. GÓI ĐỒNG PHỤC ĐÃ ĐẶT */}
            <div className="order-section-card">
              <div className="order-section-header">
                <div className="order-section-icon shirt">
                  <Shirt size={15} />
                </div>
                <div className="order-section-title">Gói đồng phục đã đặt</div>
                <span className="order-size-badge">Size {selectedOrder.size || '—'}</span>
              </div>

              <div className="order-package-body">
                <div className="order-package-info">
                  <div className="order-package-name">
                    {selectedOrder.package_name || 'Gói đồng phục TaskLy'}
                  </div>
                  {(() => {
                    const pkg = items.find(item => item.id === selectedOrder.package_id);
                    return (
                      <>
                        {pkg?.description && (
                          <div className="order-package-desc">{pkg.description}</div>
                        )}
                        {cleanPolicy(pkg?.policy) && (
                          <div className="order-package-policy">
                            <strong>Chính sách:</strong> {cleanPolicy(pkg?.policy)}
                          </div>
                        )}
                      </>
                    );
                  })()}
                </div>

                <div className="order-package-price-box">
                  <span className="price-label">Giá niêm yết</span>
                  <span className="price-amount">
                    {Number(selectedOrder.price || 0).toLocaleString('vi-VN')} đ
                  </span>
                </div>
              </div>

              {/* Package Banner Image (if available) */}
              {(() => {
                const pkg = items.find(item => item.id === selectedOrder.package_id);
                if (!pkg?.imageUrl) return null;
                const contents: Row[] = Array.isArray(pkg.items) ? pkg.items : [];
                return (
                  <>
                    <div className="order-package-banner-wrap">
                      <img
                        src={pkg.imageUrl}
                        alt={pkg.name || 'Gói đồng phục'}
                        className="order-package-banner-img"
                      />
                    </div>
                    {contents.length > 0 && (
                      <div className="order-package-items-tray">
                        <span className="items-tray-label">Gồm có:</span>
                        {contents.map((item, index) => (
                          <span key={index} className="package-item-chip">
                            {item.name}
                          </span>
                        ))}
                      </div>
                    )}
                  </>
                );
              })()}
            </div>

            {/* 3. THÔNG TIN ĐỐI TÁC */}
            <div className="order-section-card">
              <div className="order-section-header">
                <div className="order-section-icon user">
                  <User size={15} />
                </div>
                <div className="order-section-title">Thông tin đối tác nhận đồng phục</div>
              </div>

              <div className="order-partner-row">
                {portraits[selectedOrder.application_id] ? (
                  <img
                    src={portraits[selectedOrder.application_id]}
                    alt="Ảnh chân dung đối tác"
                    className="order-partner-avatar"
                  />
                ) : (
                  <div className="order-partner-avatar-placeholder">
                    <User size={24} />
                  </div>
                )}

                <div className="order-partner-details">
                  <div className="order-partner-name">
                    {selectedOrder.partner_name || 'Chưa cập nhật tên'}
                  </div>

                  <div className="order-partner-meta-grid">
                    <div className="order-partner-meta-item">
                      <span className="meta-label">Số điện thoại:</span>
                      <a
                        href={selectedOrder.contact_phone ? `tel:${selectedOrder.contact_phone}` : '#'}
                        className="meta-value phone-link"
                      >
                        <Phone size={13} />
                        <span>{selectedOrder.contact_phone || '—'}</span>
                      </a>
                    </div>

                    <div className="order-partner-meta-item">
                      <span className="meta-label">Mã hồ sơ:</span>
                      <div className="meta-code-wrap">
                        <code className="meta-code">{selectedOrder.application_id || '—'}</code>
                        {selectedOrder.application_id && (
                          <button
                            type="button"
                            className="code-copy-btn"
                            title="Sao chép mã hồ sơ"
                            onClick={() => copyToClipboard(selectedOrder.application_id, 'app_id')}
                          >
                            {copiedField === 'app_id' ? <Check size={12} color="#059669" /> : <Copy size={12} />}
                            <span className="copy-text">{copiedField === 'app_id' ? 'Đã chép' : 'Chép'}</span>
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* 4. THANH TOÁN & BÀN GIAO */}
            <div className="order-grid-two-col">
              {/* Payment Card */}
              <div className="order-subcard">
                <div className="order-subcard-title">
                  <CreditCard size={14} /> Thông tin thanh toán
                </div>
                <div className="order-subcard-row">
                  <span className="row-label">Phương thức:</span>
                  <span className="row-val font-semibold">
                    {selectedOrder.payment_method === 'AT_OFFICE' ? 'Tiền mặt tại văn phòng' : 'Thanh toán trực tuyến'}
                  </span>
                </div>
                <div className="order-subcard-row">
                  <span className="row-label">Trạng thái:</span>
                  <span className="row-val font-semibold">
                    {paymentStatusLabels[effectivePaymentStatus(selectedOrder)]?.label || selectedOrder.payment_status}
                  </span>
                </div>
                {selectedOrder.receipt_id && (
                  <div className="order-subcard-row">
                    <span className="row-label">Mã biên nhận:</span>
                    <div className="meta-code-wrap">
                      <code className="meta-code">{selectedOrder.receipt_id}</code>
                      <button
                        type="button"
                        className="code-copy-btn"
                        title="Sao chép mã biên nhận"
                        onClick={() => copyToClipboard(selectedOrder.receipt_id, 'receipt_id')}
                      >
                        {copiedField === 'receipt_id' ? <Check size={12} color="#059669" /> : <Copy size={12} />}
                      </button>
                    </div>
                  </div>
                )}
              </div>

              {/* Handover & Timestamps Card */}
              <div className="order-subcard">
                <div className="order-subcard-title">
                  <Package size={14} /> Bàn giao & Thời gian
                </div>
                <div className="order-subcard-row">
                  <span className="row-label">Mã đơn đầy đủ:</span>
                  <div className="meta-code-wrap">
                    <code className="meta-code">{selectedOrder.id}</code>
                    <button
                      type="button"
                      className="code-copy-btn"
                      title="Sao chép mã đơn"
                      onClick={() => copyToClipboard(selectedOrder.id, 'order_id')}
                    >
                      {copiedField === 'order_id' ? <Check size={12} color="#059669" /> : <Copy size={12} />}
                    </button>
                  </div>
                </div>
                <div className="order-subcard-row">
                  <span className="row-label">Thời gian đặt:</span>
                  <span className="row-val">
                    {selectedOrder.created_at ? new Date(selectedOrder.created_at).toLocaleString('vi-VN') : '—'}
                  </span>
                </div>
                <div className="order-subcard-row">
                  <span className="row-label">Thời gian nhận:</span>
                  <span className="row-val">
                    {selectedOrder.handed_over_at ? (
                      <span style={{ color: '#059669', fontWeight: 700 }}>
                        {new Date(selectedOrder.handed_over_at).toLocaleString('vi-VN')}
                      </span>
                    ) : (
                      <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Chưa bàn giao</span>
                    )}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 16 }}>
            {selectedOrder.payment_method === 'AT_OFFICE' && selectedOrder.payment_status === 'PENDING' && selectedOrder.status === 'RESERVED' && (
              <button
                type="button"
                className="btn btn-primary"
                disabled={busy}
                onClick={() => void confirmOfficePayment(selectedOrder.id)}
              >
                <DollarSign size={15} /> Xác nhận thu tiền mặt
              </button>
            )}
            {selectedOrder.status === 'RESERVED' && (selectedOrder.payment_status === 'PAID' || selectedOrder.payment_status === 'WAIVED') && (
              <button
                type="button"
                className="btn btn-primary"
                disabled={busy}
                onClick={() => void confirmHandover(selectedOrder.id)}
              >
                <Check size={15} /> Xác nhận bàn giao đồng phục
              </button>
            )}
            <button
              type="button"
              className="btn btn-outline"
              onClick={() => setSelectedOrder(null)}
            >
              Đóng
            </button>
          </div>
        </CataloguePopup>
      )}
      {editing && (
        <CataloguePopup
          title={modules[module].label}
          eyebrow="TASKLY PARTNER · TUYỂN DỤNG"
          busy={busy}
          onClose={() => setEditing(null)}
        >
          <form
            className="modal-form-grid"
            onSubmit={(e) => {
              e.preventDefault();
              void save();
            }}
          >
            {module === 'agreements' && (
              <>
                <label className="modal-label">
                  Loại tài liệu cam kết
                  <select
                    disabled={busy}
                    value={editing.documentType}
                    onChange={(e) => setEditing({ ...editing, documentType: e.target.value })}
                  >
                    {[
                      'PARTNER_CONDUCT',
                      'PARTNER_SAFETY',
                      'PARTNER_COOPERATION',
                      'PARTNER_PRIVACY',
                      'PARTNER_UNIFORM',
                    ].map((key) => (
                      <option key={key}>{key}</option>
                    ))}
                  </select>
                </label>
                {field('version', 'Mã phiên bản (VD: v2.0 hoặc demo-1)')}
                {field('contentUrl', 'URL nội dung điều khoản HTTPS', 'url')}
                {field('effectiveAt', 'Thời điểm có hiệu lực (ISO UTC)')}
              </>
            )}

            {module === 'uniforms' && (
              <>
                <div style={{ marginBottom: 16 }}>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 700, color: '#1e293b', marginBottom: 8 }}>
                    Phân loại đồng phục & trang bị <span style={{ color: '#ef4444' }}>*</span>
                  </label>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                    <button
                      type="button"
                      onClick={() => setEditing({ ...editing, packageType: 'PACKAGE' })}
                      style={{
                        padding: '12px 14px',
                        borderRadius: 10,
                        border: (editing.packageType || 'PACKAGE') === 'PACKAGE' ? '2px solid #0284c7' : '1px solid #cbd5e1',
                        background: (editing.packageType || 'PACKAGE') === 'PACKAGE' ? '#f0f9ff' : '#ffffff',
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: 'flex-start',
                        cursor: 'pointer',
                        textAlign: 'left',
                        transition: 'all 0.15s ease',
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 700, fontSize: 13.5, color: (editing.packageType || 'PACKAGE') === 'PACKAGE' ? '#0369a1' : '#334155' }}>
                        <span>📦 Gói đồng phục (Combo)</span>
                      </div>
                      <span style={{ fontSize: 11.5, color: '#64748b', marginTop: 4 }}>
                        Hiển thị cả trong chặng tuyển dụng (Bước 4) và Cửa hàng ngoài cho Đối tác.
                      </span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setEditing({ ...editing, packageType: 'ITEM' })}
                      style={{
                        padding: '12px 14px',
                        borderRadius: 10,
                        border: editing.packageType === 'ITEM' ? '2px solid #d97706' : '1px solid #cbd5e1',
                        background: editing.packageType === 'ITEM' ? '#fffbeb' : '#ffffff',
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: 'flex-start',
                        cursor: 'pointer',
                        textAlign: 'left',
                        transition: 'all 0.15s ease',
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 700, fontSize: 13.5, color: editing.packageType === 'ITEM' ? '#b45309' : '#334155' }}>
                        <span>👕 Món lẻ / Đồ lẻ</span>
                      </div>
                      <span style={{ fontSize: 11.5, color: '#64748b', marginTop: 4 }}>
                        Chỉ hiển thị tại Cửa hàng ngoài cho Đối tác mua lẻ/bổ sung; KHÔNG hiện trong chặng.
                      </span>
                    </button>
                  </div>
                </div>

                {field('name', editing.packageType === 'ITEM' ? 'Tên món trang bị lẻ (VD: Áo thun TaskLy, Nón bảo hiểm...)' : 'Tên gói đồng phục')}
                {field('description', editing.packageType === 'ITEM' ? 'Mô tả chi tiết món trang bị (chất liệu, công dụng...)' : 'Thành phần trang bị trong gói')}
                {field('price', 'Giá bán niêm yết (VND)', 'number')}
                {field('policy', 'Chính sách cấp phát, đổi trả và hoàn tiền')}
                <label className="modal-label">{editing.packageType === 'ITEM' ? 'Ảnh món trang bị' : 'Ảnh tổng gói'}<input type="file" accept="image/jpeg,image/png,image/webp" disabled={busy} onChange={e => uploadImage(e.target.files?.[0])} /></label>
                {editing.imageUrl && <img src={editing.imageUrl} alt={editing.packageType === 'ITEM' ? 'Ảnh món trang bị' : 'Ảnh tổng gói'} style={{ height: 140, maxWidth: '100%', objectFit: 'contain' }} />}
                {(editing.items || []).map((item: Row, index: number) => <div key={index} style={{ display: 'grid', gap: 8, padding: 12, border: '1px solid #e2e8f0', borderRadius: 10 }}>
                  <input required placeholder="Tên món và số lượng" value={item.name} onChange={e => setEditing({ ...editing, items: editing.items.map((entry: Row, i: number) => i === index ? { ...entry, name: e.target.value } : entry) })} />
                  <input type="file" accept="image/jpeg,image/png,image/webp" disabled={busy} onChange={e => uploadImage(e.target.files?.[0], index)} />
                  {item.imageUrl && <img src={item.imageUrl} alt={item.name} style={{ height: 100, maxWidth: '100%', objectFit: 'contain' }} />}
                  <button type="button" className="btn btn-outline" onClick={() => setEditing({ ...editing, items: editing.items.filter((_: Row, i: number) => i !== index) })}>Xóa món</button>
                </div>)}
                <button type="button" className="btn btn-outline" disabled={busy || (editing.items || []).length >= 12} onClick={() => setEditing({ ...editing, items: [...(editing.items || []), { name: '', imageUrl: '' }] })}>Thêm món riêng lẻ</button>
                <div style={{ background: '#f8faf9', padding: 14, borderRadius: 12 }}>
                  <div style={{ fontSize: 12, fontWeight: 700, color: '#0b785f', marginBottom: 8 }}>
                    Số lượng tồn kho theo kích thước
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
                    {['S', 'M', 'L', 'XL'].map((size) => (
                      <label className="modal-label" key={size}>
                        Size {size}
                        <input
                          required
                          type="number"
                          min={0}
                          disabled={busy}
                          value={editing.sizes?.[size] ?? 0}
                          onChange={(e) =>
                            setEditing({
                              ...editing,
                              sizes: { ...editing.sizes, [size]: Number(e.target.value) },
                            })
                          }
                        />
                      </label>
                    ))}
                  </div>
                </div>
              </>
            )}

            {module === 'office-slots' && (
              <>
                {field('name', 'Tên văn phòng tiếp nhận')}
                {field('address', 'Địa chỉ văn phòng')}
                {field('startsAt', 'Thời gian hẹn', 'datetime-local')}
                {field('capacity', 'Sức chứa tiếp nhận tối đa', 'number')}
              </>
            )}

            {module === 'benefits' && (
              <>
                {field('name', 'Tên chính sách phúc lợi')}
                {field('description', 'Mô tả chi tiết quyền lợi')}
                <label className="modal-label">
                  URL nội dung HTTPS (không bắt buộc)
                  <input
                    type="url"
                    disabled={busy}
                    value={editing.content_url ?? editing.contentUrl ?? ''}
                    onChange={(e) => setEditing({ ...editing, content_url: e.target.value })}
                  />
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 600 }}>
                  <input
                    type="checkbox"
                    disabled={busy}
                    checked={editing.requires_active ?? editing.requiresActive}
                    onChange={(e) => setEditing({ ...editing, requires_active: e.target.checked })}
                  />
                  Chỉ mở nội dung khi tài khoản đối tác ACTIVE
                </label>
              </>
            )}

            {module === 'document-checklist' && (
              <>
                {field('label', 'Tên giấy tờ cần đối chiếu')}
                <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 600 }}>
                  <input
                    type="checkbox"
                    disabled={busy}
                    checked={editing.required}
                    onChange={(e) => setEditing({ ...editing, required: e.target.checked })}
                  />
                  Bắt buộc theo chính sách
                </label>
              </>
            )}

            {module !== 'uniforms' && <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 600, background: '#f8faf9', padding: 12, borderRadius: 10 }}>
              <input
                type="checkbox"
                disabled={busy}
                checked={editing.active}
                onChange={(e) => setEditing({ ...editing, active: e.target.checked })}
              />
              Đang kích hoạt sử dụng
            </label>}

            {error && <p role="alert" className="api-error">{error}</p>}

            <button className="btn btn-primary" disabled={busy} style={{ width: '100%', marginTop: 8 }}>
              {busy ? 'Đang lưu…' : 'Lưu vào hệ thống'}
            </button>
          </form>
        </CataloguePopup>
      )}
    </div>
  );
}
