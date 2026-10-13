import { NextRequest, NextResponse } from 'next/server';
import { adminSession, callBackend, failure, requireSameOrigin } from '@/lib/admin-api';

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    requireSameOrigin(request);
    const { id } = await params;
    const { access } = await adminSession();
    const body = await request.json();
    const data = await callBackend(`/admin/tasks/${id}/assign`, 'POST', body, access);
    return NextResponse.json({ success: true, data });
  } catch (error) {
    return failure(error);
  }
}
