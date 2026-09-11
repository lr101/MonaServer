# ---- build stage ----
FROM --platform=$BUILDPLATFORM golang:1.27.1-alpine AS build
WORKDIR /src

# Install build tools for CGO-free build (we don't use CGO but keep ca-certs).
RUN apk add --no-cache git ca-certificates

# Cache module downloads.
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build a static binary.
COPY . .
ARG TARGETOS
ARG TARGETARCH
ENV CGO_ENABLED=0
# Persist compiled packages across source edits; CI exports this mount separately.
RUN --mount=type=cache,target=/root/.cache/go-build \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /out/monaserver ./cmd/server

# ---- runtime stage ----
FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/monaserver /app/monaserver
# Templates and static assets are embedded via //go:embed at build time;
# no extra COPY is needed for them.
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/monaserver"]
