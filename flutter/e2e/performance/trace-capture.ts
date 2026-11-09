import { writeFile } from 'node:fs/promises';
import type { CDPSession } from '@playwright/test';

// Diagnostic runs are excluded from scoring: profiling perturbs frame timings.
export async function startTrace(session: CDPSession) {
  await session.send('Tracing.start', {
    categories: 'toplevel,devtools.timeline,disabled-by-default-devtools.timeline,v8,disabled-by-default-v8.cpu_profiler,blink.user_timing',
    transferMode: 'ReturnAsStream',
  });
}

export async function finishTrace(session: CDPSession, path: string) {
  const complete = new Promise<{ stream: string }>(resolve =>
    session.once('Tracing.tracingComplete', resolve),
  );
  await session.send('Tracing.end');
  const { stream } = await complete;
  const chunks: Buffer[] = [];
  try {
    while (true) {
      const chunk = await session.send('IO.read', { handle: stream });
      chunks.push(Buffer.from(chunk.data, chunk.base64Encoded ? 'base64' : 'utf8'));
      if (chunk.eof) break;
    }
    // Timeline URLs may contain signed image URLs; keep the trace local/private.
    await writeFile(path, Buffer.concat(chunks), { mode: 0o600 });
  } finally {
    await session.send('IO.close', { handle: stream });
  }
}
