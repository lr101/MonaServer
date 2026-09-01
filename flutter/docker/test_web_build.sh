#!/usr/bin/env bash
set -euo pipefail

web_root="${1:?usage: test_web_build.sh <web-root>}"

required_files=(
  "main.dart.js"
  "main.dart.mjs"
  "main.dart.wasm"
  "assets/config"
  "assets/config.dev"
  "assets/assets/icon/logo-rounded-corners.png"
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -f "$web_root/$relative_path" ]]; then
    printf 'Missing web build file: %s\n' "$relative_path" >&2
    exit 1
  fi
done

node - "$web_root/flutter_bootstrap.js" "$web_root/index.html" "$web_root" <<'NODE'
const fs = require('fs');
const path = require('path');

const [bootstrapPath, indexPath, webRoot] = process.argv.slice(2);
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
const localReferences = [...index.matchAll(/(?:src|href)="([^"]+)"/g)]
  .map((match) => match[1])
  .filter((reference) => !/^(?:[a-z]+:|\/\/|#)/i.test(reference));

const missingReferences = localReferences.filter((reference) => {
  const pathname = decodeURIComponent(new URL(reference, 'http://localhost/').pathname);
  return !fs.existsSync(path.join(webRoot, pathname.replace(/^\/+/, '')));
});

if (missingReferences.length > 0) {
  throw new Error(`index.html references missing files: ${missingReferences.join(', ')}`);
}
NODE
