import React, { useContext } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import './App.css'

import Login    from './pages/Login'
import Register from './pages/Register'
import UploadPhoto from './pages/UploadPhoto'
import Advanced from './examples/Advanced'

// Importamos nuestro motor de estado global
import { AuthProvider, AuthContext } from './context/AuthContext'

// =========================================================================
// 1. EL PATOVICA VIP (Ruta Protegida por Rol)
// =========================================================================
const ProtectedRoute = ({ children, allowedRoles }) => {
  const { user } = useContext(AuthContext);
  
  // Si no hay usuario en la memoria, lo mandamos directo al Login
  if (!user) {
    return <Navigate to="/login" replace />;
  }
  
  // Si la ruta exige roles específicos y el usuario no tiene el adecuado
  if (allowedRoles && !allowedRoles.includes(user.rol)) {
    // Lo mandamos a la página principal porque no tiene permiso
    return <Navigate to="/" replace />; 
  }
  
  // Si tiene el token y el rol correcto, lo dejamos pasar
  return children;
};

// =========================================================================
// 2. PANTALLAS
// =========================================================================
function HomePage() {
  const { user } = useContext(AuthContext)
  
  return (
    <div className='app'>
      <header className='app-header'>
        <div className='app-logo'>NEX<span>US</span></div>
        <div className='app-header-right'>
          {user?.foto_perfil_url ? (
            <div
              className='header-avatar'
              style={{
                backgroundImage: `url(${user.foto_perfil_url})`,
                backgroundSize: 'cover',
                backgroundPosition: 'center'
              }}
              title={user.nombre_usuario}
            />
          ) : (
            <div className='header-avatar' title={user?.nombre_usuario}>
              {user?.nombre_usuario?.substring(0, 2).toUpperCase() || 'U'}
            </div>
          )}
        </div>
      </header>
      <div className='stage'>
        <Advanced />
      </div>
    </div>
  )
}

// Pantalla de prueba para demostrar el requisito de roles de tu consigna
function AdminDashboard() {
  return (
    <div style={{ color: 'white', textAlign: 'center', marginTop: '100px' }}>
      <h2>Panel de Control - Acceso Restringido</h2>
      <p>Si estás viendo esto, es porque tu rol es Administrador u Operador.</p>
    </div>
  )
}

// =========================================================================
// 3. EL ENRUTADOR PRINCIPAL (Donde configuramos las URLs)
// =========================================================================
function App() {
  return (
    // Envolvemos toda la app con el Provider para habilitar la memoria global
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          
          {/* Ruta Protegida: Cualquier usuario logueado puede entrar */}
          <Route 
            path='/' 
            element={
              <ProtectedRoute>
                <HomePage />
              </ProtectedRoute>
            } 
          />

          {/* Ruta Protegida VIP: Solo Administradores y Operadores */}
          <Route 
            path='/admin' 
            element={
              <ProtectedRoute allowedRoles={['Administrador', 'Operador']}>
                <AdminDashboard />
              </ProtectedRoute>
            } 
          />

          {/* Rutas Públicas (Cualquiera puede entrar a loguearse o registrarse) */}
          <Route path='/login'    element={<Login />} />
          <Route path='/register' element={<Register />} />
          <Route path='/upload-photo' element={<UploadPhoto />} />

          {/* Redirección de seguridad para URLs que no existen */}
          <Route path='*' element={<Navigate to='/' replace />} />
          
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}

export default App