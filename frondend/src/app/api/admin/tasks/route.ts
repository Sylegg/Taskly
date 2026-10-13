import { NextResponse } from 'next/server';
import { adminSession, callBackend, failure } from '@/lib/admin-api';

export async function GET() {
  try {
    const { access } = await adminSession();
    return NextResponse.json({ tasks: await callBackend('/admin/tasks', 'GET', undefined, access) });
  } catch (error) { return failure(error); }
}
