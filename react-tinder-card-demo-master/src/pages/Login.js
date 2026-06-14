import React, { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import './Login.css'

function Login() {
  const navigate = useNavigate()

  // Estado del formulario
  const [form, setForm] = useState({ email: '', password: '' })
  const [errors, setErrors] = useState({})
  const [loading, setLoading] = useState(false)

  // Actualiza un campo del form sin tocar los demás
  const handleChange = (e) => {
    const { name, value } = e.target
    setForm(prev => ({ ...prev, [name]: value }))
    // Limpia el error del campo en cuanto el usuario empieza a escribir
    if (errors[name]) setErrors(prev => ({ ...prev, [name]: null }))
  }

  // Validación del lado del cliente antes de llamar a la API
  const validate = () => {
    const newErrors = {}
    if (!form.email)    newErrors.email    = 'El correo es obligatorio.'
    else if (!/\S+@\S+\.\S+/.test(form.email)) newErrors.email = 'Correo inválido.'
    if (!form.password) newErrors.password = 'La contraseña es obligatoria.'
    return newErrors
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
      // const res  = await fetch('http://localhost:8000/auth/login', {
      //   method: 'POST',
      //   headers: { 'Content-Type': 'application/json' },
      //   body: JSON.stringify({ email: form.email, password: form.password }),
      // })
      // const data = await res.json()
      // if (!res.ok) throw new Error(data.detail || 'Error al iniciar sesión')
      // localStorage.setItem('token', data.access_token)
      // ─────────────────────────────────────────────────────────────

      // Mock temporal: simulamos 1 segundo de red y redirigimos
      await new Promise(r => setTimeout(r, 1000))
      navigate('/')

    } catch (err) {
      setErrors({ general: err.message })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className='auth-page'>
      <div className='auth-card'>

        {/* Logo */}
        <div className='auth-header'>
          <p className='auth-logo'>NEX<span>US</span></p>
          <p className='auth-tagline'>Conectá con personas que piensan como vos</p>
        </div>

        {/* Formulario */}
        <form className='auth-form' onSubmit={handleSubmit} noValidate>

          {/* Error general (ej: credenciales incorrectas desde la API) */}
          {errors.general && (
            <p className='field-error' style={{ textAlign: 'center' }}>
              {errors.general}
            </p>
          )}

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

          <div className='field'>
            <label htmlFor='password'>Contraseña</label>
            <input
              id='password'
              name='password'
              type='password'
              autoComplete='current-password'
              placeholder='••••••••'
              value={form.password}
              onChange={handleChange}
              className={errors.password ? 'error' : ''}
            />
            {errors.password && <span className='field-error'>{errors.password}</span>}
          </div>

          <button className='btn-primary' type='submit' disabled={loading}>
            {loading ? 'Ingresando...' : 'Iniciar sesión'}
          </button>

        </form>

        {/* Pie */}
        <p className='auth-footer'>
          ¿No tenés cuenta?{' '}
          <Link to='/register'>Registrate</Link>
        </p>

      </div>
    </div>
  )
}

export default Login