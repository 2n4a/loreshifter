ARG FLUTTER_VERSION=3.35.3
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION} AS build

# Build arguments (override at build time)
ARG BACKEND_URL=http://127.0.0.1:8000/api/v0
ARG BUILD_NUMBER=0

# Expose at build for dart-define; also write into ENV if any scripts read it
ENV BACKEND_URL=${BACKEND_URL}
WORKDIR /app

# Enable web & precache to avoid network during build steps later
RUN flutter config --enable-web \
 && flutter precache --web \
 && flutter --version

# Copy only dependency resolution inputs first (dependency layer caching)
COPY frontend/pubspec.yaml frontend/pubspec.lock ./

# Resolve dependencies
RUN flutter pub get

# Now copy the remainder of the source tree
COPY frontend/ .

# Re-run pub get in case additional local packages / assets appeared
RUN flutter pub get

# Optional: fail fast on analysis issues (can be commented out to speed builds)
# RUN flutter analyze --no-fatal-infos --no-fatal-warnings

# Build release web bundle with dart defines
RUN echo "Building Flutter web with BACKEND_URL=${BACKEND_URL}" && \
    flutter build web \
      --release \
      --dart-define=BACKEND_URL=${BACKEND_URL} \
      --dart-define=BUILD_NUMBER=${BUILD_NUMBER}

ARG FLUTTER_VERSION=3.35.3
FROM nginx:1.27-alpine AS runtime
ARG FLUTTER_VERSION

LABEL org.opencontainers.image.title="loreshifter-frontend" \
      org.opencontainers.image.description="Flutter web build served via Nginx" \
      org.opencontainers.image.source="https://github.com/2n4a/loreshifter" \
      org.opencontainers.image.version="${FLUTTER_VERSION}" \
      org.opencontainers.image.licenses="MIT"

# Remove default site
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy external nginx config (moved from heredoc)
COPY frontend/nginx.conf /etc/nginx/conf.d/flutter.conf

# Copy compiled artifacts
COPY --from=build /app/build/web /usr/share/nginx/html

# Optional: run as non-root (uncomment if infra permits)
# RUN adduser -D app && chown -R app:app /usr/share/nginx/html /var/cache/nginx /var/run
# USER app

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

# Usage ------------------------------------------------------------------------
# Build (default backend URL):
#   docker build -t loreshifter-web:latest frontend/
# Custom backend URL & build number:
#   docker build --build-arg BACKEND_URL=https://api.example.com --build-arg BUILD_NUMBER=42 -t loreshifter-web:prod frontend/
# Run:
#   docker run -p 8080:80 loreshifter-web:latest
# Visit: http://localhost:8080
