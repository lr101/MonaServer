# ==========================================
# Stage 1: Build the Flutter Web App
# ==========================================
# Install the exact stable SDK used by the repository.
FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.47.1
ARG FLUTTER_SHA256=a1d8166c0309267cb7dc99f1424eecf08b86946ad3b50723c6f59945964aea45

ENV FLUTTER_ROOT=/opt/flutter
ENV PATH=${FLUTTER_ROOT}/bin:${FLUTTER_ROOT}/bin/cache/dart-sdk/bin:${PATH}

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      libglu1-mesa \
      unzip \
      xz-utils \
      zip; \
    archive="/tmp/flutter.tar.xz"; \
    curl --fail --silent --show-error --location \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      --output "$archive"; \
    echo "${FLUTTER_SHA256}  ${archive}" | sha256sum --check; \
    tar -xJf "$archive" --directory /opt; \
    git config --global --add safe.directory "$FLUTTER_ROOT"; \
    flutter config --enable-web; \
    flutter precache --web; \
    rm -f "$archive"; \
    rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /app

# Copy pubspec files first to leverage Docker cache for dependencies
COPY pubspec.* ./
COPY api ./api
RUN flutter pub get

# Copy the rest of your app's source code
COPY . .

# Build the web app for production with WASM
RUN flutter build web --wasm --release

# ==========================================
# Stage 2: Serve the App with Nginx
# ==========================================
# Use a lightweight Nginx image
FROM nginx:alpine

# Copy the custom nginx.conf
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Copy the compiled web files from the 'build' stage to Nginx's public folder
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80 to the outside world
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
