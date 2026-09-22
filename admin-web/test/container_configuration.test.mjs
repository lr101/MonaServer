import assert from 'node:assert/strict';
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
