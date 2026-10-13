import { NextResponse } from 'next/server';
import { adminSession, callBackend, failure } from '@/lib/admin-api';

export async function GET() {
  try {
    const { access } = await adminSession();
    const data = await callBackend('/admin/settings/operations', 'GET', undefined, access);
    return NextResponse.json({ success: true, data });
  } catch (error) {
    return failure(error);
  }
}

export async function PUT(request: Request) {
  try {
    const { access } = await adminSession();
    const body = await request.json();
    const data = await callBackend('/admin/settings/operations', 'PUT', body, access);
    return NextResponse.json({ success: true, data });
  } catch (error) {
    return failure(error);
  }
}
