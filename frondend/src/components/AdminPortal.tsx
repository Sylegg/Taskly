'use client';
import { useEffect, useState } from 'react';
import AdminApp from './AdminApp';
import RecruitmentAdmin from './RecruitmentAdmin';
type User = { id: string; name: string; email: string; role: string; permissions: string[] };
type Customer = Record<string, any>;
export default function AdminPortal() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [email, setEmail] = useState(''); const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [customerError, setCustomerError] = useState('');
  const [customerLoading, setCustomerLoading] = useState(false);
  async function request(url: string, options?: RequestInit) {
    const response = await fetch(url, { ...options, cache: 'no-store' });
    const result = await response.json();
    if (!response.ok) {
      if (response.status === 401 || response.status === 403) { setUser(null); setCustomers([]); }
      throw Error(result.error || 'Không thể tải dữ liệu.');
    }
    return result;
  }
  async function loadCustomers() {
    setCustomerLoading(true); setCustomerError('');
    try { const result = await request('/api/admin/customers'); setCustomers(result.customers); }
    catch (e) { setCustomers([]); setCustomerError((e as Error).message); throw e; }
    finally { setCustomerLoading(false); }
  }
  useEffect(() => {
    let active = true;
    fetch('/api/admin/session', { cache: 'no-store' }).then(async response => {
      if (!active) return;
      if (response.ok) setUser((await response.json()).user);
      else if (response.status !== 401) setError((await response.json()).error);
    }).catch(() => { if (active) setError('Không thể kết nối máy chủ.'); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);
  useEffect(() => { if (user?.role === 'ADMIN') void loadCustomers().catch(() => {}); }, [user?.id]);
  async function login(e: React.FormEvent) {
    e.preventDefault(); setSubmitting(true); setError('');
    try {
      const result = await request('/api/admin/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
      setPassword(''); setUser(result.user);
    } catch (e) { setError((e as Error).message); }
    finally { setSubmitting(false); }
  }
  async function logout() {
    await request('/api/admin/logout', { method: 'POST' }); setUser(null); setCustomers([]);
  }
  async function updateCustomer(id: string, body: Customer) {
    await request('/api/admin/customers/' + id, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    await loadCustomers();
  }
  if (loading) return <div className="admin-login"><p>Đang kiểm tra phiên đăng nhập…</p></div>;
  if (!user) return <div className="admin-login"><form onSubmit={login} className="admin-login-card">
    <span className="eyebrow">TASKLY ADMIN</span><h1>Đăng nhập quản trị</h1><p>Dashboard dành riêng cho tài khoản Admin.</p>
    <label className="field"><span>Email</span><input type="email" autoComplete="username" required value={email} onChange={e => setEmail(e.target.value)} disabled={submitting}/></label>
    <label className="field"><span>Mật khẩu</span><input type="password" autoComplete="current-password" required value={password} onChange={e => setPassword(e.target.value)} disabled={submitting}/></label>
    {error && <p role="alert" className="api-error">{error}</p>}
    <button className="btn btn-primary" disabled={submitting}>{submitting ? 'Đang đăng nhập…' : 'Đăng nhập'}</button>
  </form></div>;
  if(user.role==='RECRUITMENT_STAFF')return <main className="main-content"><header className="row"><h1>TaskLy • Tuyển dụng</h1><span>{user.name}</span><button className="btn" onClick={()=>void logout()}>Đăng xuất</button></header><RecruitmentAdmin permissions={user.permissions}/></main>;
  return <AdminApp customers={customers} customerLoading={customerLoading} customerError={customerError}
    adminName={user.name} onRefreshCustomers={loadCustomers} onUpdateCustomer={updateCustomer} onLogout={logout}/>;
}
