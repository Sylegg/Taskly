'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Activity, AlertTriangle, ArrowDownToLine, ArrowLeft, ArrowRight, BarChart3, Bell, CalendarDays, Check, CheckCircle2, ChevronDown, ChevronRight, ClipboardCheck, Clock3, CreditCard, Download, FileText, Filter, Gift, Globe2, LayoutDashboard, LockKeyhole, MapPin, Menu, MessageSquare, MoreHorizontal, Plus, RefreshCw, Search, Settings2, ShieldCheck, SlidersHorizontal, Sparkles, TrendingUp, Upload, Users, Wallet, X, Zap, Video, Shirt, Award } from 'lucide-react';
import rawSeed from '@/data/seed.json';
import rawNav from '@/data/navigation.json';
import { AdminPortal, navigationForPortal, portalForRoute } from '@/lib/admin-navigation';
import rawHeadings from '@/data/headings.json';
import CatalogueAdmin from './CatalogueAdmin';
import BannerAdmin from './BannerAdmin';
import CommunityAdmin from './CommunityAdmin';
import RecruitmentAdmin from './RecruitmentAdmin';
import SupportAdmin from './SupportAdmin';
import TaskAdmin from './TaskAdmin';
import DailyMilestonesAdmin from './DailyMilestonesAdmin';
import DepositWithdrawAdmin from './DepositWithdrawAdmin';
import PartnerAdmin from './PartnerAdmin';
import PartnerDetailModal from './PartnerDetailModal';
import CustomerAdmin from './CustomerAdmin';
import CustomerDetailModal from './CustomerDetailModal';
import OperationsSettings from './OperationsSettings';
import PartnerChecks, { partnerStatusLabels } from './PartnerChecks';
import { FLOW, STATUS, CAPS, can, clone, id, record, money, stamp, taskCustomer, taskPartner, taskService, eligiblePartners, assign, advance, changeKyc, refund, cancelTask, importMobile } from '@/lib/domain.mjs';

type Row = Record<string, any>;
type DB = Record<string, any>;
type Selection = { kind: string; id: string };
type Form = { kind: string; row: Row | null };
const NAV = rawNav as [string, [string, string, string][]][];
const HEADINGS = rawHeadings as unknown as Record<string, [string, string]>;
const SEED = rawSeed as DB;
const STORE_KEY = 'taskly_next_admin_v1';
const ROLES = ['ADMIN'];
const LABEL: Record<string, string> = { apps: 'Ứng dụng', id: 'Mã', name: 'Họ và tên', email: 'Email', phone: 'Số điện thoại', status: 'Trạng thái tài khoản', recruitment_status: 'Trạng thái hồ sơ', application_id: 'Mã hồ sơ Partner', review_reason: 'Ghi chú xét duyệt', recruitment_updated_at: 'Cập nhật hồ sơ', accepted_jobs: 'Việc đã nhận', completed_jobs: 'Việc hoàn thành', kyc: 'Định danh KYC', tier: 'Hạng', points: 'TaskPoints', bookings: 'Số lần đặt', area: 'Khu vực', rating: 'Đánh giá', completed: 'Hoàn thành', online: 'Trực tuyến', skills: 'Kỹ năng', price: 'Giá từ', active: 'Đang bật', category: 'Danh mục', description: 'Mô tả', form: 'Form động', base: 'Giá cơ bản', feePercent: 'Phí (%)', urgentPercent: 'Phụ phí gấp (%)', serviceId: 'Dịch vụ', customerId: 'Customer', partnerId: 'Partner', location: 'Địa điểm', date: 'Ngày', time: 'Giờ', total: 'Tổng tiền', payment: 'Thanh toán', taskId: 'Công việc', amount: 'Số tiền', method: 'Phương thức', reason: 'Lý do', note: 'Ghi chú', subject: 'Chủ đề', priority: 'Độ ưu tiên', agent: 'Nhân viên xử lý', reply: 'Phản hồi', from: 'Nguồn', evidence: 'Bằng chứng', bank: 'Ngân hàng', code: 'Mã voucher', discount: 'Giảm giá', min: 'Đơn tối thiểu', uses: 'Đã dùng', limit: 'Giới hạn', expiry: 'Hạn', title: 'Tiêu đề', subtitle: 'Mô tả ngắn', placement: 'Vị trí', role: 'Vai trò', action: 'Hành động', at: 'Thời gian', target: 'Đối tượng', detail: 'Chi tiết', visible: 'Hiển thị', reported: 'Bị báo cáo', author: 'Người đánh giá', stars: 'Số sao', audience: 'Đối tượng', channel: 'Kênh', sent: 'Số đã gửi', cadence: 'Chu kỳ', next: 'Lượt tiếp', count: 'Số lượt', kind: 'Loại', to: 'Đến', created: 'Ngày tạo', submitted: 'Ngày nộp', type: 'Loại', last: 'Truy cập gần nhất', availability: 'Giờ hoạt động', supportEmail: 'Email hỗ trợ', supportPhone: 'Số hỗ trợ' };
const FIELDS: Record<string, string[]> = { customers: ['id', 'name', 'email', 'phone', 'apps', 'status', 'bookings'], partners: ['id', 'name', 'email', 'phone', 'apps', 'status'], kycs: ['id', 'partnerId', 'status', 'type', 'note', 'submitted'], services: ['id', 'icon', 'name', 'category', 'price', 'active', 'form', 'description'], categories: ['id', 'name', 'description', 'active'], tasks: ['id', 'serviceId', 'customerId', 'partnerId', 'date', 'time', 'location', 'total', 'status', 'payment'], payments: ['id', 'taskId', 'amount', 'status', 'method', 'providerRef'], refunds: ['id', 'taskId', 'paymentId', 'amount', 'status', 'reason'], payouts: ['id', 'partnerId', 'amount', 'status', 'bank'], ledger: ['id', 'taskId', 'kind', 'amount', 'status', 'at'], disputes: ['id', 'taskId', 'from', 'reason', 'amount', 'status'], tickets: ['id', 'subject', 'category', 'priority', 'agent', 'status'], reviews: ['id', 'taskId', 'author', 'target', 'stars', 'visible', 'reported'], reports: ['id', 'from', 'target', 'reason', 'status'], vouchers: ['id', 'code', 'discount', 'min', 'uses', 'limit', 'active', 'expiry'], banners: ['id', 'icon', 'title', 'placement', 'order', 'active'], campaigns: ['id', 'title', 'channel', 'audience', 'status', 'sent'], staff: ['id', 'name', 'email', 'role', 'status'], audit: ['id', 'actor', 'action', 'entity', 'target', 'at'] };
const SORT_FIELDS: Record<string, string[]> = { customers: ['name', 'email', 'phone', 'apps', 'status', 'bookings'], partners: ['name', 'phone', 'status', 'recruitment_status', 'kyc', 'accepted_jobs', 'completed_jobs'], kycs: ['partnerId', 'status', 'submitted', 'note'], services: ['icon', 'name', 'category', 'price', 'active'], categories: ['name', 'description', 'active'], tasks: ['id', 'serviceId', 'customerId', 'partnerId', 'total', 'status'], payments: ['id', 'taskId', 'amount', 'status'], refunds: ['id', 'taskId', 'amount', 'status'], payouts: ['id', 'partnerId', 'amount', 'status'], ledger: ['kind', 'taskId', 'amount', 'status'], disputes: ['id', 'taskId', 'reason', 'status'], tickets: ['subject', 'priority', 'agent', 'status'], reviews: ['taskId', 'stars', 'visible', 'reported'], reports: ['from', 'target', 'reason', 'status'], vouchers: ['code', 'discount', 'uses', 'limit', 'active'], banners: ['icon', 'title', 'placement', 'active'], campaigns: ['title', 'channel', 'audience', 'status'], staff: ['name', 'email', 'role', 'status'], audit: ['actor', 'action', 'entity', 'target', 'at'] };
const ROUTE_KIND: Record<string, string> = { customers: 'customers', partners: 'partners', services: 'services', categories: 'categories', tasks: 'tasks', payments: 'payments', refunds: 'refunds', payouts: 'payouts', ledger: 'ledger', disputes: 'disputes', tickets: 'tickets', reviews: 'reviews', banners: 'banners', vouchers: 'vouchers', staff: 'staff', audit: 'audit' };
const READ_ONLY = ['ledger', 'audit', 'payments', 'kycs', 'reviews'];
const NUMBER_FIELDS = new Set(['price', 'points', 'bookings', 'completed', 'total', 'base', 'feePercent', 'urgentPercent', 'amount', 'discount', 'min', 'uses', 'limit', 'order', 'sent', 'stars', 'count', 'rating']);
const DATE_FIELDS = new Set(['date', 'expiry', 'next']);
const OPTIONS: Record<string, string[]> = { status: ['ACTIVE', 'RESTRICTED', 'SUSPENDED', 'PENDING', 'APPROVED', 'REJECTED', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'PAUSED', 'DRAFT', 'SENT', 'COMPLETED', 'CANCELLED', 'MATCHING', 'ACCEPTED', 'TASKER_ON_THE_WAY', 'ARRIVED', 'PAID', 'REFUNDED'], kyc: ['PENDING', 'APPROVED', 'REJECTED'], role: ROLES, priority: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'], category: ['Việc nhà', 'Kỹ thuật', 'Vận chuyển', 'Tiện ích', 'Chăm sóc'], tier: ['New', 'Silver', 'Gold', 'Platinum'], channel: ['Push (demo)', 'Email (demo)', 'In-app (demo)'], audience: ['Customers', 'Partners', 'All'], cadence: ['Hằng tuần', 'Hai tuần', 'Hằng tháng'], placement: ['Customer Home', 'Partner Home', 'Onboarding'] };
const NAV_ICONS: Record<string, typeof FileText> = {
  dashboard: LayoutDashboard, operations: Activity, analytics: BarChart3,
  'recruitment-areas': MapPin, 'recruitment-applications': ClipboardCheck,
  'recruitment-exam': FileText, 'recruitment-uniforms': Shirt,
  customers: Users, partners: Users, 'daily-milestones': Award,
  services: ClipboardCheck, categories: SlidersHorizontal, availability: CalendarDays,
  tasks: FileText, 
  payments: ArrowDownToLine, refunds: Wallet, payouts: Wallet, ledger: FileText,
  disputes: ShieldCheck, tickets: MessageSquare, reviews: Sparkles,
  banners: Gift, vouchers: Gift, rewards: Gift, campaigns: Bell,
  staff: Users, permissions: LockKeyhole, audit: FileText, settings: Settings2,
  integrations: Globe2, datalab: Download,
};
const mainRoutes = new Set(['dashboard', 'operations', 'analytics']);
const today = () => new Date().toISOString().slice(0, 10);
const statusTone = (x: any) => { let v = String(x || ''); return ['ACTIVE', 'APPROVED', 'PAID', 'RELEASED', 'COMPLETED', 'RESOLVED', 'SENT', 'IN_PROGRESS', 'ARRIVED'].includes(v) ? 'green' : ['PENDING', 'MATCHING', 'HELD', 'OPEN', 'ACCEPTED', 'DRAFT', 'REVIEW', 'TASKER_ON_THE_WAY'].includes(v) ? 'amber' : ['REJECTED', 'FAILED', 'CANCELLED', 'REFUNDED', 'DISPUTED', 'RESTRICTED', 'SUSPENDED'].includes(v) ? 'red' : 'neutral' };
function Badge({ value }: { value: any }) { let v = String(value ?? '—'); return <span className={'badge ' + statusTone(v)}>{STATUS[v] || partnerStatusLabels[v] || v}</span> }
function moneyField(field: string, value: any) { return ['price', 'base', 'amount', 'total', 'discount', 'min'].includes(field) ? money(value) : String(value ?? '—') }
function showField(db: DB, field: string, value: any): React.ReactNode { if (field === 'serviceId') return db.services.find((s: Row) => s.id === value)?.name || value; if (field === 'customerId') return db.customers.find((s: Row) => s.id === value)?.name || value; if (field === 'partnerId') return db.partners.find((s: Row) => s.id === value)?.name || value || 'Chưa có'; if (field === 'skills') return (value || []).map((v: string) => db.services.find((s: Row) => s.id === v)?.name || v).join(', '); if (typeof value === 'boolean') return <Badge value={value ? 'ACTIVE' : 'PAUSED'} />; if (field === 'status' || field === 'recruitment_status' || field === 'kyc' || field === 'payment') return <Badge value={value} />; if (NUMBER_FIELDS.has(field) && value !== '' && value != null) return moneyField(field, value); return String(value ?? '—') }
const seedClone = () => ({ ...clone(SEED), customers: [], partners: [], staff: [] });
function downloadFile(name: string, text: string, mime: string) { let blob = new Blob([text], { type: mime }), url = URL.createObjectURL(blob); let a = document.createElement('a'); a.href = url; a.download = name; a.click(); URL.revokeObjectURL(url) }
const csv = (rows: Row[]) => { if (!rows.length) return 'No data'; let keys = [...new Set(rows.flatMap(x => Object.keys(x)))]; return [keys.join(','), ...rows.map(r => keys.map(k => '"' + String(r[k] ?? '').replace(/"/g, '""') + '"').join(','))].join('\r\n') };

type AdminProps = {
  customers: Row[]; customerLoading: boolean; customerError: string; adminName: string;
  onRefreshCustomers: () => Promise<void>;
  onUpdateCustomer: (id: string, body: Row) => Promise<void>;
  onLogout: () => Promise<void>;
};
export default function AdminApp({ customers: accounts, customerLoading, customerError, adminName, onRefreshCustomers, onUpdateCustomer, onLogout }: AdminProps) {
  const users: Row[] = accounts.map(row => ({ ...row, apps: [row.customer_app && 'Customer', row.partner_app && 'Partner'].filter(Boolean).join(' + ') || 'Customer' }));
  const customers = users.filter(row => row.customer_app || !row.partner_app);
  const partners = users.filter(row => row.partner_app);
  const [supportChatOpen, setSupportChatOpen] = useState(false);
  const [supportUnread, setSupportUnread] = useState(0);
  const [supportSender, setSupportSender] = useState('Người dùng');
  const [savingCustomer, setSavingCustomer] = useState(false);

  const [partnerEditMode,setPartnerEditMode]=useState(false);
  const [db, setDb] = useState<DB>(seedClone); const [ready, setReady] = useState(false); const [route, setRoute] = useState('dashboard'); const [q, setQ] = useState(''); const [filter, setFilter] = useState('ALL'); const role = 'ADMIN'; const [menuOpen, setMenuOpen] = useState(false); const [selected, setSelected] = useState<Selection | null>(null); const [form, setForm] = useState<Form | null>(null); const [formValues, setFormValues] = useState<Row>({}); const [toast, setToast] = useState(''); const [viewClassic, setViewClassic] = useState(false); const [range, setRange] = useState('30 ngày'); const [confirm, setConfirm] = useState<{ title: string; message: string; go: () => void } | null>(null); const [notifs, setNotifs] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const [portal, setPortal] = useState<AdminPortal>('customer');
  const [portalRoutes, setPortalRoutes] = useState<Record<AdminPortal, string>>({customer:'dashboard', partner:'recruitment'});
  useEffect(() => { try { const last=localStorage.getItem(STORE_KEY+'_route'); const owner=last?portalForRoute(last):null; setPortal(owner ?? (localStorage.getItem(STORE_KEY+'_portal') === 'partner'?'partner':'customer')); } catch {} }, []);
  useEffect(() => { if (ready) { try { localStorage.setItem(STORE_KEY+'_portal',portal); } catch {} } }, [portal,ready]);
  useEffect(() => { const owner = portalForRoute(route); if (owner) setPortal(owner); }, [route]);
  function switchPortal(next: AdminPortal) {
    if (next === portal) return;
    setPortalRoutes(previous => ({...previous, [portal]:route}));
    setPortal(next);
    navigate(portalRoutes[next]);
  }
  useEffect(() => { try { const x = window.localStorage.getItem(STORE_KEY); if (x) { let d = JSON.parse(x); if (d.version === 1) setDb({ ...d, customers: [], partners: [], staff: [] }) } const last = window.localStorage.getItem(STORE_KEY + '_route'); if (last === 'recruitment') setRoute('recruitment-applications'); else if (last === 'pricing') setRoute('services'); else if (last === 'tickets') setRoute('dashboard'); else if (last && HEADINGS[last]) setRoute(last) } catch { } if (new URLSearchParams(window.location.search).get('module') === 'tickets') { setRoute('dashboard'); setSupportChatOpen(true); } if (new URLSearchParams(window.location.search).get('module') === 'tasks') setRoute('tasks'); setReady(true) }, []);
  useEffect(() => { if (ready) { localStorage.setItem(STORE_KEY, JSON.stringify({ ...db, customers: [], partners: [], staff: [] })); localStorage.setItem(STORE_KEY + '_route', route) } }, [db, route, ready]);
  useEffect(() => { if (!toast) return; let t = setTimeout(() => setToast(''), 3500); return () => clearTimeout(t) }, [toast]);
  useEffect(() => { setDb(previous => ({ ...previous, customers, partners })); }, [accounts]);
  function notify(t: string) { setToast(t) }
  function navigate(k: string) { if (k === 'campaigns') return; const nextRoute = k === 'recruitment' ? 'recruitment-applications' : k === 'pricing' ? 'services' : k; if (!HEADINGS[nextRoute]) return; const url = new URL(window.location.href); url.searchParams.delete('taskId'); window.history.replaceState(window.history.state, '', url.toString()); setRoute(nextRoute); setQ(''); setFilter('ALL'); setSelected(null); setMenuOpen(false); setViewClassic(false); window.scrollTo(0, 0) }
  function change(next: DB, msg: string) { setDb({ ...next, customers, partners }); notify(msg) }
  function update(fn: (d: DB) => void, action: string, entity: string, target: string, desc = '') { let next = clone(db); fn(next); record(next, role, action, entity, target, desc); setDb(next); notify(desc || 'Đã cập nhật dữ liệu demo') }
  function guarded(r: string, fn: () => void) { if (!can(role, r)) { notify('Vai trò ' + role + ' không có quyền chỉnh sửa module này (demo)'); return } fn() }
  function attempt(r: string, fn: () => void) { try { guarded(r, fn) } catch (e: any) { notify('⚠ ' + e.message) } }

  function withRecord(action: string, entity: string, target: string, callback: () => DB) { try { const next = callback(); change(next, action + ' thành công') } catch (e: any) { notify('⚠ ' + e.message) } }
  function openForm(kind: string, row: Row | null = null) { if(kind==='partners' && row){setPartnerEditMode(true);setSelected({kind,id:row.id});return;}  if (['customers', 'partners'].includes(kind) && !row) { notify('Tài khoản được tạo từ ứng dụng Customer hoặc Partner.'); return; } const section = Object.keys(ROUTE_KIND).find(k => ROUTE_KIND[k] === kind) || kind; guarded(section, () => { setForm({ kind, row }); setFormValues(row ? clone(row) : {}); setSelected(null) }) }
  async function commitForm() {
    if (!form) return; const { kind, row } = form;
    if (['customers', 'partners'].includes(kind)) {
      if (!row || savingCustomer) return;
      setSavingCustomer(true);
      try { await onUpdateCustomer(row.id, { name: formValues.name, phone: formValues.phone }); setForm(null); notify('Đã lưu customer vào máy chủ.'); }
      catch (e) { notify((e as Error).message); } finally { setSavingCustomer(false); } return;
    }
    if (!formValues.name && !row && ['customers', 'partners', 'services', 'categories', 'staff'].includes(kind)) { notify('Cần nhập tên'); return } const e = (formValues.email || '').toString().trim().toLowerCase(); if (e && ['customers', 'partners', 'staff'].includes(kind) && [...db.customers, ...db.partners, ...db.staff].some((x: Row) => x.email?.toLowerCase() === e && x.id !== row?.id)) { notify('Email đã tồn tại'); return } let next = clone(db), items = next[kind]; if (!Array.isArray(items)) return; const val: Row = { ...formValues }; for (const k of Object.keys(val)) { if (NUMBER_FIELDS.has(k)) val[k] = Number(val[k]) || 0; } if (kind === 'partners' && typeof val.skills === 'string') val.skills = val.skills.split(',').map((x: string) => x.trim()).filter(Boolean); if (!row) { const prefix = ({ customers: 'C', partners: 'P', services: 'SV', categories: 'CAT', tasks: 'TL', refunds: 'RF', vouchers: 'V', banners: 'B', campaigns: 'N', staff: 'A', tickets: 'S', disputes: 'D', reports: 'REP' } as Row)[kind] || kind.slice(0, 2).toUpperCase(); val.id = id(prefix); if (kind === 'tasks') { val.status = 'MATCHING'; val.payment = 'PENDING'; val.history = [{ status: 'MATCHING', actor: role, at: stamp() }]; val.partnerId = ''; } if (kind === 'refunds') val.status = 'PENDING'; if (kind === 'tickets') val.status = 'OPEN'; if (kind === 'vouchers') { val.uses = 0; val.active = val.active ?? true; } if (kind === 'partners') { val.kyc = 'PENDING'; val.skills = val.skills || []; val.status = 'ACTIVE'; val.availability = '08:00–18:00'; val.online = false; } if (['customers', 'partners'].includes(kind)) { val.points = val.points || 0; val.bookings = 0; val.status = 'ACTIVE'; } if (kind === 'services') { val.active = val.active ?? true; } if (kind === 'staff') val.status = 'ACTIVE'; items.unshift(val); if (kind === 'tasks') { next.payments.unshift({ id: id('PM'), taskId: val.id, customerId: val.customerId, amount: Number(val.total) || 0, status: 'PENDING', method: 'Sandbox (demo)', created: today(), providerRef: id('SIM') }) } if (kind === 'partners') next.kycs.unshift({ id: id('K'), partnerId: val.id, status: 'PENDING', submitted: today(), type: 'CCCD + Selfie', note: '' }); }
    else { const index = items.findIndex((x: Row) => x.id === row.id); if (index < 0) return; items[index] = { ...items[index], ...val }; if (kind === 'partners') { const k = next.kycs.find((x: Row) => x.partnerId === row.id); if (k) k.status = val.kyc || k.status } }
    record(next, role, row ? 'EDIT' : 'CREATE', kind, val.id, row ? 'Cập nhật hồ sơ' : 'Tạo bản ghi'); setDb(next); setForm(null); notify(row ? 'Đã cập nhật' : 'Đã thêm thành công')
  }
  function itemAction(kind: string, row: Row, key: string) {
    if (kind === 'partners' && key === 'SUSPEND_TASKER') {
      if (savingCustomer || !row.application_id) return;
      const reason = window.prompt('Lý do tạm ngưng Tasker để kiểm tra tài khoản:', 'Tạm ngưng quyền nhận việc để kiểm tra thông tin tài khoản.');
      if (!reason?.trim()) return;
      setSavingCustomer(true);
      void (async () => {
        const base = `/api/admin/recruitment/applications/${row.application_id}`;
        const detailResponse = await fetch(`${base}/dossier`, { cache: 'no-store', signal: AbortSignal.timeout(25000) });
        const detail = await detailResponse.json();
        if (!detailResponse.ok) throw new Error(detail.error || 'Không tải được hồ sơ Partner.');
        const response = await fetch(`${base}/final-decision`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, signal: AbortSignal.timeout(25000), body: JSON.stringify({ version: detail.data.application.version, requestId: crypto.randomUUID(), action: 'SUSPEND', reason: reason.trim(), requiredChanges: [] }) });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Không thể tạm ngưng Tasker.');
        await onRefreshCustomers(); setSelected(null); notify('Đã tạm ngưng Tasker và gửi thông báo cho Partner.');
      })().catch(e => notify(e.message)).finally(() => setSavingCustomer(false));
      return;
    }
    if (['customers', 'partners'].includes(kind) && key === 'RESTRICT') {
      if (savingCustomer) return;
      setConfirm({
        title: row.status === 'ACTIVE' ? 'Khóa customer?' : 'Mở khóa customer?', message: 'Thay đổi này áp dụng cho tài khoản chung trên cả Customer và Partner.', go: () => {
          setSavingCustomer(true); void onUpdateCustomer(row.id, { status: row.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE' }).then(() => notify('Đã cập nhật trạng thái trên máy chủ.')).catch(e => notify(e.message)).finally(() => setSavingCustomer(false));
        }
      }); return;
    }
    const r = Object.keys(ROUTE_KIND).find(x => ROUTE_KIND[x] === kind) || kind; attempt(r, () => {
      if (key === 'edit') { openForm(kind, row); return }
      if (kind === 'kycs' && ['APPROVED', 'REJECTED', 'PENDING'].includes(key)) { change(changeKyc(db, row.id, key, role, key === 'REJECTED' ? 'Vui lòng bổ sung giấy tờ rõ nét' : ''), 'Cập nhật KYC: ' + key); return }
      if (kind === 'tasks' && key === 'NEXT') { withRecord('Chuyển trạng thái', 'Task', row.id, () => advance(db, row.id, role)); return }
      if (kind === 'tasks' && key === 'CANCELLED') { withRecord('Hủy việc', 'Task', row.id, () => cancelTask(db, row.id, role)); return }
      if (kind === 'tasks' && key === 'REMATCH') { if (['PAID', 'REFUNDED', 'DISPUTED', 'COMPLETED', 'CANCELLED'].includes(row.status)) throw Error('Không thể rematch trạng thái này'); update(d => { let t = d.tasks.find((x: Row) => x.id === row.id); t.partnerId = ''; t.status = 'MATCHING'; t.history.push({ status: 'MATCHING', actor: role, at: stamp() }) }, 'REMATCH', 'Task', row.id, 'Đã đưa công việc về trạng thái chờ phân công'); return }
      if (kind === 'refunds' && key === 'APPROVED') { withRecord('Duyệt hoàn tiền', 'Refund', row.id, () => refund(db, row.id, role)); return }
      if (kind === 'disputes' && key === 'REFUND') { const t = db.tasks.find((x: Row) => x.id === row.taskId); const p = db.payments.find((x: Row) => x.taskId === row.taskId); if (!t || !p) throw Error('Không có thanh toán'); update(d => { d.refunds.unshift({ id: id('RF'), taskId: t.id, paymentId: p.id, amount: Math.min(Number(row.amount) || p.amount, p.amount), reason: row.reason, status: 'PENDING', created: today() }); d.disputes.find((x: Row) => x.id === row.id).status = 'REVIEW' }, 'DISPUTE_REFUND', 'Dispute', row.id, 'Tạo yêu cầu refund'); navigate('refunds'); return }
      if (kind === 'tickets' && key === 'ASSIGN') { update(d => { let t = d.tickets.find((x: Row) => x.id === row.id); t.agent = role; t.status = 'IN_PROGRESS' }, 'ASSIGN_TICKET', 'Ticket', row.id, 'Đã nhận ticket'); return }
      if (kind === 'campaigns' && key === 'SEND') { update(d => { let c = d.campaigns.find((x: Row) => x.id === row.id); c.status = 'SENT'; c.sent = c.audience === 'Partners' ? d.partners.length : c.audience === 'Customers' ? d.customers.length : d.partners.length + d.customers.length }, 'SEND_DEMO', 'Campaign', row.id, 'Đã mô phỏng gửi campaign'); return }
      if (kind === 'payouts' && key === 'COMPLETED' && row.status !== 'APPROVED') throw Error('Phải duyệt payout trước');
      update(d => {
        let v = d[kind].find((x: Row) => x.id === row.id); if (key === 'TOGGLE') { v.active = !v.active; } else if (key === 'VISIBLE') { v.visible = !v.visible; } else if (key === 'ONLINE') { v.online = !v.online; } else if (key === 'RESTRICT') { v.status = v.status === 'ACTIVE' ? 'RESTRICTED' : 'ACTIVE'; } else if (key === 'SUSPEND') { v.status = v.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE'; } else if (key === 'RESOLVE') { v.status = v.status === 'RESOLVED' ? 'OPEN' : 'RESOLVED'; } else if (key === 'PAUSE') { v.status = v.status === 'ACTIVE' ? 'PAUSED' : 'ACTIVE'; } else if (key === 'REPORT') { v.reported = !v.reported; } else v.status = key;
        if (kind === 'payments') { let t = d.tasks.find((x: Row) => x.id === v.taskId); if (t) t.payment = v.status; if (key === 'RELEASED') { if (t && t.status === 'COMPLETED') t.status = 'PAID'; d.ledger.unshift({ id: id('LG'), kind: 'RELEASE', taskId: v.taskId, amount: v.amount, from: 'Escrow demo', to: t?.partnerId || 'Partner', at: stamp(), status: 'RELEASED' }); } }
        if (kind === 'payouts' && key === 'COMPLETED') d.ledger.unshift({ id: id('LG'), kind: 'PAYOUT', taskId: '—', amount: v.amount, from: 'TaskLy demo', to: v.partnerId, at: stamp(), status: 'COMPLETED' });
      }, key, kind, row.id)
    })
  }
  const summary = useMemo(() => { let pending = db.kycs.filter((k: Row) => k.status === 'PENDING').length; let active = db.tasks.filter((t: Row) => ['MATCHING', 'ACCEPTED', 'TASKER_ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED'].includes(t.status)).length; let released = db.payments.filter((p: Row) => p.status === 'RELEASED').reduce((a: number, x: Row) => a + Number(x.amount), 0); return { pending, active, released, matching: db.tasks.filter((t: Row) => t.status === 'MATCHING').length, issues: db.tasks.filter((t: Row) => ['DISPUTED', 'CANCELLED'].includes(t.status)).length, partnerOnline: db.partners.filter((p: Row) => p.status === 'ACTIVE' && p.kyc === 'APPROVED' && p.online).length } }, [db]);
  const selectedItem = selected ? db[selected.kind]?.find((x: Row) => x.id === selected.id) : null;
  const isCatalogue = route === 'tasks' || route === 'tickets' || route === 'categories' || route === 'services' || route === 'banners' || route === 'community' || route.startsWith('recruitment');
  const view = <React.Fragment>{renderModule()}</React.Fragment>;
  return <div className="app-frame">
    {menuOpen && <div className="mobile-overlay" onClick={() => setMenuOpen(false)} />}
    <aside className={'sidebar ' + (menuOpen ? 'show' : '')}>
      <div className="brand"><div className="brand-icon"><Sparkles size={24} strokeWidth={2.5} /></div><div><strong>TaskLy <span>Admin</span></strong><small>COMMAND CENTER <i>• ADMIN</i></small></div></div>
      <div className="admin-portal-tabs" role="tablist" aria-label="Ứng dụng quản lý">{(['customer','partner'] as AdminPortal[]).map(item=><button key={item} role="tab" aria-selected={portal===item} className={portal===item?'selected '+item:''} onClick={()=>switchPortal(item)}>{item==='customer'?'Customer':'Partner'}</button>)}</div>
      <div className={'workspace-label portal-'+portal}><span className="workspace-logo">{portal==='customer'?'C':'P'}</span><div><b>TaskLy {portal==='customer'?'Customer':'Partner'}</b><small>{portal==='customer'?'Khách hàng & dịch vụ':'Tuyển dụng & đối tác'}</small></div></div>
      <div className="nav-scroller" key={portal}>{navigationForPortal(NAV,portal).map(([group, items]) => <div className="nav-group" key={group}><div className="nav-heading">{group}</div>{items.map(([key, , label]) => { const Icon = NAV_ICONS[key] || FileText; return <button key={key} className={'nav-link ' + (route === key ? 'active' : '')} onClick={() => navigate(key)}><Icon size={18} /><span>{label}</span>{route === key && <span className="active-dot" />}</button> })}</div>)}</div>
      <div className="side-bottom"><div className="system-online"><span className="live-dot" /><div><b>Customers API</b><small>Dữ liệu từ máy chủ</small></div><span className="mini-ring" /></div><div className="side-profile"><div className="initials">AD</div><div><b>{adminName || 'Admin'}</b><small>{role.replaceAll('_', ' ')}</small></div><MoreHorizontal size={18} /></div></div>
    </aside>
    <div className="main-area">
      <header className="topbar"><div className="top-left"><button className="icon-button mobile-trigger" aria-label="Mở menu" onClick={() => setMenuOpen(true)}><Menu size={21} /></button><div className="breadcrumbs"><span>TaskLy</span><ChevronRight size={15} /><b>{HEADINGS[route]?.[0]}</b></div></div><div className="top-right"><div className="top-search"><Search size={17} /><input value={q} onChange={e => setQ(e.target.value)} placeholder="Tìm trong trang..." aria-label="Tìm kiếm" /><kbd>⌘ K</kbd></div><span className="badge green">ADMIN</span><button className="btn btn-outline" onClick={() => void onLogout().catch(e => notify(e.message))}>Đăng xuất</button><button className="icon-button notify-icon" onClick={() => setNotifs(!notifs)} aria-label="Thông báo"><Bell size={20} /><span /></button><div className="top-avatar">A</div></div></header>
      {notifs && <div className="notif-pop"><b>Trung tâm thông báo demo</b><p>{summary.pending} hồ sơ KYC cần duyệt</p><p>{summary.matching} công việc đang chờ Matching</p><p>{db.tickets.filter((x: Row) => x.status === 'OPEN').length} ticket mới</p><button onClick={() => { setNotifs(false); navigate('operations') }}>Đến Operations →</button></div>}
      <main className={'workspace' + (isCatalogue ? ' catalogue-workspace' : '')}>
        <div className={'page-header' + (isCatalogue ? ' catalogue-page-header' : '')}>
          <div>
            <div className="eyebrow">{isCatalogue ? 'TASKLY / ' + route.toUpperCase() : <><span className="live-dot" /> TASKLY OPERATIONS / ADMIN PLATFORM</>}</div>
            <h1>{route === 'categories' ? 'Category & Booking Forms' : HEADINGS[route]?.[0]}</h1>
            <p>{route === 'categories' ? 'Cấu hình danh mục và biểu mẫu riêng cho từng loại dịch vụ.' : HEADINGS[route]?.[1]}</p>
          </div>
          {!isCatalogue && <div className="header-buttons"><button className="btn btn-outline" disabled={customerLoading} onClick={() => void onRefreshCustomers().catch(e => notify(e.message))}><RefreshCw size={16} />Tải lại Customers</button></div>}
        </div>
        {!isCatalogue && customerError && <div role="alert" className="api-error">{customerError}</div>}
        {['customers', 'partners'].includes(route) && customerLoading && <div className="notice">Đang tải Customers từ máy chủ…</div>}
        {!isCatalogue && !['customers', 'partners'].includes(route) && <div className="notice">Customers, Partners, danh mục và dịch vụ phổ biến dùng API thật. Các module khác đang sử dụng dữ liệu mô phỏng.</div>}
        {viewClassic ? <div className="original-panel"><div className="notice">Chế độ tham chiếu: mở bản HTML Admin nguyên bản để so sánh toàn bộ tính năng và bố cục. Chế độ này lưu dữ liệu riêng với React dashboard.</div><iframe title="TaskLy Admin HTML original" src="/reference/admin-original.html" /></div> : view}
      </main>
    </div>
    {selected && selectedItem && (
      selected.kind === 'partners' ? (
        <PartnerDetailModal
          key={selectedItem.id}
          partner={selectedItem}
          initialEdit={partnerEditMode}
          onSaved={() => {onRefreshCustomers();notify('Đã lưu thông tin Partner.');}}
          onClose={() => setSelected(null)}
          onUpdatePartner={onUpdateCustomer}
          onAction={(item, action) => itemAction('partners', item, action)}
          onEditPartner={(partner) => openForm('partners', partner)}
          saving={savingCustomer}
        />
      ) : selected.kind === 'customers' ? (
        <CustomerDetailModal
          key={selectedItem.id}
          customer={selectedItem}
          tasks={db.tasks}
          onClose={() => setSelected(null)}
          onUpdateCustomer={onUpdateCustomer}
          onAction={(item, action) => itemAction('customers', item, action)}
          onEditCustomer={(customer) => openForm('customers', customer)}
          onSelectTask={(taskId) => {
            const t = db.tasks.find((x: any) => x.id === taskId);
            if (t) goDetail('tasks', t);
          }}
          saving={savingCustomer}
        />
      ) : (
        <div className="shade" onMouseDown={e => { if (e.target === e.currentTarget) setSelected(null) }}><div className="drawer"><div className="drawer-header"><div><span className="eyebrow">CHI TIẾT BẢN GHI</span><h2>{selectedItem.name || selectedItem.title || selectedItem.subject || selectedItem.code || selectedItem.id}</h2><Badge value={selectedItem.status || selectedItem.kyc || 'ACTIVE'} /></div><button className="icon-button" onClick={() => setSelected(null)}><X size={20} /></button></div><div className="drawer-body"><div className="detail-grid">{Object.entries(selectedItem).filter(([k]) => !['history', 'description', 'skills', 'reply', 'partner_checks', 'review_reason'].includes(k) && (selected.kind !== 'partners' || !['id','application_id','userId','user_id','language','areaIds','serviceIds','referral','transport'].includes(k))).map(([k, v]) => <div key={k} className="detail-tile"><small>{LABEL[k] || k}</small><strong>{typeof v === 'object' ? JSON.stringify(v) : showField(db, k, v)}</strong></div>)}</div>{selected.kind==='partners'&&<PartnerChecks values={selectedItem.partner_checks} reason={selectedItem.review_reason}/>} {selectedItem.history && <div className="history"><h3>Lịch sử trạng thái</h3>{selectedItem.history.map((h: Row, i: number) => <div key={i}><span className="live-dot" /><b>{STATUS[h.status] || h.status}</b><small>{h.actor} · {h.at}</small></div>)}</div>}</div><div className="drawer-actions">{renderActions(selected.kind, selectedItem)}<button className="btn btn-ghost" onClick={() => setSelected(null)}>Đóng</button></div></div></div>
      )
    )}
    {form && <div className="shade" onMouseDown={e => { if (e.target === e.currentTarget) setForm(null) }}><div className="form-modal"><div className="drawer-header"><div><span className="eyebrow">{['customers', 'partners'].includes(form.kind) ? 'CUSTOMER API' : 'MOCK DATA EDITOR'}</span><h2>{form.row ? 'Chỉnh sửa' : 'Tạo mới'} {form.kind}</h2></div><button className="icon-button" onClick={() => setForm(null)}><X /></button></div><div className="form-body"><div className="form-grid">{(['customers', 'partners'].includes(form.kind) ? ['name', 'phone'] : (FIELDS[form.kind] || Object.keys(form.row || {}))).filter(f => f !== 'id' && f !== 'history' && f !== 'created' && f !== 'submitted' && f !== 'last').map(field => <label className="field" key={field}><span>{LABEL[field] || field}</span>{typeof (formValues[field] ?? SEED[form.kind]?.[0]?.[field]) === 'boolean' ? <input type="checkbox" checked={!!formValues[field]} onChange={e => setFormValues({ ...formValues, [field]: e.target.checked })} /> : field === 'serviceId' || field === 'customerId' || field === 'partnerId' || OPTIONS[field] ? <select value={formValues[field] ?? ''} onChange={e => setFormValues({ ...formValues, [field]: e.target.value })}><option value="">— Chọn —</option>{(field === 'serviceId' ? db.services : field === 'customerId' ? db.customers : field === 'partnerId' ? db.partners : (OPTIONS[field] || [])).map((o: any) => <option key={typeof o === 'string' ? o : o.id} value={typeof o === 'string' ? o : o.id}>{typeof o === 'string' ? o : o.name}</option>)}</select> : <input type={DATE_FIELDS.has(field) ? 'date' : NUMBER_FIELDS.has(field) ? 'number' : 'text'} value={typeof formValues[field] === 'object' ? (formValues[field] || []).join(', ') : formValues[field] ?? ''} onChange={e => setFormValues({ ...formValues, [field]: e.target.value })} />}</label>)}</div><div className="notice">{['customers', 'partners'].includes(form.kind) ? 'Họ tên và số điện thoại được lưu vào tài khoản thật trên máy chủ.' : 'Dữ liệu mẫu được lưu vào trình duyệt.'}</div></div><div className="drawer-actions"><button className="btn btn-ghost" onClick={() => setForm(null)}>Hủy</button><button className="btn btn-primary" disabled={savingCustomer} onClick={commitForm}><Check size={17} />Lưu thông tin</button></div></div></div>}
    {confirm && <div className="shade"><div className="confirm"><AlertTriangle size={32} color="#e18a17" /><h2>{confirm.title}</h2><p>{confirm.message}</p><div className="row"><button className="btn btn-outline" onClick={() => setConfirm(null)}>Quay lại</button><button className="btn btn-primary" onClick={() => { confirm.go(); setConfirm(null) }}>Xác nhận</button></div></div></div>}
    {route !== 'tickets' && <div className="admin-chat-launcher">
      {<section style={{display:supportChatOpen?undefined:'none'}} className="admin-chat-popover" aria-label="Hộp chat chăm sóc khách hàng">
        <header className="admin-chat-popover-heading"><strong><span className="live-dot" />Chăm sóc khách hàng</strong><button className="icon-button" aria-label="Đóng hộp chat" onClick={() => setSupportChatOpen(false)}><X size={18}/></button></header>
        <SupportAdmin visible={supportChatOpen} onUnreadChange={(count,name)=>{setSupportUnread(count);setSupportSender(name);}} onNewMessage={()=>notify('Có tin nhắn CSKH mới')} onClose={() => setSupportChatOpen(false)} />
      </section>}
      {!supportChatOpen&&supportUnread>0&&<button className="admin-chat-alert" onClick={()=>setSupportChatOpen(true)} aria-live="polite">{supportSender}: có {supportUnread} tin nhắn chưa đọc</button>}
      <button className="admin-chat-fab" aria-label={supportChatOpen ? 'Thu nhỏ hộp chat' : 'Mở hộp chat'} title={supportUnread>0 ? `${supportUnread} tin nhắn CSKH chưa đọc` : 'Hộp chat chăm sóc khách hàng'} onClick={() => setSupportChatOpen(open => !open)}><MessageSquare size={25}/>{supportUnread>0&&<span className="admin-chat-count">{supportUnread>99?'99+':supportUnread}</span>}</button>
    </div>}
    {toast && <div className="toast"><CheckCircle2 size={18} />{toast}</div>}
  </div>;

  function kpi(name: string, value: any, icon: React.ReactNode, sub: string, tone = 'green') { return <div className="kpi-card"><div className="kpi-top"><span>{name}</span><div className={'kpi-icon ' + tone}>{icon}</div></div><strong>{value}</strong><small>{sub}</small></div> }
  function btn(label: string, onClick: () => void, kind = 'outline') { return <button className={'btn btn-' + kind} onClick={onClick}>{label}</button> }
  function goDetail(kind: string, item: Row) { setPartnerEditMode(false); setSelected({ kind, id: item.id }) }
  function sectionTitle(title: string, desc?: string, action?: React.ReactNode) { return <div className="section-head"><div><h2>{title}</h2>{desc && <p>{desc}</p>}</div>{action}</div> }
  function renderModule(): React.ReactNode {
    if (route === 'tasks') return <TaskAdmin query={q} />;
    if (route === 'tickets') return <SupportAdmin fullPage />;
    if (route === 'banners') return <BannerAdmin />;
    if (route === 'community') return <CommunityAdmin />;
    if (route.startsWith('recruitment')) return <RecruitmentAdmin key={route} initialTab={route==='recruitment-areas'?'areas':route==='recruitment-exam'?'exam':route==='recruitment-uniforms'?'uniforms':'applications'} />;
    if (route === 'categories' || route === 'services') return <CatalogueAdmin mode={route} />;
    if (route === 'daily-milestones') return <DailyMilestonesAdmin />;
    if (route === 'payments') return <DepositWithdrawAdmin
      key={route + portal}
      role={portal === 'partner' ? 'PARTNER' : 'CUSTOMER'}
      db={db}
      customers={db.customers}
      partners={db.partners}
      onNotify={notify}
      onRefreshParent={onRefreshCustomers}
    />;
    if (route === 'payouts') return <DepositWithdrawAdmin
      key={route}
      role="PARTNER"
      db={db}
      customers={db.customers}
      partners={db.partners}
      initialTab="WITHDRAWAL"
      onNotify={notify}
      onRefreshParent={onRefreshCustomers}
    />;
    if (route === 'partners') return <PartnerAdmin
      partners={db.partners}
      loading={customerLoading}
      onRefresh={onRefreshCustomers}
      onUpdatePartner={onUpdateCustomer}
      onAction={(item, action) => itemAction('partners', item, action)}
      onNavigate={navigate}
      saving={savingCustomer}
      onEditPartner={(partner) => openForm('partners', partner)}
    />;
    if (route === 'customers') return <CustomerAdmin
      customers={db.customers}
      tasks={db.tasks}
      loading={customerLoading}
      onRefresh={onRefreshCustomers}
      onUpdateCustomer={onUpdateCustomer}
      onAction={(item, action) => itemAction('customers', item, action)}
      onNavigate={navigate}
      saving={savingCustomer}
      onEditCustomer={(customer) => openForm('customers', customer)}
      onSelectTask={(taskId) => {
        const t = db.tasks.find((x: any) => x.id === taskId);
        if (t) goDetail('tasks', t);
      }}
    />;
    if (route === 'dashboard') return dashboard(); if (route === 'operations') return operations(); if (route === 'analytics') return analytics(); if (route === 'rewards') return rewards(); if (route === 'permissions') return <div className="panel"><h2>Vai trò Admin</h2><p>Dashboard chỉ có một vai trò Admin. Quyền đăng nhập và truy cập Customers được kiểm tra tại máy chủ.</p></div>; if (route === 'settings') return settings(); if (route === 'integrations') return integrations(); if (route === 'datalab') return datalab();
    const kind = ROUTE_KIND[route]; return kind ? listing(route, kind) : <div className="empty">Không tìm thấy module</div>
  }
  function dashboard() {
    const bar = [32, 45, 37, 60, 56, 72, 68, 81, 63, 86, 74, 92]; return <>
      <div className="welcome-banner"><div><div className="welcome-tag"><Sparkles size={15} /> TASKLY COMMAND CENTER</div><h2>Chào mừng trở lại, Admin <span>✳</span></h2><p>Hệ thống đang hoạt động tốt. Đây là tổng quan dữ liệu mẫu của hai ứng dụng Customer & Partner.</p><div className="welcome-actions"><button onClick={() => navigate('operations')}>Mở Operations <ArrowRight size={17} /></button><button onClick={() => navigate('analytics')}>Xem báo cáo</button></div></div><div className="welcome-visual"><div className="float-card fc-one"><CheckCircle2 size={18} /> <span>Đơn hàng ổn định</span></div><div className="circle-main"><Activity size={62} strokeWidth={1.7} /></div><div className="float-card fc-two"><TrendingUp size={17} /> <span>Real-time demo</span></div></div></div>
      <div className="kpi-grid">{kpi('Tổng khách hàng', db.customers.length, <Users size={23} />, 'Tài khoản thật từ API')}{kpi('Partner khả dụng', db.partners.filter((x: Row) => x.kyc === 'APPROVED' && x.status === 'ACTIVE').length, <ShieldCheck size={23} />, `${summary.partnerOnline} người đang online`, 'blue')}{kpi('Công việc cần xử lý', summary.active, <ClipboardCheck size={23} />, `${summary.matching} đang chờ Matching`, 'amber')}{kpi('Giải ngân mô phỏng', money(summary.released), <Wallet size={23} />, 'Số liệu mẫu, không phải tiền thật', 'purple')}</div>
      <div className="dashboard-grid"><div className="panel chart-panel">{sectionTitle('Xu hướng đặt dịch vụ', '12 kỳ minh họa • không phải dữ liệu lịch sử thật', <button className="btn btn-outline" onClick={() => navigate('analytics')}>Chi tiết <ChevronRight size={15} /></button>)}<div className="bar-chart">{bar.map((v, i) => <div key={i} className="bar-column"><div className="bar-track"><div style={{ height: v + '%' }} className={'bar-fill ' + (i === 11 ? 'selected' : '')} /></div><span>T{i + 1}</span></div>)}</div></div><div className="panel"><h2>Phân bố trạng thái</h2><p className="subtle">Tổng số: {db.tasks.length} công việc</p><div className="donut-wrap"><div className="donut" style={{ background: `conic-gradient(#0da981 0 ${Math.round(db.tasks.filter((x: Row) => x.status === 'PAID').length / db.tasks.length * 100)}%,#4b8de8 0 48%,#f2b156 48% 80%,#dfeae7 80% 100%)` }}><div><b>{db.tasks.length}</b><small>Công việc</small></div></div><div className="donut-legend"><span><i style={{ background: '#0da981' }} /> Hoàn tất</span><span><i style={{ background: '#4b8de8' }} /> Đang làm</span><span><i style={{ background: '#f2b156' }} /> Cần xử lý</span><span><i style={{ background: '#dfeae7' }} /> Khác</span></div></div></div></div>
      <div className="dashboard-grid"><div className="panel">{sectionTitle('Công việc cần chú ý', 'Các tác vụ có thể cần can thiệp', <button className="text-link" onClick={() => navigate('tasks')}>Xem tất cả <ChevronRight size={15} /></button>)}<div className="list-stack">{db.tasks.filter((t: Row) => ['MATCHING', 'POSTED', 'COMPLETED', 'DISPUTED'].includes(t.status)).slice(0, 6).map((t: Row) => <button key={t.id} className="queue-item" onClick={() => goDetail('tasks', t)}><div className="task-avatar"><ClipboardCheck size={19} /></div><div className="queue-main"><b>{t.id} · {taskService(db, t)}</b><small>{taskCustomer(db, t)} • {t.location}</small></div><Badge value={t.status} /><ChevronRight size={17} /></button>)}</div></div><div className="panel">{sectionTitle('Hàng đợi ưu tiên', 'Các hạng mục cần xử lý hôm nay')}<div className="priority-list">{[['Duyệt KYC', summary.pending, 'kyc', ShieldCheck], ['Matching', summary.matching, 'matching', Search], ['Ticket mới', db.tickets.filter((x: Row) => x.status === 'OPEN').length, 'tickets', MessageSquare], ['Tranh chấp', db.disputes.filter((x: Row) => x.status !== 'RESOLVED').length, 'disputes', AlertTriangle]].map(([title, num, to, Icon]: any) => <button key={to} onClick={() => navigate(to)}><span className="priority-icon"><Icon size={19} /></span><b>{title}</b><strong>{num}</strong><ChevronRight size={17} /></button>)}</div></div></div>
    </>
  }
  function operations() {
    const cols = [['MATCHING', 'Đang tìm Partner', '#f5ac45'], ['ACCEPTED', 'Đã nhận việc', '#4c86da'], ['IN_PROGRESS', 'Đang thực hiện', '#18a986'], ['COMPLETED', 'Chờ xác nhận', '#9284d9']]; return <>{<div className="kpi-grid">{kpi('Matching', summary.matching, <Search size={22} />, 'Cần điều phối')}{kpi('Đang làm', db.tasks.filter((x: Row) => x.status === 'IN_PROGRESS').length, <Zap size={22} />, 'Trong quá trình xử lý', 'blue')}{kpi('Chờ xác nhận', db.tasks.filter((x: Row) => x.status === 'COMPLETED').length, <ClipboardCheck size={22} />, 'Chờ Customer', 'amber')}{kpi('Tranh chấp', db.tasks.filter((x: Row) => x.status === 'DISPUTED').length, <AlertTriangle size={22} />, 'Cần hỗ trợ', 'purple')}</div>}
      {sectionTitle('Live Operations Board', 'Quản lý các công việc theo luồng vận hành', <button className="btn btn-primary" onClick={() => openForm('tasks')}><Plus size={16} /> Tạo đơn demo</button>)}
      <div className="kanban">{cols.map(([status, title, color]) => <div className="kanban-col" key={status}><div className="kanban-head"><span className="kdot" style={{ background: color }} />{title}<b>{db.tasks.filter((x: Row) => x.status === status).length}</b></div>{db.tasks.filter((x: Row) => x.status === status).map((t: Row) => <button className="kanban-card" key={t.id} onClick={() => goDetail('tasks', t)}><div className="row between"><small className="mono">{t.id}</small><MoreHorizontal size={17} /></div><h4>{taskService(db, t)}</h4><p>{taskCustomer(db, t)}</p><div className="kanban-meta"><MapPin size={14} /> {t.location}</div><div className="kanban-bottom"><strong>{money(t.total)}</strong><span>{t.time}</span></div></button>)}{!db.tasks.some((x: Row) => x.status === status) && <div className="kanban-empty">Chưa có công việc</div>}</div>)}</div>
      <div className="panel mt-22"><div className="row between"><div><h2>Điều phối nhanh</h2><p className="subtle">Xem hàng đợi Partner hoặc toàn bộ task</p></div><div className="row">{btn('Toàn bộ công việc', () => navigate('tasks'), 'primary')}</div></div></div>
    </>
  }
  function analytics() { const counts = db.services.map((s: Row) => ({ ...s, count: db.tasks.filter((t: Row) => t.serviceId === s.id).length })); const max = Math.max(...counts.map((x: Row) => x.count), 1); return <>{sectionTitle('Phân tích dữ liệu mẫu', 'Số liệu được tổng hợp từ MockStore • xu hướng theo thời gian là minh họa', <div className="row">{['7 ngày', '30 ngày', '90 ngày'].map(x => <button key={x} className={'btn ' + (range === x ? 'btn-primary' : 'btn-outline')} onClick={() => setRange(x)}>{x}</button>)}{btn('Xuất CSV', () => downloadFile('taskly-tasks.csv', csv(db.tasks), 'text/csv'))}</div>)}<div className="kpi-grid">{kpi('Tổng số booking', db.tasks.length, <ClipboardCheck size={20} />, 'Tất cả dữ liệu mock')}{kpi('Tỷ lệ hoàn tất', Math.round(db.tasks.filter((x: Row) => x.status === 'PAID').length / Math.max(db.tasks.length, 1) * 100) + '%', <TrendingUp size={20} />, 'Đã giải ngân trên tổng số', 'blue')}{kpi('Tổng giá trị đơn', money(db.tasks.reduce((a: number, t: Row) => a + Number(t.total), 0)), <CreditCard size={20} />, 'Không phải doanh thu thực', 'amber')}{kpi('Khách hàng', db.customers.length, <Users size={20} />, 'Trong mô hình thử nghiệm', 'purple')}</div><div className="panel mt-22"><h2>Dịch vụ được đặt nhiều</h2><p className="subtle">Thống kê từ mảng công việc hiện tại</p><div className="analysis-bars">{counts.map((s: Row) => <div className="analysis-row" key={s.id}><span>{s.icon} {s.name}</span><div className="progress"><i style={{ width: (s.count / max * 100) + '%' }} /></div><b>{s.count}</b></div>)}</div></div></> }
  function listing(page: string, kind: string) { let items: Row[] = db[kind] || []; const filterField = kind==='partners'?'recruitment_status':'status'; let available = [...new Set(items.map(x => x[filterField]).filter(Boolean))]; if (filter !== 'ALL') items = items.filter(x => x[filterField] === filter); if (q.trim()) items = items.filter(x => JSON.stringify(x).toLowerCase().includes(q.trim().toLowerCase())); let cols = SORT_FIELDS[kind] || ['id', 'name', 'status']; const canCreate = !['customers', 'partners'].includes(kind) && !READ_ONLY.includes(kind); return <><div className="panel"><div className="list-head"><div><h2>{HEADINGS[page][0]}</h2><p className="subtle">{items.length} bản ghi • {['customers', 'partners'].includes(kind) ? 'dữ liệu từ máy chủ' : 'dữ liệu mô phỏng trong trình duyệt'}</p></div><div className="row"><div className="inline-search"><Search size={17} /><input value={q} onChange={e => setQ(e.target.value)} placeholder="Tìm kiếm bảng..." /></div>{canCreate && <button className="btn btn-primary" onClick={() => openForm(kind)}><Plus size={16} /> Tạo mới</button>}{kind === 'partners' && <button className="btn btn-outline" onClick={() => navigate('daily-milestones')}><Award size={15} /> Thưởng mốc đơn</button>}<button className="btn btn-outline" onClick={() => downloadFile('taskly-' + kind + '.csv', csv(items), 'text/csv')}><Download size={16} /> CSV</button></div></div>{available.length > 1 && <div className="filter-pills"><button className={filter === 'ALL' ? 'active' : ''} onClick={() => setFilter('ALL')}>Tất cả <small>{db[kind].length}</small></button>{available.map(v => <button className={filter === v ? 'active' : ''} key={v} onClick={() => setFilter(v)}>{partnerStatusLabels[v] || STATUS[v] || v}<small>{db[kind].filter((x: Row) => x[filterField] === v).length}</small></button>)}</div>}<div className="table-wrapper"><table><thead><tr>{cols.map(c => <th key={c}>{LABEL[c] || c}</th>)}<th>Thao tác</th></tr></thead><tbody>{items.map(item => <tr key={item.id}>{cols.map(c => <td key={c}>{c === 'name' || c === 'title' || c === 'subject' ? <div className="cell-person"><span>{String(item[c] || '?').slice(0, 1).toUpperCase()}</span><b>{item[c]}</b></div> : showField(db, c, item[c])}</td>)}<td><button className="table-action" onClick={() => goDetail(kind, item)}>Xem <ChevronRight size={16} /></button>{kind==='partners'&&<button className="table-action" onClick={()=>openForm(kind,item)}>Chỉnh sửa</button>}{kind === 'partners' && item.recruitment_status === 'ACTIVE' && item.application_id && <button className="table-action" disabled={savingCustomer} onClick={() => itemAction(kind, item, 'SUSPEND_TASKER')}>Tạm ngưng để kiểm tra</button>}</td></tr>)}{items.length === 0 && <tr><td colSpan={cols.length + 1} className="no-data">Không tìm thấy dữ liệu phù hợp</td></tr>}</tbody></table></div><div className="table-footer"><span>Hiển thị {items.length} / {db[kind]?.length || 0} bản ghi</span><span>{['customers', 'partners'].includes(kind) ? 'API TaskLy • Dữ liệu theo tài khoản' : 'Dữ liệu mô phỏng'}</span></div></div></> }
  function rewards() { return <><div style={{ display: 'flex', gap: 10, marginBottom: 18 }}><button className="btn btn-outline" style={{ background: '#ffffff', fontWeight: 800, borderColor: '#0b9879', color: '#0b9879' }}>Điểm khách hàng (TaskPoints)</button></div><div className="kpi-grid">{kpi('Tổng TaskPoints', db.customers.reduce((n: number, c: Row) => n + Number(c.points || 0), 0), <Gift size={20} />, 'Điểm mock hiện tại')}{kpi('Voucher hoạt động', db.vouchers.filter((x: Row) => x.active).length, <Gift size={20} />, 'Khuyến mãi', 'blue')}{kpi('Khách có điểm', db.customers.filter((x: Row) => x.points > 0).length, <Users size={20} />, 'Có ví Rewards', 'amber')}{kpi('Tỷ lệ đổi điểm', 'Demo', <BarChart3 size={20} />, 'Chưa có nghiệp vụ đổi thật', 'purple')}</div><div className="panel mt-22">{sectionTitle('Điều chỉnh điểm thưởng', 'Mỗi cập nhật ghi Audit Log')}{db.customers.map((c: Row) => <div className="reward-row" key={c.id}><div className="cell-person"><span>{c.name.slice(0, 1)}</span><b>{c.name}</b></div><strong>{c.points} điểm</strong><button className="btn btn-outline" onClick={() => attempt('rewards', () => { const x = prompt('Nhập số điểm cộng hoặc trừ:', '100'); if (x === null) return; const v = Number(x); if (!Number.isFinite(v) || c.points + v < 0) throw Error('Số điểm không hợp lệ'); update(d => { d.customers.find((u: Row) => u.id === c.id).points += v }, 'ADJUST_REWARDS', 'Customer', c.id, `${v >= 0 ? '+' : ''}${v} TaskPoints`) })}>Điều chỉnh</button></div>)}</div></> }
  function permissions() { let modules = ['customers', 'partners', 'tasks', 'matching', 'services', 'payments', 'refunds', 'payouts', 'tickets', 'disputes', 'reviews', 'banners']; return <div className="panel"><div className="notice">Ma trận này chỉ mô phỏng kiểm soát nút ở frontend. Hệ thống thật phải xác minh quyền tại backend.</div><div className="table-wrapper"><table className="permission-table"><thead><tr><th>Module</th>{ROLES.map(r => <th key={r}>{r}</th>)}</tr></thead><tbody>{modules.map(mod => <tr key={mod}><td><b>{HEADINGS[mod]?.[0] || mod}</b></td>{ROLES.map(r => <td key={r}>{can(r, mod) ? <CheckCircle2 size={18} color="#0d9d78" /> : <X size={17} color="#aab7b3" />}</td>)}</tr>)}</tbody></table></div></div> }
  function settings() { return <OperationsSettings notify={notify} />; }
  function integrations() { const arr = [['Spring Boot API', 'REST, JWT & RBAC', 'Chưa kết nối'], ['PostgreSQL', 'Dữ liệu tập trung và transaction', 'Chưa kết nối'], ['Redis/OTP', 'Cache, OTP và rate limiting', 'Chưa kết nối'], ['Email Service', 'SMTP và email OTP', 'Chưa kết nối'], ['Payments', 'Gateway + webhook', 'Chưa kết nối'], ['Object Storage', 'KYC, ảnh công việc và file', 'Chưa kết nối'], ['Maps & GPS', 'Geocoding và check-in', 'Chưa kết nối'], ['WebSocket / Push', 'Chat và thông báo real-time', 'Chưa kết nối']]; return <div className="integration-grid">{arr.map(([name, desc, status]) => <div className="panel integration-card" key={name}><span className="integration-icon"><Globe2 size={22} /></span><Badge value="NOT_CONNECTED" /><h3>{name}</h3><p>{desc}</p><small>{status} • Prototype mock</small></div>)}</div> }
  function datalab() { return <><div className="notice"><b>Data Lab:</b> dữ liệu lưu bằng localStorage. Import snapshot Mobile V3 chỉ ghép Task ID chưa trùng, không đồng bộ hai chiều và không đọc dữ liệu hai ứng dụng trực tiếp.</div><div className="lab-grid"><div className="panel lab-card"><div className="lab-icon"><Download size={26} /></div><h3>Sao lưu toàn bộ</h3><p>Tải JSON đầy đủ gồm Customers, Partners, Task, Finance, Marketing và Audit.</p><button className="btn btn-primary" onClick={() => downloadFile('taskly-admin-backup.json', JSON.stringify(db, null, 2), 'application/json')}><Download size={16} /> Tải JSON</button></div><div className="panel lab-card"><div className="lab-icon"><Upload size={26} /></div><h3>Nhập snapshot Mobile V3</h3><p>Đọc file JSON và nhập các công việc chưa tồn tại từ TaskLy Mobile HTML.</p><input type="file" ref={inputRef} accept="application/json,.json" onChange={async e => { let file = e.target.files?.[0]; if (!file) return; try { const snapshot = JSON.parse(await file.text()); guarded('datalab', () => { let result = importMobile(db, snapshot, role); change(result.next, 'Đã nhập ' + result.added + ' Task') }) } catch (err: any) { notify('⚠ ' + err.message) } e.target.value = '' }} hidden /><button className="btn btn-outline" onClick={() => inputRef.current?.click()}><Upload size={16} /> Chọn JSON</button></div><div className="panel lab-card"><div className="lab-icon"><FileText size={26} /></div><h3>Xuất báo cáo CSV</h3><p>Xuất công việc, thanh toán, thu nhập và nhật ký để đối chiếu.</p><div className="row">{['tasks', 'payments', 'ledger', 'audit'].map(k => <button className="btn btn-outline" key={k} onClick={() => downloadFile('taskly-' + k + '.csv', csv(db[k]), 'text/csv')}>{k}</button>)}</div></div><div className="panel lab-card"><div className="lab-icon"><RefreshCw size={26} /></div><h3>Reset toàn bộ</h3><p>Khôi phục dữ liệu mẫu như ban đầu. Không thể hoàn tác trong trình duyệt.</p><button className="btn btn-danger" onClick={() => setConfirm({ title: 'Khôi phục dữ liệu?', message: 'Toàn bộ chỉnh sửa local của Admin sẽ mất. Hãy xuất JSON nếu muốn lưu lại.', go: () => { setDb({ ...seedClone(), customers, partners }); notify('Đã reset dữ liệu demo') } })}>Reset dữ liệu demo</button></div></div><div className="panel mt-22"><h2>Chẩn đoán dữ liệu</h2><div className="diagnostics">{Object.entries(db).filter(([, x]) => Array.isArray(x)).map(([key, value]) => <div key={key}><b>{key}</b><span>{(value as any[]).length} records</span></div>)}</div></div></> }
  function renderActions(kind: string, item: Row) {
    const list: [string, string, boolean?][] = [];
    if (kind === 'partners' && item.recruitment_status === 'ACTIVE' && item.application_id) list.push(['Tạm ngưng để kiểm tra tài khoản', 'SUSPEND_TASKER']);
    if (!READ_ONLY.includes(kind) && kind !== 'audit' && kind !== 'ledger') list.push(['✎ Chỉnh sửa', 'edit']);
    if (['customers', 'partners'].includes(kind) && ['ACTIVE', 'SUSPENDED'].includes(item.status)) list.push([item.status === 'ACTIVE' ? 'Khóa tài khoản' : 'Mở khóa', 'RESTRICT']);
    
    if (kind === 'kycs') list.push(['Duyệt KYC', 'APPROVED'], ['Từ chối', 'REJECTED'], ['Xem lại', 'PENDING']);
    if (kind === 'tasks') list.push(['Tiếp theo →', 'NEXT'], ['Hủy', 'CANCELLED'], ['Rematch', 'REMATCH']);
    if (kind === 'refunds' && item.status === 'PENDING') list.push(['Duyệt hoàn tiền', 'APPROVED'], ['Từ chối', 'REJECTED']);
    if (kind === 'payouts') { if (item.status === 'PENDING') list.push(['Duyệt', 'APPROVED'], ['Từ chối', 'REJECTED']); if (item.status === 'APPROVED') list.push(['Đánh dấu đã chuyển', 'COMPLETED']); }
    if (kind === 'payments' && item.status === 'PENDING') list.push(['Đánh dấu HELD', 'HELD'], ['Thanh toán lỗi', 'FAILED']);
    if (kind === 'payments' && item.status === 'HELD') list.push(['Đối soát giải ngân', 'RELEASED'], ['Thanh toán lỗi', 'FAILED']);
    if (kind === 'disputes') list.push(['Đang xử lý', 'REVIEW'], ['Tạo Refund', 'REFUND'], ['Đóng tranh chấp', 'RESOLVED']);
    if (kind === 'tickets') list.push(['Nhận ticket', 'ASSIGN'], [item.status === 'RESOLVED' ? 'Mở lại' : 'Hoàn tất', 'RESOLVE']);
    if (kind === 'reviews') list.push([item.visible ? 'Ẩn đánh giá' : 'Hiện đánh giá', 'VISIBLE'], [item.reported ? 'Gỡ cờ' : 'Báo cáo', 'REPORT']);
    if (kind === 'reports') list.push(['Đang xử lý', 'IN_REVIEW'], ['Hoàn thành', 'RESOLVED']);
    if (kind === 'services' || kind === 'categories' || kind === 'banners' || kind === 'vouchers') list.push([item.active ? 'Tắt' : 'Bật', 'TOGGLE']);
    if (kind === 'campaigns' && item.status !== 'SENT') list.push(['Gửi thử (demo)', 'SEND']);
    if (kind === 'staff') list.push([item.status === 'ACTIVE' ? 'Vô hiệu hóa' : 'Kích hoạt', 'SUSPEND']);
    return <div className="action-wrap">{list.map(([label, key], i) => <button key={key} className={'btn ' + (i === 0 ? 'btn-primary' : 'btn-outline')} disabled={['customers', 'partners'].includes(kind) && savingCustomer} onClick={() => itemAction(kind, item, key)}>{label}</button>)}{list.length === 0 && <span className="subtle">Bản ghi chỉ đọc</span>}</div>
  }
}
