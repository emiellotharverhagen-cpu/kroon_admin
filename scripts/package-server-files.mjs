import { cp, mkdir, rm } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const output = path.join(root, 'server-files')
const resource = path.join(output, 'fivem', 'kroon_admin')
const hosting = path.join(output, 'web-panel')

async function copy(source, destination) {
  await mkdir(path.dirname(destination), { recursive: true })
  await cp(path.join(root, source), destination, { recursive: true })
}

await rm(output, { recursive: true, force: true })
await mkdir(output, { recursive: true })

for (const filename of ['fxmanifest.lua', 'config.lua', 'database.lua', 'server.lua', 'client.lua', 'nui.lua']) {
  await copy(filename, path.join(resource, filename))
}
await copy('sql/schema.sql', path.join(resource, 'sql', 'schema.sql'))
await copy('web/dist', path.join(resource, 'web', 'dist'))

await copy('staff-panel-php/public', path.join(hosting, 'upload-to-document-root'))
await copy('staff-panel-php/sql/schema.sql', path.join(hosting, 'database', 'schema.sql'))
await copy('staff-panel-php/private/config.example.php', path.join(hosting, 'private', 'config.example.php'))
await copy('staff-panel-php/bin/create-user.php', path.join(hosting, 'tools', 'create-user.php'))
await copy('staff-panel-php/bin/hash-password.php', path.join(hosting, 'tools', 'hash-password.php'))
await copy('staff-panel-php/README.md', path.join(hosting, 'README.md'))

console.log(`Serverbestanden klaargezet in ${path.relative(root, output)}/`)
