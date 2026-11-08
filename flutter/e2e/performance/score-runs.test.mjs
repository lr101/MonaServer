import assert from 'node:assert/strict';
import { test } from 'node:test';
import { scoreRuns } from './score-runs.mjs';

const phases = Array.from({ length: 10 }, (_, round) =>
  ['Groups', 'Map', 'Profile', 'Feed'].map(destination => `${round + 1}:${destination}`),
).flat();

function gapsFor(windowMs, gapMs) {
  const fullSamples = Math.floor(windowMs / gapMs);
  const gaps = Array(fullSamples).fill(gapMs);
  const remainder = windowMs - fullSamples * gapMs;
  if (remainder > 1e-9) gaps.push(remainder);
  return gaps;
}

function artifact(gap, overrides = {}) {
  return {
    schemaVersion: 1,
    workloadId: 'navigation-feed',
    workloadVersion: 2,
    cpuThrottle: 4,
    rounds: 10,
    phaseWindowsMs: { navigation: 1000, feed: 2000 },
    viewport: { width: 450, height: 900 },
    browser: { name: 'chromium', version: '1.64.1' },
    hostFingerprint: 'host-a',
    fixtureFingerprint: 'fixture-a',
    build: { gitSha: 'abcdef0', mode: 'release', bundleSha256: 'a'.repeat(64) },
    results: phases.map(phase => ({
      phase,
      gapsMs: gapsFor(phase.endsWith(':Feed') ? 2000 : 1000, gap),
    })),
    ...overrides,
  };
}

function runs(gap, overrides) {
  return Array.from({ length: 5 }, () => artifact(gap, {
    ...overrides,
  }));
}

test('passes when five comparable candidate runs reduce median mean raw gap by 20%', () => {
  const result = scoreRuns(runs(50), runs(40));
  assert.equal(result.verdict, 'PASS');
  assert.ok(Math.abs(result.metric.rawGapReduction - 0.2) < 1e-12);
  assert.ok(result.metric.excessReduction > 0.2);
});

test('rejects missing or mixed release bundles within each arm', () => {
  const missing = runs(50);
  delete missing[0].build.bundleSha256;
  assert.throws(() => scoreRuns(missing, runs(40)), /bundleSha256/);
  const mixed = runs(40);
  mixed[2].build.bundleSha256 = 'b'.repeat(64);
  assert.throws(() => scoreRuns(runs(50), mixed), /bundleSha256 differs/);
  const distinct = runs(40);
  for (const run of distinct) run.build.bundleSha256 = 'b'.repeat(64);
  assert.equal(scoreRuns(runs(50), distinct).verdict, 'PASS');
});

test('fails when raw gap reduction is below 20 percent even if excess improves by over 20%', () => {
  const result = scoreRuns(runs(50), runs(1000 / 24));
  assert.equal(result.verdict, 'FAILURE');
  assert.ok(result.metric.excessReduction > 0.2);
  assert.match(result.reasons[0], /below 20%/);
});

test('rejects incomplete runs and invalid samples', () => {
  const incomplete = artifact(26.67, { results: artifact(26.67).results.slice(1) });
  assert.throws(() => scoreRuns([incomplete, ...runs(26.67).slice(1)], runs(24.67)), /exactly 40 phases/);
  const invalid = artifact(26.67);
  invalid.results[0].gapsMs = [NaN];
  assert.throws(() => scoreRuns([invalid, ...runs(26.67).slice(1)], runs(24.67)), /finite number/);
});

test('rejects clipped, overrun, and under-sampled phase recordings', () => {
  const clipped = artifact(50);
  clipped.results[0].gapsMs = Array(17).fill(50);
  assert.throws(() => scoreRuns([clipped, ...runs(50).slice(1)], runs(40)), /outside 1000/);
  const overrun = artifact(50);
  overrun.results[0].gapsMs = Array(23).fill(50);
  assert.throws(() => scoreRuns([overrun, ...runs(50).slice(1)], runs(40)), /outside 1000/);
  const underSampled = artifact(100);
  underSampled.results[0].gapsMs = Array(10).fill(100);
  assert.throws(() => scoreRuns([underSampled, ...runs(100).slice(1)], runs(40)), /at least 11 samples/);
});

test('rejects incompatible metadata and requires five runs in each arm', () => {
  const candidate = runs(24.67);
  candidate[0].fixtureFingerprint = 'other-fixture';
  assert.throws(() => scoreRuns(runs(26.67), candidate), /fixtureFingerprint differs/);
  assert.throws(() => scoreRuns(runs(26.67).slice(1), runs(24.67)), /exactly 5 runs/);
});
