---
name: transcribe-voice
description: "Transcribe incoming voice messages or audio files to text with local tooling."
---

# Transcribe Voice

Use when Luis sends a voice message or asks to transcribe an audio file.

## Workflow

1. Locate the local audio file. In Telegram/OpenClaw messages, media usually lands under `/home/node/.openclaw/media/inbound/`.
2. If `scripts/node_modules` is missing, install the local tooling from the skill package:

```bash
npm install --prefix /home/node/.openclaw/skills/transcribe-voice/scripts
```

3. Run the bundled script:

```bash
node /home/node/.openclaw/skills/transcribe-voice/scripts/transcribe.mjs /path/to/audio.ogg 2>/dev/null
```

4. Return the transcript clearly. If the user intends the audio as a note, process the transcript with the note creation workflow.

## Tooling

Keep the local tooling installed because voice transcription is a recurring workflow.

## Notes

- Default model: `Xenova/whisper-tiny`.
- Optional second argument overrides the model, for example `Xenova/whisper-small`.
- The first run downloads model files into the Transformers cache and may take longer.
- The script converts input audio to 16 kHz mono WAV through `ffmpeg-static` before transcription.
- ONNX Runtime may emit warnings to stderr; redirect stderr when the caller only needs the transcript text.
