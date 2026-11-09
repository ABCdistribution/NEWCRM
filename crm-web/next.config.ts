import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // Indicateur de dev Next.js déplacé en bas à droite.
  devIndicators: { position: 'bottom-right' },
  // Aucun rewrite vers l'API : le navigateur ne l'appelle jamais (serverFetch / Server Actions uniquement).
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ];
  },
};

export default nextConfig;
