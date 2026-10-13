import { NextResponse } from 'next/server';
import { adminSession, callBackend, failure } from '@/lib/admin-api';
export async function GET() {
  try {
    const { access } = await adminSession();
    return NextResponse.json({ success: true, data: await callBackend('/admin/wallet-config', 'GET', undefined, access) });
  } catch (error) { return failure(error); }
}
export async function PUT(request: Request) {
  try {
    const { access } = await adminSession();
    return NextResponse.json({ success: true, data: await callBackend('/admin/wallet-config', 'PUT', await request.json(), access) });
  } catch (error) { return failure(error); }
}
