import { defineConfig } from 'vite'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const directory = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  root: path.join(directory, 'ui'),
  base: './',
  build: {
    outDir: path.join(directory, 'build'),
    emptyOutDir: true,
  },
})
