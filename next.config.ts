import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // Indicateur de dev Next.js déplacé en bas à droite.
  devIndicators: { position: 'bottom-right' },
  // Le portail terrain consomme l'API NestJS (@crm/api) sur :4000.
  // Un rewrite évite les soucis CORS en dev : /api/* → http://localhost:4000/*
  async rewrites() {
    const apiUrl = process.env.API_URL ?? 'http://localhost:4000';
    return [{ source: '/api/:path*', destination: `${apiUrl}/:path*` }];
  },
};

export default nextConfig;
