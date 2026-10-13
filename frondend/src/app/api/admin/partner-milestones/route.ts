import { NextRequest, NextResponse } from 'next/server';
import { adminSession, callBackend, failure, requireSameOrigin } from '@/lib/admin-api';
async function forward(request: NextRequest, method: string) {
 try {
  if (method !== 'GET') requireSameOrigin(request);
  const { access } = await adminSession();
  const id = request.nextUrl.searchParams.get('id');
  const path = '/admin/partner-milestones' + (id ? '?id=' + encodeURIComponent(id) : '');
  const body = ['POST','PUT','PATCH'].includes(method) ? await request.json() : undefined;
  const data = await callBackend(path, method, body, access);
  return NextResponse.json({ success: true, data });
 } catch(error) { return failure(error); }
}
export const GET = (r: NextRequest) => forward(r, 'GET');
export const POST = (r: NextRequest) => forward(r, 'POST');
export const PUT = (r: NextRequest) => forward(r, 'PUT');
export const PATCH = (r: NextRequest) => forward(r, 'PATCH');
export const DELETE = (r: NextRequest) => forward(r, 'DELETE');
