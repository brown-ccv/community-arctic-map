// API Configuration
// Uses environment variables with fallback to localhost for development

// Backend API URL (main service on port 8000)
export const BACKEND_API_URL = import.meta.env.VITE_BACKEND_API_URL || 'http://localhost:8000';

// Download service API URL (download service on port 8001)
export const DOWNLOAD_API_URL = import.meta.env.VITE_DOWNLOAD_API_URL || 'http://localhost:8001';

// For production deployment where both services are behind the same nginx proxy,
// both URLs can point to the same domain
