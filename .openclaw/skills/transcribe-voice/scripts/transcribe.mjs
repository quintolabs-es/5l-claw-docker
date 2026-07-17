#!/usr/bin/env node
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import ffmpegPath from 'ffmpeg-static';
import wavefile from 'wavefile';

const { WaveFile } = wavefile;

process.env.ORT_LOG_SEVERITY_LEVEL ??= '3';
process.env.ORT_LOG_VERBOSITY_LEVEL ??= '0';

const input = process.argv[2];
const model = process.argv[3] || 'Xenova/whisper-tiny';

if (!input) {
  console.error('Usage: transcribe.mjs <audio-file> [model]');
  process.exit(2);
}

const workDir = mkdtempSync(path.join(tmpdir(), 'transcribe-voice-'));
const wavPath = path.join(workDir, 'audio.wav');

try {
  const ffmpeg = spawnSync(
    ffmpegPath,
    ['-y', '-i', input, '-ac', '1', '-ar', '16000', wavPath],
    { encoding: 'utf8' },
  );

  if (ffmpeg.status !== 0) {
    console.error(ffmpeg.stderr || ffmpeg.stdout);
    process.exit(ffmpeg.status || 1);
  }

  const wav = new WaveFile(readFileSync(wavPath));
  wav.toBitDepth('32f');
  const samples = wav.getSamples(false, Float32Array);
  const audio = Array.isArray(samples) ? samples[0] : samples;
  const { pipeline } = await import('@xenova/transformers');
  const transcriber = await pipeline('automatic-speech-recognition', model);
  const result = await transcriber(audio, {
    language: 'spanish',
    task: 'transcribe',
  });

  const text = typeof result === 'string' ? result : result?.text;
  if (!text) {
    console.error(JSON.stringify(result, null, 2));
    process.exit(1);
  }

  console.log(text.trim());
} finally {
  rmSync(workDir, { recursive: true, force: true });
}
