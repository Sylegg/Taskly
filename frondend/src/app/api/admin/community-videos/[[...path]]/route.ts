import { NextRequest, NextResponse } from 'next/server';
import { adminSession, requireSameOrigin, failure, ApiError } from '@/lib/admin-api';
import { backendApiUrl } from '@/lib/backend-url';
async function handle(request:NextRequest,context:{params:Promise<{path?:string[]}>}){
 try{
  const {path=[]}=await context.params;
  if(path.length>1||(path[0]&&!/^[0-9a-f-]{36}$/i.test(path[0])))throw new ApiError('Đường dẫn không hợp lệ.',404);
  if(request.method!=='GET')requireSameOrigin(request);
  const {access}=await adminSession();
  const headers:Record<string,string>={Authorization:`Bearer ${access}`};
  let body:BodyInit|undefined;
  if(request.method==='POST')body=await request.formData();
  if(request.method==='PATCH'){headers['Content-Type']='application/json';body=JSON.stringify(await request.json());}
  const result=await fetch(backendApiUrl+'/admin/community-videos'+(path[0]?'/'+path[0]:''),{method:request.method,headers,body,cache:'no-store',signal:AbortSignal.timeout(120000)});
  return NextResponse.json(await result.json(),{status:result.status});
 }catch(error){return failure(error);}
}
export {handle as GET,handle as POST,handle as PATCH,handle as DELETE};
