import { useEffect, useMemo, useState } from 'react'

async function api(path, { method = 'GET', data, csrf } = {}) {
  const response = await fetch(`/api/${path}`, {
    method,
    credentials: 'same-origin',
    headers: {
      ...(data ? { 'Content-Type': 'application/json' } : {}),
      ...(csrf ? { 'X-CSRF-Token': csrf } : {}),
    },
    ...(data ? { body: JSON.stringify(data) } : {}),
  })
  const result = await response.json().catch(() => ({}))
  if (!response.ok || result.ok === false) throw new Error(result.error || 'De aanvraag is mislukt.')
  return result
}

function App() {
  const [session, setSession] = useState(null)
  const [csrf, setCsrf] = useState('')
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [loginError, setLoginError] = useState('')
  const [page, setPage] = useState('players')
  const [players, setPlayers] = useState([])
  const [logs, setLogs] = useState([])
  const [locations, setLocations] = useState([])
  const [selectedId, setSelectedId] = useState(null)
  const [search, setSearch] = useState('')
  const [reason, setReason] = useState('')
  const [days, setDays] = useState('0')
  const [message, setMessage] = useState('')
  const [amount, setAmount] = useState('')
  const [itemAmount, setItemAmount] = useState('')
  const [item, setItem] = useState('')
  const [account, setAccount] = useState('cash')
  const [vehicle, setVehicle] = useState('')
  const [busy, setBusy] = useState(false)
  const [toast, setToast] = useState('')

  const selected = players.find((player) => player.id === selectedId) || null
  const filtered = useMemo(() => players.filter((player) => `${player.name} ${player.id}`.toLowerCase().includes(search.toLowerCase())), [players, search])

  const showToast = (text) => {
    setToast(text)
    window.setTimeout(() => setToast(''), 3000)
  }

  const refreshPlayers = async () => {
    try {
      const result = await api('players')
      setPlayers(result.players || [])
      setLocations(result.locations || [])
      setSelectedId((id) => result.players?.some((player) => player.id === id) ? id : null)
    } catch (error) { showToast(error.message) }
  }

  const refreshLogs = async () => {
    try {
      const result = await api('logs')
      setLogs(result.logs || [])
    } catch (error) { showToast(error.message) }
  }

  useEffect(() => {
    api('session').then((result) => {
      setSession(result.authenticated ? result.username : null)
      setCsrf(result.csrf || '')
      setLocations(result.locations || [])
      if (result.authenticated) {
        refreshPlayers()
        refreshLogs()
      }
    }).catch(() => setSession(null))
  }, [])

  useEffect(() => {
    if (!session) return undefined
    const timer = window.setInterval(() => {
      refreshPlayers()
      if (page === 'history') refreshLogs()
    }, 10000)
    return () => window.clearInterval(timer)
  }, [session, page])

  const login = async (event) => {
    event.preventDefault()
    setLoginError('')
    try {
      const result = await api('login', { method: 'POST', data: { username, password } })
      setCsrf(result.csrf)
      setSession(result.username)
      setPassword('')
      refreshPlayers()
      refreshLogs()
    } catch (error) { setLoginError(error.message) }
  }

  const logout = async () => {
    try { await api('logout', { method: 'POST', csrf }) } catch {}
    setSession(null)
    setPlayers([])
    setLogs([])
    setSelectedId(null)
    setCsrf('')
  }

  const submit = async (path, data) => {
    if (busy) return
    setBusy(true)
    try {
      await api(path, { method: 'POST', data, csrf })
      showToast('Actie uitgevoerd en gelogd.')
      setReason('')
      await refreshPlayers()
      await refreshLogs()
    } catch (error) { showToast(error.message) } finally { setBusy(false) }
  }

  const playerAction = (action) => {
    if (!selected) return
    if (['kick', 'ban'].includes(action) && !window.confirm(`${action === 'ban' ? 'Verban' : 'Verwijder'} ${selected.name} (ID ${selected.id})?`)) return
    submit('action', { action, target: selected.id, reason, days: Number(days) })
  }
  const tool = (action, extra = {}) => selected && submit('tool', { action, target: selected.id, ...extra })

  if (!session) return (
    <main className="login-page">
      <form className="login-card" onSubmit={login}>
        <div className="logo">K</div><span className="overline">KRoon ROLEPLAY · STAFF</span>
        <h1>Staffpaneel</h1><p>Meld je aan om serverbeheer te openen.</p>
        <label>Gebruikersnaam<input autoComplete="username" value={username} onChange={(event) => setUsername(event.target.value)} required maxLength={64} /></label>
        <label>Wachtwoord<input type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} required maxLength={200} /></label>
        {loginError && <div className="error-message">{loginError}</div>}
        <button className="primary" type="submit">Veilig aanmelden <span>→</span></button>
        <small className="login-note">Alle beheeracties worden geregistreerd.</small>
      </form>
    </main>
  )

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="brand"><div className="logo small">K</div><div><strong>KROON</strong><small>STAFFPANEEL</small></div></div>
        <div className="server-status"><i /> VERBONDEN MET SERVER</div>
        <nav>
          {[['players', 'Spelers', '♙'], ['tools', 'Beheer', '⌘'], ['history', 'Geschiedenis', '◷']].map(([id, label, icon]) =>
            <button key={id} className={page === id ? 'nav active' : 'nav'} onClick={() => { setPage(id); if (id === 'history') refreshLogs() }}><span>{icon}</span>{label}{id === 'players' && <em>{players.length}</em>}</button>)}
        </nav>
        <div className="staff"><div className="staff-avatar">{session.slice(0, 1).toUpperCase()}</div><div><strong>{session}</strong><small>Stafflid</small></div><button title="Afmelden" onClick={logout}>↪</button></div>
      </aside>

      <main className="main">
        <header className="topbar"><div><div className="overline">SERVERBEHEER / {page.toUpperCase()}</div><h1>{page === 'players' ? 'Spelerbeheer' : page === 'tools' ? 'Beheer & tools' : 'Auditgeschiedenis'}</h1></div><div className="top-actions"><span className="status"><i />LIVE</span><button className="icon" aria-label="Vernieuwen" onClick={() => { refreshPlayers(); refreshLogs() }}>↻</button></div></header>

        {page === 'players' && <div className="player-layout">
          <section className="card player-card">
            <div className="card-heading"><div><h2>Spelers online</h2><p>Selecteer een speler om beheeracties uit te voeren.</p></div><b>{players.length} ONLINE</b></div>
            <div className="search"><span>⌕</span><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Zoek naam of server-ID..." /></div>
            <div className="player-list">
              {filtered.map((player) => <button className={selectedId === player.id ? 'player selected' : 'player'} key={player.id} onClick={() => setSelectedId(player.id)}><div className="avatar">{player.name.slice(0, 1).toUpperCase()}</div><div className="player-info"><strong>{player.name}</strong><small>ID {player.id} <i>·</i> {player.ping} ms</small></div><span className="arrow">›</span></button>)}
              {!filtered.length && <div className="empty"><strong>Geen spelers gevonden</strong><small>Er zijn geen overeenkomende spelers online.</small></div>}
            </div>
          </section>
          <section className="card player-detail">
            {selected ? <>
              <div className="selected-player"><div className="avatar large">{selected.name.slice(0, 1).toUpperCase()}</div><div><div className="overline">SERVER-ID {selected.id}</div><h2>{selected.name}</h2><small><i className="dot" /> Online · {selected.ping} ms</small></div></div>
              <div className="license"><span>LICENSE</span><code>{selected.identifiers?.license || 'Onbekend'}</code></div>
              <label className="field">Reden / notitie<input value={reason} onChange={(event) => setReason(event.target.value)} maxLength={240} placeholder="Optioneel, bijvoorbeeld: verstoring van de RP..." /></label>
              <label className="field">Verbanningsduur<div className="suffix"><input type="number" min="0" max="3650" value={days} onChange={(event) => setDays(event.target.value)} /><span>dagen · 0 = permanent</span></div></label>
              <div className="action-grid">
                <button onClick={() => playerAction(selected.frozen ? 'unfreeze' : 'freeze')}>{selected.frozen ? '▶ Ontdooien' : '❄ Bevriezen'}</button>
                <button onClick={() => playerAction(selected.muted ? 'unmute' : 'mute')}>{selected.muted ? '◖ Ontdempen' : '◖ Dempen'}</button>
                <button onClick={() => playerAction('revive')}>＋ Revive speler</button>
              </div>
              <div className="danger-actions"><button disabled={busy} onClick={() => playerAction('warn')}>Waarschuw</button><button disabled={busy} onClick={() => playerAction('kick')}>Kick</button><button disabled={busy} onClick={() => playerAction('ban')}>Ban</button></div>
            </> : <div className="empty detail-empty"><strong>Selecteer een speler</strong><small>Kies een online speler om acties uit te voeren.</small></div>}
          </section>
        </div>}

        {page === 'tools' && <div className="tools-layout">
          <section className="card tools-card"><div className="card-heading"><div><h2>Personagebeheer</h2><p>Toggles worden op de geselecteerde speler toegepast.</p></div></div>
            {!selected && <div className="inline-warning">Selecteer eerst een speler op het tabblad Spelers.</div>}
            {[
              ['godmode', 'God mode', 'Schade uitschakelen'],
              ['noclip', 'Noclip', 'Vrij door de wereld bewegen'],
              ['invisible', 'Onzichtbaar', 'Personage verbergen'],
            ].map(([toggle, label, detail]) => <div className="tool-row" key={toggle}><div><strong>{label}</strong><small>{detail}</small></div><button disabled={!selected || busy} className={selected?.toggles?.[toggle] ? 'switch on' : 'switch'} aria-label={label} onClick={() => tool('toggle', { toggle, enabled: !selected?.toggles?.[toggle] })}><i /></button></div>)}
            <div className="section-title">TELEPORTEREN</div>
            {locations.map((location, index) => <button className="location" disabled={!selected || busy} key={location.label} onClick={() => tool('teleportLocation', { index: index + 1 })}><span>⌖</span><div><strong>{location.label}</strong><small>Verplaats geselecteerde speler</small></div><b>›</b></button>)}
          </section>
          <div className="tools-column">
            <section className="card tools-card"><div className="card-heading"><div><h2>Geld en items</h2><p>Uitdelen aan de geselecteerde speler</p></div></div>
              <label className="field">Geldbedrag<div className="suffix"><input type="number" min="1" value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="Bedrag" /><select value={account} onChange={(event) => setAccount(event.target.value)}><option value="cash">Contant</option><option value="bank">Bank</option></select></div></label>
              <button className="primary" disabled={!selected || !amount || busy} onClick={() => { tool('giveMoney', { amount: Number(amount), account }); setAmount('') }}>Geld geven <span>→</span></button>
              <label className="field separated">Itemnaam en aantal<div className="suffix"><input value={item} onChange={(event) => setItem(event.target.value)} placeholder="Bijv. water" /><input className="quantity" type="number" min="1" value={itemAmount} onChange={(event) => setItemAmount(event.target.value)} placeholder="Aantal" /></div></label>
              <button className="secondary" disabled={!selected || !item || !itemAmount || busy} onClick={() => { tool('giveItem', { item, amount: Number(itemAmount) }); setItem(''); setItemAmount('') }}>Item geven</button>
            </section>
            <section className="card tools-card"><div className="card-heading"><div><h2>Voertuig spawnen</h2><p>Spawn het voertuig bij de speler.</p></div></div><label className="field">Voertuigmodel<input value={vehicle} onChange={(event) => setVehicle(event.target.value)} maxLength={50} placeholder="Bijv. adder" /></label><button className="primary" disabled={!selected || !vehicle.trim() || busy} onClick={() => { tool('spawnVehicle', { model: vehicle.trim() }); setVehicle('') }}>Spawn voertuig <span>→</span></button></section>
            <section className="card tools-card"><div className="card-heading"><div><h2>Servermededeling</h2><p>Verstuur aan alle spelers online.</p></div></div><label className="field">Bericht<textarea value={message} maxLength={500} onChange={(event) => setMessage(event.target.value)} placeholder="Schrijf een mededeling..." /></label><button className="primary" disabled={!message.trim() || busy} onClick={() => { submit('tool', { action: 'announce', message: message.trim() }); setMessage('') }}>Verstuur mededeling <span>→</span></button></section>
          </div>
        </div>}

        {page === 'history' && <section className="card history"><div className="card-heading"><div><h2>Recente beheeracties</h2><p>Auditlog van geregistreerde serveracties.</p></div><button className="secondary refresh" onClick={refreshLogs}>↻ Vernieuwen</button></div><div className="history-head"><span>BEHEERDER</span><span>ACTIE</span><span>SPELER / DETAILS</span><span>DATUM</span></div>
          {logs.map((log) => <div className="history-row" key={log.id}><strong>{log.admin_name}</strong><span className="tag">{log.action}</span><div><strong>{log.target_name || '—'}</strong><small>{log.details || 'Geen details'}</small></div><time>{log.created_at || ''}</time></div>)}
          {!logs.length && <div className="empty"><strong>Geen logregels beschikbaar</strong><small>Beheeracties verschijnen hier automatisch.</small></div>}
        </section>}
        <footer>KRoon ADMIN <span>·</span> Verbonden stafflid: {session}<small>Alle acties worden server-side gecontroleerd en gelogd.</small></footer>
      </main>
      {toast && <div className="toast">{toast}</div>}
    </div>
  )
}

export default App
