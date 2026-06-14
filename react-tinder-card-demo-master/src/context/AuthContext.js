import React, { createContext, useState, useEffect } from 'react';
import api from '../API/axios';

export const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);

    // Cuando la página carga, preguntamos a FastAPI si la sesión sigue viva
    useEffect(() => {
        const checkSession = async () => {
            const token = localStorage.getItem('token');
            if (token) {
                try {
                    // Llamamos al endpoint /me que ahora retorna foto_perfil_url
                    const response = await api.get('/me');
                    setUser(response.data);
                } catch (error) {
                    // Si FastAPI dice que el token expiró, lo borramos
                    console.error("Sesión inválida o expirada");
                    localStorage.removeItem('token');
                }
            }
            setLoading(false);
        };
        checkSession();
    }, []);

    // Función que llamaremos cuando el usuario haga clic en "Ingresar" en la vista de Login
    const login = (token, userData) => {
        localStorage.setItem('token', token);
        setUser(userData);
    };

    const logout = () => {
        localStorage.removeItem('token');
        setUser(null);
    };

    // Actualizar la foto de perfil del usuario en el contexto
    const updateUserPhoto = (fotoUrl) => {
        if (user) {
            setUser(prev => ({
                ...prev,
                foto_perfil_url: fotoUrl
            }));
        }
    };

    if (loading) return <div>Cargando el sistema Nexus...</div>;

    return (
        <AuthContext.Provider value={{ user, login, logout, updateUserPhoto }}>
            {children}
        </AuthContext.Provider>
    );
};