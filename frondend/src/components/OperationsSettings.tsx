'use client';

import React, { useEffect, useState } from 'react';
import { Settings2, Clock, ShieldAlert, CheckCircle2, RefreshCw, AlertCircle, UserCheck, Timer, AlertTriangle } from 'lucide-react';

export default function OperationsSettings({ notify }: { notify: (msg: string) => void }) {
  const [minBufferMinutes, setMinBufferMinutes] = useState<number>(60);
  const [travelSafetyMinutes, setTravelSafetyMinutes] = useState<number>(15);
  const [earlyCheckinWindowMinutes, setEarlyCheckinWindowMinutes] = useState<number>(15);
  const [maxEarlyStartMinutes, setMaxEarlyStartMinutes] = useState<number>(60);
  const [earlyStartExpiryMinutes, setEarlyStartExpiryMinutes] = useState<number>(15);
  const [loading, setLoading] = useState<boolean>(true);
  const [saving, setSaving] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const fetchSettings = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/admin/settings/operations');
      const json = await res.json();
      if (json.success && json.data) {
        setMinBufferMinutes(json.data.minBufferMinutes ?? 60);
        setTravelSafetyMinutes(json.data.travelSafetyMinutes ?? 15);
        setEarlyCheckinWindowMinutes(json.data.earlyCheckinWindowMinutes ?? 15);
        setMaxEarlyStartMinutes(json.data.maxEarlyStartMinutes ?? 60);
        setEarlyStartExpiryMinutes(json.data.earlyStartExpiryMinutes ?? 15);
      }
    } catch (err: any) {
      setError(err.message || 'Không thể tải cấu hình vận hành.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void fetchSettings();
  }, []);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (minBufferMinutes < 15 || minBufferMinutes > 360) {
      notify('Khoảng thời gian tối thiểu giữa hai đơn phải từ 15 đến 360 phút.');
      return;
    }
    if (travelSafetyMinutes < 0 || travelSafetyMinutes > 180) {
      notify('Thời gian đệm an toàn phải từ 0 đến 180 phút.');
      return;
    }
    if (earlyCheckinWindowMinutes < 0 || earlyCheckinWindowMinutes > 120) {
      notify('Cửa sổ check-in sớm phải từ 0 đến 120 phút.');
      return;
    }
    if (maxEarlyStartMinutes < 0 || maxEarlyStartMinutes > 240) {
      notify('Số phút tối đa được đề nghị bắt đầu sớm phải từ 0 đến 240 phút.');
      return;
    }
    if (earlyStartExpiryMinutes < 1 || earlyStartExpiryMinutes > 120) {
      notify('Thời hạn phản hồi đề nghị phải từ 1 đến 120 phút.');
      return;
    }

    setSaving(true);
    try {
      const res = await fetch('/api/admin/settings/operations', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          minBufferMinutes,
          travelSafetyMinutes,
          earlyCheckinWindowMinutes,
          maxEarlyStartMinutes,
          earlyStartExpiryMinutes,
        }),
      });
      const json = await res.json();
      if (!res.ok || json.error) {
        throw new Error(json.error?.message || 'Lỗi khi lưu cấu hình');
      }
      notify('Đã cập nhật chính sách khoảng cách ca 60 phút, check-in sớm và đề nghị làm sớm thành công!');
    } catch (err: any) {
      notify(`Lỗi: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="panel" style={{ maxWidth: 840 }}>
      <div className="section-head" style={{ marginBottom: 20 }}>
        <div>
          <h2 style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Settings2 size={20} className="text-blue-600" />
            Cấu hình Lịch trình, Khoảng cách Ca & Khởi đầu Sớm (Scheduling & Job Lifecycle)
          </h2>
          <p className="subtle">
            Quản trị quy tắc khoảng cách ca 60 phút giữa các việc của đối tác, cửa sổ check-in sớm, giới hạn đề nghị bắt đầu sớm và quyền chấp thuận của khách hàng.
          </p>
        </div>
        <button
          type="button"
          className="btn btn-outline"
          disabled={loading || saving}
          onClick={() => void fetchSettings()}
        >
          <RefreshCw size={15} className={loading ? 'animate-spin' : ''} /> Tải lại
        </button>
      </div>

      {error && (
        <div className="notice" style={{ borderColor: '#ef4444', color: '#b91c1c', marginBottom: 16 }}>
          <AlertCircle size={16} /> {error}
        </div>
      )}

      <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
        {/* 1. Khoảng cách ca 60 phút */}
        <div style={{ background: '#f8fafc', padding: 18, borderRadius: 14, border: '1px solid #e2e8f0' }}>
          <label style={{ display: 'block', fontWeight: 700, fontSize: 14, color: '#0f172a', marginBottom: 6 }}>
            <Clock size={16} style={{ display: 'inline', marginRight: 6, verticalAlign: 'text-bottom' }} />
            Khoảng cách tối thiểu giữa 2 công việc của Partner (minInterJobBufferMinutes)
          </label>
          <input
            type="number"
            min={15}
            max={360}
            value={minBufferMinutes}
            onChange={(e) => setMinBufferMinutes(Number(e.target.value))}
            style={{
              width: '100%',
              maxWidth: 240,
              padding: '10px 14px',
              borderRadius: 10,
              border: '1.5px solid #cbd5e1',
              fontSize: 15,
              fontWeight: 700,
            }}
          />
          <p style={{ margin: '8px 0 0', fontSize: 12.5, color: '#64748b', lineHeight: 1.45 }}>
            Giá trị mặc định: <strong>60 phút</strong>. Khi đối tác nhận ca trước A và ca sau B: <code>scheduledStart(B) &gt;= effectiveEnd(A) + requiredGap</code>. Đảm bảo bảo toàn vùng đặt chỗ cho đến khi ca trước kết thúc thực tế được xác minh.
          </p>
        </div>

        {/* 2. Đệm an toàn di chuyển */}
        <div style={{ background: '#f8fafc', padding: 18, borderRadius: 14, border: '1px solid #e2e8f0' }}>
          <label style={{ display: 'block', fontWeight: 700, fontSize: 14, color: '#0f172a', marginBottom: 6 }}>
            <ShieldAlert size={16} style={{ display: 'inline', marginRight: 6, verticalAlign: 'text-bottom' }} />
            Thời gian đệm an toàn di chuyển bổ sung (travelSafetyMinutes)
          </label>
          <input
            type="number"
            min={0}
            max={180}
            value={travelSafetyMinutes}
            onChange={(e) => setTravelSafetyMinutes(Number(e.target.value))}
            style={{
              width: '100%',
              maxWidth: 240,
              padding: '10px 14px',
              borderRadius: 10,
              border: '1.5px solid #cbd5e1',
              fontSize: 15,
              fontWeight: 700,
            }}
          />
          <p style={{ margin: '8px 0 0', fontSize: 12.5, color: '#64748b', lineHeight: 1.45 }}>
            Giá trị mặc định: <strong>15 phút</strong>. Khi có dữ liệu tọa độ định vị giữa 2 đơn, khoảng cách thực tế là <code>requiredGap = max(minBufferMinutes, travelETA + travelSafetyMinutes)</code>.
          </p>
        </div>

        {/* 3. Cửa sổ check-in sớm */}
        <div style={{ background: '#f8fafc', padding: 18, borderRadius: 14, border: '1px solid #e2e8f0' }}>
          <label style={{ display: 'block', fontWeight: 700, fontSize: 14, color: '#0f172a', marginBottom: 6 }}>
            <UserCheck size={16} style={{ display: 'inline', marginRight: 6, verticalAlign: 'text-bottom' }} />
            Cửa sổ cho phép check-in sớm trước giờ làm (earlyCheckInWindowMinutes)
          </label>
          <input
            type="number"
            min={0}
            max={120}
            value={earlyCheckinWindowMinutes}
            onChange={(e) => setEarlyCheckinWindowMinutes(Number(e.target.value))}
            style={{
              width: '100%',
              maxWidth: 240,
              padding: '10px 14px',
              borderRadius: 10,
              border: '1.5px solid #cbd5e1',
              fontSize: 15,
              fontWeight: 700,
            }}
          />
          <p style={{ margin: '8px 0 0', fontSize: 12.5, color: '#64748b', lineHeight: 1.45 }}>
            Giá trị mặc định: <strong>15 phút</strong>. Ví dụ hẹn 12:00 thì Partner chỉ có thể check-in từ 11:45 nếu đã thực sự đến nơi. Check-in sớm ghi nhận <code>checkedInAt/ARRIVED</code> nhưng <strong>KHÔNG</strong> tự động mở quyền làm sớm trước giờ hẹn.
          </p>
        </div>

        {/* 4. Giới hạn tối đa đề nghị bắt đầu sớm */}
        <div style={{ background: '#f8fafc', padding: 18, borderRadius: 14, border: '1px solid #e2e8f0' }}>
          <label style={{ display: 'block', fontWeight: 700, fontSize: 14, color: '#0f172a', marginBottom: 6 }}>
            <Timer size={16} style={{ display: 'inline', marginRight: 6, verticalAlign: 'text-bottom' }} />
            Số phút tối đa được đề nghị bắt đầu sớm (maxEarlyStartMinutes)
          </label>
          <input
            type="number"
            min={0}
            max={240}
            value={maxEarlyStartMinutes}
            onChange={(e) => setMaxEarlyStartMinutes(Number(e.target.value))}
            style={{
              width: '100%',
              maxWidth: 240,
              padding: '10px 14px',
              borderRadius: 10,
              border: '1.5px solid #cbd5e1',
              fontSize: 15,
              fontWeight: 700,
            }}
          />
          <p style={{ margin: '8px 0 0', fontSize: 12.5, color: '#64748b', lineHeight: 1.45 }}>
            Giá trị mặc định: <strong>60 phút</strong>. Đối tác không được gửi đề nghị bắt đầu sớm hơn giới hạn này trước giờ đặt ban đầu. Khách hàng phải bấm Đồng ý rõ ràng trong app thì Backend mới mở nút bắt đầu.
          </p>
        </div>

        {/* 5. Thời hạn hiệu lực của đề nghị */}
        <div style={{ background: '#f8fafc', padding: 18, borderRadius: 14, border: '1px solid #e2e8f0' }}>
          <label style={{ display: 'block', fontWeight: 700, fontSize: 14, color: '#0f172a', marginBottom: 6 }}>
            <AlertTriangle size={16} style={{ display: 'inline', marginRight: 6, verticalAlign: 'text-bottom' }} />
            Thời hạn phản hồi đề nghị làm sớm (earlyStartExpiryMinutes)
          </label>
          <input
            type="number"
            min={1}
            max={120}
            value={earlyStartExpiryMinutes}
            onChange={(e) => setEarlyStartExpiryMinutes(Number(e.target.value))}
            style={{
              width: '100%',
              maxWidth: 240,
              padding: '10px 14px',
              borderRadius: 10,
              border: '1.5px solid #cbd5e1',
              fontSize: 15,
              fontWeight: 700,
            }}
          />
          <p style={{ margin: '8px 0 0', fontSize: 12.5, color: '#64748b', lineHeight: 1.45 }}>
            Giá trị mặc định: <strong>15 phút</strong>. Nếu khách hàng không phản hồi trước thời điểm này hoặc trước giờ hẹn ban đầu, đề nghị sẽ tự động chuyển sang <code>EXPIRED</code> và Partner tiếp tục chờ theo giờ hẹn ban đầu.
          </p>
        </div>

        <div style={{ background: '#eff6ff', padding: 14, borderRadius: 12, border: '1px solid #bfdbfe', fontSize: 12.5, color: '#1e40af', lineHeight: 1.45 }}>
          <strong>Quy tắc bảo vệ dữ liệu &amp; Tính toàn vẹn:</strong> Cấu hình mới sẽ tác động ngay lập tức lên các yêu cầu kiểm tra lịch, check-in và đề nghị mới. Tuyệt đối không hồi tố thay đổi hoặc hủy bỏ các công việc đã được khách hàng xác nhận trước đó.
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 10 }}>
          <button
            type="submit"
            className="btn btn-primary"
            disabled={loading || saving}
            style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '10px 20px' }}
          >
            {saving ? <RefreshCw size={16} className="animate-spin" /> : <CheckCircle2 size={16} />}
            Lưu cấu hình vận hành
          </button>
        </div>
      </form>
    </div>
  );
}
