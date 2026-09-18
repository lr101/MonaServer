#!/usr/bin/env bash
set -euo pipefail

web_root="${1:?usage: test_admin_web_build.sh <web-root>}"

required_files=(
  "main.dart.js"
  "main.dart.mjs"
  "main.dart.wasm"
  "assets/config"
  "assets/config.dev"
  "flutter_bootstrap.js"
  "admin-logo.svg"
  "admin-manifest.json"
  "admin_splash.js"
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -f "$web_root/$relative_path" ]]; then
    printf 'Missing admin web build file: %s\n' "$relative_path" >&2
    exit 1
  fi
done

node - "$web_root/flutter_bootstrap.js" "$web_root/index.html" "$web_root/admin-manifest.json" "$web_root" <<'NODE'
const fs = require('fs');
const path = require('path');

const [bootstrapPath, indexPath, manifestPath, webRoot] = process.argv.slice(2);
const bootstrap = fs.readFileSync(bootstrapPath, 'utf8');
const buildConfigMatch = bootstrap.match(
  /_flutter\.buildConfig\s*=\s*(\{.*?\});\s*\n\s*_flutter\.loader\.load/s,
);
if (!buildConfigMatch) {
  throw new Error('Flutter bootstrap does not contain a build configuration');
}
const buildConfig = JSON.parse(buildConfigMatch[1]);
const compileTargets = new Set(
  buildConfig.builds.map((build) => build.compileTarget),
);
for (const target of ['dart2wasm', 'dart2js']) {
  if (!compileTargets.has(target)) {
    throw new Error(`Flutter bootstrap is missing the ${target} build`);
  }
}

const index = fs.readFileSync(indexPath, 'utf8');
if (!index.includes('name="admin-entry" content="true"')) {
  throw new Error('Admin artifact is missing its independent entry marker');
}
if (!index.includes('<title>Stick-It Admin</title>')) {
  throw new Error('Admin artifact has the consumer page title');
}
const cspMatch = index.match(
  /<meta[^>]+http-equiv="Content-Security-Policy"[^>]+content="([^"]+)"/i,
);
if (!cspMatch) {
  throw new Error('Admin artifact is missing its CSP');
}
const csp = cspMatch[1];
for (const directive of [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data:",
  "font-src 'self' data:",
  "connect-src 'self'",
  "object-src 'none'",
  "base-uri 'self'",
  "frame-ancestors 'none'",
]) {
  if (!csp.includes(directive)) {
    throw new Error(`Admin CSP is missing ${directive}`);
  }
}
const scriptSource = csp
  .split(';')
  .map((directive) => directive.trim())
  .find((directive) => directive.startsWith('script-src '));
if (scriptSource !== "script-src 'self'") {
  throw new Error('Admin CSP allows a non-local script source');
}
if (/<script(?![^>]+\bsrc=)[^>]*>/i.test(index)) {
  throw new Error('Admin artifact contains an inline script outside its CSP');
}
if (
  /cdnjs\.cloudflare\.com|jsdelivr\.net|unpkg\.com|fonts\.googleapis\.com|cropperjs|<script[^>]+src=["'](?:https?:|\/\/)/i.test(
    index,
  )
) {
  throw new Error('Admin artifact contains a third-party script or consumer CDN');
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
if (manifest.name !== 'Stick-It Admin') {
  throw new Error('Admin artifact has the consumer manifest');
}

const localReferences = [...index.matchAll(/(?:src|href)="([^"]+)"/g)]
  .map((match) => match[1])
  .filter((reference) => !/^(?:[a-z]+:|\/\/|#)/i.test(reference));
const missingReferences = localReferences.filter((reference) => {
  const pathname = decodeURIComponent(new URL(reference, 'http://localhost/').pathname);
  return !fs.existsSync(path.join(webRoot, pathname.replace(/^\/+/, '')));
});
if (missingReferences.length > 0) {
  throw new Error(`Admin index references missing files: ${missingReferences.join(', ')}`);
}
NODE
