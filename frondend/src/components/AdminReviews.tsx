'use client';

import { useEffect, useState } from 'react';

type Review = {
  task_id: string;
  title: string;
  service: string;
  customer: string;
  partner: string;
  stars: number;
  comment: string;
  created_at: string;
};

export default function AdminReviews({ openOrder }: { openOrder: (id: string) => void }) {
  const [reviews, setReviews] = useState<Review[] | null>(null);
  const [error, setError] = useState(false);
  const [revision, setRevision] = useState(0);
  useEffect(() => {
    const controller = new AbortController();
    setError(false);
    fetch('/api/admin/reviews', { cache: 'no-store', signal: controller.signal })
      .then(async response => {
        const data = await response.json();
        if (!response.ok || !Array.isArray(data.reviews)) throw Error('Invalid review response');
        if (!controller.signal.aborted) setReviews(data.reviews);
      })
      .catch(() => { if (!controller.signal.aborted) setError(true); });
    return () => controller.abort();
  }, [revision]);

  if (error) return <div role="alert" className="notice">Không thể tải đánh giá. <button className="btn btn-outline" onClick={() => setRevision(value => value + 1)}>Thử lại</button></div>;
  if (!reviews) return <div role="status" className="notice">Đang tải đánh giá…</div>;
  if (!reviews.length) return <div className="panel"><p>Chưa có đánh giá từ khách hàng.</p></div>;
  return <div className="panel table-wrapper">
    <table><thead><tr><th>Công việc</th><th>Khách hàng</th><th>Tasker</th><th>Điểm</th><th>Nhận xét</th></tr></thead>
      <tbody>{reviews.map(review => <tr key={review.task_id}>
        <td><button className="text-link" onClick={() => openOrder(review.task_id)}>{review.title || review.service}</button></td>
        <td>{review.customer || '—'}</td><td>{review.partner || '—'}</td>
        <td>{review.stars}/5</td><td>{review.comment || '—'}</td>
      </tr>)}</tbody>
    </table>
  </div>;
}
