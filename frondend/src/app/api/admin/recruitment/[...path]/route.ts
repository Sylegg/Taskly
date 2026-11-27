import { NextRequest, NextResponse } from 'next/server';
import { adminSession, authorizedPhoto, callBackend, failure, requireSameOrigin, ApiError } from '@/lib/admin-api';
type Context = { params: Promise<{path: string[]}> };
async function proxy(request: NextRequest, context: Context) {
 try {
  const {path} = await context.params;
  const route = path.join('/');
  if(route==='services'&&request.method==='GET'){const session=await adminSession(true);return NextResponse.json({data:await callBackend('/public/services','GET',undefined,session.access)});}
  if (request.method === 'POST' && /^kyc\/assisted\/[0-9a-f-]{36}\/(?:submit|[0-9a-f-]{36}\/approve)$/.test(route)) {
   requireSameOrigin(request);
   const session = await adminSession(true);
   if (!session.user.permissions.includes('KYC_REVIEW')) throw new ApiError('Bạn không có quyền xác minh CCCD.', 403);
   const target = '/admin/verifications/' + route.slice(4);
   if (route.endsWith('/approve')) {
    return NextResponse.json({data:await callBackend(target + request.nextUrl.search, 'POST', undefined, session.access)});
   }
   const form = await request.formData().catch(() => null);
   if (!form) throw new ApiError('Không thể đọc ảnh CCCD.', 400);
   const upload = new FormData();
   for (const field of ['verificationId', 'version', 'legalName', 'documentNumber', 'ownerAuthorized']) {
    const value = form.get(field);
    if (typeof value === 'string') upload.set(field, value);
   }
   for (const side of ['front', 'back']) {
    const file = form.get(side);
    if (file === null || file instanceof File && !file.size && !file.name) continue;
    if (!(file instanceof File) || !file.size || file.size > 4 * 1024 * 1024 || !['image/jpeg', 'image/png'].includes(file.type)) {
     throw new ApiError('Mỗi mặt CCCD cần là ảnh JPG hoặc PNG không quá 4 MB.', 400);
    }
    upload.set(side, file);
   }
   return NextResponse.json({data:await callBackend(target, 'POST', upload, session.access)});
  }
  if (request.method === 'POST' && /^kyc\/[0-9a-f-]{36}\/documents\/(FRONT|BACK|SELFIE)$/.test(route)) {
   requireSameOrigin(request);
   const session = await adminSession(true);
   return NextResponse.json({data:await callBackend('/admin/verifications/'+route.slice(4),'POST',await authorizedPhoto(request),session.access)});
  }
  if (request.method === 'POST' && /^kyc\/office\/[0-9a-f-]{36}\/(?:draft|[0-9a-f-]{36}\/(?:submit|approve))$/.test(route)) {
   requireSameOrigin(request);
   const session=await adminSession(true);
   return NextResponse.json({data:await callBackend('/admin/verifications/'+route.slice(4),'POST',await request.json(),session.access)});
  }
  if (/^kyc(?:\/[0-9a-f-]{36}\/(?:approve|reject|documents\/[0-9a-f-]{36}\/url))?$/.test(route)) {
   if(request.method!=='GET') requireSameOrigin(request);
   const session=await adminSession(true);
   const target=route==='kyc'?'/admin/verifications':'/admin/verifications/'+route.slice(4);
   return NextResponse.json({data:await callBackend(target,request.method,request.method==='GET'?undefined:await request.json(),session.access)});
  }
  if (!/^(applications(?:\/[0-9a-f-]{36}(?:\/(?:preliminary-decision|final-decision|dossier|checkin|final-documents))?)?|(?:areas|questions|lessons|agreements|uniforms|office-slots|document-checklist|benefits)(?:\/[0-9a-f-]{36})?|uniform-orders(?:\/[0-9a-f-]{36}\/(?:confirm-office-payment|adjust))?|appointments(?:\/[0-9a-f-]{36}\/(?:checkin|receive-documents))?|appeals(?:\/[0-9a-f-]{36}\/resolve)?|message-templates(?:\/[0-9a-f-]{36})?|outbox(?:\/[0-9a-f-]{36}\/retry)?|exam-config|audit|summary|applications-page|sla-calendar)$/.test(route)) throw new ApiError('Không tìm thấy API tuyển dụng.',404);
  if (request.method !== 'GET') requireSameOrigin(request);
  const session = await adminSession(true);
  const body = ['GET','DELETE'].includes(request.method) ? undefined : await request.json();
  return NextResponse.json({data:await callBackend('/admin/recruitment/'+route+(request.method==='GET'?request.nextUrl.search:''),request.method,body,session.access)});
 } catch (error) {return failure(error);}
}
export const GET = proxy;
export const PUT = proxy;
export const DELETE = proxy;
export const POST = proxy;




