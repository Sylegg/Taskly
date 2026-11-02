import { NextRequest, NextResponse } from 'next/server';
import { adminSession, callBackend, failure, requireSameOrigin, ApiError } from '@/lib/admin-api';
type Context = { params: Promise<{path: string[]}> };
async function proxy(request: NextRequest, context: Context) {
 try {
  const {path} = await context.params;
  const route = path.join('/');
  if(route==='services'&&request.method==='GET'){const session=await adminSession(true);return NextResponse.json({data:await callBackend('/public/services','GET',undefined,session.access)});}
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




