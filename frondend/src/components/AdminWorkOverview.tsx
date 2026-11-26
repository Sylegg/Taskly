'use client';

import { useState } from 'react';
import { money, STATUS } from '@/lib/domain.mjs';

export type AdminOrder = {
  id: string;
  title: string;
  status: string;
  service: string;
  customer: string;
  customer_id: string;
  tasker_id?: string;
  address: string;
  created_at: string;
  scheduled_at?: string;
  total: number | null;
  pending_booking?: boolean;
  payment_status?: string;
};

export const isDemoOrder = (order: AdminOrder) =>
  order.title.startsWith('EXE201 · ') || order.title.startsWith('[THỬ NGHIỆM] EXE201-');

const active = new Set(['POSTED', 'MATCHING', 'ACCEPTED', 'TASKER_ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS']);
const monthFormat = new Intl.DateTimeFormat('fr-CA', { timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit' });
const calendarDate = new Intl.DateTimeFormat('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh', dateStyle: 'short' });

function monthOf(value: string) {
  const fields = monthFormat.formatToParts(new Date(value));
  return fields.find(field => field.type === 'year')?.value + '-' + fields.find(field => field.type === 'month')?.value;
}

export default function AdminWorkOverview({ page, orders, onOrder, onOpenTasks }: {
  page: 'dashboard' | 'operations' | 'analytics';
  orders: AdminOrder[];
  onOrder: (id: string) => void;
  onOpenTasks: () => void;
}) {
  const [scope, setScope] = useState<'all' | 'demo' | 'other'>('all');
  const hasDemo = orders.some(isDemoOrder);
  const filtered = orders.filter(order => !order.pending_booking &&
    (scope === 'all' || isDemoOrder(order) === (scope === 'demo')));
  const paid = filtered.filter(order => order.status === 'PAID' && order.payment_status === 'PAID');
  const monthCounts = new Map<string, number>();
  const serviceCounts = new Map<string, number>();
  for (const order of filtered) {
    const month = monthOf(order.created_at);
    monthCounts.set(month, (monthCounts.get(month) ?? 0) + 1);
    serviceCounts.set(order.service, (serviceCounts.get(order.service) ?? 0) + 1);
  }
  const months = [...monthCounts].sort(([a], [b]) => a.localeCompare(b));
  const services = [...serviceCounts].sort((a, b) => b[1] - a[1]);
  const totals = [
    ['Đơn đã tạo', filtered.length],
    ['Đã thanh toán', paid.length],
    ['Đang xử lý', filtered.filter(order => active.has(order.status)).length],
    [scope === 'demo' ? 'Giá trị thanh toán mô phỏng' : 'Giá trị thanh toán ghi nhận',
      money(paid.reduce((sum, order) => sum + Number(order.total ?? 0), 0))],
  ] as const;
  const activity = [
    ['Chờ nhận việc', ['POSTED', 'MATCHING']],
    ['Đã nhận việc', ['ACCEPTED', 'TASKER_ON_THE_WAY', 'ARRIVED']],
    ['Đang thực hiện', ['IN_PROGRESS']],
    ['Hoàn thành / đã thanh toán', ['COMPLETED', 'PAID']],
    ['Ngoại lệ', ['CANCELLED', 'REFUNDED', 'EXPIRED', 'DISPUTED']],
  ] as const;

  function orderLink(order: AdminOrder) {
    return <button key={order.id} className="queue-item" onClick={() => onOrder(order.id)}>
      <span className="queue-main"><b>{order.service || order.title}</b><small>{order.customer} · {calendarDate.format(new Date(order.created_at))}</small></span>
      <span>{STATUS[order.status] || order.status}</span>
    </button>;
  }

  return <>
    <div className="row" style={{ flexWrap: 'wrap', marginBottom: 14 }}>
      {hasDemo && <label className="field">
        <span>Phạm vi đơn hàng</span>
        <select value={scope} onChange={event => setScope(event.target.value as typeof scope)}>
          <option value="all">Tất cả đơn</option>
          <option value="demo">Bộ đơn trình diễn</option>
          <option value="other">Các đơn ngoài EXE201</option>
        </select>
      </label>}
      <button className="btn btn-outline" onClick={onOpenTasks}>Mở danh sách công việc</button>
    </div>
    <div className="kpi-grid">
      {totals.map(([label, value]) => <div className="kpi-card" key={label}><span>{label}</span><strong>{value}</strong></div>)}
    </div>
    {!filtered.length && <div className="notice">Chưa có đơn hàng trong phạm vi này.</div>}
    {page === 'operations' && filtered.length > 0 && <div className="kanban">
      {activity.map(([label, statuses]) => {
        const items = filtered.filter(order => (statuses as readonly string[]).includes(order.status));
        return <section className="kanban-col" key={label}>
          <div className="kanban-head">{label}<b>{items.length}</b></div>
          {items.length ? items.slice(0, 6).map(orderLink) : <p className="kanban-empty">Chưa có công việc</p>}
        </section>;
      })}
    </div>}
    {page !== 'operations' && filtered.length > 0 && <div className="dashboard-grid">
      <section className="panel">
        <h2>Đơn đặt theo tháng</h2>
        <div className="analysis-bars">{months.map(([period, count]) => <div className="analysis-row" key={period}>
          <span>{period.slice(5)}/{period.slice(0, 4)}</span>
          <progress value={count} max={Math.max(...monthCounts.values())} aria-label={period} />
          <b>{count}</b>
        </div>)}</div>
      </section>
      <section className="panel">
        <h2>{page === 'analytics' ? 'Đơn theo dịch vụ' : 'Đơn cập nhật gần đây'}</h2>
        {page === 'analytics'
          ? <div className="analysis-bars">{services.map(([label, count]) => <div className="analysis-row" key={label}>
            <span>{label}</span><progress value={count} max={services[0][1]} aria-label={label} /><b>{count}</b>
          </div>)}</div>
          : <div className="list-stack">{filtered.slice(0, 6).map(orderLink)}</div>}
      </section>
    </div>}
  </>;
}
