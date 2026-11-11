import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

// Two pages: index.html is the character screen (NUI), dui.html is the poster drawn behind the character (DUI).
export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  resolve: { alias: { '@': path.resolve(import.meta.dirname, './src') } },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    chunkSizeWarningLimit: 800,
    rollupOptions: {
      input: {
        index: path.resolve(import.meta.dirname, 'index.html'),
        dui: path.resolve(import.meta.dirname, 'dui.html'),
      },
    },
  },
})
