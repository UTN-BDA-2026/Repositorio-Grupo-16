import React, { useContext, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../API/axios'
import { AuthContext } from '../context/AuthContext'
import './Login.css'

function Dato({ etiqueta, valor }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid #2a3145', paddingBottom: 8 }}>
      <span style={{ color: '#8a93a6', fontSize: 13 }}>{etiqueta}</span>
      <span style={{ fontSize: 14, fontWeight: 600, textAlign: 'right', maxWidth: '60%', wordBreak: 'break-word' }}>{valor}</span>
    </div>
  )
}

function Perfil() {
  const navigate = useNavigate()
  const { user } = useContext(AuthContext)
  const [perfil, setPerfil] = useState(user)
  const [cargando, setCargando] = useState(true)

  useEffect(() => {
    if (!user) { navigate('/login'); return }
    // Traemos /me para tener datos completos (fecha_creacion, estado, etc.)
    api.get('/me')
      .then((res) => setPerfil(res.data))
      .catch(() => setPerfil(user))
      .finally(() => setCargando(false))
  }, []) // eslint-disable-line

  if (!user) return null

  const p = perfil || user
  const fecha = p.fecha_creacion ? new Date(p.fecha_creacion).toLocaleDateString() : '—'

  return (
    <div className='auth-page'>
      <div className='auth-card' style={{ maxWidth: 460 }}>
        <div className='auth-header'>
          <p className='auth-logo'>NEX<span>US</span></p>
          <p className='auth-tagline'>Mi perfil</p>
        </div>

        <div style={{ display: 'flex', justifyContent: 'center', margin: '10px 0 20px' }}>
          {p.foto_perfil_url ? (
            <img src={p.foto_perfil_url} alt='perfil'
              style={{ width: 120, height: 120, objectFit: 'cover', borderRadius: '50%', border: '3px solid #2e75b6' }} />
          ) : (
            <div style={{ width: 120, height: 120, borderRadius: '50%', background: '#2e75b6', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 36, fontWeight: 700 }}>
              {p.nombre_usuario?.substring(0, 2).toUpperCase() || 'U'}
            </div>
          )}
        </div>

        <div style={{ color: '#dfe4ee', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <Dato etiqueta='Nombre de usuario' valor={p.nombre_usuario} />
          <Dato etiqueta='Email' valor={p.email} />
          <Dato etiqueta='Bio' valor={p.bio || '—'} />
          <Dato etiqueta='Rol' valor={p.rol || 'usuario'} />
          <Dato etiqueta='Miembro desde' valor={fecha} />
          <Dato etiqueta='Estado' valor={p.activo === false ? 'Inactivo' : 'Activo'} />
        </div>

        <div style={{ display: 'flex', gap: 10, marginTop: 24 }}>
          <button className='btn-primary' style={{ flex: 1 }} onClick={() => navigate('/upload-photo')}>
            Editar foto
          </button>
          <button onClick={() => navigate('/')}
            style={{ flex: 1, background: 'transparent', border: '1px solid #2a3145', color: '#dfe4ee', borderRadius: 6, cursor: 'pointer' }}>
            Volver
          </button>
        </div>

        {cargando && <p style={{ color: '#8a93a6', fontSize: 12, textAlign: 'center', marginTop: 10 }}>Actualizando datos…</p>}
      </div>
    </div>
  )
}

export default Perfil