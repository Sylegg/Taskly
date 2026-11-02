import { NextRequest, NextResponse } from 'next/server';
import { adminSession, ApiError, callBackend, failure, requireSameOrigin } from '@/lib/admin-api';
async function handle(request: NextRequest, context: { params: Promise<{ id: string }> }) {
 try {
  const { id } = await context.params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) throw new ApiError('Dịch vụ không hợp lệ.', 400);
  if (request.method !== 'GET') requireSameOrigin(request);
  const { access } = await adminSession();
  return NextResponse.json({ data: await callBackend(`/admin/services/${id}/booking-fields`, request.method, request.method === 'PUT' ? await request.json() : undefined, access) });
 } catch (error) { return failure(error); }
}
export { handle as GET, handle as PUT };
