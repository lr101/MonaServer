import { readdir, readFile, stat } from 'node:fs/promises';
import { basename, extname, resolve } from 'node:path';

const TARGET_FRAME_MS = 16.67;
const REQUIRED_RUNS = 5;
const MINIMUM_SAMPLES_PER_PHASE = 11;
const WINDOW_TOLERANCE_MS = 100;
const PHASE_WINDOWS_MS = { navigation: 1000, feed: 2000 };
const DESTINATIONS = ['Groups', 'Map', 'Profile', 'Feed'];
const EXPECTED_PHASES = Array.from(
  { length: 10 },
  (_, round) => DESTINATIONS.map(destination => `${round + 1}:${destination}`),
).flat();
const METADATA_FIELDS = [
  'schemaVersion',
  'workloadId',
  'workloadVersion',
  'cpuThrottle',
  'rounds',
  'phaseWindowsMs',
  'viewport',
  'browser',
  'hostFingerprint',
  'fixtureFingerprint',
];

function fail(message) {
  throw new Error(message);
}

function finiteNumber(value, label) {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    fail(`${label} must be a finite number`);
  }
  return value;
}

function stableJson(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
}

function median(values) {
  const sorted = [...values].sort((left, right) => left - right);
  const middle = sorted.length / 2;
  return sorted.length % 2 ? sorted[Math.floor(middle)] : (sorted[middle - 1] + sorted[middle]) / 2;
}

function phaseMetric(gaps, label, expectedWindowMs) {
  if (!Array.isArray(gaps) || gaps.length === 0) fail(`${label}.gapsMs must contain samples`);
  const valid = gaps.map((gap, index) => {
    finiteNumber(gap, `${label}.gapsMs[${index}]`);
    if (gap < 0) fail(`${label}.gapsMs[${index}] must not be negative`);
    return gap;
  });
  if (valid.length < MINIMUM_SAMPLES_PER_PHASE) {
    fail(`${label}.gapsMs must contain at least ${MINIMUM_SAMPLES_PER_PHASE} samples`);
  }
  const actualSpanMs = valid.reduce((sum, gap) => sum + gap, 0);
  if (Math.abs(actualSpanMs - expectedWindowMs) > WINDOW_TOLERANCE_MS) {
    fail(`${label}.gapsMs span ${actualSpanMs} ms is outside ${expectedWindowMs} ± ${WINDOW_TOLERANCE_MS} ms`);
  }
  return {
    meanGapMs: valid.reduce((sum, gap) => sum + gap, 0) / valid.length,
    meanExcessMs: valid.reduce((sum, gap) => sum + Math.max(0, gap - TARGET_FRAME_MS), 0) / valid.length,
    worstGapMs: Math.max(...valid),
    stallsOver100Ms: valid.filter(gap => gap > 100).length,
    actualSpanMs,
  };
}

function validateRun(run, label) {
  if (!run || typeof run !== 'object' || Array.isArray(run)) fail(`${label} must be an object`);
  for (const field of METADATA_FIELDS) {
    if (run[field] === undefined) fail(`${label}.${field} is required`);
  }
  if (!run.build || typeof run.build !== 'object') fail(`${label}.build is required`);
  if (typeof run.build.gitSha !== 'string' || !run.build.gitSha) fail(`${label}.build.gitSha is required`);
  if (typeof run.build.bundleSha256 !== 'string' || !/^[a-f0-9]{64}$/.test(run.build.bundleSha256)) fail(`${label}.build.bundleSha256 must be a SHA-256 hash`);
  if (run.build.mode !== 'release') fail(`${label}.build.mode must be release`);
  if (!Number.isInteger(run.rounds) || run.rounds !== 10) fail(`${label}.rounds must be 10`);
  if (run.workloadVersion !== 2) fail(`${label}.workloadVersion must be 2`);
  if (run.workloadId !== 'navigation-feed') fail(`${label}.workloadId is invalid`);
  if (stableJson(run.phaseWindowsMs) !== stableJson(PHASE_WINDOWS_MS)) {
    fail(`${label}.phaseWindowsMs must equal ${JSON.stringify(PHASE_WINDOWS_MS)}`);
  }
  if (!Array.isArray(run.results) || run.results.length !== EXPECTED_PHASES.length) {
    fail(`${label}.results must contain exactly ${EXPECTED_PHASES.length} phases`);
  }
  const phases = new Map();
  for (const result of run.results) {
    if (!result || typeof result.phase !== 'string') fail(`${label}.results contains an invalid phase`);
    if (phases.has(result.phase)) fail(`${label}.results duplicates phase ${result.phase}`);
    const destination = result.phase.split(':')[1];
    const expectedWindowMs = destination === 'Feed'
        ? PHASE_WINDOWS_MS.feed
        : PHASE_WINDOWS_MS.navigation;
    phases.set(result.phase, phaseMetric(result.gapsMs, `${label}.${result.phase}`, expectedWindowMs));
  }
  for (const phase of EXPECTED_PHASES) {
    if (!phases.has(phase)) fail(`${label}.results is missing phase ${phase}`);
  }
  const values = [...phases.values()];
  return {
    metadata: Object.fromEntries(METADATA_FIELDS.map(field => [field, run[field]])),
    build: run.build,
    meanGapMs: values.reduce((sum, value) => sum + value.meanGapMs, 0) / values.length,
    meanExcessMs: values.reduce((sum, value) => sum + value.meanExcessMs, 0) / values.length,
    worstGapMs: Math.max(...values.map(value => value.worstGapMs)),
    stallsOver100Ms: values.reduce((sum, value) => sum + value.stallsOver100Ms, 0),
  };
}

function assertComparable(baseline, candidate) {
  const reference = baseline[0].metadata;
  for (const [arm, runs] of Object.entries({ baseline, candidate })) {
    for (const [index, run] of runs.entries()) {
      if (run.build.bundleSha256 !== runs[0].build.bundleSha256) {
        fail(`${arm}[${index}] build.bundleSha256 differs from ${arm}[0]`);
      }
      for (const field of METADATA_FIELDS) {
        if (stableJson(run.metadata[field]) !== stableJson(reference[field])) {
          fail(`${arm}[${index}] metadata ${field} differs from baseline[0]`);
        }
      }
    }
  }
}

function armMetrics(runs) {
  return {
    runMeanGapMs: runs.map(run => run.meanGapMs),
    runMeanExcessMs: runs.map(run => run.meanExcessMs),
    runWorstGapMs: runs.map(run => run.worstGapMs),
    runStallsOver100Ms: runs.map(run => run.stallsOver100Ms),
    medianMeanGapMs: median(runs.map(run => run.meanGapMs)),
    medianMeanExcessMs: median(runs.map(run => run.meanExcessMs)),
    medianWorstGapMs: median(runs.map(run => run.worstGapMs)),
    medianStallsOver100Ms: median(runs.map(run => run.stallsOver100Ms)),
  };
}

export function scoreRuns(baselineArtifacts, candidateArtifacts) {
  if (!Array.isArray(baselineArtifacts) || baselineArtifacts.length !== REQUIRED_RUNS) {
    fail(`baseline must contain exactly ${REQUIRED_RUNS} runs`);
  }
  if (!Array.isArray(candidateArtifacts) || candidateArtifacts.length !== REQUIRED_RUNS) {
    fail(`candidate must contain exactly ${REQUIRED_RUNS} runs`);
  }
  const baseline = baselineArtifacts.map((run, index) => validateRun(run, `baseline[${index}]`));
  const candidate = candidateArtifacts.map((run, index) => validateRun(run, `candidate[${index}]`));
  assertComparable(baseline, candidate);
  const baselineMetrics = armMetrics(baseline);
  const candidateMetrics = armMetrics(candidate);
  if (baselineMetrics.medianMeanGapMs <= 0) fail('baseline median mean frame gap must be greater than zero');
  const rawGapReduction = 1 - candidateMetrics.medianMeanGapMs / baselineMetrics.medianMeanGapMs;
  const excessReduction = baselineMetrics.medianMeanExcessMs <= 0
    ? null
    : 1 - candidateMetrics.medianMeanExcessMs / baselineMetrics.medianMeanExcessMs;
  const reasons = [];
  if (rawGapReduction < 0.2 - 1e-12) reasons.push(`mean frame gap reduction ${(rawGapReduction * 100).toFixed(2)}% is below 20%`);
  if (candidateMetrics.medianWorstGapMs > baselineMetrics.medianWorstGapMs) reasons.push('median worst gap worsened');
  if (candidateMetrics.medianStallsOver100Ms > baselineMetrics.medianStallsOver100Ms) reasons.push('median >100 ms stall count worsened');
  return {
    verdict: reasons.length === 0 ? 'PASS' : 'FAILURE',
    reasons,
    metric: {
      name: 'mean_frame_gap_ms',
      targetFrameMs: TARGET_FRAME_MS,
      aggregation: 'mean raw frame gap with equal-weight phases within each run; median of five independent runs per arm',
      requiredReduction: 0.2,
      rawGapReduction,
      excessReduction,
    },
    baseline: baselineMetrics,
    candidate: candidateMetrics,
    protocol: baseline[0].metadata,
    builds: { baseline: baseline.map(run => run.build), candidate: candidate.map(run => run.build) },
  };
}

async function discoverArtifacts(input) {
  const inputPath = resolve(input);
  const inputStat = await stat(inputPath);
  if (inputStat.isFile()) {
    if (extname(inputPath) !== '.json') fail(`${input} must be a JSON file or directory`);
    return [inputPath];
  }
  const found = [];
  async function visit(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      const path = resolve(directory, entry.name);
      if (entry.isDirectory()) await visit(path);
      else if (entry.isFile() && /^ui-frame-gaps.*\.json$/i.test(basename(path))) found.push(path);
    }
  }
  await visit(inputPath);
  return found.sort();
}

export async function loadArtifacts(input) {
  const paths = await discoverArtifacts(input);
  if (!paths.length) fail(`No ui-frame-gaps JSON artifacts found below ${input}`);
  return Promise.all(paths.map(async path => JSON.parse(await readFile(path, 'utf8'))));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [, , baselineInput, candidateInput] = process.argv;
  if (!baselineInput || !candidateInput || process.argv.length !== 4) {
    fail('Usage: node performance/score-runs.mjs <baseline-artifact-root> <candidate-artifact-root>');
  }
  const result = scoreRuns(await loadArtifacts(baselineInput), await loadArtifacts(candidateInput));
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}
