# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.27.1-alpine AS api-build
WORKDIR /src
RUN apk add --no-cache git ca-certificates
COPY go-server/go.mod go-server/go.sum ./
RUN go mod download
COPY go-server/ ./
ARG TARGETOS
ARG TARGETARCH
RUN --mount=type=cache,target=/root/.cache/go-build CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags='-s -w' -o /out/monaserver ./cmd/server

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS web-build
ARG FLUTTER_VERSION=3.47.4
ARG FLUTTER_SHA256=5b45f0ceda99b9bebdc873e7e69f6450aeb4c30f454b505e2e62fc9255a907d3
ENV FLUTTER_ROOT=/opt/flutter
ENV PATH=${FLUTTER_ROOT}/bin:${FLUTTER_ROOT}/bin/cache/dart-sdk/bin:${PATH}
RUN set -eux; apt-get update; apt-get install -y --no-install-recommends bash ca-certificates curl git libglu1-mesa unzip xz-utils zip; \
    curl --fail --silent --show-error --location "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" --output /tmp/flutter.tar.xz; \
    echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum --check; \
    tar --no-same-owner -xJf /tmp/flutter.tar.xz -C /opt; flutter config --enable-web; flutter precache --web; \
    rm -f /tmp/flutter.tar.xz; rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY flutter/pubspec.* ./
COPY flutter/api ./api
RUN flutter pub get
COPY flutter/ ./
ARG WEB_ORIGIN
RUN test -n "$WEB_ORIGIN" && flutter build web --wasm --release --no-pub --dart-define=API_HOST="$WEB_ORIGIN" && \
    test -s build/web/main.dart.js && test -s build/web/main.dart.mjs && test -s build/web/main.dart.wasm

FROM nginx:1.28-alpine
RUN mkdir -p /tmp/nginx/client /tmp/nginx/proxy /tmp/nginx/fastcgi /tmp/nginx/uwsgi /tmp/nginx/scgi && \
    chown -R nginx:nginx /tmp/nginx
COPY --from=api-build /out/monaserver /app/monaserver
COPY --from=web-build /app/build/web/ /srv/web/
COPY admin-web/index.html /srv/admin/index.html
COPY admin-web/src/ /srv/admin/src/
COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY deploy/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
USER nginx
EXPOSE 8081 8082 8083
HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1:8081/healthz || exit 1
ENTRYPOINT ["/app/entrypoint.sh"]
