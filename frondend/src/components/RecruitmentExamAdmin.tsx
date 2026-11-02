'use client';

import { useEffect, useMemo, useState } from 'react';
import {
  FileText, CheckCircle2, AlertCircle, Plus, Search, Edit3,
  Trash2, RefreshCw, Clock, Check, Award, SlidersHorizontal,
  Star, HelpCircle, Eye, EyeOff
} from 'lucide-react';
import CataloguePopup from './CataloguePopup';

type Question = {
  id: string;
  text: string;
  options: string[];
  correctOption: number;
  category: string;
  difficulty: number;
  active: boolean;
  version: number;
};

type Config = {
  exam_minutes: number;
  pass_mark: number;
  attempts_per_day: number;
  version: number;
};

async function api(path: string, method = 'GET', body?: unknown) {
  const r = await fetch('/api/admin/recruitment/' + path, {
    method,
    cache: 'no-store',
    headers: { 'Content-Type': 'application/json' },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const v = await r.json();
  if (!r.ok) throw new Error(v.error || 'Không thể xử lý ngân hàng câu hỏi.');
  return v.data;
}

export default function RecruitmentExamAdmin() {
  const [questions, setQuestions] = useState<Question[]>([]);
  const [config, setConfig] = useState<Config | null>(null);
  const [configDraft, setConfigDraft] = useState<Config | null>(null);
  const [editing, setEditing] = useState<Question | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [configSuccess, setConfigSuccess] = useState('');

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'ACTIVE' | 'INACTIVE'>('ALL');

  async function load() {
    setBusy(true);
    setError('');
    try {
      const [q, c] = await Promise.all([api('questions'), api('exam-config')]);
      setQuestions(q);
      setConfig(c);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  async function action(path: string, method: string, body?: unknown) {
    setBusy(true);
    setError('');
    try {
      await api(path, method, body);
      setEditing(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function saveConfig(e: React.FormEvent) {
    e.preventDefault();
    if (!configDraft) return;
    setBusy(true);
    setError('');
    setConfigSuccess('');
    try {
      const saved = await api('exam-config', 'PUT', {
        examMinutes: configDraft.exam_minutes,
        passMark: configDraft.pass_mark,
        attemptsPerDay: configDraft.attempts_per_day,
        version: configDraft.version,
      });
      setConfig(saved);
      setConfigDraft(null);
      setConfigSuccess('Đã lưu cấu hình quy chế thi thành công.');
      setTimeout(() => setConfigSuccess(''), 3000);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const allCategories = useMemo(() => {
    return Array.from(new Set(questions.map((q) => q.category).filter(Boolean)));
  }, [questions]);

  const filteredQuestions = useMemo(() => {
    return questions.filter((q) => {
      if (searchQuery.trim()) {
        const query = searchQuery.toLowerCase();
        const matchText = q.text.toLowerCase().includes(query);
        const matchOptions = q.options.some((opt) => opt.toLowerCase().includes(query));
        if (!matchText && !matchOptions) return false;
      }
      if (categoryFilter !== 'ALL' && q.category !== categoryFilter) return false;
      if (statusFilter === 'ACTIVE' && !q.active) return false;
      if (statusFilter === 'INACTIVE' && q.active) return false;
      return true;
    });
  }, [questions, searchQuery, categoryFilter, statusFilter]);

  const activeCount = questions.filter((q) => q.active).length;

  return (
    <div className="recruitment-container">
      {/* KPI CARDS */}
      <div className="recruitment-kpi-grid">
        <div className="recruitment-kpi-card emerald">
          <span className="kpi-label">Ngân hàng câu hỏi</span>
          <span className="kpi-val">{questions.length}</span>
        </div>
        <div className="recruitment-kpi-card blue">
          <span className="kpi-label">Đang đưa vào đề thi</span>
          <span className="kpi-val">{activeCount}</span>
        </div>
        <div className="recruitment-kpi-card purple">
          <span className="kpi-label">Thời gian làm bài</span>
          <span className="kpi-val">{config ? `${config.exam_minutes} phút` : '—'}</span>
        </div>
        <div className="recruitment-kpi-card amber">
          <span className="kpi-label">Số câu đúng để đạt</span>
          <span className="kpi-val">
            {config ? `${config.pass_mark}/20 (${Math.round((config.pass_mark / 20) * 100)}%)` : '—'}
          </span>
        </div>
      </div>

      {activeCount < 20 && !busy && <p role="alert">Chưa đủ 20 câu hỏi thật đang hoạt động. Hãy bổ sung câu hỏi trước khi mở bài thi.</p>}
      {/* EXAM CONFIGURATION CARD */}
      {config && (
        <div className="exam-config-card">
          <div className="exam-config-header">
            <h3 className="exam-config-title">
              <SlidersHorizontal size={18} color="#0b9879" />
              <span>Cấu hình bài kiểm tra kiến thức</span>
            </h3>
            {configSuccess && (
              <span style={{ color: '#0b785f', fontSize: 13, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 4 }}>
                <CheckCircle2 size={16} /> {configSuccess}
              </span>
            )}
          </div>

          <p className="subtle">Mỗi đề có 20 câu ngẫu nhiên từ ngân hàng câu hỏi thật. Bấm Sửa cấu hình để chọn số câu đúng tối thiểu, rồi lưu để áp dụng cho các bài thi bắt đầu sau đó.</p>
          <div className="row">
            <span>{config.exam_minutes} phút · Đạt {config.pass_mark}/20 câu · {config.attempts_per_day} lượt/ngày</span>
            <button type="button" className="btn btn-primary" disabled={busy} onClick={() => { setError(''); setConfigDraft({ ...config }); }}><Edit3 size={16} /> Sửa cấu hình</button>
          </div>
        </div>
      )}

      {configDraft && (
        <CataloguePopup title="Sửa cấu hình bài kiểm tra kiến thức" eyebrow="PARTNER ACADEMY" drawer busy={busy} onClose={() => setConfigDraft(null)}>
          {error && <p role="alert" className="error">{error}</p>}
          <p className="subtle">Thay đổi chỉ áp dụng sau khi lưu và dành cho các bài thi bắt đầu sau đó.</p>
          <form onSubmit={saveConfig}>
            <div className="exam-config-grid">
              <div className="exam-config-field">
                <label htmlFor="exam-config-minutes">Thời gian làm bài (phút)</label>
                <input
                  type="number"
                  min={1}
                  max={120}
                  required
                  disabled={busy}
                  id="exam-config-minutes"
                  value={configDraft.exam_minutes}
                  onChange={(e) => setConfigDraft({ ...configDraft, exam_minutes: Number(e.target.value) })}
                />
              </div>

              <div className="exam-config-field">
                <label htmlFor="exam-config-pass">Số câu đúng tối thiểu để đạt / 20 câu</label>
                <input
                  type="number"
                  min={1}
                  max={20}
                  step={1}
                  required
                  disabled={busy}
                  id="exam-config-pass"
                  value={configDraft.pass_mark}
                  onChange={(e) => setConfigDraft({ ...configDraft, pass_mark: Number(e.target.value) })}
                />
              </div>

              <div className="exam-config-field">
                <label htmlFor="exam-config-attempts">Số lượt thi tối đa mỗi ngày (UTC)</label>
                <input
                  type="number"
                  min={1}
                  max={10}
                  required
                  disabled={busy}
                  id="exam-config-attempts"
                  value={configDraft.attempts_per_day}
                  onChange={(e) => setConfigDraft({ ...configDraft, attempts_per_day: Number(e.target.value) })}
                />
              </div>

              <div>
                <button className="btn btn-primary" disabled={busy} style={{ width: '100%', minHeight: 44 }}>
                  <Check size={16} /> {busy ? 'Đang lưu…' : 'Lưu cấu hình bài thi'}
                </button>
                <button type="button" className="btn btn-outline" disabled={busy} style={{ width: '100%', marginTop: 10 }} onClick={() => setConfigDraft(null)}>Hủy</button>
              </div>
            </div>
          </form>
        </CataloguePopup>
      )}

      {/* TOOLBAR */}
      <div className="recruitment-toolbar">
        <div className="recruitment-toolbar-row">
          <div className="recruitment-filter-group">
            <div className="recruitment-search-input">
              <Search size={16} color="#7b8e86" />
              <input
                type="text"
                placeholder="Tìm nội dung câu hỏi hoặc đáp án..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>

            <select
              className="recruitment-select"
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
            >
              <option value="ALL">Tất cả chủ đề</option>
              {allCategories.map((cat) => (
                <option key={cat} value={cat}>
                  {cat}
                </option>
              ))}
            </select>

            <div className="recruitment-region-chips">
              {[
                { key: 'ALL', label: 'Tất cả' },
                { key: 'ACTIVE', label: 'Đang dùng' },
                { key: 'INACTIVE', label: 'Ngừng dùng' },
              ].map((pill) => (
                <button
                  key={pill.key}
                  type="button"
                  className={'region-chip ' + (statusFilter === pill.key ? 'active' : '')}
                  onClick={() => setStatusFilter(pill.key as any)}
                >
                  {pill.label}
                </button>
              ))}
            </div>
          </div>

          <div className="table-actions">
            <button className="btn btn-outline" disabled={busy} onClick={() => void load()}>
              <RefreshCw size={15} /> Tải lại
            </button>
            <button
              className="btn btn-primary"
              disabled={busy}
              onClick={() =>
                setEditing({
                  id: crypto.randomUUID(),
                  text: '',
                  options: ['', '', '', ''],
                  correctOption: 0,
                  category: 'An toàn',
                  difficulty: 1,
                  active: true,
                  version: 0,
                })
              }
            >
              <Plus size={16} /> Thêm câu hỏi
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

      {/* QUESTIONS LIST */}
      {filteredQuestions.length === 0 ? (
        <div className="recruitment-card-table" style={{ padding: '40px 20px', textAlign: 'center' }}>
          <HelpCircle size={40} color="#94a3b8" style={{ margin: '0 auto 12px' }} />
          <h3 style={{ margin: '0 0 6px', color: '#1e293b' }}>Không tìm thấy câu hỏi phù hợp</h3>
          <p style={{ margin: 0, color: '#64748b', fontSize: 13 }}>
            Thử thay đổi bộ lọc hoặc thêm câu hỏi mới vào ngân hàng đề thi tuyển dụng.
          </p>
        </div>
      ) : (
        <div className="exam-questions-list">
          {filteredQuestions.map((q, index) => (
            <div className="exam-question-card" key={q.id}>
              {/* HEADER */}
              <div className="exam-question-header">
                <div className="exam-question-meta">
                  <span className="exam-q-num">Câu #{index + 1}</span>
                  <span className="exam-q-category">{q.category || 'Chung'}</span>
                  <span className="exam-q-diff">
                    <Star size={12} fill="#d97706" color="#d97706" />
                    <span>Độ khó {q.difficulty}/5</span>
                  </span>
                  <span className={'status-pill ' + (q.active ? 'open' : 'closed')}>
                    <span className="status-pill-dot" />
                    {q.active ? 'Đang dùng' : 'Ngừng dùng'}
                  </span>
                </div>

                <div className="table-actions">
                  <button
                    className="btn-icon-action"
                    disabled={busy}
                    onClick={() => setEditing({ ...q, options: [...q.options] })}
                    style={{ background: '#effaf6', color: '#0b785f', borderColor: '#cde9de' }}
                  >
                    <Edit3 size={14} /> Sửa
                  </button>
                  <button
                    className={'btn-icon-action ' + (q.active ? 'danger' : '')}
                    disabled={busy}
                    onClick={() => {
                      if (q.active) {
                        if (window.confirm('Ngừng sử dụng câu hỏi này? Các bài thi cũ vẫn được giữ.')) {
                          void action('questions/' + q.id, 'DELETE');
                        }
                      } else {
                        void action('questions/' + q.id, 'PUT', { ...q, active: true });
                      }
                    }}
                  >
                    {q.active ? <Trash2 size={14} /> : <Eye size={14} />}
                    {q.active ? 'Ngừng dùng' : 'Kích hoạt lại'}
                  </button>
                </div>
              </div>

              {/* QUESTION TEXT */}
              <p className="exam-q-text">{q.text}</p>

              {/* 4 OPTIONS GRID */}
              <div className="exam-options-grid">
                {q.options.map((opt, i) => {
                  const isCorrect = i === q.correctOption;
                  return (
                    <div className={'exam-opt-card ' + (isCorrect ? 'correct' : '')} key={i}>
                      <span className="exam-opt-letter">{String.fromCharCode(65 + i)}</span>
                      <span style={{ flex: 1 }}>{opt || '(Chưa nhập nội dung)'}</span>
                      {isCorrect && (
                        <span style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#059669', fontSize: 11, fontWeight: 800 }}>
                          <CheckCircle2 size={15} /> Đáp án đúng
                        </span>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* EDIT MODAL */}
      {editing && (
        <CataloguePopup
          title={editing.version === 0 ? 'Thêm câu hỏi mới' : 'Chỉnh sửa câu hỏi'}
          eyebrow="PARTNER ACADEMY · NGÂN HÀNG CÂU HỎI"
          busy={busy}
          onClose={() => setEditing(null)}
        >
          <form
            className="modal-form-grid"
            onSubmit={(e) => {
              e.preventDefault();
              void action('questions/' + editing.id, 'PUT', editing);
            }}
          >
            <label className="modal-label">
              Nội dung câu hỏi
              <textarea
                required
                maxLength={2000}
                rows={3}
                disabled={busy}
                placeholder="VD: Khi phát hiện đồ đạc của khách để quên, đối tác cần xử lý như thế nào?"
                value={editing.text}
                onChange={(e) => setEditing({ ...editing, text: e.target.value })}
              />
            </label>

            <div className="modal-row">
              <label className="modal-label">
                Chủ đề
                <input
                  required
                  maxLength={100}
                  disabled={busy}
                  placeholder="VD: An toàn, Ứng xử, Quy trình..."
                  value={editing.category}
                  onChange={(e) => setEditing({ ...editing, category: e.target.value })}
                />
              </label>

              <label className="modal-label">
                Độ khó (1 – 5)
                <input
                  type="number"
                  min={1}
                  max={5}
                  required
                  disabled={busy}
                  value={editing.difficulty}
                  onChange={(e) => setEditing({ ...editing, difficulty: Number(e.target.value) })}
                />
              </label>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <span style={{ fontSize: 12, fontWeight: 700, color: '#324c43' }}>
                4 Phương án lựa chọn (chọn nút bên phải để đánh dấu đáp án đúng)
              </span>
              {editing.options.map((option, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span className="exam-opt-letter" style={{ width: 28, height: 28 }}>
                    {String.fromCharCode(65 + i)}
                  </span>
                  <input
                    required
                    maxLength={500}
                    disabled={busy}
                    placeholder={`Nội dung phương án ${String.fromCharCode(65 + i)}...`}
                    style={{ flex: 1 }}
                    value={option}
                    onChange={(e) => {
                      const options = [...editing.options];
                      options[i] = e.target.value;
                      setEditing({ ...editing, options });
                    }}
                  />
                  <button
                    type="button"
                    className={'btn ' + (editing.correctOption === i ? 'btn-primary' : 'btn-outline')}
                    onClick={() => setEditing({ ...editing, correctOption: i })}
                    style={{ minWidth: 110, fontSize: 11, padding: '8px 10px' }}
                  >
                    {editing.correctOption === i ? '✓ Đáp án đúng' : 'Chọn đúng'}
                  </button>
                </div>
              ))}
            </div>

            <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, fontWeight: 600, cursor: 'pointer', background: '#f8faf9', padding: 12, borderRadius: 10 }}>
              <input
                type="checkbox"
                disabled={busy}
                checked={editing.active}
                onChange={(e) => setEditing({ ...editing, active: e.target.checked })}
              />
              Đang sử dụng trong ngân hàng câu hỏi
            </label>

            {error && <p role="alert" className="api-error">{error}</p>}

            <button className="btn btn-primary" disabled={busy} style={{ width: '100%', marginTop: 8 }}>
              {busy ? 'Đang lưu câu hỏi…' : 'Lưu câu hỏi'}
            </button>
          </form>
        </CataloguePopup>
      )}
    </div>
  );
}
