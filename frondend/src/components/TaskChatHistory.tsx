'use client';
import { useEffect, useState } from 'react';
import { MessageCircle } from 'lucide-react';

type Message = { id: string; text: string; image_data?: string; at: string; sender_name: string; sender_portal: string };
export default function TaskChatHistory({ taskId }: { taskId: string }) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  useEffect(() => {
    const controller = new AbortController();
    let busy = false;
    const load = async () => {
      if (busy) return;
      busy = true;
      try {
        const response = await fetch(`/api/admin/tasks/${taskId}/messages`, { cache: 'no-store', signal: controller.signal });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Không tải được cuộc trò chuyện.');
        if (!controller.signal.aborted) { setMessages(data.messages || []); setError(''); }
      } catch (e) {
        if (!controller.signal.aborted) setError((e as Error).message);
      } finally {
        busy = false;
        if (!controller.signal.aborted) setLoading(false);
      }
    };
    void load();
    const timer = setInterval(() => { if (document.visibilityState === 'visible') void load(); }, 5000);
    return () => { controller.abort(); clearInterval(timer); };
  }, [taskId]);
  return <section className="task-section-card">
    <div className="task-section-header"><span className="task-section-title"><div className="task-section-icon"><MessageCircle size={15} /></div>Chat khách hàng và Partner</span></div>
    <p style={{ color: '#64748b', fontSize: 12 }}>Lịch sử trò chuyện · Tự cập nhật</p>
    {loading && <p role="status">Đang tải tin nhắn...</p>}
    {error && <p role="alert" style={{ color: '#b91c1c' }}>{error}</p>}
    {!loading && !error && messages.length === 0 && <p style={{ color: '#64748b' }}>Chưa có tin nhắn giữa khách hàng và Partner.</p>}
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12, maxHeight: 420, overflowY: 'auto', padding: 4 }}>
      {messages.map(message => {
        const partner = message.sender_portal === 'PARTNER';
        const label = partner ? 'Partner' : message.sender_portal === 'CUSTOMER' ? 'Khách hàng' : 'Chưa xác định vai trò';
        return <article key={message.id} style={{ alignSelf: partner ? 'flex-start' : 'flex-end', maxWidth: '85%', padding: '12px 14px', borderRadius: 14, border: '1px solid #e2e8f0', background: partner ? '#059669' : '#f8fafc', color: partner ? '#fff' : '#0f172a', overflowWrap: 'anywhere' }}>
          <div style={{ fontSize: 12, fontWeight: 700, marginBottom: 6 }}>{label} · {message.sender_name}</div>
          {message.image_data && /^data:image\/(png|jpeg);base64,/.test(message.image_data) && <a href={message.image_data} target="_blank" rel="noreferrer"><img src={message.image_data} alt={`Ảnh do ${label} gửi`} style={{ maxWidth: '100%', maxHeight: 240, borderRadius: 8 }} /></a>}
          {message.text && !(message.image_data && message.text === 'Ảnh đính kèm') && <div style={{ whiteSpace: 'pre-wrap' }}>{message.text}</div>}
          <time dateTime={message.at} style={{ display: 'block', fontSize: 11, marginTop: 6, opacity: .8 }}>{new Date(message.at).toLocaleString('vi-VN')}</time>
        </article>;
      })}
    </div>
  </section>;
}
