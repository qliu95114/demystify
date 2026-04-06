#!/usr/bin/env python3
"""
Faster-Whisper Subtitle Generator - CPU Version
Usage: python faster_whisper_subtitle.py <video_file> [model_size] [language]
"""
import sys
import os
from pathlib import Path
from datetime import timedelta

def format_timestamp(seconds):
    """Convert seconds to SRT timestamp format (HH:MM:SS,mmm)"""
    td = timedelta(seconds=seconds)
    hours = td.seconds // 3600
    minutes = (td.seconds % 3600) // 60
    secs = td.seconds % 60
    millis = td.microseconds // 1000
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"

def format_timestamp_vtt(seconds):
    """Convert seconds to VTT timestamp format (HH:MM:SS.mmm)"""
    td = timedelta(seconds=seconds)
    hours = td.seconds // 3600
    minutes = (td.seconds % 3600) // 60
    secs = td.seconds % 60
    millis = td.microseconds // 1000
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"

def generate_subtitle(video_path, model="base", language=None, device="cpu"):
    """Generate subtitles using Faster-Whisper"""
    from faster_whisper import WhisperModel

    # Check if video file exists
    if not os.path.exists(video_path):
        print(f"Error: Video file '{video_path}' not found!")
        return False

    print(f"Loading Faster-Whisper model: {model}")
    print(f"Device: {device}")
    print("(First run will download the model, this may take a while)")

    # Load model - CPU only for now
    model_obj = WhisperModel(model, device=device, compute_type="int8")

    print(f"\nTranscribing: {video_path}")
    print("This may take several minutes depending on video length...\n")

    # Transcribe
    segments, info = model_obj.transcribe(
        video_path,
        language=language,
        beam_size=5,
        vad_filter=True  # Voice Activity Detection for better accuracy
    )

    # Collect segments
    print(f"Detected language: {info.language} (probability: {info.language_probability:.2f})")
    print(f"\nProcessing segments...")

    segments_list = list(segments)

    if not segments_list:
        print("No speech detected in the video!")
        return False

    # Prepare output paths
    video_name = Path(video_path).stem
    output_dir = os.path.dirname(video_path) or "."

    srt_path = os.path.join(output_dir, f"{video_name}.srt")
    vtt_path = os.path.join(output_dir, f"{video_name}.vtt")
    txt_path = os.path.join(output_dir, f"{video_name}.txt")

    # Generate SRT file
    print(f"Writing SRT subtitle...")
    with open(srt_path, "w", encoding="utf-8") as f:
        for i, segment in enumerate(segments_list, 1):
            f.write(f"{i}\n")
            f.write(f"{format_timestamp(segment.start)} --> {format_timestamp(segment.end)}\n")
            f.write(f"{segment.text.strip()}\n\n")

    # Generate VTT file
    print(f"Writing VTT subtitle...")
    with open(vtt_path, "w", encoding="utf-8") as f:
        f.write("WEBVTT\n\n")
        for i, segment in enumerate(segments_list, 1):
            f.write(f"{i}\n")
            f.write(f"{format_timestamp_vtt(segment.start)} --> {format_timestamp_vtt(segment.end)}\n")
            f.write(f"{segment.text.strip()}\n\n")

    # Generate plain text file
    print(f"Writing plain text...")
    with open(txt_path, "w", encoding="utf-8") as f:
        for segment in segments_list:
            f.write(f"{segment.text.strip()}\n")

    print("\n✅ Transcription complete!")
    print(f"  SRT subtitle: {srt_path}")
    print(f"  VTT subtitle: {vtt_path}")
    print(f"  Plain text:   {txt_path}")

    # Print statistics
    print(f"\n📊 Statistics:")
    print(f"  Detected language: {info.language} ({info.language_probability:.1%} confidence)")
    print(f"  Number of segments: {len(segments_list)}")
    if segments_list:
        total_duration = segments_list[-1].end
        print(f"  Video duration: {timedelta(seconds=int(total_duration))}")

    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Faster-Whisper Subtitle Generator - CPU Version\n")
        print("Usage:")
        print("  python faster_whisper_subtitle.py <video_file> [model] [language] [device]\n")
        print("Models (size vs accuracy/speed trade-off):")
        print("  tiny        - Fastest, least accurate (~75MB)")
        print("  tiny.en     - English-only tiny model")
        print("  base        - Fast, decent accuracy (~145MB) [DEFAULT]")
        print("  base.en     - English-only base model")
        print("  small       - Balanced (~480MB)")
        print("  small.en    - English-only small model")
        print("  medium      - Good accuracy, slower (~1.5GB)")
        print("  medium.en   - English-only medium model")
        print("  large-v2    - Best accuracy, slowest (~3GB)")
        print("  large-v3    - Latest large model (~3GB)")
        print("\nLanguage: auto-detect by default, or specify like 'en', 'zh', 'ja', etc.")
        print("\nDevice: 'cpu' (default), 'cuda' (NVIDIA GPU)")
        print("\nExamples:")
        print("  python faster_whisper_subtitle.py video.mp4")
        print("  python faster_whisper_subtitle.py video.mp4 small")
        print("  python faster_whisper_subtitle.py video.mp4 medium zh")
        print("  python faster_whisper_subtitle.py video.mp4 base en cpu")
        sys.exit(1)

    video_file = sys.argv[1]
    model_size = sys.argv[2] if len(sys.argv) > 2 else "base"
    lang = sys.argv[3] if len(sys.argv) > 3 else None
    device = sys.argv[4] if len(sys.argv) > 4 else "cpu"

    print("="*60)
    print("Faster-Whisper Subtitle Generator")
    print("="*60)

    try:
        import time
        start_time = time.time()

        success = generate_subtitle(video_file, model_size, lang, device)

        if success:
            elapsed = time.time() - start_time
            print(f"\n⏱️  Total time: {timedelta(seconds=int(elapsed))}")
    except KeyboardInterrupt:
        print("\n\n❌ Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
