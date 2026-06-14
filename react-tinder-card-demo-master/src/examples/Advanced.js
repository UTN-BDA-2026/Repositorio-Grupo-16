import React, { useState, useMemo, useRef } from 'react'
import TinderCard from 'react-tinder-card'

// ─── Mock data ────────────────────────────────────────────────────────────────
// Estructura lista para reemplazar con la respuesta real de la API de FastAPI.
// Cada objeto representa lo que devuelve el endpoint /recommendations/{userId}
// combinando datos de PostgreSQL (username, foto_perfil_url, fecha_nacimiento)
// con los de Neo4j (shared_tags, match_score).
const MOCK_USERS = [
  {
    id: 1,
    username: 'Martina Ruiz',
    age: 26,
    location: 'Buenos Aires',
    foto_perfil_url: './img/monica.jpg',
    match_score: 87,
    shared_tags: [
      { label: 'Tecnología', category: 'tech' },
      { label: 'Música', category: 'music' },
      { label: 'Vida activa', category: 'active' },
      { label: 'Fotografía', category: 'art' },
    ],
  },
  {
    id: 2,
    username: 'Lucas Campos',
    age: 29,
    location: 'Córdoba',
    foto_perfil_url: './img/richard.jpg',
    match_score: 74,
    shared_tags: [
      { label: 'Tecnología', category: 'tech' },
      { label: 'Fotografía', category: 'art' },
    ],
  },
  {
    id: 3,
    username: 'Sofía Vidal',
    age: 24,
    location: 'Rosario',
    foto_perfil_url: './img/erlich.jpg',
    match_score: 68,
    shared_tags: [
      { label: 'Música', category: 'music' },
      { label: 'Vida activa', category: 'active' },
    ],
  },
  {
    id: 4,
    username: 'Agustín Pereyra',
    age: 31,
    location: 'Mendoza',
    foto_perfil_url: './img/jared.jpg',
    match_score: 61,
    shared_tags: [
      { label: 'Tecnología', category: 'tech' },
      { label: 'Arte digital', category: 'social' },
    ],
  },
  {
    id: 5,
    username: 'Camila Torres',
    age: 27,
    location: 'La Plata',
    foto_perfil_url: './img/dinesh.jpg',
    match_score: 55,
    shared_tags: [
      { label: 'Fotografía', category: 'art' },
    ],
  },
]

// Estadísticas de sesión — vendrán de la API o del estado global
const SESSION_STATS = {
  vistos: 12,
  enviados: 5,
  confirmados: 2,
}

const MY_TAGS = [
  { label: 'Tecnología', pct: 90, color: '#378ADD' },
  { label: 'Música',     pct: 60, color: '#7F77DD' },
  { label: 'Vida activa',pct: 40, color: '#1D9E75' },
]

// ─── Tag icons ────────────────────────────────────────────────────────────────
const TAG_ICONS = {
  tech:    '💻',
  music:   '🎵',
  active:  '🏃',
  art:     '📷',
  social:  '✨',
  default: '🏷️',
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
function getMatchClass(score) {
  if (score >= 75) return 'high'
  if (score >= 55) return 'mid'
  return 'low'
}

function getInitials(name) {
  return name
    .split(' ')
    .map(p => p[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

const QUEUE_COLORS = [
  { bg: 'rgba(55,138,221,0.15)',  text: '#85B7EB'  },
  { bg: 'rgba(127,119,221,0.15)', text: '#AFA9EC'  },
  { bg: 'rgba(29,158,117,0.15)',  text: '#5DCAA5'  },
  { bg: 'rgba(239,159,39,0.15)',  text: '#FAC775'  },
  { bg: 'rgba(212,83,126,0.15)',  text: '#ED93B1'  },
]

// ─── Componente UserCard ──────────────────────────────────────────────────────
function UserCard({ user }) {
  const matchClass = getMatchClass(user.match_score)

  return (
    <div className='card'>
      {/* Foto con overlay y badge de match */}
      <div
        className='card-photo'
        style={{ backgroundImage: `url(${user.foto_perfil_url})` }}
      >
        <div className={`match-badge`}>
          <span className={`match-dot ${matchClass}`} />
          {user.match_score}% match
        </div>
        <div className='card-name-overlay'>
          <h3>{user.username}</h3>
          <p className='card-meta'>{user.age} años · {user.location}</p>
        </div>
      </div>

      {/* Cuerpo: tags de afinidad compartida */}
      <div className='card-body'>
        <p className='card-section-label'>intereses en común</p>
        <div className='tags'>
          {user.shared_tags.map((tag, i) => (
            <span key={i} className={`tag ${tag.category}`}>
              <span className='tag-icon'>{TAG_ICONS[tag.category] || TAG_ICONS.default}</span>
              {tag.label}
            </span>
          ))}
        </div>
      </div>
    </div>
  )
}

// ─── Componente principal Advanced ───────────────────────────────────────────
function Advanced() {
  const db = MOCK_USERS
  const [currentIndex, setCurrentIndex] = useState(db.length - 1)
  const [lastAction, setLastAction] = useState(null)
  const currentIndexRef = useRef(currentIndex)

  const childRefs = useMemo(
    () => Array(db.length).fill(0).map(() => React.createRef()),
    []
  )

  const updateCurrentIndex = (val) => {
    setCurrentIndex(val)
    currentIndexRef.current = val
  }

  const canGoBack = currentIndex < db.length - 1
  const canSwipe  = currentIndex >= 0

  const swiped = (direction, username, index) => {
    const msg = direction === 'right'
      ? `Conectaste con ${username} 💙`
      : direction === 'left'
      ? `Pasaste a ${username}`
      : direction === 'up'
      ? `Super like a ${username} ⭐`
      : null
    setLastAction(msg)
    updateCurrentIndex(index - 1)
  }

  const outOfFrame = (username, idx) => {
    if (currentIndexRef.current >= idx) {
      childRefs[idx].current?.restoreCard()
    }
  }

  const swipe = async (dir) => {
    if (canSwipe && currentIndex < db.length) {
      await childRefs[currentIndex].current?.swipe(dir)
    }
  }

  const goBack = async () => {
    if (!canGoBack) return
    const newIndex = currentIndex + 1
    updateCurrentIndex(newIndex)
    await childRefs[newIndex].current?.restoreCard()
    setLastAction(null)
  }

  // Perfiles en cola (los 3 siguientes después del actual)
  const queueProfiles = db
    .slice(0, Math.max(currentIndex - 1, 0))
    .reverse()
    .slice(0, 3)

  return (
    <>
      {/* ── Zona central: pila de tarjetas ── */}
      <div className='card-stack-zone'>
        <div className='cardContainer'>
          {db.map((user, index) => (
            <TinderCard
              ref={childRefs[index]}
              className='swipe'
              key={user.id}
              onSwipe={(dir) => swiped(dir, user.username, index)}
              onCardLeftScreen={() => outOfFrame(user.username, index)}
              preventSwipe={['down']}
            >
              <UserCard user={user} />
            </TinderCard>
          ))}
          {/* Estado vacío cuando se terminan las tarjetas */}
          {currentIndex < 0 && (
            <div style={{
              position: 'absolute', inset: 0,
              display: 'flex', flexDirection: 'column',
              alignItems: 'center', justifyContent: 'center',
              gap: '12px', color: 'var(--color-text-muted)',
              fontSize: '14px', textAlign: 'center', padding: '20px'
            }}>
              <span style={{ fontSize: '32px' }}>✨</span>
              <p>Ya viste todos los perfiles por hoy.</p>
              <p style={{ fontSize: '12px' }}>Volvé mañana para nuevas recomendaciones.</p>
            </div>
          )}
        </div>

        {/* ── Botones de acción ── */}
        <div className='action-buttons'>
          <button
            className='action-btn pass'
            title='Pasar'
            onClick={() => swipe('left')}
            disabled={!canSwipe}
          >✕</button>

          <button
            className='action-btn undo'
            title='Deshacer'
            onClick={goBack}
            disabled={!canGoBack}
          >↩</button>

          <button
            className='action-btn super'
            title='Super like'
            onClick={() => swipe('up')}
            disabled={!canSwipe}
          >★</button>

          <button
            className='action-btn like'
            title='Me interesa conectar'
            onClick={() => swipe('right')}
            disabled={!canSwipe}
          >♥</button>
        </div>

        {/* ── Feedback de swipe ── */}
        <p className='swipe-feedback'>{lastAction || ''}</p>
      </div>

      {/* ── Panel lateral ── */}
      <div className='side-panel'>

        {/* Stats de sesión */}
        <div className='panel-card'>
          <p className='panel-title'>📊 tu sesión de hoy</p>
          <div className='stat-row'>
            <span className='stat-label'>Perfiles vistos</span>
            <span className='stat-value'>{SESSION_STATS.vistos}</span>
          </div>
          <div className='stat-row'>
            <span className='stat-label'>Conexiones enviadas</span>
            <span className='stat-value accent'>{SESSION_STATS.enviados}</span>
          </div>
          <div className='stat-row'>
            <span className='stat-label'>Matches confirmados</span>
            <span className='stat-value green'>{SESSION_STATS.confirmados}</span>
          </div>
        </div>

        {/* Mis tags más conectados */}
        <div className='panel-card'>
          <p className='panel-title'>🏷️ tus tags activos</p>
          {MY_TAGS.map((t, i) => (
            <div className='bar-item' key={i}>
              <div className='bar-header'>
                <span>{t.label}</span>
                <span>{t.pct}% afinidad</span>
              </div>
              <div className='bar-track'>
                <div
                  className='bar-fill'
                  style={{ width: `${t.pct}%`, background: t.color }}
                />
              </div>
            </div>
          ))}
        </div>

        {/* Cola de perfiles */}
        {queueProfiles.length > 0 && (
          <div className='panel-card'>
            <p className='panel-title'>👥 próximos en cola</p>
            {queueProfiles.map((u, i) => (
              <div className='queue-item' key={u.id}>
                <div
                  className='queue-avatar'
                  style={{
                    background: QUEUE_COLORS[i % QUEUE_COLORS.length].bg,
                    color: QUEUE_COLORS[i % QUEUE_COLORS.length].text,
                  }}
                >
                  {getInitials(u.username)}
                </div>
                <div className='queue-info'>
                  <p className='queue-name'>{u.username}</p>
                  <p className='queue-match'>
                    {u.match_score}% · {u.shared_tags.map(t => t.label).join(', ')}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  )
}

export default Advanced
