import { NextResponse } from 'next/server';
import { adminSession, callBackend, failure } from '@/lib/admin-api';

export async function GET(request: Request) {
  try {
    const { access } = await adminSession();
    const role = new URL(request.url).searchParams.get('role');
    if (role && !['CUSTOMER', 'PARTNER'].includes(role)) throw new Error('Role không hợp lệ');
    const data = await callBackend('/admin/partner-wallet-transactions' + (role ? `?role=${role}` : ''), 'GET', undefined, access);
    return NextResponse.json({ success: true, data });
  } catch (error) { return failure(error); }
}

export async function POST(request: Request) {
  try {
    const { access } = await adminSession();
    const body = await request.json();
    if (body.action === 'CREATE') {
      const data = await callBackend('/admin/partner-wallet-transactions', 'POST', body, access);
      return NextResponse.json({ success: true, data });
    }
    const { id, status, referenceCode, note } = body;
    if (typeof id !== 'string' || !/^[0-9a-f-]{36}$/i.test(id)) throw new Error('Mã giao dịch không hợp lệ');
    const data = await callBackend(`/admin/partner-wallet-transactions/${id}/status`, 'POST', { status, referenceCode, note }, access);
    return NextResponse.json({ success: true, data });
  } catch (error) { return failure(error); }
}
