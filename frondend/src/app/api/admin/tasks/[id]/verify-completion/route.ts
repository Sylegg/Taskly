import { NextResponse } from 'next/server';
import { adminSession, callBackend, failure } from '@/lib/admin-api';

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const { access } = await adminSession();
    const body = await request.json().catch(() => undefined);
    const data = await callBackend(`/admin/tasks/${id}/verify-completion`, 'POST', body, access);
    return NextResponse.json({ success: true, data });
  } catch (error) {
    return failure(error);
  }
}
