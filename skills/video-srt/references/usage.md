# video-srt reference

## Components

| File | Purpose |
|---|---|
| `scripts\Invoke-VideoSrt.ps1` | One-command entry point; preflight and worker invocation |
| `scripts\Setup-VideoSrt.ps1` | Check/install tools, create isolated environment, prepare models |
| `scripts\setup_models.py` | Verify runtime/model hashes; import cache or download models safely |
| `scripts\asr_backends.py` | Shared backend/language routing and validation |
| `scripts\models.json` | Public model release URLs and pinned SHA-256 file hashes |
| `scripts\requirements.txt` | Local CPU Python dependencies |
| `scripts\transcribe.py` | Media extraction, chunked ASR, music scores, checkpoints and SRT |
| `tests` | Python standard-library unit tests; no test package installation |

All skill code stays here. By default, the virtual environment, model cache,
checkpoints and output files stay under the skill's ignored `.runtime` directory.
Do not commit models, private transcripts, source media or the virtual environment.
`-RuntimeDir` and `-OutputDirectory` explicitly override those locations.

## Requirements and installation

Windows x64; PowerShell 5.1 or 7; CPython 3.11-3.14 x64; FFmpeg and FFprobe.
Both ASR backends run on CPU, so CUDA, PyTorch and a GPU are not required. Allow several
GB of RAM and disk for dependencies, models, audio and intermediate results.

```powershell
# Install only missing tools/packages/models; no media processing yet.
pwsh -NoProfile -File .\scripts\Setup-VideoSrt.ps1 -InstallMissing

# Reuse an already downloaded model directory instead of downloading again.
pwsh -NoProfile -File .\scripts\Setup-VideoSrt.ps1 `
  -InstallMissing -ModelSourceDir 'D:\Models'

# Check readiness using local files only.
pwsh -NoProfile -File .\scripts\Setup-VideoSrt.ps1
```

If Python or FFmpeg is missing and installation was authorized, setup uses
`winget` with exact package IDs `Python.Python.3.12` and `Gyan.FFmpeg`, user scope.
It does not upgrade working system installations. If `winget`/App Installer is
unavailable or policy blocks it, the script stops with an actionable message:
install the missing tool manually, reopen PowerShell and rerun. No silent fallback
to a cloud service or executable downloaded from an arbitrary mirror.

Python packages are installed only inside `.runtime\venv`. Model downloads use the
official `k2-fsa/sherpa-onnx` release assets. Required extracted model files are
SHA-256 checked against `models.json`; archive links and unrequested paths are
never extracted. These hashes pin the model bytes used by this skill, not an
upstream signature or guarantee of model accuracy. Review model licenses at their
upstream sources before redistribution.

The model set is the selected ASR backend (SenseVoice int8 or multilingual Whisper
small int8), Silero VAD, and Zipformer-small AudioSet int8. Whisper's official
archive is about 639 MB; it is only needed for that backend. Archives may also
contain unused float32 weights; only required int8 files and labels are installed. Successful cached runs
do not need the network.

## Invocation parameters

| Parameter | Default | Meaning |
|---|---|---|
| `-InputPath` | Required | Literal path to a video or directory; quote spaces, brackets and Unicode |
| `-OutputDirectory` | `.runtime\output` | M4A/SRT/JSON destination, separate from original media |
| `-Language` | `auto` | `auto`, `zh`, `en`, `ja`, `ko`, `yue`, `fr`, `de`, `es`, `pt`, `it` |
| `-Backend` | `auto` | Routes `fr/de/es/pt/it` to Whisper, others including `auto` to SenseVoice; can explicitly select `sensevoice` or `whisper` |
| `-AudioStream` | `0` | Zero-based index among audio streams, not absolute stream index |
| `-Threads` | `4` | CPU inference threads; lower on a shared/busy machine |
| `-ChunkSeconds` | `300` | Decode in bounded chunks, with boundary handling/checkpoints |
| `-Recurse` | Off | Include nested directories and preserve relative paths |
| `-InstallMissing` | Off | Permit installation of missing prerequisites/model downloads |
| `-ModelSourceDir` | None | Copy verified required files from an existing cache |
| `-PythonPath` | Auto-detected | Explicit compatible interpreter used for environment creation |
| `-RuntimeDir` | `.runtime` | Environment and model cache directory |
| `-AllowAacEncode` | Off | Explicitly permit conversion of unsupported source audio to AAC |
| `-SkipMusic` | Off | Skip the extra music/speech detector and detector-guided gap recovery |
| `-Force` | Off | Permit replacing owned artifacts when input/settings change; not arbitrary overwrite |

Examples:

```powershell
# English video; first run installs prerequisites if necessary.
pwsh -NoProfile -File .\scripts\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\Lecture [1].mp4' -Language en -InstallMissing

# Second audio track; permit AAC conversion if the source is AC-3, Opus, etc.
pwsh -NoProfile -File .\scripts\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\movie.mkv' -AudioStream 1 -Language zh -AllowAacEncode

# Lower CPU usage, custom destination, recursive batch.
pwsh -NoProfile -File .\scripts\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\Series' -OutputDirectory 'D:\Subtitles' `
  -Recurse -Threads 2 -Language zh
```

For French, German, Spanish, Portuguese and Italian, use `-Language fr`, `de`,
`es`, `pt`, or `it`; the default backend selector chooses Whisper automatically.
To prepare only that backend, run `Setup-VideoSrt.ps1 -Backend whisper -InstallMissing`.
For unknown-language audio that may include these languages, explicitly use
`-Backend whisper -Language auto`. **`-Language auto` alone still uses SenseVoice's
five-language detector**, preserving previous behavior.

Whisper is generally slower on CPU and lacks SenseVoice emotion/event tags.
Its current export configuration uses VAD timing, not token-level alignment.
See [language support and official sources](languages.md) for the documented model
scope, the five-language checkpoint versus 50-language research distinction, and
the Cantonese exception.

## Output and repeat runs

Each video produces `samename.m4a`, `samename.srt`, `samename.asr.json`,
`samename.manifest.json`, and (unless skipped) `samename.music.json`.
Intermediate files/checkpoints are under the output directory's `.video-srt`
folder. A manifest is the completion record; a partially written M4A or checkpoint
is not proof of success.

Run the same command again to reuse matching completed results/checkpoints.
Changed input, settings or models must not reuse stale transcription. Duplicate
source basenames mapping to the same destination are rejected rather than silently
overwritten. Recursive batches preserve relative directories.

M4A is an extracted audio artifact; SRT uses **video playback time**, not
concatenated speech time. Track delay and container timestamp origins matter.
Inspect the recorded timing mapping if synchronization looks wrong.

## Accuracy and scope

- Timestamped ASR is not manual transcription or forced alignment. Names,
  accents, chants, overlapping voices, song lyrics and noisy speech can be wrong.
  Long ASR segments are divided into readable cues with estimated time splits;
  original token timestamps remain available in the JSON evidence.
- Voice activity detection can miss short or stylized speech. Default acoustic
  gap recovery helps but cannot prove that all words were captured.
- Music/speech probabilities can both be high. Five-second music windows are
  coarse evidence, not exact edit points. Do not remove every music-tagged span.
- Ads and previews are transcribed like other speech; this skill deliberately
  does not call an LLM for semantic classification or edit the program.
- First test a short representative video before a large batch. Processing speed
  depends on hardware and content, so do not promise a fixed completion time.
- Silence can legitimately yield zero cues; inspect the explicit no-speech status
  rather than treating an empty SRT as verified speech recognition.

## Validation and troubleshooting

```powershell
python -m unittest discover -s .\tests -p 'test_*.py' -v
```

- **Missing runtime/model:** run setup with `-InstallMissing`, or import a verified
  cache. A broken native import is an error, not an excuse to write empty subtitles.
- **Unsupported M4A codec:** use `-AllowAacEncode` only if lossy conversion is
  acceptable; otherwise stop and preserve the input.
- **No audio/invalid track:** inspect `ffprobe -v error -show_streams 'video.mkv'`
  and choose a valid zero-based audio index.
- **Output conflict:** choose a fresh output directory. Do not delete existing
  subtitles automatically or use `-Force` to erase unrelated files.
- **Interrupted run:** confirm the old process has ended before rerunning. Read
  lock/error guidance; never terminate processes by executable name.
- **Long batch:** use a persistent process, inspect progress/logs and wait for
  actual completion. No repeated agent turns are needed to perform inference.

## Upstream references

- [SenseVoice Python example](https://github.com/k2-fsa/sherpa-onnx/blob/master/python-api-examples/offline-sense-voice-ctc-decode-files.py)
- [Silero VAD example](https://github.com/k2-fsa/sherpa-onnx/blob/master/python-api-examples/vad-remove-non-speech-segments-from-file.py)
- [Audio tagging example](https://github.com/k2-fsa/sherpa-onnx/blob/master/python-api-examples/audio-tagging-from-a-file.py)
- [FFmpeg documentation](https://ffmpeg.org/ffmpeg.html)
- [SenseVoice checkpoint scope](https://github.com/FunAudioLLM/SenseVoice#introduction)
- [Whisper language table](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py)

Unlike the upstream VAD demonstration that concatenates detected speech, this
workflow must preserve original gaps for correct video subtitle timestamps.
