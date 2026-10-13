import { cookies } from 'next/headers';
import { NextRequest, NextResponse } from 'next/server';
import { isAdmin, isRecruitmentStaff } from './admin-role.mjs';
import { backendApiUrl } from './backend-url';
export { isAdmin, isRecruitmentStaff } from './admin-role.mjs';

const secure = process.env.NODE_ENV === 'production';
const accessKey = 'taskly_admin_access', refreshKey = 'taskly_admin_refresh';
type SessionTokens = {accessToken: string; refreshToken: string; refreshExpiresAt: string};
// Share rotation across parallel routes, including late requests carrying the old cookie.
const sessionGlobal = globalThis as typeof globalThis & {
  tasklyRefreshes?: Map<string, {promise: Promise<SessionTokens>; expires: number}>;
};
const refreshes = sessionGlobal.tasklyRefreshes ??= new Map();
async function rotateSession(refresh: string): Promise<SessionTokens> {
  const now = Date.now();
  for (const [key, entry] of refreshes) {
    if (entry.expires <= now) refreshes.delete(key);
  }
  const existing = refreshes.get(refresh);
  if (existing) return existing.promise;
  const entry = {
    expires: Infinity,
    promise: callBackend('/auth/mobile/refresh', 'POST', {refreshToken: refresh}) as Promise<SessionTokens>,
  };
  refreshes.set(refresh, entry);
  try {
    const tokens = await entry.promise;
    entry.expires = Date.now() + 15000;
    return tokens;
  } catch (error) {
    refreshes.delete(refresh);
    throw error;
  }
}
export class ApiError extends Error {
  constructor(message: string, public status = 500) { super(message); }
}
export function requireSameOrigin(request: NextRequest) {
  const origin = request.headers.get('origin');
  const host = request.headers.get('host');
  let source: URL;
  try { source = new URL(origin || ''); }
  catch { throw new ApiError('Yêu cầu không hợp lệ.', 403); }
  if (!host || source.host !== host || source.protocol !== request.nextUrl.protocol) {
    throw new ApiError('Yêu cầu không hợp lệ.', 403);
  }
}
export async function callBackend(path: string, method = 'GET', body?: unknown, access?: string) {
  let response: Response;
  try {
    response = await fetch(backendApiUrl + path, {
      method, cache: 'no-store', signal: AbortSignal.timeout(15000),
      headers: { 'Content-Type': 'application/json', ...(access ? { Authorization: 'Bearer ' + access } : {}) },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    });
  } catch {
    if (method !== 'GET') throw new ApiError('Không thể kết nối máy chủ TaskLy. Vui lòng thử lại.', 503);
    let recovered: Response | undefined;
    for (let attempt = 1; attempt <= 3; attempt++) {
      await new Promise(resolve => setTimeout(resolve, attempt * 1000));
      try {
        recovered = await fetch(backendApiUrl + path, { method, cache: 'no-store', signal: AbortSignal.timeout(15000), headers: { 'Content-Type': 'application/json', ...(access ? { Authorization: 'Bearer ' + access } : {}) } });
        break;
      } catch { /* Backend may still be starting. */ }
    }
    if (!recovered) throw new ApiError('Máy chủ TaskLy chưa sẵn sàng. Vui lòng tải lại sau vài giây.', 503);
    response = recovered;
  }
  const result = await response.json().catch(() => null);
  if (!response.ok || !result?.success) throw new ApiError(result?.error?.message || 'Máy chủ không thể xử lý yêu cầu.', response.status >= 400 ? response.status : 502);
  return result.data;
}
export async function clearSession() {
  const store = await cookies(); store.delete(accessKey); store.delete(refreshKey);
}
export async function saveSession(tokens: {accessToken: string; refreshToken: string; refreshExpiresAt: string}) {
  const store = await cookies();
  const options = { httpOnly: true, secure, sameSite: 'lax' as const, path: '/' };
  store.set(accessKey, tokens.accessToken, { ...options, maxAge: 3600 });
  store.set(refreshKey, tokens.refreshToken, { ...options, expires: new Date(tokens.refreshExpiresAt) });
}
export async function adminSession(recruitmentOnly = false) {
  const store = await cookies();
  let access = store.get(accessKey)?.value;
  const refresh = store.get(refreshKey)?.value;
  if (!access && !refresh) throw new ApiError('Vui lòng đăng nhập Admin.', 401);
  let user;
  try { user = await callBackend('/users/me', 'GET', undefined, access); }
  catch (error) {
    if (!(error instanceof ApiError) || error.status !== 401 || !refresh) throw error;
    const tokens = await rotateSession(refresh);
    access = tokens.accessToken;
    await saveSession(tokens);
    user = await callBackend('/users/me', 'GET', undefined, access);
  }
  if (!isAdmin(user) && !(recruitmentOnly && isRecruitmentStaff(user))) {
    await clearSession();
    throw new ApiError('Dashboard chỉ dành cho tài khoản Admin.', 403);
  }
  return { access, user: { id: user.id, name: user.fullName, email: user.email, role: isAdmin(user) ? 'ADMIN' : 'RECRUITMENT_STAFF', permissions: user.permissions || [] } };
}
export function failure(error: unknown) {
  return NextResponse.json({ error: error instanceof ApiError ? error.message : 'Không thể hoàn tất thao tác.' },
    { status: error instanceof ApiError ? error.status : 500 });
}
