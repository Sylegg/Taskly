import { NextRequest, NextResponse } from 'next/server';
import { adminSession, callBackend, failure, requireSameOrigin, ApiError } from '@/lib/admin-api';
export async function PATCH(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  try {
    requireSameOrigin(request);
    const { access } = await adminSession(); const { id } = await context.params;
    if (!/^[0-9a-f-]{36}$/i.test(id)) throw new ApiError('Mã khách hàng không hợp lệ.', 400);
    const body = await request.json();
    if (body.profileField !== undefined) {
      await callBackend('/admin/customers/' + id + '/profile-field', 'PATCH', body.profileField, access);
      return NextResponse.json({success:true});
    }
    if (body.edits) return NextResponse.json({success:true,data:await callBackend('/admin/customers/' + id + '/details/batch','PATCH',body,access)});
    if (body.section) return NextResponse.json({success:true,data:await callBackend('/admin/customers/' + id + '/details','PATCH',body,access)});
    if (body.status !== undefined) await callBackend('/admin/customers/' + id + '/status', 'PATCH', { status: body.status }, access);
    else await callBackend('/admin/customers/' + id, 'PATCH', { name: body.name, phone: body.phone, email: body.email }, access);
    return NextResponse.json({ success: true });
  } catch (e) { return failure(e); }
}

export async function GET(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  try {
    const { access, user } = await adminSession(); const { id } = await context.params;
    if (!/^[0-9a-f-]{36}$/i.test(id)) throw new ApiError('Mã tài khoản không hợp lệ.', 400);
    const isCustomer = request.nextUrl.searchParams.get('app') === 'customer';
    const data = await callBackend('/admin/customers/' + id + (isCustomer ? '/customer-details' : '/details'), 'GET', undefined, access);
    return NextResponse.json({ success: true, data: isCustomer ? data : { ...data, canReviewIdentity: user.permissions.includes('KYC_REVIEW') } });
  } catch (error) { return failure(error); }
}
