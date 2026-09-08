import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// TODO: proxy /api to the mcp-server axum API once it exists.
export default defineConfig({
  plugins: [react()],
});
