# Multi-stage build: build static assets with Node, serve with nginx
FROM node:22-alpine AS builder
WORKDIR /app

# Copy package manifests first to install dependencies
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm install

# Copy source and build
COPY . .
RUN npm run build

FROM nginx:1.26-alpine
# Remove default nginx content and copy built assets
RUN rm -rf /usr/share/nginx/html/*
# Copy built static assets into a 'public' folder so paths in index.html remain valid
COPY --from=builder /app/public /usr/share/nginx/html/public
# Copy the HTML entrypoint
COPY index.html /usr/share/nginx/html/index.html

# Copy custom, hardened nginx configuration
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# Ensure permissions are correct for the nginx user
RUN chown -R nginx:nginx /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]