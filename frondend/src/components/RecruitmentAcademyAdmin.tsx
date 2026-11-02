'use client';

import { useEffect, useMemo, useState } from 'react';
import {
  Video, Play, CheckCircle2, AlertCircle, Plus, Search,
  Edit3, RefreshCw, Clock, Eye, EyeOff, Check, Sparkles, Layers
} from 'lucide-react';
import CataloguePopup from './CataloguePopup';

type Lesson = {
  id: string;
  title: string;
  videoUrl: string;
  durationSeconds: number;
  watchRatio: number;
  quizText: string;
  quizOptions: string[];
  correctOption: number;
  required: boolean;
  demo: boolean;
  active: boolean;
  displayOrder: number;
  version: number;
};

export default function RecruitmentAcademyAdmin() {
  const [items, setItems] = useState<Lesson[]>([]);
  const [editing, setEditing] = useState<Lesson | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState('');

  // Search & Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [filterType, setFilterType] = useState<'ALL' | 'ACTIVE' | 'INACTIVE' | 'REQUIRED' | 'DEMO'>('ALL');

  useEffect(() => {
    if (!file) {
      setPreview('');
      return;
    }
    const url = URL.createObjectURL(file);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  async function api(path = '', method = 'GET', body?: unknown) {
    const r = await fetch('/api/admin/recruitment/lessons' + path, {
      method,
      cache: 'no-store',
      headers: { 'Content-Type': 'application/json' },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const v = await r.json();
    if (!r.ok) throw new Error(v.error || 'Không thể lưu bài học.');
    return v.data;
  }

  async function load() {
    setBusy(true);
    setError('');
    try {
      setItems(await api());
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  function open(lesson: Lesson) {
    setEditing({ ...lesson, quizOptions: [...lesson.quizOptions] });
    setFile(null);
    setError('');
  }

  function pick(video: File | undefined) {
    if (!video) return;
    if (!video.name.toLowerCase().endsWith('.mp4') || video.size === 0 || video.size > 100 * 1024 * 1024) {
      setError('Chọn video MP4 tối đa 100 MB.');
      return;
    }
    setFile(video);
    setError('');
  }

  async function save() {
    if (!editing) return;
    if (!file && !editing.videoUrl) {
      setError('Vui lòng chọn video MP4 để tải lên.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      let videoUrl = editing.videoUrl;
      if (file) {
        const form = new FormData();
        form.append('video', file, file.name);
        const response = await fetch('/api/admin/recruitment/training-videos', { method: 'POST', body: form });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Không tải được video.');
        videoUrl = result.data.videoUrl;
        setEditing({ ...editing, videoUrl });
        setFile(null);
      }
      await api('/' + editing.id, 'PUT', { ...editing, videoUrl });
      setEditing(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function toggleActive(lesson: Lesson) {
    setBusy(true);
    setError('');
    try {
      await api('/' + lesson.id, 'PUT', { ...lesson, active: !lesson.active });
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const storedPreview = editing?.videoUrl.startsWith('/api/v1/partner/training/videos/')
    ? '/api/admin/recruitment/training-videos/' + editing.videoUrl.split('/').pop()
    : editing?.videoUrl;

  // Filtered Items
  const filteredItems = useMemo(() => {
    return items.filter((item) => {
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchTitle = item.title.toLowerCase().includes(q);
        const matchQuiz = item.quizText?.toLowerCase().includes(q);
        if (!matchTitle && !matchQuiz) return false;
      }
      if (filterType === 'ACTIVE') return item.active;
      if (filterType === 'INACTIVE') return !item.active;
      if (filterType === 'REQUIRED') return item.required;
      if (filterType === 'DEMO') return item.demo;
      return true;
    });
  }, [items, searchQuery, filterType]);

  const totalSeconds = items.reduce((acc, cur) => acc + (cur.durationSeconds || 0), 0);
  const totalMinutes = Math.floor(totalSeconds / 60);
  const remainingSeconds = totalSeconds % 60;

  return (
    <div className="recruitment-container">
      {/* KPI METRICS */}
      <div className="recruitment-kpi-grid">
        <div className="recruitment-kpi-card emerald">
          <span className="kpi-label">Tổng bài giảng</span>
          <span className="kpi-val">{items.length}</span>
        </div>
        <div className="recruitment-kpi-card blue">
          <span className="kpi-label">Đang hiển thị Partner</span>
          <span className="kpi-val">{items.filter((i) => i.active).length}</span>
        </div>
        <div className="recruitment-kpi-card purple">
          <span className="kpi-label">Bắt buộc hoàn thành</span>
          <span className="kpi-val">{items.filter((i) => i.required).length}</span>
        </div>
        <div className="recruitment-kpi-card amber">
          <span className="kpi-label">Tổng thời lượng đào tạo</span>
          <span className="kpi-val">
            {totalMinutes > 0 ? `${totalMinutes}p ${remainingSeconds}s` : `${remainingSeconds}s`}
          </span>
        </div>
      </div>

      {/* TOOLBAR */}
      <div className="recruitment-toolbar">
        <div className="recruitment-toolbar-row">
          <div className="recruitment-filter-group">
            <div className="recruitment-search-input">
              <Search size={16} color="#7b8e86" />
              <input
                type="text"
                placeholder="Tìm kiếm bài giảng hoặc câu hỏi..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
            <div className="recruitment-region-chips">
              {[
                { key: 'ALL', label: 'Tất cả' },
                { key: 'ACTIVE', label: 'Đang hiển thị' },
                { key: 'INACTIVE', label: 'Đang ẩn' },
                { key: 'REQUIRED', label: 'Bắt buộc' },
                { key: 'DEMO', label: 'Video mẫu' },
              ].map((pill) => (
                <button
                  key={pill.key}
                  type="button"
                  className={'region-chip ' + (filterType === pill.key ? 'active' : '')}
                  onClick={() => setFilterType(pill.key as any)}
                >
                  {pill.label}
                </button>
              ))}
            </div>
          </div>

          <div className="table-actions">
            <button
              className="btn btn-outline"
              disabled={busy}
              onClick={() => void load()}
              title="Tải lại danh sách"
            >
              <RefreshCw size={15} /> Tải lại
            </button>
            <button
              className="btn btn-primary"
              disabled={busy}
              onClick={() =>
                open({
                  id: crypto.randomUUID(),
                  title: '',
                  videoUrl: '',
                  durationSeconds: 60,
                  watchRatio: 0.9,
                  quizText: '',
                  quizOptions: ['', '', '', ''],
                  correctOption: 0,
                  required: true,
                  demo: false,
                  active: true,
                  displayOrder: items.length,
                  version: 0,
                })
              }
            >
              <Plus size={16} /> Thêm video đào tạo
            </button>
          </div>
        </div>
      </div>

      {/* ERROR NOTICE */}
      {error && !editing && (
        <div className="notice catalogue-notice" role="alert" style={{ background: '#fef2f2', borderColor: '#fca5a5', color: '#991b1b' }}>
          <AlertCircle size={16} /> {error}
        </div>
      )}

      {/* ACADEMY CARDS GRID */}
      {filteredItems.length === 0 ? (
        <div className="recruitment-card-table" style={{ padding: '40px 20px', textAlign: 'center' }}>
          <Video size={40} color="#94a3b8" style={{ margin: '0 auto 12px' }} />
          <h3 style={{ margin: '0 0 6px', color: '#1e293b' }}>Chưa có video đào tạo nào</h3>
          <p style={{ margin: 0, color: '#64748b', fontSize: 13 }}>
            Thêm video đầu tiên để Partner có thể bắt đầu học ở bước 3 quy trình tuyển dụng.
          </p>
        </div>
      ) : (
        <div className="academy-grid">
          {filteredItems.map((lesson) => {
            const minWatchSeconds = Math.ceil((lesson.durationSeconds || 0) * (lesson.watchRatio || 0.9));
            return (
              <div className="academy-card" key={lesson.id}>
                {/* PREVIEW CONTAINER */}
                <div className="academy-video-preview">
                  <span className="academy-order-badge">#{lesson.displayOrder + 1}</span>
                  <div className="academy-play-icon">
                    <Play size={24} fill="currentColor" />
                  </div>
                  <div className="academy-duration-badge">
                    <Clock size={12} />
                    <span>{lesson.durationSeconds} giây</span>
                  </div>
                </div>

                {/* CARD BODY */}
                <div className="academy-card-body">
                  <div>
                    <h3 className="academy-title">{lesson.title || 'Bài học chưa đặt tên'}</h3>
                    <div className="academy-badges">
                      <span className={'status-pill ' + (lesson.active ? 'open' : 'closed')}>
                        <span className="status-pill-dot" />
                        {lesson.active ? 'Đang hiển thị' : 'Đang ẩn'}
                      </span>
                      {lesson.required && (
                        <span className="status-pill open" style={{ background: '#eff6ff', color: '#1d4ed8', borderColor: '#bfdbfe' }}>
                          Bắt buộc
                        </span>
                      )}
                      {lesson.demo && (
                        <span className="status-pill open" style={{ background: '#faf5ff', color: '#7e22ce', borderColor: '#e9d5ff' }}>
                          Video mẫu
                        </span>
                      )}
                      <span className="area-city-badge">
                        Xem tối thiểu {minWatchSeconds}s ({Math.round(lesson.watchRatio * 100)}%)
                      </span>
                    </div>
                  </div>

                  {/* QUIZ BOX */}
                  {lesson.quizText && (
                    <div className="academy-quiz-box">
                      <div className="academy-quiz-header">
                        <CheckCircle2 size={13} />
                        <span>Câu hỏi kiểm tra sau video</span>
                      </div>
                      <div className="academy-quiz-question">{lesson.quizText}</div>
                      <div className="academy-quiz-options">
                        {lesson.quizOptions.map((opt, idx) => (
                          <div
                            key={idx}
                            className={'academy-quiz-option ' + (idx === lesson.correctOption ? 'correct' : '')}
                          >
                            <span style={{ fontWeight: 800, width: 18 }}>
                              {String.fromCharCode(65 + idx)}.
                            </span>
                            <span>{opt || '(Chưa nhập)'}</span>
                            {idx === lesson.correctOption && <Check size={14} style={{ marginLeft: 'auto' }} />}
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                {/* CARD FOOTER ACTIONS */}
                <div className="academy-card-footer">
                  <button
                    className="btn-icon-action"
                    onClick={() => toggleActive(lesson)}
                    disabled={busy}
                    title={lesson.active ? 'Ẩn khỏi Partner' : 'Bật hiển thị'}
                  >
                    {lesson.active ? <EyeOff size={14} /> : <Eye size={14} />}
                    <span>{lesson.active ? 'Ẩn video' : 'Hiện video'}</span>
                  </button>

                  <button
                    className="btn-icon-action"
                    onClick={() => open(lesson)}
                    disabled={busy}
                    style={{ background: '#effaf6', color: '#0b785f', borderColor: '#cde9de' }}
                  >
                    <Edit3 size={14} />
                    <span>Sửa video</span>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* EDITING MODAL */}
      {editing && (
        <CataloguePopup
          title={editing.version === 0 && !editing.videoUrl ? 'Thêm video bước 3' : 'Chỉnh sửa video đào tạo'}
          eyebrow="TUYỂN DỤNG · PARTNER ACADEMY"
          busy={busy}
          onClose={() => {
            setEditing(null);
            setFile(null);
          }}
        >
          <form
            className="modal-form-grid"
            onSubmit={(e) => {
              e.preventDefault();
              void save();
            }}
          >
            <label className="modal-label">
              Tên video bài giảng
              <input
                required
                maxLength={200}
                disabled={busy}
                placeholder="VD: Quy chuẩn đón trả khách và an toàn lao động..."
                value={editing.title}
                onChange={(e) => setEditing({ ...editing, title: e.target.value })}
              />
            </label>

            <label className="modal-label">
              Tải video trực tiếp (MP4, tối đa 100 MB)
              <input
                type="file"
                accept="video/mp4,.mp4"
                disabled={busy}
                onChange={(e) => pick(e.target.files?.[0])}
              />
              {file && (
                <small style={{ color: '#0b785f', fontWeight: 600 }}>
                  ✓ Đã chọn: {file.name} · {(file.size / 1024 / 1024).toFixed(1)} MB
                </small>
              )}
            </label>

            {(preview || storedPreview) && (
              <video
                key={preview || storedPreview}
                src={preview || storedPreview}
                controls
                preload="metadata"
                style={{
                  width: '100%',
                  maxHeight: 280,
                  borderRadius: 14,
                  background: '#0e271f',
                  boxShadow: '0 4px 14px rgba(0,0,0,0.15)',
                }}
                onLoadedMetadata={(e) => {
                  if (!file) return;
                  const seconds = Math.ceil(e.currentTarget.duration);
                  if (Number.isFinite(seconds) && seconds > 0) {
                    setEditing((current) =>
                      current ? { ...current, durationSeconds: seconds } : current
                    );
                  }
                }}
              />
            )}

            <div className="modal-row">
              <label className="modal-label">
                Thời lượng video (giây)
                <input
                  type="number"
                  min={10}
                  max={14400}
                  required
                  disabled={busy}
                  value={editing.durationSeconds}
                  onChange={(e) => setEditing({ ...editing, durationSeconds: Number(e.target.value) })}
                />
                <small>Tự lấy từ file video hoặc chỉnh lại thủ công.</small>
              </label>

              <label className="modal-label">
                Tỷ lệ xem bắt buộc (0.5 – 1.0)
                <input
                  type="number"
                  min={0.5}
                  max={1}
                  step={0.01}
                  required
                  disabled={busy}
                  value={editing.watchRatio}
                  onChange={(e) => setEditing({ ...editing, watchRatio: Number(e.target.value) })}
                />
                <small>
                  Partner cần xem ít nhất {Math.ceil(editing.durationSeconds * editing.watchRatio)} giây.
                </small>
              </label>
            </div>

            <label className="modal-label">
              Câu kiểm tra trắc nghiệm sau video
              <input
                required
                maxLength={2000}
                disabled={busy}
                placeholder="VD: Khi khách hàng yêu cầu hỗ trợ thêm, đối tác cần làm gì?"
                value={editing.quizText}
                onChange={(e) => setEditing({ ...editing, quizText: e.target.value })}
              />
            </label>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              {editing.quizOptions.map((o, i) => (
                <label className="modal-label" key={i}>
                  Lựa chọn {String.fromCharCode(65 + i)}
                  <input
                    required
                    maxLength={500}
                    disabled={busy}
                    placeholder={`Nội dung lựa chọn ${String.fromCharCode(65 + i)}...`}
                    value={o}
                    onChange={(e) => {
                      const options = [...editing.quizOptions];
                      options[i] = e.target.value;
                      setEditing({ ...editing, quizOptions: options });
                    }}
                  />
                </label>
              ))}
            </div>

            <div className="modal-row">
              <label className="modal-label">
                Đáp án đúng
                <select
                  disabled={busy}
                  value={editing.correctOption}
                  onChange={(e) => setEditing({ ...editing, correctOption: Number(e.target.value) })}
                >
                  {[0, 1, 2, 3].map((i) => (
                    <option key={i} value={i}>
                      Lựa chọn {String.fromCharCode(65 + i)}
                    </option>
                  ))}
                </select>
              </label>

              <label className="modal-label">
                Thứ tự hiển thị
                <input
                  type="number"
                  min={0}
                  required
                  disabled={busy}
                  value={editing.displayOrder}
                  onChange={(e) => setEditing({ ...editing, displayOrder: Number(e.target.value) })}
                />
              </label>
            </div>

            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, background: '#f8faf9', padding: 12, borderRadius: 10 }}>
              {(['required', 'active', 'demo'] as const).map((key) => (
                <label key={key} style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 600, cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    disabled={busy}
                    checked={editing[key]}
                    onChange={(e) => setEditing({ ...editing, [key]: e.target.checked })}
                  />
                  {({ required: 'Video bắt buộc', active: 'Hiển thị trên Partner', demo: 'Video mẫu' })[key]}
                </label>
              ))}
            </div>

            {error && <p role="alert" className="api-error">{error}</p>}

            <button className="btn btn-primary" disabled={busy} style={{ width: '100%', marginTop: 8 }}>
              {busy ? 'Đang tải video và lưu…' : 'Lưu video đào tạo'}
            </button>
          </form>
        </CataloguePopup>
      )}
    </div>
  );
}
