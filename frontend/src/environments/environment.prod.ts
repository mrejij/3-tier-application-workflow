// Production environment values are injected at runtime via
// Kubernetes ConfigMap / environment variables read by the nginx config.
// The API base URL is replaced during the Docker build process.
export const environment = {
  production: true,
  apiUrl: '${API_BASE_URL}',   // replaced by envsubst in entrypoint
  appName: 'ShopMart',
  version: '1.0.0'
};
