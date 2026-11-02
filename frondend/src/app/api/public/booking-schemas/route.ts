import { NextResponse } from 'next/server';
import { backendApiUrl } from '@/lib/backend-url';

export async function GET() {
  try {
    const upstream = await fetch(backendApiUrl + '/public/booking-schemas', {
      cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000),
    });
    const result = await upstream.json().catch(() => null);
    if (!upstream.ok || result?.success !== true || !Array.isArray(result.data)) {
      return NextResponse.json({ error: 'Không thể tải biểu mẫu dịch vụ.' }, { status: 502 });
    }
    return NextResponse.json({ data: result.data }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Không thể kết nối máy chủ TaskLy.' }, { status: 503 });
  }
}
