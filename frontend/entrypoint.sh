#!/bin/sh
set -e

# Replace ${API_BASE_URL} placeholder in built Angular JS files with the actual env var value
find /usr/share/nginx/html -name "*.js" -exec sed -i "s|\${API_BASE_URL}|${API_BASE_URL}|g" {} \;

exec nginx -g "daemon off;"
