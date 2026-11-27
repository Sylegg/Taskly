'use client';

import React, { useEffect, useState } from 'react';
import {
  X,
  User,
  Phone,
  Mail,
  Calendar,
  CreditCard,
  Building2,
  CheckCircle2,
  XCircle,
  AlertCircle,
  Clock,
  MapPin,
  Briefcase,
  Award,
  ShieldCheck,
  FileText,
  Copy,
  Check,
  ExternalLink,
  Lock,
  Unlock,
  AlertTriangle,
  RefreshCw,
  Sparkles,
  Edit3,
  ShoppingBag,
  Gift,
  Smartphone,
  ChevronRight,
} from 'lucide-react';
import './customer-admin.css';
import AdminAddressBook from './AdminAddressBook';
import AdminInlineField, { type ProfileField } from './AdminInlineField';

const orderStatusLabels: Record<string,string> = { DRAFT:'Bản nháp', POSTED:'Đã đặt dịch vụ', MATCHING:'Đang tìm đối tác', ACCEPTED:'Đối tác đã nhận việc', TASKER_ON_THE_WAY:'Đối tác đang đến', ARRIVED:'Đối tác đã đến', IN_PROGRESS:'Đang thực hiện', COMPLETED:'Đã hoàn thành', PAID:'Đã thanh toán', CANCELLED:'Đã hủy', DISPUTED:'Đang xử lý khiếu nại', REFUNDED:'Đã hoàn tiền', EXPIRED:'Đã hết hạn' };


type CustomerDetailModalProps = {
  customer: any;
  tasks?: any[];
  onClose: () => void;
  onUpdateCustomer?: (id: string, body: any) => Promise<void>;
  onAction?: (item: any, action: string) => void;
  onEditCustomer?: (customer: any) => void;
  onSelectTask?: (taskId: string) => void;
  saving?: boolean;
};

export default function CustomerDetailModal({
  customer,
  tasks = [],
  onClose,
  onUpdateCustomer,
  onAction,
  onEditCustomer,
  onSelectTask,
  saving,
}: CustomerDetailModalProps) {
  const [activeTab, setActiveTab] = useState<'overview' | 'addresses' | 'orders'>('overview');
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError('');

    fetch('/api/admin/customers/' + encodeURIComponent(customer.id) + '?app=customer', { cache: 'no-store' })
      .then(async (res) => {
        const j = await res.json();
        if (!res.ok) throw new Error(j.error || 'Không thể tải hồ sơ chi tiết khách hàng');
        return j.data;
      })
      .then((d) => {
        if (active) {
          setData(d);
          setLoading(false);
        }
      })
      .catch((e) => {
        if (active) {
          setError(e.message);
          setLoading(false);
        }
      });

    return () => {
      active = false;
    };
  }, [customer.id]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const isSuspended = customer.status === 'SUSPENDED';
  const profile = data?.profile || customer;
  const addresses = data?.addresses || [];

  // Filter tasks belonging to this customer
  const customerTasks = data?.orders || [];
  const completedTasksCount = customerTasks.filter((t:any) => ['COMPLETED', 'PAID'].includes(t.status)).length;
  const totalSpent = customerTasks.filter((t:any) => ['COMPLETED', 'PAID'].includes(t.status)).reduce((sum:number,t:any) => sum + Number(t.total || 0),0);
  const [editing,setEditing]=useState(false),[editName,setEditName]=useState(''),[editPhone,setEditPhone]=useState(''),[editEmail,setEditEmail]=useState(''),[editSaving,setEditSaving]=useState(false),[editError,setEditError]=useState('');
  function beginEdit(){setEditName(profile.full_name || customer.name || '');setEditPhone(profile.phone || customer.phone || '');setEditEmail(profile.email || '');setEditError('');setActiveTab('overview');setEditing(true)}
  async function saveProfile(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setEditSaving(true);
    setEditError('');
    try {
      if (!onUpdateCustomer) throw Error('Không thể lưu thông tin');
      const email = editEmail.trim().toLowerCase() || null;
      const phone = editPhone.trim() || null;
      await onUpdateCustomer(customer.id,{name:editName,phone,email});
      setData((old:any)=>({...old,profile:{...profile,full_name:editName.trim(),phone:phone ?? profile.phone,email:email ?? profile.email}}));
      setEditing(false);
    } catch (e) { setEditError((e as Error).message); }
    finally { setEditSaving(false); }
  }

  async function saveProfileField(field: ProfileField, value: string) {
    if (!onUpdateCustomer) throw Error('Không thể lưu thông tin.');
    await onUpdateCustomer(customer.id, { profileField: { field, value } });
    setData((previous: any) => ({
      ...previous, profile: { ...previous.profile, [field === 'name' ? 'full_name' : field]: value || null },
    }));
  }

  return (
    <div
      className="customer-modal-overlay"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="customer-modal-card" role="dialog" aria-modal="true">
        {/* Modal Header Banner */}
        <div className="customer-modal-header">
          <div className="customer-modal-profile">
            <div className="customer-modal-avatar">
              {String(customer.name || 'C').slice(0, 1).toUpperCase()}
            </div>
            <div className="customer-modal-name-group">
              <div className="customer-modal-name-row">
                <h2>{profile.full_name || customer.name || 'Khách hàng chưa cập nhật tên'}</h2>
                <span className={`customer-badge ${customer.status === 'ACTIVE' ? 'active' : 'suspended'}`}>
                  {customer.status === 'ACTIVE' ? '● Đang hoạt động' : 'Tạm ngưng'}
                </span>

              </div>
              <div className="customer-modal-id-row">

                <span>
                  <Phone size={13} /> {profile.phone || customer.phone || 'Chưa có SĐT'}
                </span>
                <span>•</span>
                <span>
                  <Mail size={13} /> {customer.email || 'Chưa có email'}
                </span>
              </div>
            </div>
          </div>
          <button className="customer-modal-close-btn" onClick={onClose} aria-label="Đóng cửa sổ">
            <X size={20} />
          </button>
        </div>

        {/* Modal Navigation Tabs */}
        <div className="customer-modal-tabs" style={{display:editing?'none':undefined}}>
          <button
            className={`customer-tab-btn ${activeTab === 'overview' ? 'active' : ''}`}
            onClick={() => setActiveTab('overview')}
          >
            <User size={15} /> Tổng quan & Hồ sơ
          </button>
          <button
            className={`customer-tab-btn ${activeTab === 'addresses' ? 'active' : ''}`}
            onClick={() => setActiveTab('addresses')}
          >
            <MapPin size={15} /> Sổ địa chỉ ({addresses.length})
          </button>
          <button
            className={`customer-tab-btn ${activeTab === 'orders' ? 'active' : ''}`}
            onClick={() => setActiveTab('orders')}
          >
            <ShoppingBag size={15} /> Lịch sử đặt đơn ({loading ? '…' : data ? customerTasks.length : '—'})
          </button>
        </div>

        {/* Modal Body */}
        <div className="customer-modal-body">
          {error && (
            <div
              style={{
                padding: '12px 16px',
                borderRadius: 10,
                background: '#fff1f2',
                border: '1px solid #fecdd3',
                color: '#e11d48',
                fontSize: 13,
                display: 'flex',
                alignItems: 'center',
                gap: 8,
              }}
            >
              <AlertCircle size={16} /> {error}
            </div>
          )}

          {/* TAB 1: OVERVIEW */}
          {editing && <form className="customer-card-box" onSubmit={saveProfile}>
            <h4>Thông tin cá nhân</h4>
            <div className="form-grid">
              <label className="field"><span>Họ và tên</span><input required minLength={2} maxLength={160} value={editName} onChange={e=>setEditName(e.target.value)} /></label>
              <label className="field"><span>Số điện thoại</span><input required={Boolean(profile.phone)} type="tel" pattern="0[0-9]{9}" value={editPhone} onChange={e=>setEditPhone(e.target.value)} /></label>
              <label className="field"><span>Email</span><input type="email" required={Boolean(profile.email)} maxLength={254} value={editEmail} onChange={e=>setEditEmail(e.target.value)} /></label>
            </div>
            {editError && <p role="alert">{editError}</p>}
            <button className="btn btn-primary" disabled={editSaving}>{editSaving?'Đang lưu…':'Lưu thay đổi'}</button>
            <button type="button" className="btn btn-ghost" disabled={editSaving} onClick={()=>setEditing(false)}>Hủy</button>
          </form>}
          {!editing && activeTab === 'overview' && (
            <>
              {/* Profile Card */}
              <div className="customer-card-box">
                <div className="customer-card-header">
                  <h4 className="customer-card-title">
                    <User size={16} color="#2563eb" /> Thông tin tài khoản khách hàng
                  </h4>
                  {!editing && onUpdateCustomer && (
                    <button
                      className="btn btn-outline"
                      style={{ padding: '4px 10px', fontSize: 12 }}
                      onClick={beginEdit}
                    >
                      <Edit3 size={13} /> Chỉnh sửa
                    </button>
                  )}
                </div>
                <div className="customer-spec-grid">
                  <div className="customer-spec-item">
                    <span className="customer-spec-label">Họ và tên</span>
                    {data && onUpdateCustomer ? <AdminInlineField field="name" label="Họ và tên" value={profile.full_name} onSave={saveProfileField} />
                      : <span className="customer-spec-val">{profile.full_name || customer.name || '—'}</span>}
                  </div>
                  <div className="customer-spec-item">
                    <span className="customer-spec-label">Số điện thoại</span>
                    {data && onUpdateCustomer ? <AdminInlineField field="phone" label="Số điện thoại" value={profile.phone} onSave={saveProfileField} />
                      : <span className="customer-spec-val">{profile.phone || customer.phone || '—'}</span>}
                  </div>
                  <div className="customer-spec-item">
                    <span className="customer-spec-label">Địa chỉ email</span>
                    {data && onUpdateCustomer ? <AdminInlineField field="email" label="Email" value={profile.email} onSave={saveProfileField} />
                      : <span className="customer-spec-val">{profile.email || customer.email || '—'}</span>}
                  </div>

                  <div className="customer-spec-item">
                    <span className="customer-spec-label">Ngày tạo tài khoản</span>
                    <span className="customer-spec-val">
                      {profile.created_at || customer.created
                        ? new Date(profile.created_at || customer.created).toLocaleString('vi-VN')
                        : '—'}
                    </span>
                  </div>
                  {data && onUpdateCustomer && <div className="customer-spec-item">
                    <span className="customer-spec-label">Ngày hồ sơ</span>
                    <AdminInlineField field="profile_date" label="Ngày hồ sơ" value={profile.profile_date} onSave={saveProfileField} />
                  </div>}

                </div>
              </div>

              {/* Booking & Spending Summary Card */}
              <div className="customer-card-box">
                <div className="customer-card-header">
                  <h4 className="customer-card-title">
                    <ShoppingBag size={16} color="#059669" /> Tổng quan giao dịch & đơn dịch vụ
                  </h4>
                </div>
                <div className="customer-spec-grid">
                  <div className="customer-spec-item">
                    <span className="customer-spec-label">Tổng số đơn đã đặt</span>
                    <span className="customer-spec-val" style={{ fontSize: 17, color: '#2563eb' }}>
                      {loading ? '…' : data ? customerTasks.length : '—'} đơn
                    </span>
                  </div>
                  <div className="customer-spec-item">
                    <span className="customer-spec-label">Đơn hoàn thành</span>
                    <span className="customer-spec-val" style={{ fontSize: 17, color: '#059669' }}>
                      {loading ? '…' : data ? completedTasksCount : '—'} đơn
                    </span>
                  </div>
                  <div className="customer-spec-item">
                    <span className="customer-spec-label">Tổng chi tiêu hoàn tất</span>
                    <span className="customer-spec-val" style={{ fontSize: 17, color: '#0f172a' }}>
                      {loading ? 'Đang tải…' : data ? totalSpent.toLocaleString('vi-VN') + ' đ' : 'Chưa có dữ liệu'}
                    </span>
                  </div>

                </div>
              </div>
            </>
          )}

          {/* TAB 2: ADDRESSES */}
          {activeTab === 'addresses' && (
            <div className="customer-card-box">
              <div className="customer-card-header">
                <h4 className="customer-card-title">
                  <MapPin size={16} color="#2563eb" /> Sổ địa chỉ đã lưu của khách hàng
                </h4>
                <span style={{ fontSize: 12, color: '#64748b' }}>
                  {addresses.length} địa chỉ được đồng bộ từ máy chủ
                </span>
              </div>
              {loading ? <p role="status">Đang tải sổ địa chỉ…</p> : (
                <AdminAddressBook userId={customer.id} addresses={addresses}
                  onSaved={next => setData((previous: any) => ({ ...previous, addresses: next }))} />
              )}
            </div>
          )}

          {/* TAB 3: ORDERS */}
          {activeTab === 'orders' && (
            <div className="customer-card-box">
              <div className="customer-card-header">
                <h4 className="customer-card-title">
                  <ShoppingBag size={16} color="#2563eb" /> Lịch sử các đơn công việc đã tạo
                </h4>
                <span style={{ fontSize: 12, color: '#64748b' }}>
                  Tổng cộng: {loading ? '…' : data ? customerTasks.length : '—'} đơn
                </span>
              </div>
              {loading ? <p>Đang tải đơn dịch vụ…</p> : error ? <p>Không tải được đơn dịch vụ.</p> : customerTasks.length > 0 ? (
                <div className="customer-orders-list">
                  {customerTasks.map((t: any) => {
                    const isDone = ['COMPLETED', 'PAID'].includes(t.status);
                    const isDoing = ['IN_PROGRESS', 'ACCEPTED', 'TASKER_ON_THE_WAY', 'ARRIVED'].includes(t.status);
                    const isCancelled = ['CANCELLED', 'REFUNDED','EXPIRED'].includes(t.status);

                    const statusClass = isDone
                      ? 'active'
                      : isDoing
                      ? 'app-customer'
                      : isCancelled
                      ? 'suspended'
                      : 'vip';

                    const statusLabel = orderStatusLabels[t.status] || 'Chưa xác định';

                    return (
                      <div key={t.id} className="customer-order-item">
                        <div className="customer-order-main">
                          <div className="customer-order-title-row">
                            <span className="customer-order-service">{t.service_name || 'Dịch vụ'}</span>
                            <span className={`customer-badge ${statusClass}`}>{statusLabel}</span>
                          </div>
                          <div className="customer-order-meta">
                            <span>
                              <Calendar size={12} /> {t.scheduled_at ? new Date(t.scheduled_at).toLocaleString('vi-VN') : 'Chưa có lịch'}
                            </span>
                            <span>•</span>
                            <span>
                              <MapPin size={12} /> {t.location || 'Địa chỉ khách hàng'}
                            </span>
                          </div>
                        </div>
                        <div className="customer-order-right">
                          <span className="customer-order-price">
                            {Number(t.total || 0).toLocaleString('vi-VN')} đ
                          </span>

                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div className="customer-empty-box">
                  <ShoppingBag size={32} style={{ opacity: 0.3 }} />
                  <strong>Chưa có đơn đặt nào</strong>
                  <span>Khách hàng chưa phát sinh đơn đặt dịch vụ nào trong hệ thống.</span>
                </div>
              )}
            </div>
          )}

        </div>

        {/* Modal Footer Actions */}
        <div className="customer-modal-footer">
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            {!editing && onUpdateCustomer && (
              <button className="btn btn-outline" onClick={beginEdit}>
                <Edit3 size={15} /> Chỉnh sửa thông tin
              </button>
            )}
          </div>
          <div className="customer-modal-footer-actions">
            {!editing && onAction && ['ACTIVE', 'SUSPENDED'].includes(customer.status) && (
              <button
                className={`btn ${isSuspended ? 'btn-primary' : 'btn-danger'}`}
                disabled={saving}
                onClick={() => onAction(customer, 'RESTRICT')}
              >
                {isSuspended ? <Unlock size={15} /> : <Lock size={15} />}
                {isSuspended ? 'Mở khóa tài khoản' : 'Khóa tài khoản'}
              </button>
            )}

            <button className="btn btn-ghost" onClick={onClose}>
              Đóng
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
