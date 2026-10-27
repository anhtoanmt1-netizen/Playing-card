import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

// base: dùng '/' (Vercel/Netlify/Cloudflare). Nếu đặt ở GitHub Pages dạng /ten-repo/, đặt biến VITE_BASE=/ten-repo/
export default defineConfig({
  base: process.env.VITE_BASE ?? '/',
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icons/favicon.svg'],
      manifest: {
        name: 'Wonder Cards – Thế Giới Thẻ Bài Kỳ Diệu',
        short_name: 'Wonder Cards',
        description: 'Học vui mỗi ngày, kiếm Point, mở túi mù và sưu tầm thẻ bài.',
        lang: 'vi',
        start_url: '/',
        scope: '/',
        display: 'standalone',
        orientation: 'portrait',
        background_color: '#FFF4E0',
        theme_color: '#FF8FB1',
        icons: [
          { src: 'icons/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icons/icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icons/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        // Chỉ cache tài nguyên tĩnh của ứng dụng. KHÔNG cache API/Supabase (dữ liệu riêng tư, Point).
        globPatterns: ['**/*.{js,css,html,svg,png,webp,woff2}'],
        navigateFallback: 'index.html',
        navigateFallbackDenylist: [/^\/rest\//, /^\/auth\//, /^\/functions\//],
        cleanupOutdatedCaches: true,
        runtimeCaching: [
          { urlPattern: ({ url }) => url.hostname.endsWith('.supabase.co'), handler: 'NetworkOnly' },
        ],
      },
    }),
  ],
});
