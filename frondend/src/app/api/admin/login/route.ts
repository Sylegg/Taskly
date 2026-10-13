import { NextRequest, NextResponse } from 'next/server';
import { callBackend, saveSession, isAdmin, isRecruitmentStaff, failure, requireSameOrigin, ApiError } from '@/lib/admin-api';
export async function POST(request: NextRequest) {
  try {
    requireSameOrigin(request);
    const { email, password } = await request.json();
    const tokens = await callBackend('/auth/mobile/login', 'POST', { email, password, deviceName: 'TaskLy Admin Dashboard' });
    const user = await callBackend('/users/me', 'GET', undefined, tokens.accessToken);
    if (!isAdmin(user) && !isRecruitmentStaff(user)) {
      await callBackend('/auth/mobile/logout', 'POST', { refreshToken: tokens.refreshToken }).catch(() => {});
      throw new ApiError('Dashboard chỉ dành cho tài khoản Admin.', 403);
    }
    await saveSession(tokens);
    return NextResponse.json({ user: { id: user.id, name: user.fullName, email: user.email, role: isAdmin(user) ? 'ADMIN' : 'RECRUITMENT_STAFF', permissions: user.permissions || [] } });
  } catch (e) { return failure(e); }
}
