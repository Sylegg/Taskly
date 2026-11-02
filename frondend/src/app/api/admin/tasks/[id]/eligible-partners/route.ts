import { NextResponse } from 'next/server';
import { adminSession, callBackend, failure } from '@/lib/admin-api';

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const { access } = await adminSession();
    const data = await callBackend(`/admin/tasks/${id}/eligible-partners`, 'GET', undefined, access);
    return NextResponse.json({ success: true, data });
  } catch (error) {
    return failure(error);
  }
}
