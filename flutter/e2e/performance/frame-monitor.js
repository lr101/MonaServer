// Serialized by Playwright: keep this function free of module dependencies.
export function startFrameMonitor() {
  const gaps = [];
  let previous;
  let handle;
  const tick = timestamp => {
    if (previous !== undefined) gaps.push(timestamp - previous);
    previous = timestamp;
    handle = requestAnimationFrame(tick);
  };
  handle = requestAnimationFrame(tick);
  window.__frameMonitor = {
    stop() {
      cancelAnimationFrame(handle);
      return gaps;
    },
  };
}

export function summarizeFrames(gaps) {
  if (!gaps.length) throw new Error('No frame samples recorded');
  const sorted = [...gaps].sort((a, b) => a - b);
  return {
    samples: gaps.length,
    durationMs: gaps.reduce((a, b) => a + b, 0),
    p95Ms: sorted[Math.ceil(sorted.length * 0.95) - 1],
    maxMs: sorted[sorted.length - 1],
    framesOver34Ms: gaps.filter(ms => ms > 34).length,
    stallsOver100Ms: gaps.filter(ms => ms > 100).length,
  };
}
