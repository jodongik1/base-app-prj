import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ mode }) => {
  const portValue = process.env.FRONTEND_PORT ?? loadEnv(mode, '../', '').FRONTEND_PORT
  const port = Number(portValue)

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('FRONTEND_PORT must be set to a valid port in the root .env file')
  }

  return {
    plugins: [react(), tailwindcss()],
    server: { host: '0.0.0.0', port, strictPort: true },
    preview: { host: '0.0.0.0', port, strictPort: true },
  }
})
