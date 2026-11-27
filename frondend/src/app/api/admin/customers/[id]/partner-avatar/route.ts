import { NextRequest, NextResponse } from 'next/server';
import { adminSession, authorizedPhoto, callBackend, failure, requireSameOrigin, ApiError } from '@/lib/admin-api';

export async function POST(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  try {
    requireSameOrigin(request);
    const { access } = await adminSession();
    const { id } = await context.params;
    if (!/^[0-9a-f-]{36}$/i.test(id)) throw new ApiError('Mã đối tác không hợp lệ.', 400);
    const upload = await authorizedPhoto(request);
    const data = await callBackend(`/admin/customers/${id}/partner-avatar`, 'POST', upload, access);
    return NextResponse.json({ data });
  } catch (error) { return failure(error); }
}
