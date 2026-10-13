import { NextRequest, NextResponse } from 'next/server';
import { adminSession, ApiError, callBackend, failure, requireSameOrigin } from '@/lib/admin-api';

type Context = { params: Promise<{ path: string[] }> };
async function handle(request: NextRequest, context: Context) {
  try {
    const { path } = await context.params;
    const [resource, id, action] = path;
    if (!['service-categories', 'services', 'banners', 'articles'].includes(resource) || path.length > 3
      || (id && !/^[0-9a-f-]{36}$/i.test(id))
      || (action && !['activate', 'deactivate', 'popular', 'comments'].includes(action))
      || (action && ['banners', 'articles'].includes(resource) && !(resource === 'articles' && action === 'comments'))
      || (action === 'popular' && resource !== 'services') || (action === 'comments' && resource !== 'articles')) throw new ApiError('Đường dẫn không hợp lệ.', 404);
    const method = request.method;
    if (!((method === 'GET' && (path.length === 1 || (resource === 'articles' && action === 'comments' && path.length === 3))) || (method === 'PATCH' && action === 'popular' && path.length === 3) || (method === 'POST' && (path.length === 1 || (path.length === 3 && action !== 'popular' && action !== 'comments')))
      || (['PATCH', 'DELETE'].includes(method) && path.length === 2))) throw new ApiError('Thao tác không hợp lệ.', 405);
    if (method !== 'GET') requireSameOrigin(request);
    const { access } = await adminSession();
    const body = (method === 'PATCH' || (method === 'POST' && !action)) ? await request.json() : undefined;
    return NextResponse.json({ data: await callBackend('/admin/' + path.join('/'), method, body, access) });
  } catch (error) { return failure(error); }
}
export { handle as GET, handle as POST, handle as PATCH, handle as DELETE };
