import React, { useState, useContext } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import api from '../API/axios'
import { AuthContext } from '../context/AuthContext'
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
  const { login } = useContext(AuthContext)

  const [form, setForm] = useState({
    username:         '',
    email:            '',
    password:         '',
    confirmPassword:  '',
    fecha_nacimiento: '',
    sexo:             '',
  })

  const [errors, setErrors] = useState({})
  const [loading, setLoading] = useState(false)

  const handleChange = (e) => {
    const { name, value } = e.target
    setForm(prev => ({ ...prev, [name]: value }))
    if (errors[name]) setErrors(prev => ({ ...prev, [name]: null }))
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
      // 1. Registrarse
      await api.post('/usuarios/registro', {
        email: form.email,
        nombre_usuario: form.username,
        contrasena: form.password,
        fecha_nacimiento: form.fecha_nacimiento,
        sexo: form.sexo,
        bio: '',
        etiquetas_interes: [],
      })

      // 2. Login automático con esas credenciales
      const loginRes = await api.post('/login', new URLSearchParams({
        username: form.email,
        password: form.password,
      }))

      const loginData = loginRes.data
      if (!loginData.access_token || !loginData.usuario) {
        throw new Error('Error en respuesta de login')
      }

      // 3. Guardar sesión en contexto
      login(loginData.access_token, loginData.usuario)

      // 4. Redirigir a subir foto
      navigate('/upload-photo')

    } catch (err) {
      setErrors({ general: err.response?.data?.detail || err.message })
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