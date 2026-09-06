import { defineConfig } from "vite";
export default defineConfig({
  server: {
    proxy: { "/api": "http://127.0.0.1:8787" },
    fs: {
      deny: [
        ".env",
        ".env.*",
        "*.{crt,pem}",
        "**/.git/**",
        "**/.private/**",
        "**/leads.json",
        "**/leads-*.tmp",
        "**/leads.lock",
      ],
    },
  },
  build: {
    rollupOptions: {
      input: {
        main: new URL("./index.html", import.meta.url).pathname,
        orchard: new URL("./orchard.html", import.meta.url).pathname,
      },
      output: { manualChunks: { three: ["three"] } },
    },
  },
});
