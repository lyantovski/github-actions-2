#!/bin/sh
# Entry point for the nginx container. Replaces ${PORT} in nginx config and starts nginx.
set -e

# Default port if not provided
: ${PORT:=80}

# If Azure sets WEBSITES_PORT prefer it (App Service uses this variable)
if [ -n "${WEBSITES_PORT:-}" ]; then
  PORT=${WEBSITES_PORT}
fi

# Write effective vars for diagnostics
echo "[entrypoint] WEBSITES_PORT=${WEBSITES_PORT:-}<unset> PORT=${PORT}"

# Validate PORT is numeric, fallback to 80
if ! printf '%s' "$PORT" | grep -Eq '^[0-9]+$'; then
  echo "[entrypoint] invalid PORT='$PORT', falling back to 80"
  PORT=80
fi

# Export so envsubst can access it
export PORT

# Use envsubst to replace ${PORT} in the nginx config template
if command -v envsubst >/dev/null 2>&1; then
  envsubst '$PORT' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf
else
  # If envsubst is not available (should not happen since we install it), copy template as-is
  cp /etc/nginx/conf.d/default.conf.template /etc/nginx/conf.d/default.conf
fi

# drop privileges and run nginx in foreground
exec nginx -g 'daemon off;'
