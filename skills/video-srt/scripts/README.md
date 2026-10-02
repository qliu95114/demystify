# video-srt scripts

Convert a video or folder of videos into same-named SRT subtitles using local CPU
speech recognition, with opt-in Intel NPU, Intel GPU, and AMD GPU support for SenseVoice. The workflow checks prerequisites, extracts M4A audio, runs
SenseVoice or multilingual Whisper with voice activity and music detection, and writes subtitles aligned
to the original video's playback timeline.

No cloud upload, API key, GPU, or repeated LLM calls are required. Original videos
are not modified.

## Quick start

Open PowerShell and enter this directory:

```powershell
Set-Location 'D:\source_git\demystify\skills\video-srt\scripts'
```

Generate subtitles for one video, allowing installation of missing prerequisites:

```powershell
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\episode.mkv' `
  -Language zh `
  -InstallMissing
```

Replace the example input path with your video. Quote paths containing spaces,
brackets, or non-English characters. PowerShell line-continuation backticks must
be the last character on their line.

If PowerShell 7 (`pwsh`) is unavailable, replace `pwsh` with `powershell.exe`.
Windows PowerShell 5.1 is supported.

Default results are saved to:

```text
D:\source_git\demystify\skills\video-srt\.runtime\output
```

This location is relative to the skill directory, not the current terminal
directory. Results are not placed beside the original video unless you explicitly
select that output directory.

## Prerequisites

| Requirement | Details |
|---|---|
| Operating system | Windows x64 |
| PowerShell | 5.1 or 7; 7 preferred |
| Python | CPython 3.11-3.14 x64 |
| Media tools | FFmpeg and FFprobe |
| Python packages | Installed in the skill's isolated environment |
| Models | Selected SenseVoice or Whisper small int8, Silero VAD, and optional Zipformer music/speech detector |

With `-InstallMissing`, setup installs only missing/incompatible requirements.
Missing system tools are installed through `winget` using `Python.Python.3.12`
and `Gyan.FFmpeg`. If `winget` is unavailable or installation is blocked, setup
stops and explains what to install manually.

Python packages, models, and default output are stored under the skill's ignored
`.runtime` directory. Model files are SHA-256 checked before use. Network access
is needed for initial downloads, but prepared local runs work offline.

To prepare the environment without processing a video:

```powershell
pwsh -NoProfile -File .\Setup-VideoSrt.ps1 -InstallMissing
```

To check an already prepared environment without permitting installation:

```powershell
pwsh -NoProfile -File .\Setup-VideoSrt.ps1
```

## Common examples

### Choose an output folder

```powershell
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\episode.mkv' `
  -OutputDirectory 'D:\Subtitles' `
  -Language zh
```

### Process a folder

```powershell
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\Series' `
  -OutputDirectory 'D:\Subtitles\Series' `
  -Language zh
```

Add `-Recurse` to include subdirectories. Their relative folder structure is
preserved in the output:

```powershell
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\Series' `
  -OutputDirectory 'D:\Subtitles\Series' `
  -Recurse -Language zh -Threads 2
```

Supported video extensions: `.mkv`, `.mp4`, `.mov`, `.avi`, `.webm`, `.m4v`,
`.ts`, `.m2ts`, `.wmv`, `.flv`, `.mpeg`, and `.mpg`. The entry point accepts videos,
not standalone M4A input.

### Select a language or audio track

```powershell
# English speech.
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\lecture.mp4' -Language en

# Second audio track, such as an alternate-language dub.
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\movie.mkv' -AudioStream 1 -Language zh
```

Languages: `auto`, `zh` (Mandarin), `en` (English), `ja` (Japanese), `ko` (Korean),
`yue` (Cantonese), `fr` (French), `de` (German), `es` (Spanish), `pt` (Portuguese),
and `it` (Italian). Specifying the known language is preferable to guessing.
Audio stream indexes start at zero and count only audio tracks.

### French, German, Spanish, Portuguese, and Italian

These five language codes automatically select local **multilingual Whisper
small INT8**, not the English-only `.en` model:

```powershell
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\french.mkv' -Language fr -InstallMissing
```

Replace `fr` with `de`, `es`, `pt`, or `it` as needed. First setup may download
the approximately 639 MB Whisper archive; subsequent runs use its cached models.
Whisper generally runs more slowly than SenseVoice on CPU.

**Automatic language identification is model-specific.** To preserve existing
behavior, `-Language auto` alone still uses SenseVoiceSmall (its five languages).
For broad automatic identification, select Whisper explicitly:

```powershell
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\unknown.mkv' -Backend whisper -Language auto -InstallMissing
```

SenseVoiceSmall's five-language scope is documented by the
[official SenseVoice README](https://github.com/FunAudioLLM/SenseVoice#introduction).
The broader project's "50+ languages" claim is not the scope of this released
checkpoint. Whisper's [official language table](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py#L10-L26)
lists all five added languages. See [full model evidence and routing](../references/languages.md).

Use SenseVoice for explicit Cantonese: the original Whisper small export lacks
the later `yue` token. Unsupported backend/language combinations fail explicitly.
Whisper transcribes in the spoken language; it does not translate to English.

### Allow conversion when audio cannot be copied into M4A

AAC and ALAC are stream-copied without re-encoding. For other codecs, such as
AC-3, PCM, or Opus, the script stops unless you explicitly permit AAC conversion:

```powershell
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\movie.mkv' `
  -Language zh -AllowAacEncode
```

This permits lossy AAC encoding at 192 kbps for the extracted audio. It does not
re-encode or change the original video.

### Intel NPU (optional SenseVoice acceleration)

```powershell
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\episode.mkv' -Language zh -Device npu `
  -OutputDirectory 'D:\Benchmarks\npu-cold' -InstallMissing
```

Requires an Intel NPU visible to OpenVINO and a compatible installed driver.
Setup installs only the applicable pinned accelerator requirements when authorized.
The SenseVoice network runs through OpenVINO directly; audio features, CTC
decoding, VAD and music detection remain on CPU. There is **no silent CPU
fallback**, and Whisper NPU or other vendors' NPUs are not supported.
CPU remains the default and does not require OpenVINO.

The adapter uses the same verified ONNX weights with static frame buckets and
real-length padding masks; it does not rewrite the source model or truncate
speech. NPU arithmetic can produce different recognition from CPU.
First model compilation can take minutes. Compiled models are reused from
`<RuntimeDir>\openvino-cache`; use a **new output directory** for a warm
inference benchmark, not cached subtitles/checkpoints. Keep audio track, models,
language, threads and music settings identical for comparisons. NPU is not
guaranteed faster. See [benchmarking details](../references/usage.md#accelerator-behavior-and-benchmarking).

Intel and AMD GPU targets use the same command shape:

```powershell
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\episode.mkv' -Language zh -Device intel-gpu -InstallMissing

pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\episode.mkv' -Language zh -Device amd-gpu -InstallMissing
```

Intel GPU uses OpenVINO with FP32 inference. AMD GPU uses DirectML and is
auto-selected from DXGI adapter order; use `-GpuDeviceId` to override the index.
Both paths verify the execution target and fail instead of silently assigning
SenseVoice model nodes to CPU. Supporting VAD/music stages remain on CPU.

### Reuse downloaded models

```powershell
pwsh -NoProfile -File .\Setup-VideoSrt.ps1 `
  -InstallMissing -ModelSourceDir 'D:\Models'
```

The model source must contain the expected model files and subdirectories listed
in `models.json`. Only files matching the pinned hashes are imported.

### Run from any directory

```powershell
pwsh -NoProfile -File 'D:\source_git\demystify\skills\video-srt\scripts\Invoke-VideoSrt.ps1' `
  -InputPath 'D:\Videos\episode.mkv' -Language zh
```

## Parameters

| Parameter | Default | Purpose |
|---|---|---|
| `-InputPath` | Required | Video file or folder; literal path, not a wildcard |
| `-OutputDirectory` | `<RuntimeDir>\output` | Destination for generated files |
| `-Language` | `auto` | `auto`, `zh`, `en`, `ja`, `ko`, `yue`, `fr`, `de`, `es`, `pt`, or `it` |
| `-Backend` | `auto` | `auto`, `sensevoice`, or `whisper`; `auto` routes the five added codes to Whisper and retains SenseVoice otherwise |
| `-Device` | `cpu` | `cpu`, `npu`, `intel-gpu`, or `amd-gpu`; accelerator targets are SenseVoice-only |
| `-GpuDeviceId` | `-1` | Auto-select the matching GPU, or explicitly choose its OpenVINO/DirectML index |
| `-AudioStream` | `0` | Zero-based audio track index, range 0-100 |
| `-Threads` | `4` | CPU inference threads, range 1-32 |
| `-ChunkSeconds` | `300` | Processing chunk duration, range 30-1800 seconds |
| `-Recurse` | Off | Include nested folders |
| `-InstallMissing` | Off | Permit prerequisite installation and model downloads |
| `-AllowAacEncode` | Off | Permit lossy AAC conversion for non-AAC/ALAC audio |
| `-SkipMusic` | Off | Skip music detection and detector-guided missed-speech recovery |
| `-Force` | Off | Permit replacing verified generated artifacts when inputs/settings change |
| `-PythonPath` | Auto-detected | Compatible Python executable used to create the environment |
| `-ModelSourceDir` | None | Existing model cache to import |
| `-RuntimeDir` | `<skill directory>\.runtime` | Isolated environment and model storage |

`Setup-VideoSrt.ps1` accepts `-InstallMissing`, `-PythonPath`, `-ModelSourceDir`,
`-RuntimeDir`, `-SkipMusic`, `-Backend`, `-Language`, `-Device`, and `-GpuDeviceId`.

## Output files

For `episode.mkv`, the output folder contains:

| File | Contents |
|---|---|
| `episode.m4a` | Extracted audio |
| `episode.srt` | UTF-8 subtitles aligned to the video timeline |
| `episode.asr.json` | Raw recognition text, token timestamps, events, and timing metadata |
| `episode.music.json` | Music/speech detection windows; omitted with `-SkipMusic` |
| `episode.manifest.json` | Completion status, configuration, source signature, and output hashes |
| `.video-srt\...` | Ownership records, progress, and resumable chunk checkpoints |

The raw JSON retains evidence that may not appear in SRT, including empty or
punctuation-only recognition. SRT cues are made readable and nonoverlapping;
their boundaries are estimates, not manually verified word alignments.
Whisper does not provide SenseVoice emotion/event tags; those values are `null`.
Its token timestamp list can be empty with the current export configuration.
Separate music detection remains available with either ASR backend.
Manifests also include invocation `performance` measurements and actual
`execution` device details; cached chunks are counted separately. NPU model
compilation/inference counters are cumulative per loaded model, including across
files in folder runs. They are not wall-clock measurements for every file.

A genuinely silent file can produce an empty SRT with an explicit `no_speech`
status and warning. Do not interpret that as a verified speech transcript.

## Resume and existing files

After interruption, confirm the old process has stopped and rerun the same command.
Matching completed outputs and chunk checkpoints are reused automatically.

Changed source content, models, engine, or settings invalidate previous results.
Use a fresh output folder, or add `-Force` to permit replacement of artifacts
whose ownership and hashes still match. `-Force` does not erase unrelated or
manually edited subtitles, and it does not force recomputation of identical
verified results.

Two inputs such as `episode.mp4` and `episode.mkv` cannot share the same output
basename in one destination. Such collisions are rejected. Use separate
directories or separate invocations with distinct output directories.

Do not delete `.video-srt` while expecting automatic resume or owned-file
replacement to work.

## Limitations and troubleshooting

| Situation | Action |
|---|---|
| Missing Python, FFmpeg, packages, or models | Rerun with `-InstallMissing`; if system installation is blocked, install the missing tool manually and reopen PowerShell |
| Unsupported audio codec | Authorize `-AllowAacEncode`, or stop if lossless extraction is required |
| Wrong voice/language | Inspect tracks with `ffprobe -v error -show_streams 'D:\Videos\movie.mkv'`, then set `-AudioStream` and `-Language` |
| Existing output conflict | Choose a fresh output folder; do not overwrite another subtitle file |
| Another process holds the output lock | Wait for that process or stop the specific run before retrying |
| Empty SRT | Inspect the manifest status and source audio; silence or missed speech is possible |
| High CPU usage | Reduce `-Threads`; processing time varies by hardware and content |
| Timing or transcription errors | Inspect the ASR JSON and review the SRT against the video |

Music may coexist with dialogue. Detection uses coarse five-second windows, not
exact edit points. Short utterances, chants, names, lyrics, noise, and overlapping
voices may be misrecognized. Long recognition segments use estimated time splits.

These scripts do **not** remove advertisements, previews, or songs, and do not
cut audio/video or translate speech. They generate transcription and acoustic
evidence without semantic LLM review.

## Script files and further reference

- `Invoke-VideoSrt.ps1`: recommended entry point.
- `Setup-VideoSrt.ps1`: environment preparation only.
- `transcribe.py`: local media/inference engine, normally invoked by PowerShell.
- `setup_models.py`, `models.json`, `requirements.txt`: runtime/model setup.
- `asr_backends.py`: shared language routing and backend validation.
- `accelerated_sensevoice.py`: explicit Intel NPU/GPU and AMD GPU inference.
- `requirements-accelerator-base.txt`, `requirements-openvino.txt`, `requirements-directml.txt`: optional pinned accelerator dependencies.

Additional implementation and model details are in
[the usage reference](../references/usage.md).
