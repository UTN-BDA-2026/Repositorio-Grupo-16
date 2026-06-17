import React, { useContext, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import api from '../API/axios'
import { AuthContext } from '../context/AuthContext'
import './Login.css'

function Login() {
  const navigate = useNavigate()
  const { login } = useContext(AuthContext)

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
      const res = await api.post('/login', new URLSearchParams({
        username: form.email,
        password: form.password,
      }))

      const data = res.data
      if (!data.access_token || !data.usuario) {
        throw new Error('Respuesta inválida del servidor')
      }

      login(data.access_token, data.usuario)
      navigate('/')

    } catch (err) {
      setErrors({ general: err.response?.data?.detail || err.message })
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