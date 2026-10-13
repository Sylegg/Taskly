import { NextRequest, NextResponse } from 'next/server';
import { backendApiUrl } from '@/lib/backend-url';

type Context = { params: Promise<{ id: string; filename: string }> };

export async function GET(_request: NextRequest, context: Context) {
  const { id, filename } = await context.params;
  const path = `/public/banner-images/${id}/${filename}`;
  if (!/^[0-9a-f-]{36}$/i.test(id) || !/^[0-9a-f]{64}\.png$/.test(filename)) return new NextResponse(null, { status: 404 });
  try {
    const upstream = await fetch(backendApiUrl + path, {
      method: 'GET', cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000),
    });
    if (!upstream.ok) return new NextResponse(null, { status: upstream.status === 404 ? 404 : 502 });
    if (upstream.headers.get('content-type')?.split(';')[0].trim() !== 'image/png') {
      return new NextResponse(null, { status: 502 });
    }
    const headers = new Headers({ 'Content-Type': 'image/png', 'X-Content-Type-Options': 'nosniff' });
    for (const name of ['cache-control', 'etag', 'last-modified']) {
      const value = upstream.headers.get(name);
      if (value) headers.set(name, value);
    }
    return new NextResponse(await upstream.arrayBuffer(), { headers });
  } catch {
    return new NextResponse(null, { status: 503 });
  }
}
