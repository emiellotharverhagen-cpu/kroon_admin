import { useEffect, useMemo, useState } from 'react'

const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'kroon_admin'
const callNui = (name, data = {}) => fetch(`https://${resourceName}/${name}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json; charset=UTF-8' },
  body: JSON.stringify(data),
}).catch(() => {})

const navigation = [
  ['players', 'Spelers', '♙'],
  ['tools', 'Beheer', '⌘'],
  ['history', 'Geschiedenis', '◷'],
]

function App() {
  const [visible, setVisible] = useState(false)
  const [page, setPage] = useState('players')
  const [players, setPlayers] = useState([])
  const [logs, setLogs] = useState([])
  const [locations, setLocations] = useState([])
  const [selected, setSelected] = useState(null)
  const [query, setQuery] = useState('')
  const [notice, setNotice] = useState(null)
  const [announcement, setAnnouncement] = useState(null)
  const [toggles, setToggles] = useState({})
  const [reason, setReason] = useState('')
  const [days, setDays] = useState('0')
  const [amount, setAmount] = useState('')
  const [item, setItem] = useState('')
  const [account, setAccount] = useState('cash')
  const [vehicle, setVehicle] = useState('')
  const [message, setMessage] = useState('')

  const filteredPlayers = useMemo(() => players.filter((player) =>
    `${player.name} ${player.id}`.toLowerCase().includes(query.toLowerCase())), [players, query])

  useEffect(() => {
    const onMessage = (event) => {
      const data = event.data
      if (data.type === 'open') {
        setVisible(true)
        setLocations(data.locations || [])
        callNui('players')
        callNui('logs')
      }
      if (data.type === 'close') setVisible(false)
      if (data.type === 'players') {
        const nextPlayers = data.players || []
        setPlayers(nextPlayers)
        setSelected((current) => current ? nextPlayers.find((player) => player.id === current.id) || null : null)
      }
      if (data.type === 'logs') setLogs(data.logs || [])
      if (data.type === 'toggleState') setToggles((current) => ({ ...current, [data.toggle]: data.enabled }))
      if (data.type === 'notification') {
        setNotice({ message: data.message, kind: data.kind })
        window.setTimeout(() => setNotice(null), 3200)
      }
      if (data.type === 'announcement') {
        setAnnouncement(data)
        window.setTimeout(() => setAnnouncement(null), 6500)
      }
    }
    const onKeyDown = (event) => {
      if (event.key === 'Escape') {
        setVisible(false)
        callNui('close')
      }
    }
    window.addEventListener('message', onMessage)
    window.addEventListener('keydown', onKeyDown)
    return () => {
      window.removeEventListener('message', onMessage)
      window.removeEventListener('keydown', onKeyDown)
    }
  }, [])

  const playerAction = (action) => {
    if (!selected) return
    callNui('playerAction', { action, target: selected.id, reason, days: Number(days) })
    setReason('')
    if (action === 'kick' || action === 'ban') setSelected(null)
    window.setTimeout(() => callNui('players'), 300)
  }

  const tool = (action, data = {}) => callNui('tool', { action, ...data })

  if (!visible) return <>{announcement && <div className="announcement"><span>{announcement.title}</span><strong>{announcement.message}</strong><small>Mededeling van {announcement.admin}</small></div>}</>

  return (
    <main className="shell">
      <aside className="sidebar">
        <div className="brand"><div className="brand-mark">K</div><div><strong>KROON</strong><span>ADMINISTRATIE</span></div></div>
        <div className="server-chip"><i /> SERVER BEHEER</div>
        <nav>{navigation.map(([id, label, icon]) => <button key={id} className={page === id ? 'nav-item active' : 'nav-item'} onClick={() => { setPage(id); if (id === 'history') callNui('logs') }}><span className="nav-icon">{icon}</span>{label}{id === 'players' && <em>{players.length}</em>}</button>)}</nav>
        <div className="sidebar-bottom"><div className="online"><i />{players.length} spelers online</div><span>F10 om te openen · ESC sluiten</span></div>
      </aside>

      <section className="content">
        <header className="topbar"><div><span className="eyebrow">SERVERPANEEL / {navigation.find(([id]) => id === page)?.[1].toUpperCase()}</span><h1>{page === 'players' ? 'Spelerbeheer' : page === 'tools' ? 'Beheer & tools' : 'Auditgeschiedenis'}</h1></div><div className="header-actions"><div className="live-pill"><i /> LIVE</div><button className="icon-button" aria-label="Vernieuwen" onClick={() => { callNui('players'); callNui('logs') }}>↻</button><button className="icon-button close-button" aria-label="Sluiten" onClick={() => { setVisible(false); callNui('close') }}>×</button></div></header>

        {page === 'players' && <div className="page-grid">
          <section className="panel roster">
            <div className="panel-heading"><div><h2>Online spelers</h2><p>Selecteer een speler om acties uit te voeren</p></div><span className="count">{players.length} ONLINE</span></div>
            <label className="search"><span>⌕</span><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Zoek op naam of server-ID..." /><kbd>/</kbd></label>
            <div className="player-list">
              {filteredPlayers.map((player) => <button key={player.id} className={selected?.id === player.id ? 'player-row selected' : 'player-row'} onClick={() => setSelected(player)}>
                <div className="avatar">{player.name?.slice(0, 1)?.toUpperCase() || '?'}</div>
                <div className="player-name"><strong>{player.name}</strong><span>ID {player.id} <i>·</i> {player.ping ?? 0} ms</span></div>
                {player.muted && <span className="muted-tag">GEDempt</span>}
                <span className="row-arrow">›</span>
              </button>)}
              {filteredPlayers.length === 0 && <div className="empty"><span>♙</span><strong>Geen spelers gevonden</strong><small>Probeer een andere zoekopdracht</small></div>}
            </div>
          </section>
          <section className="panel details">
            {selected ? <>
              <div className="detail-title"><div className="avatar big">{selected.name?.slice(0, 1)?.toUpperCase() || '?'}</div><div><span className="eyebrow">SPELER ID {selected.id}</span><h2>{selected.name}</h2><p><i className="online-dot" /> Online · {selected.ping ?? 0} ms ping</p></div><button className="refresh-small" title="Spelers vernieuwen" onClick={() => callNui('players')}>↻</button></div>
              <div className="identifier"><span>LICENSE</span><code>{selected.identifiers?.license || 'Onbekend'}</code></div>
              <div className="field"><label>Reden / notitie</label><input value={reason} onChange={(event) => setReason(event.target.value)} maxLength={240} placeholder="Optioneel, bijvoorbeeld: verstoring van de RP..." /></div>
              <div className="field"><label>Verbanningsduur</label><div className="input-suffix"><input type="number" min="0" max="3650" value={days} onChange={(event) => setDays(event.target.value)} /><span>dagen (0 = permanent)</span></div></div>
              <div className="action-grid">
                <button className="action-btn" onClick={() => playerAction('goto')}><span>⌖</span><div><strong>Ga naar</strong><small>Teleport naar speler</small></div></button>
                <button className="action-btn" onClick={() => playerAction('bring')}><span>↙</span><div><strong>Breng hierheen</strong><small>Haal speler naar jou</small></div></button>
                <button className="action-btn" onClick={() => playerAction(selected.frozen ? 'unfreeze' : 'freeze')}><span>❄</span><div><strong>{selected.frozen ? 'Ontdooi' : 'Bevries'}</strong><small>Beweging blokkeren</small></div></button>
                <button className="action-btn" onClick={() => playerAction('revive')}><span>＋</span><div><strong>Herstel</strong><small>Speler tot leven brengen</small></div></button>
                <button className="action-btn" onClick={() => playerAction(selected.muted ? 'unmute' : 'mute')}><span>◖</span><div><strong>{selected.muted ? 'Ontdemp' : 'Dempen'}</strong><small>Spraakbediening</small></div></button>
              </div>
              <div className="danger-actions"><button onClick={() => playerAction('kick')}>Verwijder speler</button><button onClick={() => playerAction('ban')}>Verban speler</button><button onClick={() => playerAction('warn')}>Waarschuw</button></div>
            </> : <div className="empty detail-empty"><div className="empty-art">♙</div><strong>Selecteer een speler</strong><small>Kies iemand uit de lijst om speleracties te bekijken.</small></div>}
          </section>
        </div>}

        {page === 'tools' && <div className="tools-grid">
          <section className="panel tool-panel"><div className="panel-heading"><div><h2>Persoonlijke tools</h2><p>Beheerdersacties voor je eigen personage</p></div></div>
            {[
              ['godmode', 'God mode', 'Schade aan- of uitzetten', '◈'],
              ['noclip', 'Noclip', 'Vrij door de wereld bewegen', '✣'],
              ['invisible', 'Onzichtbaar', 'Verberg je personage', '◉'],
            ].map(([id, label, desc, icon]) => <button className="toggle-row" key={id} onClick={() => tool('toggle', { toggle: id })}><span className="tool-icon">{icon}</span><span className="toggle-copy"><strong>{label}</strong><small>{desc}</small></span><span className={toggles[id] ? 'switch on' : 'switch'}><i /></span></button>)}
          </section>
          <section className="panel tool-panel"><div className="panel-heading"><div><h2>Teleportatie</h2><p>Verplaats jezelf naar een locatie</p></div></div>
            <button className="wide-action" onClick={() => tool('teleportWaypoint')}><span>⌖</span><div><strong>Naar waypoint</strong><small>Teleport naar je kaartmarkering</small></div><b>›</b></button>
            {locations.map((location, index) => <button className="wide-action" key={location.label} onClick={() => tool('teleportLocation', { index: index + 1, label: location.label })}><span>⌂</span><div><strong>{location.label}</strong><small>Opgeslagen locatie</small></div><b>›</b></button>)}
          </section>
          <section className="panel tool-panel"><div className="panel-heading"><div><h2>Uitdelen</h2><p>Geld of items aan een speler geven</p></div></div>
            <div className="field"><label>Doelspeler</label><select value={selected?.id || ''} onChange={(event) => setSelected(players.find((player) => player.id === Number(event.target.value)) || null)}><option value="">Selecteer speler</option>{players.map((player) => <option key={player.id} value={player.id}>{player.name} (ID {player.id})</option>)}</select></div>
            <div className="field"><label>Geldbedrag</label><div className="input-suffix"><input type="number" min="1" value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="Bedrag" /><select value={account} onChange={(event) => setAccount(event.target.value)}><option value="cash">Contant</option><option value="bank">Bank</option></select></div></div>
            <button className="primary-button" disabled={!selected || !amount} onClick={() => { tool('giveMoney', { target: selected.id, amount: Number(amount), account }); setAmount('') }}>Geld geven <span>→</span></button>
            <div className="field item-field"><label>Itemnaam & aantal</label><div className="input-suffix"><input value={item} onChange={(event) => setItem(event.target.value)} placeholder="Bijv. water" /><input type="number" min="1" value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="Aantal" /></div></div>
            <button className="secondary-button" disabled={!selected || !item || !amount} onClick={() => { tool('giveItem', { target: selected.id, item, amount: Number(amount) }); setItem(''); setAmount('') }}>Item geven</button>
          </section>
          <section className="panel tool-panel"><div className="panel-heading"><div><h2>Voertuig spawnen</h2><p>Spawn een voertuig op jouw locatie</p></div></div>
            <div className="field"><label>Voertuigmodel</label><input value={vehicle} onChange={(event) => setVehicle(event.target.value)} maxLength={50} placeholder="Bijv. adder" /></div>
            <button className="primary-button" disabled={!vehicle.trim()} onClick={() => { tool('spawnVehicle', { model: vehicle.trim() }); setVehicle('') }}>Spawn voertuig <span>→</span></button>
          </section>
          <section className="panel tool-panel announcement-tool"><div className="panel-heading"><div><h2>Servermededeling</h2><p>Stuur een bericht naar alle spelers online</p></div></div>
            <div className="field"><label>Bericht</label><textarea value={message} maxLength={500} onChange={(event) => setMessage(event.target.value)} placeholder="Schrijf een mededeling..." /></div>
            <button className="primary-button" disabled={!message.trim()} onClick={() => { tool('announce', { message: message.trim() }); setMessage('') }}>Verstuur mededeling <span>→</span></button>
          </section>
        </div>}

        {page === 'history' && <section className="panel history-panel"><div className="panel-heading"><div><h2>Recente beheeracties</h2><p>Auditlog van de meest recente serveracties</p></div><button className="refresh-button" onClick={() => callNui('logs')}>↻ Vernieuwen</button></div>
          <div className="history-head"><span>BEHEERDER</span><span>ACTIE</span><span>SPELER / DETAILS</span><span>DATUM</span></div>
          {logs.map((log) => <div className="history-row" key={log.id}><strong>{log.admin_name}</strong><span className="action-tag">{log.action}</span><div><strong>{log.target_name || '—'}</strong><small>{log.details || 'Geen details'}</small></div><time>{log.created_at || ''}</time></div>)}
          {logs.length === 0 && <div className="empty"><span>◷</span><strong>Nog geen logregels</strong><small>Beheeracties verschijnen hier automatisch.</small></div>}
        </section>}
        <footer className="footer"><span>KROON ADMIN <b>·</b> VEILIG BEHEER</span><span>Alle beheeracties worden gelogd</span></footer>
      </section>
      {notice && <div className={`toast ${notice.kind || ''}`}>{notice.message}</div>}
      {announcement && <div className="announcement"><span>{announcement.title}</span><strong>{announcement.message}</strong><small>Mededeling van {announcement.admin}</small></div>}
    </main>
  )
}

export default App
