import type { NextConfig } from 'next';
import { PHASE_DEVELOPMENT_SERVER } from 'next/constants';
const nextConfig: NextConfig = {
  reactStrictMode: true,
  async redirects() {
    return [{ source: '/reference/:path*', destination: '/', permanent: false }];
  },
};
export default (phase: string): NextConfig => ({
  ...nextConfig,
  distDir: phase === PHASE_DEVELOPMENT_SERVER ? '.next-dev' : '.next',
});
