import { cookies } from 'next/headers';
import { NextRequest, NextResponse } from 'next/server';
import { callBackend, clearSession, failure, requireSameOrigin } from '@/lib/admin-api';
export async function POST(request: NextRequest) {
  try {
    requireSameOrigin(request);
    const token = (await cookies()).get('taskly_admin_refresh')?.value;
    if (token) await callBackend('/auth/mobile/logout', 'POST', { refreshToken: token }).catch(() => {});
    await clearSession(); return NextResponse.json({ success: true });
  } catch (e) { return failure(e); }
}
