import { NextResponse } from 'next/server';
import { adminSession, callBackend, failure } from '@/lib/admin-api';

export async function GET() {
  try {
    const { access } = await adminSession();
    const data = await callBackend('/admin/refund-withdrawals', 'GET', undefined, access);
    return NextResponse.json({ success: true, data });
  } catch (error) {
    return failure(error);
  }
}

export async function POST(request: Request) {
  try {
    const { access } = await adminSession();
    const body = await request.json();
    const { id, status } = body;
    if (!id) throw new Error('Thiếu mã yêu cầu rút tiền');
    const data = await callBackend(`/admin/refund-withdrawals/${id}/status`, 'POST', { status }, access);
    return NextResponse.json({ success: true, data });
  } catch (error) {
    return failure(error);
  }
}
