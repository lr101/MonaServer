FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY src /usr/share/nginx/html/src

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --start-period=2s --retries=3 \
  CMD wget --quiet --output-document=- http://127.0.0.1/healthz >/dev/null || exit 1
