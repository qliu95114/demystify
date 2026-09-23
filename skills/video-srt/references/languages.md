# Language support and model evidence

## Why SenseVoiceSmall is limited to five listed languages

The [official SenseVoice README](https://github.com/FunAudioLLM/SenseVoice#introduction)
explicitly states:

> SenseVoiceSmall supports ASR and language ID for Mandarin, Cantonese, English, Japanese, and Korean.

Its **Highlights** section distinguishes the wider research project (more than
50 languages) from this released **SenseVoiceSmall checkpoint** (the five languages
above). The research claim is not a claim that every released checkpoint supports
all those languages.

The [inference example](https://github.com/FunAudioLLM/SenseVoice#inference) lists
`auto`, `zh`, `en`, `yue`, `ja`, and `ko`. `auto` means language identification
within the model's supported scope; it does not add recognition capability.
`nospeech`, mentioned in the upstream example, is a special label, not another
spoken language.

This is also reflected in the
[sherpa-onnx v1.13.8 SenseVoice configuration](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.8/sherpa-onnx/csrc/offline-sense-voice-model-config.cc).

Saying "the model may output text" for an unsupported language is not the same
as official support or reliable transcription. No ASR model guarantees accuracy
even for supported languages.

## Added multilingual backend

This skill uses **multilingual Whisper small INT8**, not `small.en`, for French,
German, Spanish, Portuguese, and Italian. It runs locally through the existing
sherpa-onnx CPU runtime; no extra cloud service or Python ASR package is needed.

The [OpenAI Whisper language table](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py#L10-L26)
defines `fr`, `de`, `es`, `pt`, and `it`. The
[official model overview](https://github.com/openai/whisper#available-models-and-languages)
distinguishes multilingual `small` from English-only `small.en`.
The [sherpa pretrained model guide](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/whisper/tiny.en.html)
documents the export/archive naming pattern, including `small`.

The official archive is approximately **639 MB** compressed and contains both
float32 and INT8 weights. Setup installs only the pinned INT8 encoder, INT8 decoder,
and tokenizer files. CPU speed and memory use differ from SenseVoice; expect
Whisper to be slower for many workloads.

## Script language routing

| `-Language` | Language | Default backend with `-Backend auto` |
|---|---|---|
| `zh` | Mandarin | SenseVoiceSmall |
| `en` | English | SenseVoiceSmall |
| `ja` | Japanese | SenseVoiceSmall |
| `ko` | Korean | SenseVoiceSmall |
| `yue` | Cantonese | SenseVoiceSmall |
| `fr` | French | Whisper small |
| `de` | German | Whisper small |
| `es` | Spanish | Whisper small |
| `pt` | Portuguese | Whisper small |
| `it` | Italian | Whisper small |
| `auto` | Automatic identification | SenseVoiceSmall, preserving existing behavior |

The explicit language selector therefore exposes **10 languages**. Accents and
regional varieties, including Brazilian/European Portuguese, can have different
accuracy; `pt` is the language selector, not a separate country/accent model.

**Important:** `-Language auto` alone preserves the original five-language
SenseVoice path. For automatic identification that can include the added languages,
use **`-Backend whisper -Language auto`**.

```powershell
# Run from the scripts directory. French automatically selects Whisper.
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\french.mkv' -Language fr -InstallMissing

# Unknown language, using the multilingual Whisper model.
pwsh -NoProfile -File .\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\unknown.mp4' -Backend whisper -Language auto -InstallMissing
```

`-Backend sensevoice -Language fr` fails explicitly. This original Whisper small
export has the original 99-language vocabulary and lacks the later `yue` token;
use SenseVoice for explicit Cantonese. The current upstream tokenizer's inclusion
of `yue` does not change the vocabulary of an older checkpoint.

## Native API and output differences

- In sherpa-onnx, Whisper automatic language selection requires `language=""`.
  Omitting it defaults to English. The wrapper maps `-Language auto` to the empty
  string: see the
  [v1.13.8 Python API](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.8/sherpa-onnx/python/sherpa_onnx/offline_recognizer.py#L1205-L1215)
  and [decoder language-selection branch](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.8/sherpa-onnx/csrc/offline-whisper-greedy-search-decoder.cc#L53-L71).
- Whisper runs with `task="transcribe"`: French remains French, rather than being
  translated into English.
- Automatic identification is performed on recognition segments, not a guaranteed
  whole-file language decision. Very short utterances, silence and code-switching
  can confuse it; explicitly choose the language when known.
- Whisper does not produce SenseVoice emotion/audio-event tags. Those fields are
  `null`, not inferred or fabricated. The independent Zipformer detector still
  provides music/speech evidence unless `-SkipMusic` is set.
- This exported Whisper configuration uses VAD segment timing and heuristic SRT
  cue splits, not token-level forced alignment. Its token timestamp list can be
  empty; the metadata declares that limitation.
- The selected backend, model files and configuration participate in checkpoint
  identity. Switching models does not silently reuse the other model's results.

Sources checked when adding the multilingual backend on 2026-09-23.
