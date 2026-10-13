'use client';
import { useEffect, useMemo, useRef, useState } from 'react';
import {
  MapPin, Users, Plus, Trash2, Search, Filter, Edit3, CheckCircle2,
  XCircle, ToggleLeft, ToggleRight, ArrowLeft, ArrowRight, RefreshCw,
  Building2, Layers, CheckSquare, Square, AlertCircle, FileText,
  ShieldCheck, ShieldAlert, Award, Clock, Eye, Check, X, Phone, Mail,
  ChevronRight, Sparkles, AlertTriangle
} from 'lucide-react';
import CataloguePopup from './CataloguePopup';
import './catalogue-admin.css';
import './recruitment-admin.css';
import RecruitmentExamAdmin from './RecruitmentExamAdmin';
import RecruitmentConfigAdmin from './RecruitmentConfigAdmin';
import RecruitmentDossier, { type Dossier } from './RecruitmentDossier';
import { partnerStatusLabels } from './PartnerChecks';
import { VIETNAM_PROVINCES, ALL_CITY_NAMES, getRegion } from '@/lib/vietnam-locations';

type Area = {
  id: string;
  city: string;
  name: string;
  recruiting: boolean;
  capacity: number;
  version: number;
  serviceIds: string[];
};

type Application = {
  id: string;
  fullName: string;
  status: string;
  contactPhone?: string;
  version: number;
  updatedAt: string;
  reason: string;
  reviewReady?: boolean;
  eligibility?: Record<string, boolean>;
};

type Service = { id: string; name: string };
type Summary = {
  total: number;
  awaitingReview: number;
  overdueWorkingHours: number;
  openAppeals: number;
  failedEmailMocks: number;
  statuses: { status: string; total: number }[];
  generatedAt: string;
};

async function api(path: string, method = 'GET', body?: unknown) {
  const r = await fetch('/api/admin/recruitment/' + path, {
    method,
    cache: 'no-store',
    signal: AbortSignal.timeout(25000),
    headers: { 'Content-Type': 'application/json' },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const result = await r.json();
  if (!r.ok) throw new Error(result.error || 'Thao tác thất bại.');
  return result.data;
}

export default function RecruitmentAdmin({
  permissions,
  initialTab = 'applications',
}: {
  permissions?: string[];
  initialTab?: 'applications' | 'areas' | 'exam' | 'uniforms';
}) {
  const can = (permission: string) =>
    permissions === undefined || permissions.includes(permission);

  const [apps, setApps] = useState<Application[]>([]);
  const [portraits, setPortraits] = useState<Record<string, string>>({});
  useEffect(() => {
    let cancelled = false;
    if (permissions !== undefined && !permissions.includes('RECRUITMENT_FINAL')) return;
    void Promise.all(apps.map(async app => {
      const images = await api(`applications/${app.id}/final-documents`);
      return [app.id, images[0]?.portrait || ''] as const;
    })).then(entries => { if (!cancelled) setPortraits(Object.fromEntries(entries)); }).catch(() => { if (!cancelled) setPortraits({}); });
    return () => { cancelled = true; };
  }, [apps, permissions]);
  const [areas, setAreas] = useState<Area[]>([]);
  const [services, setServices] = useState<Service[]>([]);
  const [summary, setSummary] = useState<Summary | null>(null);

  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [areaFilter, setAreaFilter] = useState('');
  const [serviceFilter, setServiceFilter] = useState('');
  const requestSequence = useRef(0);

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [tab, setTab] = useState<string>(initialTab);

  // --- AREA MANAGEMENT STATE ---
  const [areaRegionFilter, setAreaRegionFilter] = useState<string>('Tất cả');
  const [areaCityFilter, setAreaCityFilter] = useState<string>('');
  const [areaSearchQuery, setAreaSearchQuery] = useState<string>('');
  const [areaStatusFilter, setAreaStatusFilter] = useState<string>('ALL');
  const [selectedAreaIds, setSelectedAreaIds] = useState<string[]>([]);
  const [editing, setEditing] = useState<Area | null>(null);
  const [areaPage, setAreaPage] = useState<number>(0);
  const AREA_PAGE_SIZE = 5;

  // Batch publish state

  // City area form (region and province/city).
  const [modalRegion, setModalRegion] = useState<string>('Miền Bắc');
  const [modalCity, setModalCity] = useState<string>('Hà Nội');

  // --- APPLICATION REVIEW STATE ---
  const [review, setReview] = useState<Application | null>(null);
  const [dossier, setDossier] = useState<Dossier | null>(null);
  const [finalImages, setFinalImages] = useState<Record<string, string> | null>(null);
  const [reason, setReason] = useState('');
  const [changes, setChanges] = useState('');
  const [decision, setDecision] = useState('REQUEST_CHANGES');
  const [sendingDecision, setSendingDecision] = useState(false);
  const [loadingReview, setLoadingReview] = useState(false);

  const [receivedItems, setReceivedItems] = useState<string[]>([]);
  const [originalsReturned, setOriginalsReturned] = useState(false);
  const [officeNotes, setOfficeNotes] = useState('');
  const [reviewMinutes, setReviewMinutes] = useState('60');
  const [reviewUnit, setReviewUnit] = useState<'minutes' | 'hours'>('minutes');
  const totalReviewMinutes = Number(reviewMinutes) * (reviewUnit === 'hours' ? 60 : 1);

  const decisionReasons: Record<string, string[]> = {
    APPROVE_PRELIMINARY: [
      'Thông tin cá nhân và CCCD đã được đối chiếu hợp lệ. Hồ sơ được phê duyệt sơ bộ; vui lòng chọn đồng phục và đặt lịch đối chiếu giấy tờ tại văn phòng.',
      'Bài thi đầu vào đã đạt và các cam kết hiện hành đã được chấp thuận. Hồ sơ được phê duyệt sơ bộ để chuyển sang bước làm thủ tục tại văn phòng.',
      'Hồ sơ đăng ký đã hoàn tất và đáp ứng điều kiện xét duyệt sơ bộ. Vui lòng chuẩn bị giấy tờ gốc để đối chiếu theo lịch hẹn.',
    ],
    REJECT_WITH_REASON: [
      'Thông tin đăng ký không khớp với giấy tờ định danh sau khi đối chiếu. Hồ sơ ứng tuyển bị từ chối.',
      'Giấy tờ định danh không hợp lệ sau khi kiểm tra. Hồ sơ ứng tuyển bị từ chối.',
      'Ứng viên chưa đáp ứng điều kiện độ tuổi tham gia. Hồ sơ ứng tuyển bị từ chối.',
    ],
    EXTEND_REVIEW: [
      'Cần thêm thời gian đối chiếu thông tin đăng ký với giấy tờ định danh trước khi kết luận.',
      'Đang xác minh thông tin với ứng viên; cần thêm thời gian để hoàn tất việc kiểm tra.',
      'Hồ sơ cần được kiểm tra thêm trước khi đưa ra quyết định xét duyệt sơ bộ.',
    ],
    APPROVE_FINAL: ['Giấy tờ gốc đã được đối chiếu, hồ sơ tại văn phòng đã tiếp nhận đầy đủ và thủ tục đồng phục đã hoàn tất. Phê duyệt chính thức và kích hoạt đối tác.'],
    REQUEST_CHANGES: ['Hồ sơ chưa được duyệt do thiếu thông tin. Vui lòng bổ sung các mục được liệt kê để gửi lại hồ sơ.', 'Thông tin hoặc ảnh giấy tờ chưa đủ rõ để đối chiếu. Vui lòng cập nhật các mục được yêu cầu và gửi lại hồ sơ.'],
    ESCALATE: ['Hồ sơ cần cấp quản lý xem xét thêm trước khi quyết định.'],
    SUSPEND: ['Tạm ngưng quyền nhận việc để kiểm tra việc tuân thủ quy định đối tác.'],
  };
  const canDecide = review && dossier && dossier.application.reviewReady &&
    ((['PRELIMINARY_REVIEW', 'ESCALATED'].includes(review.status) && can('RECRUITMENT_PRELIMINARY')) ||
     (['DOCUMENTS_RECEIVED', 'FINAL_REVIEW', 'ACTIVE'].includes(review.status) && can('RECRUITMENT_FINAL')));

  async function openReview(application: Application) {
    setLoadingReview(true);
    setBusy(true); setError('');
    try {
      const detail: Dossier = await api('applications/' + application.id + '/dossier');
      setDossier(detail); setReview(detail.application);
      setFinalImages(null);
      if (can('RECRUITMENT_FINAL')) { const images = await api('applications/' + application.id + '/final-documents'); setFinalImages(images[0] || null); }
      setReceivedItems([]); setOriginalsReturned(false); setOfficeNotes('');
      setReason(''); setChanges(''); setReviewMinutes('60'); setReviewUnit('minutes');
      if (detail.application.status === 'ACTIVE') {
        setDecision('SUSPEND');
      } else if (['DOCUMENTS_RECEIVED', 'FINAL_REVIEW'].includes(detail.application.status)) {
        setDecision('APPROVE_FINAL');
      } else {
        setDecision('APPROVE_PRELIMINARY');
      }
    } catch (e) { setError((e as Error).message); } finally { setBusy(false); setLoadingReview(false); }
  }

  async function officeAction(path: string, body?: unknown) {
    if (!review || busy) return;
    setBusy(true); setError('');
    try {
      await api(path, 'POST', body);
      await openReview(review);
    } catch (e) { setError((e as Error).message); }
    finally { setBusy(false); }
  }

  async function decide() {
    if (!review || !canDecide || sendingDecision) return;
    if (!reason.trim()) { setError('Vui lòng chọn hoặc nhập lý do xét duyệt.'); return; }
    if (decision === 'REQUEST_CHANGES' && !changes.trim()) { setError('Vui lòng tick ít nhất một mục cần bổ sung.'); return; }
    setSendingDecision(true);
    setBusy(true);
    setError('');
    try {
      await api(
        'applications/' +
          review.id +
          (['DOCUMENTS_RECEIVED', 'FINAL_REVIEW', 'ACTIVE'].includes(review.status)
            ? '/final-decision'
            : '/preliminary-decision'),
        'POST',
        {
          version: review.version,
          requestId: crypto.randomUUID(),
          action: decision,
          reason,
          reviewMinutes: decision === 'EXTEND_REVIEW' ? totalReviewMinutes : undefined,
          requiredChanges: (decision === 'REQUEST_CHANGES' ? changes : '')
            .split(',')
            .map((s) => s.trim())
            .filter(Boolean),
        }
      );
      await load();
      await openReview(review);
    } catch (e) {
      setError((e as Error).name === 'TimeoutError' ? 'Máy chủ phản hồi quá lâu. Hãy tải lại hồ sơ để kiểm tra kết quả trước khi gửi lại.' : (e as Error).message);
    } finally {
      setSendingDecision(false);
      setBusy(false);
    }
  }

  async function load() {
    const sequence = ++requestSequence.current;
    setBusy(true);
    setError('');
    try {
      const params = new URLSearchParams({
        page: String(page),
        size: '5',
        query,
        status: statusFilter,
      });
      if (areaFilter) params.set('area', areaFilter);
      if (serviceFilter) params.set('service', serviceFilter);

      const [a, b, c, d] = await Promise.all([
        api('applications-page?' + params),
        api('areas'),
        api('services'),
        api('summary'),
      ]);
      if (sequence !== requestSequence.current) return;
      setApps(a.items);
      setTotal(a.total);
      setAreas(b);
      setServices(Array.isArray(c) ? c : c.services || []);
      setSummary(d);
    } catch (e) {
      if (sequence === requestSequence.current) setError((e as Error).message);
    } finally {
      if (sequence === requestSequence.current) setBusy(false);
    }
  }

  useEffect(() => {
    void load();
  }, [page, query, statusFilter, areaFilter, serviceFilter]);

  // --- AREA ACTIONS ---
  async function saveArea() {
    if (!editing) return;
    setBusy(true);
    setError('');
    try {
      const finalCity = modalCity.trim();
      const finalName = finalCity;
      if (!finalCity) {
        throw new Error('Vui lòng chọn Tỉnh/Thành phố.');
      }
      const payload = {
        ...editing,
        city: finalCity,
        name: finalName,
        recruiting: true,
        capacity: 1000,
        serviceIds: services.map((s) => s.id),
      };
      await api('areas/' + editing.id, 'PUT', payload);
      setEditing(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function deleteSingleArea(areaId: string, areaName: string) {
    if (!confirm('Bạn có chắc chắn muốn xóa khu vực "' + areaName + '"? Thao tác này sẽ xóa sạch khu vực khỏi danh sách tuyển dụng.')) {
      return;
    }
    setBusy(true);
    setError('');
    try {
      await api('areas/' + areaId, 'DELETE');
      setSelectedAreaIds((prev) => prev.filter((id) => id !== areaId));
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function toggleAreaRecruiting(area: Area) {
    setBusy(true);
    setError('');
    try {
      await api('areas/' + area.id, 'PUT', {
        ...area,
        recruiting: !area.recruiting,
      });
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function deleteSelectedAreas() {
    if (!selectedAreaIds.length) return;
    if (
      !confirm(
        'Bạn có chắc chắn muốn xóa ' +
          selectedAreaIds.length +
          ' khu vực đã chọn? Các khu vực không còn liên quan sẽ được xóa bỏ an toàn.'
      )
    ) {
      return;
    }
    setBusy(true);
    setError('');
    try {
      for (const id of selectedAreaIds) {
        await api('areas/' + id, 'DELETE');
      }
      setSelectedAreaIds([]);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  // Filtered areas for display
  const filteredAreas = useMemo(() => {
    return areas.filter((a) => {
      if (areaRegionFilter !== 'Tất cả') {
        const reg = getRegion(a.city);
        if (reg !== areaRegionFilter) return false;
      }
      if (areaCityFilter && a.city !== areaCityFilter) return false;
      if (areaStatusFilter === 'OPEN' && !a.recruiting) return false;
      if (areaStatusFilter === 'CLOSED' && a.recruiting) return false;
      if (areaSearchQuery.trim()) {
        const q = areaSearchQuery.toLowerCase();
        return (
          a.name.toLowerCase().includes(q) || a.city.toLowerCase().includes(q)
        );
      }
      return true;
    });
  }, [areas, areaRegionFilter, areaCityFilter, areaStatusFilter, areaSearchQuery]);

  // Available provinces for chosen region
  const provincesInSelectedRegion = useMemo(() => {
    if (areaRegionFilter === 'Tất cả') return VIETNAM_PROVINCES;
    return VIETNAM_PROVINCES.filter((p) => p.region === areaRegionFilter);
  }, [areaRegionFilter]);

  // Reset areaPage when search or filter changes
  useEffect(() => {
    setAreaPage(0);
  }, [areaRegionFilter, areaCityFilter, areaStatusFilter, areaSearchQuery]);

  const totalAreaPages = Math.ceil(filteredAreas.length / AREA_PAGE_SIZE) || 1;
  const pagedAreas = useMemo(() => {
    const start = areaPage * AREA_PAGE_SIZE;
    return filteredAreas.slice(start, start + AREA_PAGE_SIZE);
  }, [filteredAreas, areaPage]);

  if (tab === 'uniforms') return <section className="catalogue-manager"><RecruitmentConfigAdmin uniformOnly /></section>;
  // Submodules routing
  if (tab === 'exam')
    return (
      <section className="catalogue-manager">
        <RecruitmentExamAdmin />
      </section>
    );
  if (tab === 'config')
    return (
      <section className="catalogue-manager">
        <RecruitmentConfigAdmin />
      </section>
    );

  return (
    <div className="recruitment-container">
      {/* ERROR ALERT */}
      {error && (
        <div className="notice catalogue-notice" role="alert" style={{ background: '#fef2f2', borderColor: '#fca5a5', color: '#991b1b' }}>
          <AlertCircle size={16} /> {error}
        </div>
      )}

      {/* ======================================================== */}
      {/* TAB 1: KHU VỰC TUYỂN DỤNG (AREAS) */}
      {/* ======================================================== */}
      {tab === 'areas' && (
        <>
          {/* KPI STATS FOR AREAS */}
          <div className="recruitment-kpi-grid">
            <div className="recruitment-kpi-card emerald">
              <span className="kpi-label">Tổng khu vực</span>
              <span className="kpi-val">{areas.length}</span>
            </div>
            <div className="recruitment-kpi-card blue">
              <span className="kpi-label">Tỉnh / Thành phố</span>
              <span className="kpi-val">
                {new Set(areas.map((a) => a.city)).size}
              </span>
            </div>
            <div className="recruitment-kpi-card purple">
              <span className="kpi-label">Miền Bắc</span>
              <span className="kpi-val">
                {areas.filter((a) => getRegion(a.city) === 'Miền Bắc').length}
              </span>
            </div>
            <div className="recruitment-kpi-card amber">
              <span className="kpi-label">Miền Trung & Nam</span>
              <span className="kpi-val">
                {areas.filter((a) => getRegion(a.city) !== 'Miền Bắc').length}
              </span>
            </div>
          </div>

          {/* TOOLBAR: REGION, PROVINCE (63 TỈNH), SEARCH, BATCH ACTIONS */}
          <div className="recruitment-toolbar">
            <div className="recruitment-toolbar-row">
              {/* Region Filter Chips */}
              <div className="recruitment-region-chips">
                {['Tất cả', 'Miền Bắc', 'Miền Trung', 'Miền Nam'].map((reg) => (
                  <button
                    key={reg}
                    type="button"
                    className={'region-chip ' + (areaRegionFilter === reg ? 'active' : '')}
                    onClick={() => {
                      setAreaRegionFilter(reg);
                      setAreaCityFilter('');
                    }}
                  >
                    {reg}
                  </button>
                ))}
              </div>

              {/* Action Buttons */}
              <div className="header-buttons">
                {can('RECRUITMENT_CONFIG') && (
                  <>
                    <button
                      className="btn btn-primary"
                      disabled={busy}
                      onClick={() => {
                        const reg = areaRegionFilter !== 'Tất cả' ? areaRegionFilter : 'Miền Bắc';
                        setModalRegion(reg);
                        const provs = VIETNAM_PROVINCES.filter((p) => p.region === reg);
                        const initialCity = areaCityFilter || provs[0]?.name || 'Hà Nội';
                        setModalCity(initialCity);
                        setEditing({
                          id: crypto.randomUUID(),
                          city: initialCity,
                          name: initialCity,
                          recruiting: true,
                          capacity: 1000,
                          version: 0,
                          serviceIds: services.map((s) => s.id),
                        });
                      }}
                    >
                      <Plus size={16} /> Đăng khu vực mới
                    </button>
                  </>
                )}
              </div>
            </div>

            <div className="recruitment-toolbar-row">
              <div className="recruitment-filter-group">
                {/* 63 Provinces Dropdown */}
                <select
                  aria-label="Chọn tỉnh thành"
                  className="recruitment-select"
                  value={areaCityFilter}
                  onChange={(e) => setAreaCityFilter(e.target.value)}
                >
                  <option value="">Tất cả tỉnh / thành ({provincesInSelectedRegion.length})</option>
                  {provincesInSelectedRegion.map((p) => {
                    const count = areas.filter((a) => a.city === p.name).length;
                    return (
                      <option key={p.name} value={p.name}>
                        {p.name} {count > 0 ? '(' + count + ' khu vực)' : ''}
                      </option>
                    );
                  })}
                </select>

                {/* Status Dropdown */}
                <select
                  aria-label="Lọc trạng thái mở tuyển"
                  className="recruitment-select"
                  style={{ minWidth: 140 }}
                  value={areaStatusFilter}
                  onChange={(e) => setAreaStatusFilter(e.target.value)}
                >
                  <option value="ALL">Mọi trạng thái</option>
                  <option value="OPEN">Đang mở tuyển</option>
                  <option value="CLOSED">Đang tạm đóng</option>
                </select>

                {/* Realtime Search Input */}
                <div className="recruitment-search-input">
                  <Search size={15} color="#7b8e86" />
                  <input
                    placeholder="Tìm tỉnh/thành phố..."
                    value={areaSearchQuery}
                    onChange={(e) => setAreaSearchQuery(e.target.value)}
                  />
                  {areaSearchQuery && (
                    <button
                      type="button"
                      style={{ border: 0, background: 'transparent', cursor: 'pointer', padding: 0 }}
                      onClick={() => setAreaSearchQuery('')}
                    >
                      ✕
                    </button>
                  )}
                </div>
              </div>

              {/* Batch selection summary & actions */}
              {selectedAreaIds.length > 0 && (
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--emerald, #0b9879)' }}>
                    Đã chọn {selectedAreaIds.length} mục
                  </span>
                  <button
                    className="btn btn-outline"
                    style={{ color: '#dc2626', borderColor: '#fca5a5' }}
                    onClick={deleteSelectedAreas}
                    disabled={busy || !can('RECRUITMENT_CONFIG')}
                  >
                    <Trash2 size={14} /> Xóa {selectedAreaIds.length} khu vực
                  </button>
                </div>
              )}
            </div>
          </div>

          {/* TABLE OF RECRUITMENT AREAS */}
          <div className="recruitment-card-table">
            <table className="recruitment-table">
              <thead>
                <tr>
                  <th style={{ width: 40, textAlign: 'center' }}>
                    <input
                      type="checkbox"
                      aria-label="Chọn tất cả"
                      checked={
                        filteredAreas.length > 0 &&
                        filteredAreas.every((a) => selectedAreaIds.includes(a.id))
                      }
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedAreaIds(filteredAreas.map((a) => a.id));
                        } else {
                          setSelectedAreaIds([]);
                        }
                      }}
                    />
                  </th>
                  <th>Vùng / Miền</th>
                  <th>Tỉnh / Thành phố</th>
                  <th style={{ textAlign: 'right' }}>Thao tác</th>
                </tr>
              </thead>
              <tbody>
                {filteredAreas.length === 0 ? (
                  <tr>
                    <td colSpan={4} style={{ textAlign: 'center', padding: '36px 16px', color: '#7b8e86' }}>
                      <Building2 size={36} style={{ margin: '0 auto 8px', opacity: 0.5 }} />
                      <div style={{ fontWeight: 700, fontSize: 14 }}>Không tìm thấy khu vực nào</div>
                      <div style={{ fontSize: 12, marginTop: 4 }}>
                        Thử đổi bộ lọc hoặc bấm nút "Đăng khu vực mới" để thêm địa bàn.
                      </div>
                    </td>
                  </tr>
                ) : (
                  pagedAreas.map((a) => {
                    const isSelected = selectedAreaIds.includes(a.id);
                    return (
                      <tr key={a.id} style={{ background: isSelected ? '#f2fbf7' : undefined }}>
                        <td style={{ textAlign: 'center' }}>
                          <input
                            type="checkbox"
                            checked={isSelected}
                            onChange={(e) => {
                              if (e.target.checked) {
                                setSelectedAreaIds((prev) => [...prev, a.id]);
                              } else {
                                setSelectedAreaIds((prev) => prev.filter((id) => id !== a.id));
                              }
                            }}
                          />
                        </td>
                        <td>
                          <span style={{ fontSize: 12, fontWeight: 600, color: '#475569' }}>
                            {getRegion(a.city)}
                          </span>
                        </td>
                        <td>
                          <span className="area-city-badge">
                            <Building2 size={12} /> {a.city}
                          </span>
                        </td>
                        <td>
                          <div className="table-actions" style={{ justifyContent: 'flex-end' }}>
                            <button
                              className="btn-icon-action"
                              disabled={busy || !can('RECRUITMENT_CONFIG')}
                              onClick={() => {
                                const reg = getRegion(a.city);
                                setModalRegion(reg);
                                setModalCity(a.city);
                                setEditing({ ...a });
                              }}
                              title="Chỉnh sửa địa bàn"
                            >
                              <Edit3 size={13} /> Sửa
                            </button>
                            <button
                              className="btn-icon-action danger"
                              disabled={busy || !can('RECRUITMENT_CONFIG')}
                              onClick={() => deleteSingleArea(a.id, a.city)}
                              title="Xóa khu vực không liên quan"
                            >
                              <Trash2 size={13} /> Xóa
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
            {filteredAreas.length > 0 && (
              <div
                style={{
                  display: 'flex',
                  flexWrap: 'wrap',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  gap: 12,
                  padding: '12px 18px',
                  background: '#ffffff',
                  borderTop: '1px solid #e5efec',
                  borderRadius: '0 0 16px 16px',
                }}
              >
                <span style={{ fontSize: 12, color: '#64748b', fontWeight: 600 }}>
                  Hiển thị {areaPage * AREA_PAGE_SIZE + 1} -{' '}
                  {Math.min((areaPage + 1) * AREA_PAGE_SIZE, filteredAreas.length)} /{' '}
                  {filteredAreas.length} khu vực (5 mục/trang)
                </span>
                <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                  <button
                    type="button"
                    className="btn btn-outline"
                    style={{ padding: '4px 10px', fontSize: 12 }}
                    disabled={areaPage === 0}
                    onClick={() => setAreaPage((p) => Math.max(0, p - 1))}
                  >
                    <ArrowLeft size={13} /> Trang trước
                  </button>
                  <span style={{ fontSize: 12, fontWeight: 700, color: '#1e293b' }}>
                    Trang {areaPage + 1} / {totalAreaPages}
                  </span>
                  <button
                    type="button"
                    className="btn btn-outline"
                    style={{ padding: '4px 10px', fontSize: 12 }}
                    disabled={areaPage >= totalAreaPages - 1}
                    onClick={() => setAreaPage((p) => p + 1)}
                  >
                    Trang sau <ArrowRight size={13} />
                  </button>
                </div>
              </div>
            )}
          </div>
        </>
      )}

      {/* ======================================================== */}
      {/* TAB 2: HỒ SƠ ỨNG TUYỂN (APPLICATIONS) */}
      {/* ======================================================== */}
      {tab === 'applications' && (
        <>
          {/* SUMMARY STATS FOR APPLICATIONS */}
          {summary && (
            <div className="recruitment-kpi-grid">
              <div className="recruitment-kpi-card emerald">
                <span className="kpi-label">Tổng hồ sơ tuyển dụng</span>
                <span className="kpi-val">{summary.total}</span>
              </div>
              <div className="recruitment-kpi-card amber">
                <span className="kpi-label">Chờ duyệt sơ bộ</span>
                <span className="kpi-val">
                  {summary.statuses.find((s) => s.status === 'PRELIMINARY_REVIEW')?.total ?? summary.awaitingReview ?? 0}
                </span>
              </div>
              <div className="recruitment-kpi-card blue">
                <span className="kpi-label">Chờ duyệt chính thức</span>
                <span className="kpi-val">
                  {(summary.statuses.find((s) => s.status === 'FINAL_REVIEW')?.total ?? 0) +
                    (summary.statuses.find((s) => s.status === 'DOCUMENTS_RECEIVED')?.total ?? 0)}
                </span>
              </div>
              <div className="recruitment-kpi-card emerald">
                <span className="kpi-label">Đang hoạt động</span>
                <span className="kpi-val">
                  {summary.statuses.find((s) => s.status === 'ACTIVE')?.total ?? 0}
                </span>
              </div>
              <div className="recruitment-kpi-card red">
                <span className="kpi-label">Cần bổ sung / Từ chối</span>
                <span className="kpi-val">
                  {(summary.statuses.find((s) => s.status === 'ACTION_REQUIRED')?.total ?? 0) +
                    (summary.statuses.find((s) => s.status === 'REJECTED')?.total ?? 0)}
                </span>
              </div>
            </div>
          )}

          {/* APPLICATION FILTER & SEARCH */}
          <div className="recruitment-toolbar">
            <div className="recruitment-toolbar-row">
              <form
                style={{ display: 'flex', gap: 10, flex: 1 }}
                onSubmit={(e) => {
                  e.preventDefault();
                  setPage(0);
                  setQuery(search.trim());
                }}
              >
                <div className="recruitment-search-input" style={{ flex: 1 }}>
                  <Search size={15} color="#7b8e86" />
                  <input
                    maxLength={160}
                    placeholder="Tìm theo tên ứng viên, số điện thoại hoặc mã hồ sơ..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                  {search && (
                    <button
                      type="button"
                      style={{ border: 0, background: 'transparent', cursor: 'pointer', padding: 2 }}
                      onClick={() => {
                        setSearch('');
                        setQuery('');
                        setPage(0);
                      }}
                    >
                      <X size={13} color="#94a3b8" />
                    </button>
                  )}
                </div>
                <button className="btn btn-primary" disabled={busy}>
                  Tìm kiếm
                </button>
              </form>

              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <select
                  aria-label="Lọc trạng thái"
                  className="recruitment-select"
                  value={statusFilter}
                  onChange={(e) => {
                    setPage(0);
                    setStatusFilter(e.target.value);
                  }}
                >
                  <option value="">Tất cả trạng thái ({summary?.total ?? total})</option>
                  {summary?.statuses.map((s) => (
                    <option key={s.status} value={s.status}>
                      {partnerStatusLabels[s.status] || s.status} ({s.total})
                    </option>
                  ))}
                </select>

                <select
                  aria-label="Lọc khu vực"
                  className="recruitment-select"
                  value={areaFilter}
                  onChange={(e) => {
                    setPage(0);
                    setAreaFilter(e.target.value);
                  }}
                >
                  <option value="">Tất cả khu vực</option>
                  {areas.map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.city} · {a.name}
                    </option>
                  ))}
                </select>

                <select
                  aria-label="Lọc dịch vụ"
                  className="recruitment-select"
                  value={serviceFilter}
                  onChange={(e) => {
                    setPage(0);
                    setServiceFilter(e.target.value);
                  }}
                >
                  <option value="">Tất cả dịch vụ</option>
                  {services.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>

                <button
                  type="button"
                  className="btn btn-outline"
                  title="Tải lại danh sách"
                  disabled={busy}
                  onClick={() => void load()}
                  style={{ padding: '8px 12px' }}
                >
                  <RefreshCw size={14} className={busy ? 'animate-spin' : ''} />
                </button>
              </div>
            </div>

            <div className="recruitment-toolbar-row" style={{ paddingTop: 4 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <button
                  className="btn btn-outline"
                  disabled={busy || page === 0}
                  onClick={() => setPage((p) => p - 1)}
                >
                  <ArrowLeft size={14} /> Trang trước
                </button>
                <span style={{ fontSize: 12, fontWeight: 700, color: '#4b6359' }}>
                  Trang {page + 1} · {total} hồ sơ (5 mục/trang)
                </span>
                <button
                  className="btn btn-outline"
                  disabled={busy || (page + 1) * 5 >= total}
                  onClick={() => setPage((p) => p + 1)}
                >
                  Trang sau <ArrowRight size={14} />
                </button>
              </div>
            </div>
          </div>

          {/* APPLICATION DATA TABLE */}
          <div className="recruitment-card-table">
            <table className="recruitment-table">
              <thead>
                <tr>
                  <th>Ứng viên</th>
                  <th>Điện thoại liên hệ</th>
                  <th>Trạng thái hồ sơ</th>
                  <th>Tiến trình kiểm duyệt</th>
                  <th>Cập nhật gần nhất</th>
                  <th style={{ textAlign: 'right' }}>Thao tác</th>
                </tr>
              </thead>
              <tbody>
                {apps.length === 0 ? (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: '40px 16px', color: '#7b8e86' }}>
                      <Users size={36} style={{ margin: '0 auto 8px', opacity: 0.4 }} />
                      <div style={{ fontWeight: 800, fontSize: 14 }}>Không tìm thấy hồ sơ ứng tuyển nào</div>
                      <small style={{ color: '#94a3b8' }}>Thử điều chỉnh bộ lọc hoặc từ khóa tìm kiếm</small>
                    </td>
                  </tr>
                ) : (
                  apps.map((a) => {
                    const canReview =
                      (['PRELIMINARY_REVIEW', 'ESCALATED'].includes(a.status) &&
                        can('RECRUITMENT_PRELIMINARY')) ||
                      (['DOCUMENTS_RECEIVED', 'FINAL_REVIEW'].includes(a.status) &&
                        can('RECRUITMENT_FINAL'));

                    const statusLabel = partnerStatusLabels[a.status] || a.status;
                    let statusBadgeClass = 'neutral';
                    if (['ACTIVE', 'APPROVED', 'PRELIMINARY_APPROVED'].includes(a.status)) {
                      statusBadgeClass = 'green';
                    } else if (['PRELIMINARY_REVIEW', 'FINAL_REVIEW', 'DOCUMENTS_RECEIVED'].includes(a.status)) {
                      statusBadgeClass = 'amber';
                    } else if (['ACTION_REQUIRED', 'WAITLISTED', 'PROFILE_INCOMPLETE'].includes(a.status)) {
                      statusBadgeClass = 'orange';
                    } else if (['REJECTED', 'SUSPENDED', 'EXAM_FAILED'].includes(a.status)) {
                      statusBadgeClass = 'red';
                    }

                    return (
                      <tr key={a.id}>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                            <div
                              style={{
                                width: 34,
                                height: 34,
                                borderRadius: 10,
                                background: '#def5ec',
                                color: '#09886d',
                                fontWeight: 800,
                                display: 'grid',
                                placeItems: 'center',
                                fontSize: 13,
                                flex: 'none',
                              }}
                            >
                              {portraits[a.id] ? <img src={portraits[a.id]} alt={`Chân dung ${a.fullName}`} style={{ width: 34, height: 34, objectFit: 'cover', borderRadius: 10 }} /> : (a.fullName || 'T').charAt(0).toUpperCase()}
                            </div>
                            <div>
                              <div style={{ fontWeight: 800, color: '#1e293b' }}>
                                {a.fullName || 'Đăng ký chưa hoàn tất'}
                              </div>
                            </div>
                          </div>
                        </td>
                        <td>
                          <span style={{ fontFamily: 'monospace', fontWeight: 700, color: '#334155' }}>
                            {a.contactPhone || '—'}
                          </span>
                        </td>
                        <td>
                          <span className={'badge ' + statusBadgeClass}>
                            {statusLabel}
                          </span>
                        </td>
                        <td>
                          <span className={'badge ' + statusBadgeClass}>
                            {a.eligibility?.appointment_checked_in && !a.eligibility?.documents_valid && ['PRELIMINARY_APPROVED', 'UNIFORM_PENDING', 'DOCUMENT_APPOINTMENT', 'ACTION_REQUIRED'].includes(a.status) ? 'Đã check-in · Chờ đối chiếu giấy tờ' : ({ PRELIMINARY_REVIEW: 'Chờ duyệt sơ bộ', ESCALATED: 'Đang xem xét thêm', PRELIMINARY_APPROVED: 'Chờ check-in', UNIFORM_PENDING: 'Đang làm thủ tục đồng phục', DOCUMENT_APPOINTMENT: 'Chờ tiếp nhận tại văn phòng', DOCUMENTS_RECEIVED: 'Hoàn tất hồ sơ gốc', FINAL_REVIEW: 'Chờ duyệt chính thức', APPROVED: 'Chờ bổ sung ảnh chặng 4', ACTIVE: 'Đã kích hoạt', ACTION_REQUIRED: 'Chờ bổ sung hồ sơ', REJECTED: 'Đã từ chối', SUSPENDED: 'Đã tạm ngưng' } as Record<string, string>)[a.status] || statusLabel}
                          </span>
                        </td>
                        <td>
                          <span style={{ fontSize: 12, color: '#64748b' }}>
                            {new Date(a.updatedAt).toLocaleString('vi-VN', {
                              hour: '2-digit',
                              minute: '2-digit',
                              day: '2-digit',
                              month: '2-digit',
                              year: 'numeric',
                            })}
                          </span>
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          {can('RECRUITMENT_VIEW') && (
                            <button
                              className={canReview && a.reviewReady !== false ? 'btn btn-primary' : 'btn btn-outline'}
                              style={{ padding: '6px 12px', fontSize: 11, fontWeight: 700 }}
                              disabled={busy}
                              onClick={() => void openReview(a)}
                            >
                              {canReview && a.reviewReady !== false ? (
                                <>
                                  <ShieldCheck size={13} /> Xét duyệt hồ sơ
                                </>
                              ) : (
                                <>
                                  <Eye size={13} /> {['ACTIVE', 'APPROVED'].includes(a.status) ? 'Chi tiết' : ['PRELIMINARY_APPROVED', 'UNIFORM_PENDING', 'DOCUMENT_APPOINTMENT'].includes(a.status) ? 'Tiếp nhận tại văn phòng' : 'Xem chi tiết'}
                                </>
                              )}
                            </button>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </>
      )}

      {/* ======================================================== */}
      {/* POPUP 1: ĐĂNG / SỬA KHU VỰC (SINGLE AREA: MIỀN -> TỈNH -> QUẬN) */}
      {/* ======================================================== */}
      {editing && (
        <CataloguePopup
          title={editing.version === 0 ? 'Đăng khu vực tuyển dụng mới' : 'Chỉnh sửa khu vực tuyển dụng'}
          eyebrow="QUẢN LÝ ĐỊA BÀN VIỆT NAM"
          busy={busy}
          onClose={() => setEditing(null)}
        >
          <form
            className="modal-form-grid"
            onSubmit={(e) => {
              e.preventDefault();
              void saveArea();
            }}
          >
            {/* 1. CHỌN MIỀN TRƯỚC */}
            <div className="modal-label">
              <span style={{ fontSize: 13, fontWeight: 700, color: '#134e4a' }}>
                1. Chọn Vùng / Miền
              </span>
              <div className="region-step-buttons">
                {(['Miền Bắc', 'Miền Trung', 'Miền Nam'] as const).map((r) => {
                  const isSel = modalRegion === r;
                  return (
                    <button
                      key={r}
                      type="button"
                      className={'region-step-btn ' + (isSel ? 'selected' : '')}
                      onClick={() => {
                        setModalRegion(r);
                        const provs = VIETNAM_PROVINCES.filter((p) => p.region === r);
                        const firstCity = provs[0]?.name || '';
                        setModalCity(firstCity);
                      }}
                    >
                      {isSel && <CheckCircle2 size={15} />}
                      {r}
                    </button>
                  );
                })}
              </div>
            </div>

            {/* 2. CHỌN TỈNH / THÀNH PHỐ */}
            <div className="modal-label">
              <span style={{ fontSize: 13, fontWeight: 700, color: '#134e4a' }}>
                2. Chọn Tỉnh / Thành phố ({modalRegion})
              </span>
              <select
                required
                value={modalCity}
                onChange={(e) => {
                  const newCity = e.target.value;
                  setModalCity(newCity);
                }}
                style={{ height: 42, fontSize: 13.5, borderRadius: 10 }}
              >
                {VIETNAM_PROVINCES.filter((p) => p.region === modalRegion).map((p) => (
                  <option key={p.name} value={p.name}>
                    {p.name}
                  </option>
                ))}
              </select>
            </div>

            {/* ĐÃ XÓA HOÀN TOÀN: CHỈ TIÊU TUYỂN DỤNG, TRẠNG THÁI, DỊCH VỤ */}

            <button
              className="btn btn-primary"
              type="submit"
              disabled={busy || !modalCity.trim()}
              style={{ minHeight: 44, fontSize: 14, fontWeight: 700, marginTop: 8 }}
            >
              {editing.version === 0 ? 'Đăng khu vực tuyển dụng' : 'Lưu cập nhật khu vực'}
            </button>
          </form>
        </CataloguePopup>
      )}

      {/* ======================================================== */}
      {/* ======================================================== */}
      {/* ======================================================== */}
      {/* POPUP 3: XÉT DUYỆT HỒ SƠ (REVIEW APPLICATION) */}
      {/* ======================================================== */}
      {review && (
        <CataloguePopup
          wide={true}
          title="Xét duyệt hồ sơ ứng tuyển"
          eyebrow={review.fullName ? `ỨNG VIÊN: ${review.fullName.toUpperCase()}` : 'HỒ SƠ ỨNG TUYỂN'}
          busy={busy}
          onClose={() => setReview(null)}
        >
          {/* TOP BAR WITH REFRESH BUTTON */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14, flexWrap: 'wrap', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className="badge green" style={{ fontSize: 12, padding: '4px 10px' }}>
                {partnerStatusLabels[review.status] || review.status}
              </span>
              <span style={{ fontSize: 12, color: '#64748b' }}>
                Cập nhật: {new Date(review.updatedAt).toLocaleString('vi-VN')}
              </span>
            </div>
            <button
              type="button"
              className="btn btn-outline"
              disabled={busy}
              onClick={() => void openReview(review)}
              style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, padding: '6px 12px' }}
            >
              <RefreshCw size={13} className={loadingReview ? 'animate-spin' : ''} /> {loadingReview ? 'Đang tải hồ sơ…' : 'Tải lại hồ sơ mới nhất'}
            </button>
          </div>

          {dossier && <RecruitmentDossier dossier={dossier} finalImages={finalImages} canReadIdentity={can('KYC_REVIEW')} onIdentityApproved={async () => { await openReview(review); }} />}
          {review.status === 'REJECTED' && can('RECRUITMENT_PRELIMINARY') && can('RECRUITMENT_RECEPTION') && <div className="review-decision-card"><strong>Tiếp nhận Partner tại văn phòng</strong><p>Khi Partner đã đến văn phòng, mở lại hồ sơ để đối chiếu và xét duyệt lại. Hồ sơ vẫn cần đáp ứng đủ điều kiện trước khi duyệt chính thức.</p><label>Lý do tiếp nhận lại<textarea value={officeNotes} maxLength={1000} onChange={event => setOfficeNotes(event.target.value)} placeholder="Ghi kết quả tiếp nhận và lý do xét duyệt lại hồ sơ" /></label><button className="btn btn-primary" disabled={busy || !officeNotes.trim()} onClick={() => void officeAction(`applications/${review.id}/reopen-at-office`, { version: review.version, requestId: crypto.randomUUID(), reason: officeNotes.trim() })}>Partner đã đến văn phòng · Mở lại xét duyệt</button></div>}
          {review.status === 'APPROVED' && <div className="review-decision-card"><button className="btn btn-primary" disabled>Duyệt chính thức</button><p>Đang chờ Partner bổ sung ảnh chân dung và hợp đồng đã ký ở chặng 4. Khi Partner gửi hồ sơ, nút duyệt sẽ được mở để Admin kiểm duyệt và kích hoạt tài khoản.</p></div>}
          {dossier?.application.eligibility.preliminary_approved && !['REJECTED', 'SUSPENDED', 'ACTIVE', 'APPROVED'].includes(review.status) && (() => {
            const appointment = [...dossier.appointments].reverse().find(a => ['BOOKED', 'CHECKED_IN', 'COMPLETED'].includes(String(a.status)));
            const uniform = [...dossier.uniforms].reverse().find(o => !['CANCELLED', 'REFUNDED'].includes(String(o.status)));
            const checkedIn = !!dossier.application.eligibility.appointment_checked_in;
            const handedOver = !!uniform?.handed_over_at;
            const paid = ['PAID', 'WAIVED'].includes(String(uniform?.payment_status));
            const documentsReady = !!dossier.application.eligibility.documents_valid;
            if (checkedIn) return <div className="review-decision-card"><button className="btn btn-primary" disabled={busy || !paid || !can('RECRUITMENT_FINAL')} onClick={() => void officeAction(`applications/${review.id}/final-decision`, { version: review.version, requestId: crypto.randomUUID(), action: 'APPROVE_FINAL', reason: 'Admin xác nhận đã đối chiếu giấy tờ gốc, hoàn tất thủ tục tại văn phòng và phê duyệt chính thức.', requiredChanges: [] })}>Duyệt chính thức</button>{!paid && <p>Đồng phục cần được xác nhận thanh toán trước khi duyệt chính thức.{uniform?.payment_method === 'AT_OFFICE' && can('RECRUITMENT_FINANCE') && <button className="btn btn-outline" disabled={busy} onClick={() => void officeAction(`uniform-orders/${uniform.id}/confirm-office-payment`)}>Xác nhận đã thu tiền</button>}</p>}</div>;
            return <div className="review-decision-card">
              <strong>Hoàn tất thủ tục tại văn phòng</strong>
              {checkedIn && documentsReady && !uniform && <p>Partner cần chọn đồng phục trước khi xác nhận bàn giao.</p>}
              <div style={{ marginTop: 16 }}>
                {!checkedIn && can('RECRUITMENT_RECEPTION') && <button className="btn btn-primary" disabled={busy} onClick={() => void officeAction(`applications/${review.id}/checkin`, {})}>Xác nhận đã check-in</button>}
                {checkedIn && documentsReady && !handedOver && can('RECRUITMENT_FINANCE') && (uniform && !paid && uniform.payment_method === 'AT_OFFICE'
                  ? <button className="btn btn-primary" disabled={busy} onClick={() => void officeAction(`uniform-orders/${uniform.id}/confirm-office-payment`)}>Xác nhận đã thu tiền đồng phục</button>
                  : <button className="btn btn-primary" disabled={busy || !paid} onClick={() => void officeAction(`uniform-orders/${uniform?.id}/adjust`, { action: 'HANDOVER', originalsReturned: false, reason: 'Đã bàn giao đồng phục trực tiếp cho đối tác tại văn phòng.', requestId: crypto.randomUUID() })}>Xác nhận đã phát đồng phục</button>)}
              </div>
            </div>;
          })()}
          {error && (
            <div className="notice catalogue-notice" role="alert" style={{ background: '#fef2f2', borderColor: '#fca5a5', color: '#991b1b', marginTop: 12 }}>
              <AlertCircle size={15}/> {error}
            </div>
          )}

          {canDecide && !dossier?.application.eligibility.preliminary_approved && (!['DOCUMENTS_RECEIVED', 'FINAL_REVIEW'].includes(review.status) || dossier?.uniforms.some(o => !!o.handed_over_at && !['CANCELLED', 'REFUNDED'].includes(String(o.status)))) ? (
            <div className="review-decision-card">
              <div className="review-decision-header">
                <div className="decision-header-title">
                  <ShieldCheck size={20} color="#0b9879" />
                  <span>Quyết định thẩm định hồ sơ</span>
                </div>
                <span style={{ fontSize: 12, color: '#64748b' }}>
                  Hồ sơ phiên bản v{review.version}
                </span>
              </div>

              <form
                className="modal-form-grid"
                onSubmit={(e) => {
                  e.preventDefault();
                  void decide();
                }}
              >
                {/* 1. CHỌN HÀNH ĐỘNG QUYẾT ĐỊNH */}
                <div className="modal-label">
                  <span style={{ fontSize: 13, fontWeight: 700, color: '#134e4a' }}>
                    1. Chọn hành động quyết định:
                  </span>
                  <div className="decision-action-cards">
                    {review.status === 'ACTIVE' ? (
                      <div
                        className="decision-action-card selected reject"
                        onClick={() => { setDecision('SUSPEND'); setReason(''); setChanges(''); }}
                      >
                        <div className="decision-card-icon"><XCircle size={18} /></div>
                        <div className="decision-card-text">
                          <span className="decision-card-name">Tạm ngưng hoạt động</span>
                          <span className="decision-card-desc">Khóa quyền nhận việc của đối tác</span>
                        </div>
                      </div>
                    ) : ['DOCUMENTS_RECEIVED', 'FINAL_REVIEW'].includes(review.status) ? (
                      <>
                        <div
                          className={`decision-action-card ${decision === 'APPROVE_FINAL' ? 'selected approve' : ''}`}
                          onClick={() => { setDecision('APPROVE_FINAL'); setReason(''); setChanges(''); }}
                        >
                          <div className="decision-card-icon"><CheckCircle2 size={18} /></div>
                          <div className="decision-card-text">
                            <span className="decision-card-name">Duyệt chính thức & Kích hoạt</span>
                            <span className="decision-card-desc">Đủ điều kiện nhận việc & hoạt động</span>
                          </div>
                        </div>
                        <div
                          className={`decision-action-card ${decision === 'REQUEST_CHANGES' ? 'selected changes' : ''}`}
                          onClick={() => { setDecision('REQUEST_CHANGES'); setReason(''); setChanges(''); }}
                        >
                          <div className="decision-card-icon"><AlertCircle size={18} /></div>
                          <div className="decision-card-text">
                            <span className="decision-card-name">Yêu cầu bổ sung hồ sơ</span>
                            <span className="decision-card-desc">Thông báo ứng viên bổ sung thêm</span>
                          </div>
                        </div>
                        <div
                          className={`decision-action-card ${decision === 'REJECT_WITH_REASON' ? 'selected reject' : ''}`}
                          onClick={() => { setDecision('REJECT_WITH_REASON'); setReason(''); setChanges(''); }}
                        >
                          <div className="decision-card-icon"><XCircle size={18} /></div>
                          <div className="decision-card-text">
                            <span className="decision-card-name">Từ chối hồ sơ</span>
                            <span className="decision-card-desc">Không đạt chuẩn thẩm định cuối</span>
                          </div>
                        </div>
                        <div
                          className={`decision-action-card ${decision === 'ESCALATE' ? 'selected escalate' : ''}`}
                          onClick={() => { setDecision('ESCALATE'); setReason(''); setChanges(''); }}
                        >
                          <div className="decision-card-icon"><ArrowRight size={18} /></div>
                          <div className="decision-card-text">
                            <span className="decision-card-name">Chuyển cấp thẩm quyền</span>
                            <span className="decision-card-desc">Chuyển cấp quản lý cao hơn</span>
                          </div>
                        </div>
                      </>
                    ) : (
                      <>
                        <div
                          className={`decision-action-card ${decision === 'APPROVE_PRELIMINARY' ? 'selected approve' : ''}`}
                          onClick={() => { setDecision('APPROVE_PRELIMINARY'); setReason(''); setChanges(''); }}
                        >
                          <div className="decision-card-icon"><CheckCircle2 size={18} /></div>
                          <div className="decision-card-text">
                            <span className="decision-card-name">Phê duyệt sơ bộ</span>
                            <span className="decision-card-desc">Đạt điều kiện giai đoạn 1 để qua văn phòng</span>
                          </div>
                        </div>
                        <div className={`decision-action-card ${decision === 'REQUEST_CHANGES' ? 'selected changes' : ''}`}
                          onClick={() => { setDecision('REQUEST_CHANGES'); setReason(''); setChanges(''); }}>
                          <div className="decision-card-icon"><AlertCircle size={18} /></div>
                          <div className="decision-card-text">
                            <span className="decision-card-name">Từ chối do thiếu thông tin</span>
                            <span className="decision-card-desc">Chọn mục cần bổ sung để Partner sửa và gửi lại</span>
                          </div>
                        </div>
                        <div
                          className={`decision-action-card ${decision === 'REJECT_WITH_REASON' ? 'selected reject' : ''}`}
                          onClick={() => { setDecision('REJECT_WITH_REASON'); setReason(''); setChanges(''); }}
                        >
                          <div className="decision-card-icon"><XCircle size={18} /></div>
                          <div className="decision-card-text">
                            <span className="decision-card-name">Từ chối thẳng</span>
                            <span className="decision-card-desc">Hồ sơ không đáp ứng tiêu chuẩn</span>
                          </div>
                        </div>
                        <div
                          className={`decision-action-card ${decision === 'EXTEND_REVIEW' ? 'selected escalate' : ''}`}
                          onClick={() => { setDecision('EXTEND_REVIEW'); setReason(''); setChanges(''); }}
                        >
                          <div className="decision-card-icon"><ArrowRight size={18} /></div>
                          <div className="decision-card-text">
                            <span className="decision-card-name">Thêm thời gian xem xét</span>
                            <span className="decision-card-desc">Điều chỉnh thời gian theo phút</span>
                          </div>
                        </div>
                      </>
                    )}
                  </div>
                </div>

                {decision === 'EXTEND_REVIEW' && (
                  <label className="modal-label">
                    Thời gian xem xét thêm
                    <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) 120px', gap: 10 }}>
                      <input aria-label="Thời gian xem xét thêm" type="number" min={1} max={reviewUnit === 'hours' ? 24 : 1440} step={1} required value={reviewMinutes} onChange={event => {
                        const value = event.target.value;
                        if (value === '') { setReviewMinutes(''); return; }
                        if (/^\d+$/.test(value) && Number(value) >= 1 && Number(value) <= (reviewUnit === 'hours' ? 24 : 1440)) setReviewMinutes(value);
                      }} />
                      <select aria-label="Đơn vị thời gian" value={reviewUnit} onChange={event => {
                        const unit = event.target.value as 'minutes' | 'hours';
                        setReviewMinutes(String(unit === 'hours' ? Math.max(1, Math.min(24, Math.ceil(totalReviewMinutes / 60))) : Math.max(1, Math.min(1440, totalReviewMinutes))));
                        setReviewUnit(unit);
                      }}><option value="minutes">Phút</option><option value="hours">Giờ</option></select>
                    </div>
                    <small>Tối đa {reviewUnit === 'hours' ? '24 giờ' : '1.440 phút'}. Dự kiến phản hồi trước: {Number.isInteger(totalReviewMinutes) && totalReviewMinutes > 0 ? new Date(Date.now() + totalReviewMinutes * 60000).toLocaleString('vi-VN') : 'Nhập thời gian hợp lệ'}</small>
                  </label>
                )}
                {/* 2. LÝ DO XÉT DUYỆT */}
                <div className="modal-label">
                  <span style={{ fontSize: 13, fontWeight: 700, color: '#134e4a' }}>
                    2. Lý do xét duyệt (Gửi thông báo tới ứng viên):
                  </span>
                  <div className="quick-reasons-wrap">
                    {(decisionReasons[decision] || []).map((txt) => (
                      <button
                        key={txt}
                        type="button"
                        className={`quick-reason-pill ${reason === txt ? 'active' : ''}`}
                        onClick={() => setReason(txt)}
                      >
                        + {txt}
                      </button>
                    ))}
                  </div>
                  <textarea
                    required
                    maxLength={1000}
                    rows={3}
                    placeholder="Nhập lý do thẩm định hoặc chọn từ các mẫu gợi ý trên..."
                    value={reason}
                    onChange={(e) => setReason(e.target.value)}
                    style={{ marginTop: 6 }}
                  />
                </div>

                {/* 3. CÁC MỤC CẦN SỬA (KHI YÊU CẦU BỔ SUNG) */}
                {decision === 'REQUEST_CHANGES' && (
                  <div className="modal-label">
                    <span style={{ fontSize: 13, fontWeight: 700, color: '#134e4a' }}>
                      3. Các mục cần ứng viên bổ sung:
                    </span>
                    <div className="supplement-check-grid">
                      {[
                        'Họ và tên',
                        'Số CCCD / Mã định danh',
                        'Ảnh CCCD mặt trước',
                        'Ảnh CCCD mặt sau',
                        'Ảnh chân dung',
                        'Số điện thoại liên hệ',
                        'Ngày sinh',
                        'Khu vực làm việc',
                      ].map((item) => {
                        const items = changes.split(',').map((s) => s.trim()).filter(Boolean);
                        const isSelected = items.includes(item);
                        return (
                          <label
                            key={item}
                            className={`quick-reason-pill ${isSelected ? 'active' : ''}`}
                          >
                            <input type="checkbox" checked={isSelected} onChange={() => {
                              if (isSelected) {
                                setChanges(items.filter((s) => s !== item).join(', '));
                              } else {
                                setChanges(items.concat(item).join(', '));
                              }
                            }} />
                            {item}
                          </label>
                        );
                      })}
                    </div>
                  </div>
                )}

                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={sendingDecision || (decision === 'EXTEND_REVIEW' && (!Number.isInteger(totalReviewMinutes) || totalReviewMinutes < 1 || totalReviewMinutes > 1440))}
                  style={{ minHeight: 44, fontSize: 14, fontWeight: 800, marginTop: 6 }}
                >
                  {sendingDecision ? 'Đang gửi yêu cầu…' : decision === 'APPROVE_PRELIMINARY'
                    ? '✓ Xác nhận Phê duyệt sơ bộ'
                    : decision === 'APPROVE_FINAL'
                    ? '✓ Xác nhận Phê duyệt chính thức & Kích hoạt'
                    : decision === 'REQUEST_CHANGES'
                    ? 'Gửi yêu cầu bổ sung và từ chối tạm thời'
                    : decision === 'REJECT_WITH_REASON'
                    ? '❌ Xác nhận Từ chối hồ sơ'
                    : decision === 'SUSPEND'
                    ? '⛔ Xác nhận Tạm ngưng hoạt động'
                    : decision === 'EXTEND_REVIEW' ? `Xác nhận thêm ${reviewMinutes} ${reviewUnit === 'hours' ? 'giờ' : 'phút'} xem xét` : 'Xác nhận chuyển cấp thẩm quyền'}
                </button>
              </form>
            </div>
          ) : (
            dossier && review.status === 'ESCALATED' && (
              <div className="partner-check-notice" style={{ marginTop: 14 }}>
                <Clock size={16} color="#d97706" />
                <div>
                  <strong>Hồ sơ đang được xem xét thêm:</strong>
                  <p style={{ margin: '3px 0 0', fontSize: 12 }}>
                    {review.reason}
                  </p>
                </div>
              </div>
            )
          )}
        </CataloguePopup>
      )}
    </div>
  );
}
