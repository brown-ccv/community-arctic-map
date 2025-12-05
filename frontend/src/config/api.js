/**
 * API Configuration
 * 
 * This file centralizes API endpoint configuration.
 * In production (Cloud Run), API requests go to the same origin (no CORS needed).
 * In development, they go to localhost backends.
 */

const isDevelopment = import.meta.env.MODE === 'development';

// For production builds, use environment variables if provided, otherwise use relative URLs
// For development, use localhost
export const API_CONFIG = {
  BACKEND_API_URL: isDevelopment 
    ? 'http://localhost:8000' 
    : (import.meta.env.VITE_BACKEND_API_URL || ''),
  
  DOWNLOAD_API_URL: isDevelopment 
    ? 'http://localhost:8001' 
    : (import.meta.env.VITE_DOWNLOAD_API_URL || ''),
};

/**
 * Get the full API URL for a given path
 * @param {string} path - API path (e.g., '/api/geojson/layer')
 * @param {string} service - Service type: 'backend' or 'download'
 * @returns {string} Full URL
 */
export const getApiUrl = (path, service = 'backend') => {
  const baseUrl = service === 'download' ? API_CONFIG.DOWNLOAD_API_URL : API_CONFIG.BACKEND_API_URL;
  
  // If baseUrl is empty (production), return just the path (relative URL)
  if (!baseUrl) {
    return path;
  }
  
  // Otherwise, prepend the base URL
  return `${baseUrl}${path}`;
};
