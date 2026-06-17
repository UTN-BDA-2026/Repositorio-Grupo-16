import axios from 'axios';

// Configuramos la dirección base 
const instance = axios.create({
    baseURL: 'http://localhost:8000'
});

// Este interceptor frena la petición una fracción de segundo antes de salir
instance.interceptors.request.use(
    (config) => {
        // Buscamos el token en la memoria del navegador
        const token = localStorage.getItem('token');
        config.headers = config.headers || {};
        if (token) {
            // Si hay token, lo metemos en los Headers 
            config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
    },
    (error) => {
        return Promise.reject(error);
    }
);

export default instance;