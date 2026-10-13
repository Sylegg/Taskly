import { NextRequest, NextResponse } from 'next/server';
import { adminSession, ApiError, callBackend, failure, requireSameOrigin } from '@/lib/admin-api';

type Context = { params: Promise<{ id: string }> };

async function handle(request: NextRequest, context: Context) {
  try {
    const { id } = await context.params;
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
      throw new ApiError('Mã dịch vụ không hợp lệ.', 400);
    }
    if (request.method === 'PUT') requireSameOrigin(request);
    const { access } = await adminSession();
    const body = request.method === 'PUT' ? await request.json() : undefined;
    const data = await callBackend('/admin/services/' + id + '/pricing', request.method, body, access);
    return NextResponse.json({ data }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    return failure(error);
  }
}

export { handle as GET, handle as PUT };
