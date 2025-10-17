// Centralized environment configuration
const String API_BASE_URL = 'https://t-p-deploy.onrender.com';

// If you need different URLs for development or platform-specific overrides,
// you can add logic here. For now we point to the deployed backend.

// Quick toggle: disable reverse-geocode calls (useful when backend proxy
// is temporarily unreliable). Set to true to skip reverse-geocode and avoid
// UI failures related to those calls.
const bool DISABLE_REVERSE_GEOCODE_IN_PROD = true;
