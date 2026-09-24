import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const appRoot = fileURLToPath(new URL('..', import.meta.url));

test('admin web container is a static nginx image with SPA fallback', () => {
  const dockerfile = fs.readFileSync(`${appRoot}/Dockerfile`, 'utf8');
  const nginxConfig = fs.readFileSync(`${appRoot}/nginx.conf`, 'utf8');

  assert.match(dockerfile, /^FROM nginx:alpine/m);
  assert.match(dockerfile, /COPY index\.html \/usr\/share\/nginx\/html\/index\.html/);
  assert.match(dockerfile, /COPY src \/usr\/share\/nginx\/html\/src/);
  assert.match(nginxConfig, /try_files \$uri \$uri\/ \/index\.html/);
});

test('admin web entry module parses before browser startup', () => {
  const main = fs.readFileSync(`${appRoot}/src/main.js`, 'utf8');
  const result = spawnSync(process.execPath, ['--input-type=module', '--check'], {
    input: main,
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr);
});
