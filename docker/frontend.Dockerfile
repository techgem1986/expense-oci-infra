# =============================================================================
# Production Frontend Dockerfile Override
# =============================================================================
# Extends the base expense-frontend/Dockerfile for OCI ARM deployment.
# Key differences:
#   - Uses production nginx.conf from oci-deployment/conf/
#   - Optimized static asset caching
#   - Security headers in nginx config (not in this Dockerfile)
#
# Build:
#   docker build -t expense-frontend:latest \
#     --build-arg REACT_APP_API_BASE_URL=https://your-domain.com/api \
#     -f oci-deployment/docker/frontend.Dockerfile \
#     expense-frontend/
# =============================================================================

# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --legacy-peer-deps

# Copy source and build
COPY . .

# API URL injected at build time (React reads REACT_APP_* env vars)
ARG REACT_APP_API_BASE_URL=/api
ENV REACT_APP_API_BASE_URL=$REACT_APP_API_BASE_URL

RUN npm run build

# Production stage - Nginx serving static files
FROM nginx:alpine

# Copy built React app
COPY --from=builder /app/build /usr/share/nginx/html

# Copy production nginx config
COPY nginx.prod.conf /etc/nginx/conf.d/default.conf

# Health check
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://localhost:80/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]