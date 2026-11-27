import { NextRequest, NextResponse } from 'next/server';
import { adminSession, ApiError, callBackend, failure, requireSameOrigin } from '@/lib/admin-api';

type Context = { params: Promise<{ id: string; address?: string[] }> };
const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

async function mutate(request: NextRequest, { params }: Context) {
  try {
    requireSameOrigin(request);
    const { id, address = [] } = await params;
    if (!uuid.test(id) || (request.method === 'POST'
      ? address.length !== 0
      : address.length !== 1 || !uuid.test(address[0]))) {
      throw new ApiError('Địa chỉ hoặc mã tài khoản không hợp lệ.', 400);
    }
    const { access } = await adminSession();
    const path = `/admin/customers/${id}/addresses${address.length ? '/' + address[0] : ''}`;
    const body = request.method === 'DELETE' ? undefined : await request.json();
    return NextResponse.json({ data: await callBackend(path, request.method, body, access) });
  } catch (error) { return failure(error); }
}

export const POST = mutate;
export const PATCH = mutate;
export const DELETE = mutate;
