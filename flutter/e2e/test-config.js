export function normalizeApiUrl(raw) {
  return raw.replace(/\/+$/, '');
}

export function canReuseStoredData(storedApiUrl, targetApiUrl) {
  return (
    typeof storedApiUrl === 'string' &&
    normalizeApiUrl(storedApiUrl) === normalizeApiUrl(targetApiUrl)
  );
}
