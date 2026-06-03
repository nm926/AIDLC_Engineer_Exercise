import { defineConfig } from "vite";

export default defineConfig({
  server: {
    host: "0.0.0.0",
    port: 80,
    allowedHosts: true,
    proxy: {
      "/check-payment": {
        target: "http://fraud-detection.application.svc.cluster.local",
        changeOrigin: true
      }
    }
  }
});
