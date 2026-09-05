import { isAbsolute, relative, resolve, sep } from 'node:path';

function isWithin(parent, candidate) {
  const relativePath = relative(parent, candidate);
  return (
    relativePath === '' ||
    (relativePath !== '..' &&
      !relativePath.startsWith(`..${sep}`) &&
      !isAbsolute(relativePath))
  );
}

export function dataPath() {
  const e2eRoot = resolve(process.cwd());
  const workspaceRoot = resolve(e2eRoot, '../..');
  const authRoot = resolve(e2eRoot, '.auth');
  const configuredPath = process.env.E2E_DATA_PATH;
  if (!configuredPath) return resolve(authRoot, 'test-data.json');

  const candidate = resolve(e2eRoot, configuredPath);
  if (isWithin(workspaceRoot, candidate) && !isWithin(authRoot, candidate)) {
    throw new Error(
      `E2E_DATA_PATH must be inside ${authRoot} when it points into the repository; use an external protected path instead.`,
    );
  }
  return candidate;
}
