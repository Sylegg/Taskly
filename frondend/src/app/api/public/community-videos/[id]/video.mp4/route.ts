import { NextRequest } from 'next/server';
import { backendApiUrl } from '@/lib/backend-url';
import { adminSession } from '@/lib/admin-api';
export async function GET(request:NextRequest,context:{params:Promise<{id:string}>}){
 const {id}=await context.params;if(!/^[0-9a-f-]{36}$/i.test(id))return new Response(null,{status:404});
 try{
  const headers=new Headers();const range=request.headers.get('range');if(range)headers.set('range',range);
  try{headers.set('Authorization','Bearer '+(await adminSession()).access);}catch{}
  const result=await fetch(backendApiUrl+'/public/community-videos/'+id+'/video.mp4',{headers,cache:'no-store'});
  const output=new Headers();for(const key of ['content-type','content-length','content-range','accept-ranges','cache-control']){const value=result.headers.get(key);if(value)output.set(key,value);}
  return new Response(result.body,{status:result.status,headers:output});
 }catch{return new Response(null,{status:503});}
}
