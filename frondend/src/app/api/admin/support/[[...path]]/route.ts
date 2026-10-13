import { NextRequest, NextResponse } from 'next/server';
import {adminSession, callBackend, failure, requireSameOrigin} from '@/lib/admin-api';
async function handle(request: NextRequest, context: {params: Promise<{path?: string[]}>}) {
 try {
  const {access}=await adminSession(true);
  const {path=[]}=await context.params;
  if(request.method==='POST') requireSameOrigin(request);
  const result=await callBackend('/admin/support/'+path.map(encodeURIComponent).join('/'),request.method,request.method==='POST'?await request.json():undefined,access);
  return NextResponse.json({success:true,data:result});
 } catch(error){return failure(error);}
}
export const GET=handle; export const POST=handle;
