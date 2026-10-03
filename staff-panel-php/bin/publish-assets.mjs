import { cp, copyFile, mkdir, rm } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const directory = path.dirname(fileURLToPath(import.meta.url))
const build = path.join(directory, '../build')
const publicDirectory = path.join(directory, '../public')

await mkdir(path.join(publicDirectory, 'assets'), { recursive: true })
await rm(path.join(publicDirectory, 'assets'), { recursive: true, force: true })
await cp(path.join(build, 'assets'), path.join(publicDirectory, 'assets'), { recursive: true })
await copyFile(path.join(build, 'index.html'), path.join(publicDirectory, 'index.html'))
