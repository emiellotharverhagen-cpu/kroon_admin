import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { createServer } from 'node:http'
import { randomBytes, scryptSync } from 'node:crypto'
import { once } from 'node:events'
import net from 'node:net'
import path from 'node:path'
import { after, before, test } from 'node:test'
import { fileURLToPath } from 'node:url'

const directory = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(directory, '../..')
const origin = 'https://staff.test'
const username = 'StaffTest'
const password = 'a-long-test-password-12345'
const sharedToken = randomBytes(32).toString('hex')
const salt = randomBytes(16)
const user = {
  username,
  salt: salt.toString('hex'),
  hash: scryptSync(password, salt, 64).toString('hex'),
}

let panelProcess
let panelOrigin
let upstream
let upstreamPort
let receivedAction
let sessionCookie
let csrf
let output = ''

async function unusedPort() {
  const server = net.createServer()
  server.listen(0, '127.0.0.1')
  await once(server, 'listening')
  const { port } = server.address()
  server.close()
  await once(server, 'close')
  return port
}

async function request(pathname, options = {}) {
  return fetch(`${panelOrigin}${pathname}`, options)
}

before(async () => {
  upstream = createServer(async (request, response) => {
    assert.equal(request.headers.authorization, 'Bearer ' + sharedToken)
    if (request.url === '/kroon_admin/api/players') {
      response.writeHead(200, { 'Content-Type': 'application/json' })
      response.end(JSON.stringify({ ok: true, players: [{ id: 7, name: 'Testspeler' }], locations: [] }))
      return
    }
    if (request.url === '/kroon_admin/api/logs') {
      response.writeHead(200, { 'Content-Type': 'application/json' })
      response.end(JSON.stringify({ ok: true, logs: [] }))
      return
    }
    if (request.url === '/kroon_admin/api/action' && request.method === 'POST') {
      const chunks = []
      for await (const chunk of request) chunks.push(chunk)
      receivedAction = JSON.parse(Buffer.concat(chunks).toString())
      response.writeHead(200, { 'Content-Type': 'application/json' })
      response.end(JSON.stringify({ ok: true }))
      return
    }
    response.writeHead(404)
    response.end()
  })
  upstream.listen(0, '127.0.0.1')
  await once(upstream, 'listening')
  upstreamPort = upstream.address().port

  const panelPort = await unusedPort()
  panelOrigin = `http://127.0.0.1:${panelPort}`
  panelProcess = spawn(process.execPath, [path.join(root, 'staff-panel/server.mjs')], {
    cwd: root,
    env: {
      ...process.env,
      PANEL_ORIGIN: origin,
      PANEL_HOST: '127.0.0.1',
      PANEL_PORT: String(panelPort),
      PANEL_SHARED_TOKEN: sharedToken,
      PANEL_USERS_JSON: JSON.stringify([user]),
      FIVEM_API_URL: `http://127.0.0.1:${upstreamPort}/kroon_admin/api`,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  panelProcess.stdout.on('data', (chunk) => { output += chunk.toString() })
  panelProcess.stderr.on('data', (chunk) => { output += chunk.toString() })

  const deadline = Date.now() + 10000
  while (!output.includes('Luistert op') && Date.now() < deadline) {
    if (panelProcess.exitCode !== null) throw new Error(`Panel startte niet: ${output}`)
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
  if (!output.includes('Luistert op')) throw new Error(`Timeout bij starten panel: ${output}`)
})

after(async () => {
  if (panelProcess && panelProcess.exitCode === null) {
    panelProcess.kill('SIGTERM')
    await once(panelProcess, 'exit')
  }
  if (upstream?.listening) {
    upstream.close()
    await once(upstream, 'close')
  }
})

test('vereist een geldige origin en credentials voor staff-login', async () => {
  const wrongOrigin = await request('/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: 'https://attacker.test' },
    body: JSON.stringify({ username, password }),
  })
  assert.equal(wrongOrigin.status, 403)

  const wrongPassword = await request('/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: origin },
    body: JSON.stringify({ username, password: 'incorrect' }),
  })
  assert.equal(wrongPassword.status, 401)

  const login = await request('/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: origin },
    body: JSON.stringify({ username, password }),
  })
  assert.equal(login.status, 200)
  const body = await login.json()
  csrf = body.csrf
  sessionCookie = login.headers.get('set-cookie')?.match(/kroon_admin_session=[^;]+/)?.[0]
  assert.equal(body.username, username)
  assert.ok(csrf)
  assert.ok(sessionCookie)
  assert.match(login.headers.get('set-cookie'), /HttpOnly/)
  assert.match(login.headers.get('set-cookie'), /Secure/)
  assert.match(login.headers.get('set-cookie'), /SameSite=Strict/)
})

test('vereist CSRF-bescherming en proxy-auth voor serveracties', async () => {
  const missingCsrf = await request('/api/action', {
    method: 'POST',
    headers: { Origin: origin, Cookie: sessionCookie, 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'kick', target: 7 }),
  })
  assert.equal(missingCsrf.status, 403)

  const players = await request('/api/players', { headers: { Cookie: sessionCookie } })
  assert.equal(players.status, 200)
  assert.equal((await players.json()).players[0].id, 7)

  const action = await request('/api/action', {
    method: 'POST',
    headers: { Origin: origin, Cookie: sessionCookie, 'X-CSRF-Token': csrf, 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'kick', target: 7, reason: 'test' }),
  })
  assert.equal(action.status, 200)
  assert.deepEqual(receivedAction, {
    action: 'kick',
    target: 7,
    reason: 'test',
    days: 0,
    admin: username,
  })
})

test('logout invalideert de staff-sessie', async () => {
  const logout = await request('/api/logout', {
    method: 'POST',
    headers: { Origin: origin, Cookie: sessionCookie, 'X-CSRF-Token': csrf },
  })
  assert.equal(logout.status, 200)
  const session = await request('/api/session', { headers: { Cookie: sessionCookie } })
  assert.equal((await session.json()).authenticated, false)
})
