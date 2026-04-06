# Whisper Subtitle Generator

Local, offline speech-to-text subtitle generator using faster-whisper (optimized Whisper implementation).

## Quick Start

### 1. Setup (First Time Only)

**Windows PowerShell:**
```powershell
.\setup_whisper.ps1
```

**Manual Setup:**
```powershell
# Install dependencies
pip install faster-whisper

# Verify installation
python -c "from faster_whisper import WhisperModel; print('OK')"
```

### 2. Generate Subtitles

**Basic usage:**
```powershell
python whisper_subtitle_generator.py video.mp4
```

**With specific model:**
```powershell
# Medium model (recommended - good balance)
python whisper_subtitle_generator.py video.mp4 medium

# Large model (best quality, slower)
python whisper_subtitle_generator.py video.mp4 large-v3
```

**With language specified:**
```powershell
# English
python whisper_subtitle_generator.py video.mp4 medium en

# Chinese
python whisper_subtitle_generator.py video.mp4 medium zh

# Japanese
python whisper_subtitle_generator.py video.mp4 medium ja
```

### 3. Output Files

The script generates three files in the same directory as your video:

- **`.srt`** - SubRip format (most compatible - use this for VLC, MPC-HC, etc.)
- **`.vtt`** - WebVTT format (for web players)
- **`.txt`** - Plain text transcript

---

## Model Comparison

Tested on 55-minute TV episode (The Capture S01E01):

| Model | Size | Processing Time | Accuracy | Use Case |
|---|---|---|---|---|
| **tiny** | 75MB | ~5 min | ⭐⭐ | Quick drafts, non-critical |
| **base** | 145MB | ~8 min | ⭐⭐⭐ | Fast processing, decent quality |
| **small** | 480MB | ~15 min | ⭐⭐⭐⭐ | Good balance |
| **medium** | 1.5GB | ~25 min | ⭐⭐⭐⭐⭐ | **Recommended** |
| **large-v3** | 3GB | ~50 min | ⭐⭐⭐⭐⭐ | Best quality, professional use |

**Recommendation:** Use **medium** for best speed/quality balance. Use **large-v3** for maximum accuracy when quality is critical.

---

## Quality Test Results

Tested on "The Capture S01E01" BBC drama:

**faster-whisper (large-v3) - BEST:**
- ✅ Correct character name recognition ("Bogdan", "Zane")
- ✅ Accurate word transcription ("Assault" not "A salt")
- ✅ Natural subtitle timing (700 segments)
- ✅ Proper punctuation and dialogue flow
- Processing time: ~50 minutes for 55-minute video

**Comparison vs other implementations:**
- More accurate than OpenAI Whisper (CPU - 85 min, higher memory)
- Intel NPU/AMD GPU attempts fell back to CPU (no hardware acceleration)
- Significantly better accuracy than smaller models

---

## System Requirements

### Minimum:
- **Python:** 3.8 or higher
- **RAM:** 4GB
- **Storage:** 500MB (for tiny model)
- **Processor:** Any modern CPU

### Recommended:
- **Python:** 3.10+
- **RAM:** 8GB
- **Storage:** 2-4GB (for medium/large models)
- **Processor:** Multi-core CPU (faster processing)

### Optional:
- **ffmpeg:** Required for video file processing (MP4, MKV, etc.)
  - Audio files (MP3, WAV, M4A) work without ffmpeg
  - Install: `winget install Gyan.FFmpeg`

---

## Supported Languages

Auto-detects 99+ languages including:
- English (`en`)
- Chinese (`zh`)
- Spanish (`es`)
- French (`fr`)
- German (`de`)
- Japanese (`ja`)
- Korean (`ko`)
- And many more...

Specify language for faster processing: `python whisper_subtitle_generator.py video.mp4 medium zh`

---

## Hardware Acceleration

### Current Status:
- ✅ **CPU:** Fully supported (all platforms)
- ✅ **NVIDIA GPU:** Supported via CUDA
- ❌ **Intel NPU:** Not supported (requires model conversion)
- ❌ **AMD GPU:** Not supported (CTranslate2 limitation)

### For NVIDIA GPU:
```powershell
# Install CUDA-enabled version
pip install faster-whisper[cuda]
```

The script will automatically use GPU if CUDA is available.

---

## Troubleshooting

### Issue: "ModuleNotFoundError: No module named 'faster_whisper'"
**Solution:**
```powershell
pip install faster-whisper
```

### Issue: "ffmpeg not found" when processing video files
**Solution:**
```powershell
# Option 1: Install ffmpeg
winget install Gyan.FFmpeg

# Option 2: Extract audio first, then use MP3
ffmpeg -i video.mp4 -vn -acodec mp3 audio.mp3
python whisper_subtitle_generator.py audio.mp3
```

### Issue: First run is slow
**Cause:** First run downloads the model (one-time, requires internet)
- tiny: 75MB
- base: 145MB
- medium: 1.5GB
- large-v3: 3GB

Models are cached in `~/.cache/huggingface/hub/` and reused for subsequent runs.

### Issue: Slow processing on CPU
**Solutions:**
1. Use smaller model (`medium` instead of `large-v3`)
2. For NVIDIA GPU: Install CUDA version
3. Process shorter clips instead of full video

---

## Performance Tips

### 1. Use appropriate model size:
- **Draft/rough work:** tiny or base
- **General use:** small or medium
- **Professional/accessibility:** large-v3

### 2. Specify language if known:
```powershell
# Faster than auto-detect
python whisper_subtitle_generator.py video.mp4 medium en
```

### 3. Process audio instead of video:
```powershell
# Extract audio first (faster)
ffmpeg -i video.mp4 -vn -acodec mp3 audio.mp3
python whisper_subtitle_generator.py audio.mp3 medium
```

### 4. Batch processing:
```powershell
# Process multiple files
Get-ChildItem *.mp4 | ForEach-Object {
    python whisper_subtitle_generator.py $_.FullName medium
}
```

---

## Example Workflows

### Single video with best quality:
```powershell
python whisper_subtitle_generator.py "D:\Videos\my-video.mp4" large-v3
```

### Batch process with medium quality:
```powershell
# Process all MP4 files in current directory
Get-ChildItem *.mp4 | ForEach-Object {
    Write-Host "Processing: $($_.Name)"
    python whisper_subtitle_generator.py $_.FullName medium
}
```

### Chinese video:
```powershell
python whisper_subtitle_generator.py chinese-video.mp4 medium zh
```

---

## Files in This Package

- **`whisper_subtitle_generator.py`** - Main script
- **`setup_whisper.ps1`** - Setup script for new machines
- **`WHISPER_README.md`** - This documentation

---

## Tested Configuration

Successfully tested on:
- **CPU:** Intel Core Ultra 7 165H (16 cores)
- **OS:** Windows 11
- **Python:** 3.14.3
- **Model:** faster-whisper large-v3
- **Test file:** The Capture S01E01 (55 min, 702MB MP4)
- **Result:** High accuracy, 50-minute processing time, correct character names and dialogue

---

## Support & References

- **faster-whisper:** https://github.com/SYSTRAN/faster-whisper
- **OpenAI Whisper:** https://github.com/openai/whisper
- **Supported formats:** MP4, MP3, WAV, M4A, FLAC, OGG, and more
- **Supported languages:** 99+ languages with auto-detection

---

## License

Uses faster-whisper (MIT License) and OpenAI Whisper models.

*Last updated: April 6, 2026*
