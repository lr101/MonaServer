# ==========================================
# Stage 1: Build the Flutter Web App
# ==========================================
# Install the exact stable SDK used by the repository.
FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.47.2
ARG FLUTTER_SHA256=447878859d01ca9bfdb99a85f245af07ed8a15fedcd9d189c4749e8e92d1f185

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

# Flutter's --wasm build includes both the Wasm build and a dart2js fallback.
# flutter_bootstrap.js selects the first compatible build in the browser.
RUN flutter build web --wasm --release

# Fail the image build if a future Flutter/toolchain change drops either
# browser variant or the runtime configuration assets.
RUN set -eux; \
    test -s build/web/main.dart.js; \
    test -s build/web/main.dart.mjs; \
    test -s build/web/main.dart.wasm; \
    test -s build/web/assets/config; \
    test -s build/web/assets/config.dev

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
