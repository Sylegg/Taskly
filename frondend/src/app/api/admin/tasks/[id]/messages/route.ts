import { NextResponse } from 'next/server';
import { adminSession, callBackend, failure, ApiError } from '@/lib/admin-api';

export async function GET(_: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { access } = await adminSession();
    const { id } = await params;
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) throw new ApiError('MÃ£ cÃ´ng viá»‡c khÃ´ng há»£p lá»‡.', 400);
    return NextResponse.json({ messages: await callBackend(`/admin/tasks/${id}/messages`, 'GET', undefined, access) });
  } catch (error) { return failure(error); }
}
