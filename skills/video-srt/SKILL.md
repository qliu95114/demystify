---
name: video-srt
description: Generate same-named SRT subtitles from videos using local SenseVoice (CPU, Intel NPU, Intel GPU, or AMD GPU) or multilingual Whisper (CPU). Supports Chinese, Cantonese, English, Japanese, Korean, French, German, Spanish, Portuguese and Italian. Checks and optionally installs Windows prerequisites, extracts M4A, and uses VAD/music detection without cloud uploads or repeated LLM calls. Use for video to SRT, local ASR, batch subtitles, 视频转字幕, or 语音转文字.
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
   CPU remains the default. SenseVoice supports explicit `-Device npu`,
   `intel-gpu`, or `amd-gpu`. Intel targets use OpenVINO; AMD uses DirectML.
   Audio features, CTC, VAD and music detection remain on CPU. Accelerator paths
   verify their exact target and never silently assign model nodes to CPU.
   Whisper acceleration and other NPU vendors are unsupported. Compilation can
   take time and an accelerator is not necessarily faster than CPU.
4. For a long batch, run one persistent process and retain its log. Do not run
   concurrent copies against the same output files. Rerun the same command after
   interruption to reuse matching checkpoints; never claim completion just
   because a background process started.
5. Check the exit code, per-file manifests, nonempty SRT for speech-containing
   videos, and reported `no_speech`/warnings. Summarize actual outputs and any
   uncertain timing. Never claim the recognized words are manually verified.
   For performance comparisons, use fresh output directories, the same audio
   track/settings, and report cold compilation separately from warm model-cache
   runs. Completed-output/checkpoint reuse is not an inference benchmark.

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

Intel NPU (SenseVoice only, optional dependencies installed with consent):

```powershell
pwsh -NoProfile -File .\scripts\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\episode.mkv' -Language zh -Device npu -InstallMissing
```

Intel or AMD GPU:

```powershell
pwsh -NoProfile -File .\scripts\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\episode.mkv' -Language zh -Device intel-gpu -InstallMissing

pwsh -NoProfile -File .\scripts\Invoke-VideoSrt.ps1 `
  -InputPath 'D:\Videos\episode.mkv' -Language zh -Device amd-gpu -InstallMissing
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
  editing is performed by the transcription scripts. Those are separate requests,
  not prerequisites for SRT. When cut recommendations are explicitly requested,
  apply the general and series-specific cut policies below without modifying the
  full SRT or source.
- Raw ASR/event/token evidence and optional music scores are retained separately.
  Empty/punctuation-only recognition is not rendered as a subtitle cue.
  Whisper does not supply SenseVoice emotion/event tags or token timing in this
  configuration; keep unavailable values explicit, never fabricate them.
- A silent/no-speech file must be explicitly reported, not disguised as a
  successful transcript. Model errors and unsupported inputs must surface.
- No media is uploaded. Network access during setup is limited to software
  installation and public model downloads; no API key or paid LLM is needed.

## 剪切建议：通用片头起点

仅在用户要求剪切建议时应用于所有剧集，不改变完整字幕生成流程，
也不自动执行剪切或修改编码队列。

- **保留片名／集数画面**：优先从正片前无广告的片名卡或带集数的画面开始，
  保留清晰可读的展示过程，再接入正片；不要一律从首句对白或卡片结束处开始。
  根据实际画面确定起点，不机械套用固定秒数或上一集参数。
- **去广告优先**：如果片名卡／集数画面带有广告、冠名口播或扫码引流，
  就不保留该画面，改从广告结束后的无广告卡片或正片开始。
  常驻台标本身不等同于广告。若卡片本身干净、但卡片与正片之间夹着广告，
  单一首尾剪切方案也应放弃该卡片，不能为保留它而带入广告；
  用户另行要求分段保留时，才列出分段剪切方案。
- 抽帧确认卡片及广告边界，保护首句对白和无对白剧情。
  若卡片之前已有正片／冷开场，不得为从卡片开始而删掉这部分剧情。
  报告说明起点保留了哪种卡片，或因广告放弃卡片的原因；不确定时标注待复核。
- 本规则的去广告要求优先于各剧固定提前量（包括兰香如故的提前5秒规则）。

## 剪切建议：遮天、吞噬星空

仅在用户要求分析剪切点、计算尾删时长或生成剪切建议报告时应用以下规则；
不改变字幕生成流程，也不自动执行剪切。

- **保留补充内容**：除本集正片外，尾部的小知识、问答环节、科普讲解、
  角色／设定资料卡等有信息价值的补充内容都计入保留范围。
  不要在正片结束或片尾音乐开始时直接截断，也不要因资料卡没有对白而删除。
- **去掉广告及引流**：广告、商品或游戏推广、扫码关注／支付、求关注、
  点赞投币等宣传引导段落应列为删除范围；即使由剧中角色讲述，
  或采用问答、知识卡的包装，也不能当作科普保留。
- **逐集确认边界**：结合画面、已有字幕及 ASR 判断补充内容和宣传的实际边界，
  不仅凭音乐分数、静音或关键词判定。保留完整问题和答案，
  为无对白的文字资料卡保留完整展示时间；无法明确区分时标注待复核。
- **尾删计算**：连续保留区间的终点应放在最后一个需保留的补充环节结束之后，
  `lastsecs = 原视频总时长 - 保留终点`。若补充信息一直延续到文件末尾，
  `lastsecs = 0`，不要机械沿用历史集数的尾删参数。
- **广告夹在需保留内容之间**：分别列出保留区间和广告删除区间，
  明确说明仅靠 `startsecs` / `lastsecs` 无法完成，需要分段剪切再拼接；
  不得为了去广告而丢弃后面的知识／问答，也不能把夹杂广告的单一区间称为已去广告。
- 报告应说明保留了哪些补充环节、去掉哪些宣传及其时间依据。
  原始 SRT／ASR 仍保留所有识别内容；未经用户明确要求，不修改视频或编码队列。

## 剪切建议：兰香如故

仅在用户要求片头剪切建议或生成剪切建议报告时应用，不改变字幕生成流程，
也不自动修改视频或编码队列。

- **保留片头集数信息**：先按原方法确定本集正片起点，再将候选起点提前5秒：
  `startsecs = max(0, 原计算起点秒数 - 5)`。
  例如原计算值 `02:08`（128秒），无广告且包含集数画面时使用 `02:03`（123秒）。
- 提前5秒只应用一次，始终基于未调整的原计算值；更新已有建议时，
  不要在已经提前过的结果上重复减5秒。此规则仅适用于兰香如故的片头，
  不改变保留终点或 `lastsecs`。
- 报告同时列出原计算起点和最终起点，并说明是否保留集数牌。
  结合抽帧确认集数信息；若提前5秒仍未包含无广告的集数牌，按通用规则定位卡片。
  若提前会带入广告，或集数画面本身带广告，则不保留该集数画面，
  改从广告结束后的无广告卡片或正片开始，不强制减5秒；无法判断时标注待复核。

See [reference](references/usage.md) for parameters, outputs, installation,
troubleshooting and validation commands.
