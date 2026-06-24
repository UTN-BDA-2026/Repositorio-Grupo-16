import React, { useState, useMemo, useRef, useEffect, useContext } from 'react'
import TinderCard from 'react-tinder-card'
import api from '../API/axios'
import { AuthContext } from '../context/AuthContext'

// ─── Iconos por categoría de tag ───────────────────────────────────────────────
const TAG_ICONS = {
  tech: '💻', music: '🎵', active: '🏃', art: '📷', social: '✨', default: '🏷️',
}

// Mapea el nombre de la etiqueta (viene de la API) a una categoría para el ícono/color
function categoriaDeTag(label) {
  const l = (label || '').toLowerCase()
  if (/(tecnolog|program|inteligencia|ciber|software)/.test(l)) return 'tech'
  if (/(música|musica|cine|series)/.test(l)) return 'music'
  if (/(fitness|deporte|fútbol|futbol|yoga|outdoor)/.test(l)) return 'active'
  if (/(fotograf|arte|diseño|literatura)/.test(l)) return 'art'
  return 'social'
}

// Convierte un resultado de la API en el objeto que espera la tarjeta
function mapRecomendacion(r) {
  const cant = r.cantidad_comun || 0
  return {
    id: r.usuario_id,
    username: r.nombre_usuario || r.email,
    email: r.email,
    // No tenemos edad/ubicación en la API; el score se deriva de intereses en común
    match_score: Math.min(40 + cant * 15, 99),
    shared_tags: (r.etiquetas_compartidas || []).map((label) => ({
      label, category: categoriaDeTag(label),
    })),
  }
}

function getMatchClass(score) {
  if (score >= 75) return 'high'
  if (score >= 55) return 'mid'
  return 'low'
}

function getInitials(name) {
  return (name || '?').split(' ').map((p) => p[0]).slice(0, 2).join('').toUpperCase()
}

const QUEUE_COLORS = [
  { bg: 'rgba(55,138,221,0.15)', text: '#85B7EB' },
  { bg: 'rgba(127,119,221,0.15)', text: '#AFA9EC' },
  { bg: 'rgba(29,158,117,0.15)', text: '#5DCAA5' },
  { bg: 'rgba(239,159,39,0.15)', text: '#FAC775' },
  { bg: 'rgba(212,83,126,0.15)', text: '#ED93B1' },
]

// ─── Tarjeta de usuario ─────────────────────────────────────────────────────────
function UserCard({ user }) {
  const matchClass = getMatchClass(user.match_score)
  return (
    <div className='card'>
      <div
        className='card-photo'
        style={user.foto_perfil_url ? { backgroundImage: `url(${user.foto_perfil_url})` } : {}}
      >
        <div className='match-badge'>
          <span className={`match-dot ${matchClass}`} />
          {user.match_score}% match
        </div>
        <div className='card-name-overlay'>
          <h3>{user.username}</h3>
          <p className='card-meta'>{user.shared_tags.length} intereses en común</p>
        </div>
      </div>
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

// ─── Componente principal ─────────────────────────────────────────────────────
function Advanced() {
  const { user } = useContext(AuthContext)
  const [db, setDb] = useState([])
  const [estado, setEstado] = useState('cargando') // cargando | ok | vacio | error
  const [currentIndex, setCurrentIndex] = useState(-1)
  const [lastAction, setLastAction] = useState(null)
  const [recsPerfil, setRecsPerfil] = useState([])
  const currentIndexRef = useRef(currentIndex)

  // Trae las recomendaciones reales al montar (o cuando hay usuario)
  useEffect(() => {
    const cargar = async () => {
      if (!user?.usuario_id) return
      try {
        const res = await api.get(`/api/v1/recomendaciones/intereses-comunes/${user.usuario_id}`)
        const lista = (res.data?.resultados || []).map(mapRecomendacion)
        setDb(lista)
        setCurrentIndex(lista.length - 1)
        currentIndexRef.current = lista.length - 1
        setEstado(lista.length ? 'ok' : 'vacio')
      } catch (e) {
        console.error('Error cargando recomendaciones', e)
        setEstado('error')
      }
    }
    cargar()
  }, [user])

  useEffect(() => {
    const actual = db[currentIndex]
    if (!actual) { setRecsPerfil([]); return }
    let cancelado = false
    api.get(`/api/v1/recomendaciones/amigos-de-amigos/${actual.id}`)
      .then((res) => { if (!cancelado) setRecsPerfil((res.data?.resultados || []).slice(0, 4)) })
      .catch(() => { if (!cancelado) setRecsPerfil([]) })
    return () => { cancelado = true }
  }, [currentIndex, db])

  const childRefs = useMemo(
    () => Array(db.length).fill(0).map(() => React.createRef()),
    [db.length]
  )

  const updateCurrentIndex = (val) => {
    setCurrentIndex(val)
    currentIndexRef.current = val
  }

  const canGoBack = currentIndex < db.length - 1
  const canSwipe = currentIndex >= 0

  const swiped = (direction, username, index) => {
    const msg = direction === 'right' ? `Conectaste con ${username} 💙`
      : direction === 'left' ? `Pasaste a ${username}`
      : direction === 'up' ? `Super like a ${username} ⭐` : null
    setLastAction(msg)
    updateCurrentIndex(index - 1)
  }

  const outOfFrame = (username, idx) => {
    if (currentIndexRef.current >= idx) childRefs[idx].current?.restoreCard()
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

  const queueProfiles = db.slice(0, Math.max(currentIndex - 1, 0)).reverse().slice(0, 3)

  if (estado === 'cargando') return <p style={{ color: '#aaa', padding: 40 }}>Cargando recomendaciones…</p>
  if (estado === 'error') return <p style={{ color: '#e88', padding: 40 }}>No se pudieron cargar las recomendaciones.</p>

  return (
    <>
      <div className='card-stack-zone'>
        <div className='cardContainer'>
          {db.map((u, index) => (
            <TinderCard
              ref={childRefs[index]}
              className='swipe'
              key={u.id}
              onSwipe={(dir) => swiped(dir, u.username, index)}
              onCardLeftScreen={() => outOfFrame(u.username, index)}
              preventSwipe={['down']}
            >
              <UserCard user={u} />
            </TinderCard>
          ))}
          {(currentIndex < 0 || estado === 'vacio') && (
            <div style={{
              position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
              alignItems: 'center', justifyContent: 'center', gap: '12px',
              color: 'var(--color-text-muted)', fontSize: '14px', textAlign: 'center', padding: '20px',
            }}>
              <span style={{ fontSize: '32px' }}>✨</span>
              <p>No hay más recomendaciones por ahora.</p>
            </div>
          )}
        </div>

        <div className='action-buttons'>
          <button className='action-btn pass' title='Pasar' onClick={() => swipe('left')} disabled={!canSwipe}>✕</button>
          <button className='action-btn undo' title='Deshacer' onClick={goBack} disabled={!canGoBack}>↩</button>
          <button className='action-btn super' title='Super like' onClick={() => swipe('up')} disabled={!canSwipe}>★</button>
          <button className='action-btn like' title='Me interesa conectar' onClick={() => swipe('right')} disabled={!canSwipe}>♥</button>
        </div>

        <p className='swipe-feedback'>{lastAction || ''}</p>
      </div>

      <div className='side-panel'>
        <div className='panel-card'>
          <p className='panel-title'>📊 tu sesión</p>
          <div className='stat-row'>
            <span className='stat-label'>Recomendaciones</span>
            <span className='stat-value'>{db.length}</span>
          </div>
          <div className='stat-row'>
            <span className='stat-label'>Restantes</span>
            <span className='stat-value accent'>{Math.max(currentIndex + 1, 0)}</span>
          </div>
        </div>

        {db[currentIndex] && (
          <div className='panel-card'>
            <p className='panel-title'>🔗 conectá con más gente</p>
            <p style={{ color: '#8a93a6', fontSize: 12, margin: '0 0 10px' }}>
              Personas conectadas a <strong style={{ color: '#dfe4ee' }}>{db[currentIndex].username}</strong>
            </p>
            {recsPerfil.length === 0 ? (
              <p style={{ color: '#8a93a6', fontSize: 12 }}>Buscando conexiones…</p>
            ) : (
              recsPerfil.map((r, i) => (
                <div className='queue-item' key={r.usuario_id}>
                  <div className='queue-avatar' style={{
                    background: QUEUE_COLORS[i % QUEUE_COLORS.length].bg,
                    color: QUEUE_COLORS[i % QUEUE_COLORS.length].text,
                  }}>
                    {getInitials(r.nombre_usuario || '?')}
                  </div>
                  <div className='queue-info'>
                    <p className='queue-name'>{r.nombre_usuario}</p>
                    <p className='queue-match'>{r.amigos_mutuos} amigos en común</p>
                  </div>
                </div>
              ))
            )}
          </div>
        )}

        {queueProfiles.length > 0 && (
          <div className='panel-card'>
            <p className='panel-title'>👥 próximos en cola</p>
            {queueProfiles.map((u, i) => (
              <div className='queue-item' key={u.id}>
                <div className='queue-avatar' style={{
                  background: QUEUE_COLORS[i % QUEUE_COLORS.length].bg,
                  color: QUEUE_COLORS[i % QUEUE_COLORS.length].text,
                }}>
                  {getInitials(u.username)}
                </div>
                <div className='queue-info'>
                  <p className='queue-name'>{u.username}</p>
                  <p className='queue-match'>{u.match_score}% · {u.shared_tags.map((t) => t.label).join(', ')}</p>
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