import React, { useContext, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../API/axios'
import { AuthContext } from '../context/AuthContext'
import './Login.css'

function UploadPhoto() {
  const navigate = useNavigate()
  const { user, updateUserPhoto } = useContext(AuthContext)

  const [imagenDataUrl, setImagenDataUrl] = useState('')
  const [descripcion, setDescripcion] = useState('')
  const [errors, setErrors] = useState({})
  const [loading, setLoading] = useState(false)

  if (!user) {
    navigate('/login')
    return null
  }

  // Abre el explorador, lee la imagen elegida y la convierte a data URL (base64)
  const handleFile = (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (!file.type.startsWith('image/')) {
      setErrors({ archivo: 'El archivo debe ser una imagen.' })
      return
    }
    if (file.size > 2 * 1024 * 1024) {
      setErrors({ archivo: 'La imagen es muy grande (máx. 2 MB).' })
      return
    }
    const reader = new FileReader()
    reader.onload = () => { setImagenDataUrl(reader.result); setErrors({}) }
    reader.readAsDataURL(file)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!imagenDataUrl) {
      setErrors({ archivo: 'Elegí una imagen primero.' })
      return
    }
    setLoading(true)
    try {
      await api.post(`/usuarios/${user.usuario_id}/fotos`, {
        url_imagen: imagenDataUrl,
        descripcion: descripcion || null,
      })
      if (updateUserPhoto) updateUserPhoto(imagenDataUrl)
      navigate('/')
    } catch (err) {
      const detail = err.response?.data?.detail
      const msg = Array.isArray(detail) ? detail.map((d) => d.msg).join(' | ') : (detail || err.message)
      setErrors({ general: msg })
    } finally {
      setLoading(false)
    }
  }

  const handleSkip = () => navigate('/')

  return (
    <div className='auth-page'>
      <div className='auth-card'>
        <div className='auth-header'>
          <p className='auth-logo'>NEX<span>US</span></p>
          <p className='auth-tagline'>Agregá tu foto de perfil</p>
        </div>

        <form className='auth-form' onSubmit={handleSubmit} noValidate>
          {errors.general && <p className='field-error' style={{ textAlign: 'center' }}>{errors.general}</p>}

          <div className='field'>
            <label htmlFor='archivo'>Elegí una imagen de tu dispositivo</label>
            <input id='archivo' type='file' accept='image/*' onChange={handleFile} />
            {errors.archivo && <span className='field-error'>{errors.archivo}</span>}
          </div>

          {imagenDataUrl && (
            <div style={{ display: 'flex', justifyContent: 'center', margin: '10px 0' }}>
              <img src={imagenDataUrl} alt='vista previa'
                style={{ width: 120, height: 120, objectFit: 'cover', borderRadius: '50%', border: '2px solid #2e75b6' }} />
            </div>
          )}

          <div className='field'>
            <label htmlFor='descripcion'>Descripción (opcional)</label>
            <textarea id='descripcion' value={descripcion} onChange={(e) => setDescripcion(e.target.value)}
              rows='3' placeholder='Agregá un comentario a tu foto...'
              style={{ fontFamily: 'inherit', padding: '10px', borderRadius: '4px' }} />
          </div>

          <button className='btn-primary' type='submit' disabled={loading}>
            {loading ? 'Subiendo foto...' : 'Subir foto'}
          </button>
        </form>

        <p className='auth-footer'>
          <button type='button' onClick={handleSkip}
            style={{ background: 'none', border: 'none', color: '#007bff', cursor: 'pointer', textDecoration: 'underline' }}>
            Saltar por ahora
          </button>
        </p>
      </div>
    </div>
  )
}

export default UploadPhoto