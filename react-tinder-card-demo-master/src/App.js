import React from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import './App.css'

import Login    from './pages/Login'
import Register from './pages/Register'
import Advanced from './examples/Advanced'

// Pantalla principal envuelta en su layout
function HomePage() {
  return (
    <div className='app'>
      <header className='app-header'>
        <div className='app-logo'>NEX<span>US</span></div>
        <div className='app-header-right'>
          <div className='header-avatar'>YO</div>
        </div>
      </header>
      <div className='stage'>
        <Advanced />
      </div>
    </div>
  )
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* Ruta raíz → pantalla de swipe */}
        <Route path='/'          element={<HomePage />} />

        {/* Auth */}
        <Route path='/login'    element={<Login />} />
        <Route path='/register' element={<Register />} />

        {/* Cualquier ruta desconocida → home */}
        <Route path='*' element={<Navigate to='/' replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App