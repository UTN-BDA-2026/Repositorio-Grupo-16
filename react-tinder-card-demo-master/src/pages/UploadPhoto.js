import React, { useContext, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../API/axios'
import { AuthContext } from '../context/AuthContext'
import './Login.css'

function UploadPhoto() {
  const navigate = useNavigate()
  const { user, updateUserPhoto } = useContext(AuthContext)

  const [form, setForm] = useState({
    url_imagen: '',
    descripcion: ''
  })

  const [errors, setErrors] = useState({})
  const [loading, setLoading] = useState(false)

  // Redirect si no hay usuario logueado
  if (!user) {
    navigate('/login')
    return null
  }

  const handleChange = (e) => {
    const { name, value } = e.target
    setForm(prev => ({ ...prev, [name]: value }))
    if (errors[name]) setErrors(prev => ({ ...prev, [name]: null }))
  }

  const validate = () => {
    const e = {}
    if (!form.url_imagen.trim()) {
      e.url_imagen = 'La URL de la foto es obligatoria.'
    } else if (!/^https?:\/\/.+\.(jpg|jpeg|png|gif|webp)$/i.test(form.url_imagen)) {
      e.url_imagen = 'Ingresá una URL válida de una imagen (jpg, png, gif, webp).'
    }
    return e
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    const validationErrors = validate()
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors)
      return
    }

    setLoading(true)
    try {
      const response = await api.post(`/usuarios/${user.usuario_id}/fotos`, {
        url_imagen: form.url_imagen,
        descripcion: form.descripcion || null
      })

      // Actualizar foto de perfil en contexto
      if (updateUserPhoto) {
        updateUserPhoto(form.url_imagen)
      }

      navigate('/')   // Ir a home después de subir foto

    } catch (err) {
      setErrors({ general: err.response?.data?.detail || err.message })
    } finally {
      setLoading(false)
    }
  }

  const handleSkip = () => {
    // Saltar subida de foto y ir al home
    navigate('/')
  }

  return (
    <div className='auth-page'>
      <div className='auth-card'>

        {/* Logo */}
        <div className='auth-header'>
          <p className='auth-logo'>NEX<span>US</span></p>
          <p className='auth-tagline'>Agregá tu foto de perfil</p>
        </div>

        <form className='auth-form' onSubmit={handleSubmit} noValidate>

          {errors.general && (
            <p className='field-error' style={{ textAlign: 'center' }}>
              {errors.general}
            </p>
          )}

          {/* URL de la foto */}
          <div className='field'>
            <label htmlFor='url_imagen'>URL de la foto</label>
            <input
              id='url_imagen'
              name='url_imagen'
              type='url'
              placeholder='ej: https://imgur.com/photo.jpg'
              value={form.url_imagen}
              onChange={handleChange}
              className={errors.url_imagen ? 'error' : ''}
            />
            {errors.url_imagen && <span className='field-error'>{errors.url_imagen}</span>}
          </div>

          {/* Descripción (opcional) */}
          <div className='field'>
            <label htmlFor='descripcion'>Descripción (opcional)</label>
            <textarea
              id='descripcion'
              name='descripcion'
              placeholder='Agregá un comentario a tu foto...'
              value={form.descripcion}
              onChange={handleChange}
              rows='3'
              style={{ fontFamily: 'inherit', padding: '10px', borderRadius: '4px' }}
            />
          </div>

          <button className='btn-primary' type='submit' disabled={loading}>
            {loading ? 'Subiendo foto...' : 'Subir foto'}
          </button>

        </form>

        {/* Opción de saltar */}
        <p className='auth-footer'>
          <button
            type='button'
            onClick={handleSkip}
            style={{
              background: 'none',
              border: 'none',
              color: '#007bff',
              cursor: 'pointer',
              textDecoration: 'underline'
            }}
          >
            Saltar por ahora
          </button>
        </p>

      </div>
    </div>
  )
}

export default UploadPhoto
