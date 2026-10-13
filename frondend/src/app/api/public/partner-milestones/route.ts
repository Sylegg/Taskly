import { NextResponse } from 'next/server';
import { callBackend, failure } from '@/lib/admin-api';
export async function GET() {
 try { return NextResponse.json({success: true, data: await callBackend('/public/partner-milestones')}); }
 catch(error) { return failure(error); }
}
