import { randomBytes, scryptSync } from 'node:crypto'
import { stdin, stdout } from 'node:process'

const chunks = []
for await (const chunk of stdin) chunks.push(chunk)
const password = Buffer.concat(chunks).toString('utf8').replace(/\r?\n$/, '')
if (password.length < 14 || password.length > 200) {
  console.error('Gebruik een wachtwoord van 14 tot 200 tekens en voer het via stdin aan.')
  process.exit(1)
}

const salt = randomBytes(16)
const hash = scryptSync(password, salt, 64)
stdout.write(JSON.stringify({ salt: salt.toString('hex'), hash: hash.toString('hex') }) + '\n')
