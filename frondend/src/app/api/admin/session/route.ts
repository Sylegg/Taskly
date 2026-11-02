import { NextResponse } from 'next/server';
import { adminSession, failure } from '@/lib/admin-api';
export async function GET() {
  try { const { user } = await adminSession(true); return NextResponse.json({ user }); }
  catch (e) { return failure(e); }
}
