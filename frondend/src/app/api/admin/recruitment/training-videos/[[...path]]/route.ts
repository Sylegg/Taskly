import { NextRequest, NextResponse } from 'next/server';
import { adminSession, requireSameOrigin, failure, ApiError } from '@/lib/admin-api';
import { backendApiUrl } from '@/lib/backend-url';

async function handle(request: NextRequest, context: { params: Promise<{ path?: string[] }> }) {
  try {
    const { path = [] } = await context.params;
    if (path.length > 1 || (path[0] && !/^[0-9a-f-]{36}$/i.test(path[0])) ||
        (request.method === 'POST' && path.length) || (request.method === 'GET' && !path.length)) {
      throw new ApiError('Đường dẫn không hợp lệ.', 404);
    }
    if (request.method === 'POST') requireSameOrigin(request);
    const { access } = await adminSession(true);
    const headers: Record<string, string> = { Authorization: `Bearer ${access}` };
    if (request.headers.has('range')) headers.Range = request.headers.get('range')!;
    const result = await fetch(backendApiUrl + '/admin/recruitment/training-videos' + (path[0] ? '/' + path[0] : ''), {
      method: request.method, headers, cache: 'no-store', signal: AbortSignal.timeout(120000),
      ...(request.method === 'POST' ? { body: await request.formData() } : {}),
    });
    if (request.method === 'POST' || !result.ok) {
      const payload = await result.json().catch(() => null);
      if (!result.ok) throw new ApiError(payload?.error?.message || 'Không tải được video.', result.status);
      return NextResponse.json({ data: payload.data });
    }
    const responseHeaders = new Headers({ 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    for (const key of ['Content-Type', 'Content-Length', 'Content-Range', 'Accept-Ranges']) {
      const value = result.headers.get(key); if (value) responseHeaders.set(key, value);
    }
    return new NextResponse(result.body, { status: result.status, headers: responseHeaders });
  } catch (error) { return failure(error); }
}
export { handle as GET, handle as POST };
