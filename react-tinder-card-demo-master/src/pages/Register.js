import React, { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import './Login.css'   // reutilizamos los mismos estilos base

// Calcula la edad a partir de una fecha de nacimiento en formato YYYY-MM-DD
function calcularEdad(fechaNac) {
  if (!fechaNac) return 0
  const hoy  = new Date()
  const nac  = new Date(fechaNac)
  let edad   = hoy.getFullYear() - nac.getFullYear()
  const m    = hoy.getMonth() - nac.getMonth()
  if (m < 0 || (m === 0 && hoy.getDate() < nac.getDate())) edad--
  return edad
}

function Register() {
  const navigate = useNavigate()

  const [form, setForm] = useState({
    username:         '',
    email:            '',
    password:         '',
    confirmPassword:  '',
    fecha_nacimiento: '',
    sexo:             '',
    foto_perfil:      null,      // objeto File
  })

  // Vista previa de la foto antes de subir
  const [preview, setPreview] = useState(null)
  const [errors,  setErrors]  = useState({})
  const [loading, setLoading] = useState(false)

  const handleChange = (e) => {
    const { name, value } = e.target
    setForm(prev => ({ ...prev, [name]: value }))
    if (errors[name]) setErrors(prev => ({ ...prev, [name]: null }))
  }

  // Manejo especial para el input de tipo file
  const handleFile = (e) => {
    const file = e.target.files[0]
    if (!file) return
    setForm(prev => ({ ...prev, foto_perfil: file }))
    // Genera una URL temporal para mostrar la preview en el navegador
    setPreview(URL.createObjectURL(file))
    if (errors.foto_perfil) setErrors(prev => ({ ...prev, foto_perfil: null }))
  }

  const validate = () => {
    const e = {}
    if (!form.username.trim())       e.username  = 'El nombre de usuario es obligatorio.'
    else if (form.username.length < 3) e.username = 'Mínimo 3 caracteres.'

    if (!form.email)                 e.email     = 'El correo es obligatorio.'
    else if (!/\S+@\S+\.\S+/.test(form.email)) e.email = 'Correo inválido.'

    if (!form.password)              e.password  = 'La contraseña es obligatoria.'
    else if (form.password.length < 6) e.password = 'Mínimo 6 caracteres.'

    if (form.password !== form.confirmPassword)
      e.confirmPassword = 'Las contraseñas no coinciden.'

    if (!form.fecha_nacimiento)      e.fecha_nacimiento = 'La fecha de nacimiento es obligatoria.'
    else if (calcularEdad(form.fecha_nacimiento) < 18)
      e.fecha_nacimiento = 'Debés ser mayor de 18 años para usar Nexus.'

    if (!form.sexo)                  e.sexo      = 'Seleccioná una opción.'

    if (!form.foto_perfil)           e.foto_perfil = 'Agregá una foto de perfil.'

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
      // ── TODO: reemplazar con el endpoint real de FastAPI ──────────
      // La foto se sube con FormData porque es un archivo binario.
      // FastAPI recibe esto con:  foto_perfil: UploadFile = File(...)
      //
      // const formData = new FormData()
      // formData.append('username',         form.username)
      // formData.append('email',            form.email)
      // formData.append('password',         form.password)
      // formData.append('fecha_nacimiento', form.fecha_nacimiento)
      // formData.append('sexo',             form.sexo)
      // formData.append('foto_perfil',      form.foto_perfil)
      //
      // const res  = await fetch('http://localhost:8000/auth/register', {
      //   method: 'POST',
      //   body: formData,   // NO pongas Content-Type: el browser lo pone solo con el boundary
      // })
      // const data = await res.json()
      // if (!res.ok) throw new Error(data.detail || 'Error al registrarse')
      // ─────────────────────────────────────────────────────────────

      // Mock temporal
      await new Promise(r => setTimeout(r, 1200))
      navigate('/login')   // después de registrarse, mandamos al login

    } catch (err) {
      setErrors({ general: err.message })
    } finally {
      setLoading(false)
    }
  }

  // Fecha máxima permitida: hoy menos 18 años
  const maxDate = (() => {
    const d = new Date()
    d.setFullYear(d.getFullYear() - 18)
    return d.toISOString().split('T')[0]   // formato YYYY-MM-DD
  })()

  return (
    <div className='auth-page'>
      <div className='auth-card'>

        {/* Logo */}
        <div className='auth-header'>
          <p className='auth-logo'>NEX<span>US</span></p>
          <p className='auth-tagline'>Creá tu perfil y empezá a conectar</p>
        </div>

        <form className='auth-form' onSubmit={handleSubmit} noValidate>

          {errors.general && (
            <p className='field-error' style={{ textAlign: 'center' }}>
              {errors.general}
            </p>
          )}

          {/* Foto de perfil — va primero para que sea lo más visual */}
          <div className='field' style={{ alignItems: 'center' }}>
            <label htmlFor='foto_perfil'>Foto de perfil</label>

            {/* Si hay preview mostramos la imagen, si no un placeholder */}
            <div
              style={{
                width: 90, height: 90,
                borderRadius: '50%',
                background: 'var(--color-bg)',
                border: `2px dashed ${errors.foto_perfil ? 'rgba(240,153,123,0.7)' : 'var(--color-border-md)'}`,
                overflow: 'hidden',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                cursor: 'pointer',
                transition: 'border-color 0.15s',
              }}
              onClick={() => document.getElementById('foto_perfil').click()}
            >
              {preview
                ? <img src={preview} alt='preview' style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                : <span style={{ fontSize: 28 }}>📷</span>
              }
            </div>

            {/* Input oculto — se activa al hacer clic en el círculo de arriba */}
            <input
              id='foto_perfil'
              name='foto_perfil'
              type='file'
              accept='image/*'
              style={{ display: 'none' }}
              onChange={handleFile}
            />

            <span style={{ fontSize: 11, color: 'var(--color-text-muted)' }}>
              Tocá para elegir una imagen
            </span>
            {errors.foto_perfil && <span className='field-error'>{errors.foto_perfil}</span>}
          </div>

          {/* Nombre de usuario */}
          <div className='field'>
            <label htmlFor='username'>Nombre de usuario</label>
            <input
              id='username'
              name='username'
              type='text'
              autoComplete='username'
              placeholder='ej: martina_ruiz'
              value={form.username}
              onChange={handleChange}
              className={errors.username ? 'error' : ''}
            />
            {errors.username && <span className='field-error'>{errors.username}</span>}
          </div>

          {/* Correo */}
          <div className='field'>
            <label htmlFor='email'>Correo electrónico</label>
            <input
              id='email'
              name='email'
              type='email'
              autoComplete='email'
              placeholder='tu@correo.com'
              value={form.email}
              onChange={handleChange}
              className={errors.email ? 'error' : ''}
            />
            {errors.email && <span className='field-error'>{errors.email}</span>}
          </div>

          {/* Contraseña */}
          <div className='field'>
            <label htmlFor='password'>Contraseña</label>
            <input
              id='password'
              name='password'
              type='password'
              autoComplete='new-password'
              placeholder='Mínimo 6 caracteres'
              value={form.password}
              onChange={handleChange}
              className={errors.password ? 'error' : ''}
            />
            {errors.password && <span className='field-error'>{errors.password}</span>}
          </div>

          {/* Confirmar contraseña */}
          <div className='field'>
            <label htmlFor='confirmPassword'>Confirmar contraseña</label>
            <input
              id='confirmPassword'
              name='confirmPassword'
              type='password'
              autoComplete='new-password'
              placeholder='Repetí tu contraseña'
              value={form.confirmPassword}
              onChange={handleChange}
              className={errors.confirmPassword ? 'error' : ''}
            />
            {errors.confirmPassword && <span className='field-error'>{errors.confirmPassword}</span>}
          </div>

          {/* Fecha de nacimiento — maxDate bloquea fechas que impliquen menos de 18 años */}
          <div className='field'>
            <label htmlFor='fecha_nacimiento'>Fecha de nacimiento</label>
            <input
              id='fecha_nacimiento'
              name='fecha_nacimiento'
              type='date'
              max={maxDate}
              value={form.fecha_nacimiento}
              onChange={handleChange}
              className={errors.fecha_nacimiento ? 'error' : ''}
            />
            {errors.fecha_nacimiento && <span className='field-error'>{errors.fecha_nacimiento}</span>}
          </div>

          {/* Sexo */}
          <div className='field'>
            <label htmlFor='sexo'>Sexo</label>
            <select
              id='sexo'
              name='sexo'
              value={form.sexo}
              onChange={handleChange}
              className={errors.sexo ? 'error' : ''}
            >
              <option value=''>Seleccioná una opción</option>
              <option value='M'>Masculino</option>
              <option value='F'>Femenino</option>
              <option value='NB'>No binario</option>
              <option value='NS'>Prefiero no decirlo</option>
            </select>
            {errors.sexo && <span className='field-error'>{errors.sexo}</span>}
          </div>

          <button className='btn-primary' type='submit' disabled={loading}>
            {loading ? 'Creando cuenta...' : 'Crear cuenta'}
          </button>

        </form>

        <p className='auth-footer'>
          ¿Ya tenés cuenta?{' '}
          <Link to='/login'>Iniciá sesión</Link>
        </p>

      </div>
    </div>
  )
}

export default Register