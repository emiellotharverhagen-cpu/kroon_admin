import http from 'node:http'
import { createReadStream, existsSync, statSync } from 'node:fs'
import path from 'node:path'
import { createHash, randomBytes, scrypt, scryptSync, timingSafeEqual } from 'node:crypto'
import { promisify } from 'node:util'
import { fileURLToPath } from 'node:url'

const scryptAsync = promisify(scrypt)
const directory = path.dirname(fileURLToPath(import.meta.url))
const publicDirectory = path.join(directory, 'public')
const sessionLifetime = 8 * 60 * 60 * 1000
const maxBodyBytes = 16384
const sessions = new Map()
const loginAttempts = new Map()
const mimeTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
}

function required(name) {
  const value = process.env[name]?.trim()
  if (!value) throw new Error(`Verplichte omgevingsvariabele ontbreekt: ${name}`)
  return value
}

const sharedToken = required('PANEL_SHARED_TOKEN')
if (!/^[a-f0-9]{64,}$/i.test(sharedToken)) throw new Error('PANEL_SHARED_TOKEN moet minimaal 32 random bytes als hex bevatten.')

const panelOriginUrl = new URL(required('PANEL_ORIGIN'))
if (panelOriginUrl.protocol !== 'https:' || panelOriginUrl.pathname !== '/' || panelOriginUrl.search || panelOriginUrl.hash) {
  throw new Error('PANEL_ORIGIN moet de HTTPS-origin zijn, bijvoorbeeld https://staff.example.nl.')
}
const panelOrigin = panelOriginUrl.origin

const upstream = new URL(process.env.FIVEM_API_URL || 'http://127.0.0.1:30120/kroon_admin/api')
if (upstream.protocol !== 'http:' || !['127.0.0.1', 'localhost', '[::1]'].includes(upstream.hostname)
  || upstream.username || upstream.password || upstream.search || upstream.hash) {
  throw new Error('FIVEM_API_URL moet een lokale HTTP-adres zijn zodat het gedeelde geheim niet over het netwerk reist.')
}
const upstreamBase = upstream.href.replace(/\/+$/, '')

let configuredUsers
try {
  configuredUsers = JSON.parse(required('PANEL_USERS_JSON'))
} catch (error) {
  throw new Error(`PANEL_USERS_JSON moet geldige JSON zijn: ${error.message}`)
}
if (!Array.isArray(configuredUsers) || configuredUsers.length === 0) {
  throw new Error('PANEL_USERS_JSON moet minimaal één staffaccount bevatten.')
}

const users = new Map()
for (const user of configuredUsers) {
  if (!user || typeof user.username !== 'string' || !/^[\p{L}\p{N}_.@-]{1,64}$/u.test(user.username)
    || typeof user.salt !== 'string' || !/^[a-f0-9]{32}$/i.test(user.salt)
    || typeof user.hash !== 'string' || !/^[a-f0-9]{128}$/i.test(user.hash)) {
    throw new Error('Elk staffaccount moet username, een 32-hex salt en een 128-hex scrypt hash hebben.')
  }
  const key = user.username.toLowerCase()
  if (users.has(key)) throw new Error(`Dubbele staffnaam in PANEL_USERS_JSON: ${user.username}`)
  users.set(key, { username: user.username, salt: Buffer.from(user.salt, 'hex'), hash: Buffer.from(user.hash, 'hex') })
}

const dummySalt = randomBytes(16)
const dummyHash = scryptSync(randomBytes(32), dummySalt, 64)
const host = process.env.PANEL_HOST || '127.0.0.1'
if (host !== '127.0.0.1' && host !== '::1' && host !== 'localhost') {
  throw new Error('PANEL_HOST mag alleen naar loopback binden; gebruik een HTTPS reverse proxy voor publieke toegang.')
}
const port = Number(process.env.PANEL_PORT || 3080)
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('PANEL_PORT moet een geldig poortnummer zijn.')

function safeEqual(left, right) {
  if (typeof left !== 'string' || typeof right !== 'string') return false
  const a = Buffer.from(left)
  const b = Buffer.from(right)
  return a.length === b.length && timingSafeEqual(a, b)
}

function json(response, status, body, headers = {}) {
  response.writeHead(status, {
    'Cache-Control': 'no-store',
    'Content-Type': 'application/json; charset=utf-8',
    ...headers,
  })
  response.end(JSON.stringify(body))
}

function applySecurityHeaders(response) {
  response.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'")
  response.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains')
  response.setHeader('Referrer-Policy', 'no-referrer')
  response.setHeader('X-Content-Type-Options', 'nosniff')
  response.setHeader('X-Frame-Options', 'DENY')
  response.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()')
}

function getSession(request) {
  const cookieHeader = request.headers.cookie || ''
  const match = cookieHeader.match(/(?:^|;\s*)kroon_admin_session=([A-Za-z0-9_-]{40,60})(?:;|$)/)
  if (!match) return null
  const sessionKey = createHash('sha256').update(match[1]).digest('hex')
  const session = sessions.get(sessionKey)
  if (!session || session.expiresAt <= Date.now()) {
    sessions.delete(sessionKey)
    return null
  }
  return { ...session, sessionKey }
}

function getClientAddress(request) {
  // The panel binds only to loopback; nginx must overwrite X-Real-IP.
  return request.headers['x-real-ip'] || request.socket.remoteAddress || 'unknown'
}

async function readJson(request) {
  const contentType = request.headers['content-type'] || ''
  if (!contentType.toLowerCase().startsWith('application/json')) throw new Error('Verwacht een JSON-aanvraag.')
  let size = 0
  const chunks = []
  for await (const chunk of request) {
    size += chunk.length
    if (size > maxBodyBytes) throw Object.assign(new Error('Aanvraag te groot.'), { statusCode: 413 })
    chunks.push(chunk)
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'))
  } catch {
    throw Object.assign(new Error('Ongeldige JSON-aanvraag.'), { statusCode: 400 })
  }
}

function validOrigin(request) {
  return safeEqual(request.headers.origin || '', panelOrigin)
}

function validCsrf(request, session) {
  return session && safeEqual(request.headers['x-csrf-token'] || '', session.csrf)
}

function validPlayerId(value) {
  const id = Number(value)
  return Number.isSafeInteger(id) && id > 0
}

async function proxyToFiveM(route, method = 'GET', payload) {
  const response = await fetch(`${upstreamBase}/${route}`, {
    method,
    headers: {
      Authorization: 'Bearer ' + sharedToken,
      ...(payload ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(payload ? { body: JSON.stringify(payload) } : {}),
    signal: AbortSignal.timeout(8000),
  })
  const result = await response.json().catch(() => ({ ok: false, error: 'Ongeldig antwoord van de gameserver.' }))
  return { status: response.status, result }
}

async function handleLogin(request, response) {
  if (!validOrigin(request)) return json(response, 403, { ok: false, error: 'Aanvraag geweigerd.' })
  const address = getClientAddress(request)
  const attempts = loginAttempts.get(address)
  if (attempts?.blockedUntil > Date.now()) return json(response, 429, { ok: false, error: 'Te veel mislukte aanmeldingen. Probeer het later opnieuw.' })

  let body
  try { body = await readJson(request) } catch (error) {
    return json(response, error.statusCode || 400, { ok: false, error: error.message })
  }
  const username = typeof body.username === 'string' ? body.username.trim() : ''
  const password = typeof body.password === 'string' ? body.password : ''
  const user = users.get(username.toLowerCase())
  const candidateHash = await scryptAsync(password.slice(0, 200), user?.salt || dummySalt, 64)
  const correct = timingSafeEqual(candidateHash, user?.hash || dummyHash)
  if (!user || !correct) {
    const now = Date.now()
    const withinWindow = attempts && attempts.windowExpiresAt > now
    const failed = withinWindow ? attempts.count + 1 : 1
    loginAttempts.set(address, {
      count: failed,
      windowExpiresAt: withinWindow ? attempts.windowExpiresAt : now + 15 * 60 * 1000,
      blockedUntil: failed >= 10 ? now + 15 * 60 * 1000 : 0,
    })
    return json(response, failed >= 10 ? 429 : 401, { ok: false, error: failed >= 10 ? 'Te veel mislukte aanmeldingen. Probeer het later opnieuw.' : 'Gebruikersnaam of wachtwoord onjuist.' })
  }

  loginAttempts.delete(address)
  const token = randomBytes(32).toString('base64url')
  const csrf = randomBytes(32).toString('base64url')
  const sessionKey = createHash('sha256').update(token).digest('hex')
  sessions.set(sessionKey, { username: user.username, csrf, expiresAt: Date.now() + sessionLifetime })
  const cookie = `kroon_admin_session=${token}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${sessionLifetime / 1000}`
  return json(response, 200, { ok: true, username: user.username, csrf }, { 'Set-Cookie': cookie })
}

async function handleApi(request, response, pathname) {
  if (request.method === 'POST' && pathname === '/api/login') return handleLogin(request, response)
  if (request.method === 'GET' && pathname === '/api/session') {
    const session = getSession(request)
    return json(response, 200, session
      ? { authenticated: true, username: session.username, csrf: session.csrf }
      : { authenticated: false })
  }

  const session = getSession(request)
  if (!session) return json(response, 401, { ok: false, error: 'Je sessie is verlopen. Meld je opnieuw aan.' })

  if (request.method === 'POST') {
    if (!validOrigin(request) || !validCsrf(request, session)) return json(response, 403, { ok: false, error: 'Aanvraag geweigerd.' })
    if (pathname === '/api/logout') {
      sessions.delete(session.sessionKey)
      return json(response, 200, { ok: true }, { 'Set-Cookie': 'kroon_admin_session=; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=0' })
    }

    let body
    try { body = await readJson(request) } catch (error) {
      return json(response, error.statusCode || 400, { ok: false, error: error.message })
    }
    if (pathname === '/api/action') {
      const allowed = new Set(['kick', 'ban', 'warn', 'mute', 'unmute', 'freeze', 'unfreeze', 'revive'])
      if (!allowed.has(body.action) || !validPlayerId(body.target)
        || (body.reason !== undefined && typeof body.reason !== 'string')
        || (body.reason || '').length > 240
        || (body.days !== undefined && (!Number.isInteger(Number(body.days)) || Number(body.days) < 0 || Number(body.days) > 3650))) {
        return json(response, 400, { ok: false, error: 'Ongeldige speleractie.' })
      }
      try {
        const result = await proxyToFiveM('action', 'POST', {
          action: body.action,
          target: Number(body.target),
          reason: body.reason || '',
          days: Number(body.days || 0),
          admin: session.username,
        })
        return json(response, result.status, result.result)
      } catch {
        return json(response, 502, { ok: false, error: 'De gameserver is niet bereikbaar.' })
      }
    }
    if (pathname === '/api/tool') {
      const allowedTools = new Set(['announce', 'giveMoney', 'giveItem', 'spawnVehicle', 'toggle', 'teleportLocation'])
      if (!allowedTools.has(body.action)) return json(response, 400, { ok: false, error: 'Onbekende beheertool.' })
      if (body.action === 'announce' && (typeof body.message !== 'string' || !body.message.trim() || body.message.length > 500)) {
        return json(response, 400, { ok: false, error: 'Ongeldige mededeling.' })
      }
      if (body.action !== 'announce' && !validPlayerId(body.target)) return json(response, 400, { ok: false, error: 'Selecteer een geldige speler.' })
      if (['giveMoney', 'giveItem'].includes(body.action)
        && (!Number.isSafeInteger(Number(body.amount)) || Number(body.amount) <= 0
          || Number(body.amount) > (body.action === 'giveItem' ? 1000 : 1000000))) {
        return json(response, 400, { ok: false, error: 'Ongeldig bedrag of aantal.' })
      }
      if (body.action === 'giveMoney' && !['cash', 'bank'].includes(body.account)) return json(response, 400, { ok: false, error: 'Ongeldige rekening.' })
      if (body.action === 'giveItem' && (typeof body.item !== 'string' || !/^[\w-]{1,50}$/.test(body.item))) return json(response, 400, { ok: false, error: 'Ongeldige itemnaam.' })
      if (body.action === 'spawnVehicle' && (typeof body.model !== 'string' || !/^[\w]{1,50}$/.test(body.model))) return json(response, 400, { ok: false, error: 'Ongeldige voertuigmodelnaam.' })
      if (body.action === 'toggle' && (!['godmode', 'noclip', 'invisible'].includes(body.toggle) || typeof body.enabled !== 'boolean')) {
        return json(response, 400, { ok: false, error: 'Ongeldige toggle.' })
      }
      if (body.action === 'teleportLocation' && (!Number.isInteger(Number(body.index)) || Number(body.index) < 1 || Number(body.index) > 100)) {
        return json(response, 400, { ok: false, error: 'Ongeldige locatie.' })
      }
      const payload = {
        action: body.action,
        target: Number(body.target) || undefined,
        message: body.message,
        amount: Number(body.amount) || undefined,
        account: body.account,
        item: body.item,
        model: body.model,
        toggle: body.toggle,
        enabled: body.enabled,
        index: Number(body.index) || undefined,
        admin: session.username,
      }
      try {
        const result = await proxyToFiveM('tool', 'POST', payload)
        return json(response, result.status, result.result)
      } catch {
        return json(response, 502, { ok: false, error: 'De gameserver is niet bereikbaar.' })
      }
    }
    return json(response, 404, { ok: false, error: 'Niet gevonden.' })
  }

  if (request.method === 'GET' && (pathname === '/api/players' || pathname === '/api/logs')) {
    try {
      const result = await proxyToFiveM(pathname.endsWith('/players') ? 'players' : 'logs')
      return json(response, result.status, result.result)
    } catch {
      return json(response, 502, { ok: false, error: 'De gameserver is niet bereikbaar.' })
    }
  }
  return json(response, 404, { ok: false, error: 'Niet gevonden.' })
}

async function serveStatic(request, response, pathname) {
  let decodedPath
  try { decodedPath = decodeURIComponent(pathname) } catch {
    return json(response, 400, { ok: false, error: 'Ongeldig pad.' })
  }
  const requestedPath = decodedPath === '/' ? '/index.html' : decodedPath
  const filename = path.resolve(publicDirectory, `.${requestedPath}`)
  if (!filename.startsWith(`${publicDirectory}${path.sep}`) || !existsSync(filename) || !statSync(filename).isFile()) {
    if (!path.extname(requestedPath)) {
      const indexFile = path.join(publicDirectory, 'index.html')
      if (existsSync(indexFile)) {
        response.writeHead(200, { 'Cache-Control': 'no-cache', 'Content-Type': mimeTypes['.html'] })
        return createReadStream(indexFile).pipe(response)
      }
    }
    return json(response, 404, { ok: false, error: 'Niet gevonden.' })
  }
  const extension = path.extname(filename).toLowerCase()
  response.writeHead(200, {
    'Cache-Control': extension === '.html' ? 'no-cache' : 'public, max-age=31536000, immutable',
    'Content-Type': mimeTypes[extension] || 'application/octet-stream',
  })
  createReadStream(filename).pipe(response)
}

if (!existsSync(path.join(publicDirectory, 'index.html'))) {
  throw new Error('De staffpanel-frontend ontbreekt. Voer eerst `npm run build:panel` uit.')
}

const server = http.createServer((request, response) => {
  applySecurityHeaders(response)
  const url = new URL(request.url || '/', panelOrigin)
  if (url.pathname.startsWith('/api/')) {
    handleApi(request, response, url.pathname).catch((error) => {
      console.error('[kroon_admin panel] API-fout:', error.message)
      if (!response.headersSent) json(response, 500, { ok: false, error: 'Interne serverfout.' })
      else response.destroy()
    })
    return
  }
  if (request.method !== 'GET' && request.method !== 'HEAD') return json(response, 405, { ok: false, error: 'Methode niet toegestaan.' })
  serveStatic(request, response, url.pathname).catch((error) => {
    console.error('[kroon_admin panel] Bestand kon niet worden geladen:', error.message)
    if (!response.headersSent) json(response, 500, { ok: false, error: 'Interne serverfout.' })
    else response.destroy()
  })
})

setInterval(() => {
  const now = Date.now()
  for (const [key, session] of sessions) if (session.expiresAt <= now) sessions.delete(key)
  for (const [key, attempts] of loginAttempts) {
    if (attempts.windowExpiresAt <= now && (!attempts.blockedUntil || attempts.blockedUntil <= now)) loginAttempts.delete(key)
  }
}, 60 * 1000).unref()

server.listen(port, host, () => {
  console.log(`[kroon_admin panel] Luistert op http://${host}:${port} achter HTTPS-proxy (${panelOrigin}).`)
})
