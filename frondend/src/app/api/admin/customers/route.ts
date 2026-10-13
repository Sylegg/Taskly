import { NextResponse } from 'next/server';
import { adminSession, callBackend, failure } from '@/lib/admin-api';
export async function GET() {
  try {
    const { access } = await adminSession();
    return NextResponse.json({ customers: await callBackend('/admin/customers', 'GET', undefined, access) });
  } catch (e) { return failure(e); }
}
