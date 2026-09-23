---
name: video-srt
description: Generate same-named SRT subtitles from videos using local CPU SenseVoice or multilingual Whisper. Supports Chinese, Cantonese, English, Japanese, Korean, French, German, Spanish, Portuguese and Italian. Checks and optionally installs Windows prerequisites, extracts M4A, and uses VAD/music detection without cloud uploads or repeated LLM calls. Use for video to SRT, local ASR, batch subtitles, 视频转字幕, or 语音转文字.
---

# Video SRT

Use the included scripts, not an LLM transcription loop. They extract audio without
changing the original video and run local models to create subtitles.

## Workflow

1. Resolve the input file/folder and output location. Default output is
   `.runtime\output` inside this skill, **not alongside the source video**.
   Pick the spoken language when known; use `auto` otherwise. Supported:
   Mandarin (`zh`), English (`en`), Japanese (`ja`), Korean (`ko`), Cantonese (`yue`),
   French (`fr`), German (`de`), Spanish (`es`), Portuguese (`pt`), Italian (`it`).
   `-Backend auto` routes the added five languages to Whisper small and the original
   five to SenseVoiceSmall. For broad automatic identification use
   **`-Backend whisper -Language auto`**; `-Language auto` alone retains the
   five-language SenseVoice default. See [model evidence](references/languages.md).
2. Run `scripts\Invoke-VideoSrt.ps1` with `-NoProfile`. Prefer `pwsh`; Windows
   PowerShell 5.1 is also supported. Use `-InstallMissing` when the user authorizes
   installation. Setup checks Python, FFmpeg/FFprobe, the isolated environment,
   packages and model hashes, installing only missing/incompatible requirements.
3. Let the script run through all files. Do not ask an LLM to process each chunk.
   It extracts M4A, runs CPU SenseVoice or Whisper + Silero VAD, detects music/speech with
   Zipformer, recovers likely missed vocal regions, and writes video-aligned SRT.
4. For a long batch, run one persistent process and retain its log. Do not run
   concurrent copies against the same output files. Rerun the same command after
   interruption to reuse matching checkpoints; never claim completion just
   because a background process started.
5. Check the exit code, per-file manifests, nonempty SRT for speech-containing
   videos, and reported `no_speech`/warnings. Summarize actual outputs and any
   uncertain timing. Never claim the recognized words are manually verified.

## Run

From the skill directory:

```powershell
pwsh -NoProfile -File .\scripts\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\episode.mkv' -Language zh -InstallMissing
```

Folder, preserving subdirectories:

```powershell
pwsh -NoProfile -File .\scripts\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\Series' -Recurse -Language zh -InstallMissing
```

French (automatically uses Whisper):

```powershell
pwsh -NoProfile -File .\scripts\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\french.mkv' -Language fr -InstallMissing
```

An existing model cache can be imported with `-ModelSourceDir 'D:\Models'`.
Files are checked against pinned hashes before reuse. Once setup succeeds, omit
`-InstallMissing`; cached inference runs without network access.

## Required behavior

- Preserve the original media and existing subtitles. Generated artifacts go to
  the output directory, with the source basename. Never overwrite unrelated files.
- AAC/ALAC audio is stream-copied into M4A. Other codecs **cannot** simply be
  renamed to M4A. Stop and explain, or use `-AllowAacEncode` only when lossy AAC
  conversion is authorized. Video is never re-encoded.
- Default is audio stream `0` (first audio track); `-AudioStream 1` selects the
  second. Do not mix commentary, dubbing, or alternate-language tracks.
- SRT timestamps target the original video's playback timeline, retaining
  silence and gaps. Never concatenate VAD speech to invent a new timeline.
- Music detection is a coarse five-second model estimate, **not** proof that
  speech is absent. Background score can overlap dialogue. Keep ads, previews,
  narration and lyrics when recognized; do not silently remove them.
- No ad classification, cutting, translation, speaker identification or semantic
  editing is performed. Those are separate requests, not prerequisites for SRT.
- Raw ASR/event/token evidence and optional music scores are retained separately.
  Empty/punctuation-only recognition is not rendered as a subtitle cue.
  Whisper does not supply SenseVoice emotion/event tags or token timing in this
  configuration; keep unavailable values explicit, never fabricate them.
- A silent/no-speech file must be explicitly reported, not disguised as a
  successful transcript. Model errors and unsupported inputs must surface.
- No media is uploaded. Network access during setup is limited to software
  installation and public model downloads; no API key or paid LLM is needed.

See [reference](references/usage.md) for parameters, outputs, installation,
troubleshooting and validation commands.
