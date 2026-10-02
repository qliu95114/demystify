"""Local, resumable video -> M4A -> SenseVoice/Whisper -> video-timeline SRT.

Only the standard library is imported until inference is actually necessary.
No network access, model downloads, or video encoding takes place here.
"""

import argparse
import contextlib
import hashlib
import importlib.metadata
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import unicodedata
import uuid

from asr_backends import (
    BACKENDS, DEVICES, LANGUAGES, WHISPER_DIRECTORY, WHISPER_FILES,
    resolve_backend, validate_device,
)

RATE = 16000
TOOL = "video-srt"
SCHEMA = 1
VIDEO_EXTENSIONS = {
    ".mkv", ".mp4", ".mov", ".avi", ".webm", ".m4v", ".ts",
    ".m2ts", ".wmv", ".flv", ".mpeg", ".mpg",
}
ASR_DIRECTORY = "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"
TAG_DIRECTORY = "sherpa-onnx-zipformer-small-audio-tagging-2024-04-15"
POLICY = {
    "revision": 1, "sample_rate": RATE, "context_seconds": 3,
    "vad_threshold": 0.45, "min_silence": 0.35, "min_speech": 0.2,
    "max_speech": 15, "batch_size": 4, "tag_window_seconds": 5,
    "gap_min_seconds": 0.8, "gap_speech_threshold": 0.65,
    "gap_singing_threshold": 0.5, "music_threshold": 0.35,
    "speech_threshold": 0.35, "singing_threshold": 0.25,
    "cue_max_seconds": 7, "cue_max_characters": 84,
    "timing": (
        "Video-normalized playback timeline. VAD and model token timestamps are "
        "approximate, not forced alignment. SRT cue splitting distributes times "
        "heuristically within ASR segments; token times remain in raw JSON. "
        "Music labels are coarse five-second windows. "
        "Tags never delete speech, advertisements, lyrics, or story content."
    ),
}


class EngineError(RuntimeError):
    pass


def canonical(path):
    return os.path.normcase(str(Path(path).resolve())).casefold()


def digest(value):
    return hashlib.sha256(json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")).hexdigest()


def file_hash(path):
    result = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def source_signature(path):
    path = Path(path).resolve()
    before = path.stat()
    result = {
        "path": canonical(path), "size": before.st_size,
        "mtime_ns": before.st_mtime_ns, "sha256": file_hash(path),
    }
    after = path.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise EngineError(f"Source changed while hashing: {path}")
    return result


def check_source_unchanged(path, signature):
    stat = Path(path).stat()
    if (stat.st_size, stat.st_mtime_ns) != (
        signature["size"], signature["mtime_ns"]
    ):
        raise EngineError(f"Source changed during processing: {path}")


def atomic_bytes(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".partial")
    try:
        with temporary.open("xb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")


def save_json(path, value):
    atomic_bytes(path, json_bytes(value))


def load_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (ValueError, UnicodeError) as error:
        raise EngineError(f"Invalid JSON; inspect or remove this file: {path}: {error}") from error


@contextlib.contextmanager
def file_lock(path):
    """OS locks are released on crashes; the lock inode must not be unlinked."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+b") as stream:
        stream.seek(0, os.SEEK_END)
        if stream.tell() == 0:
            stream.write(b"\0")
            stream.flush()
        stream.seek(0)
        try:
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            raise EngineError(f"Another process is working on these outputs: {path}") from error
        try:
            yield
        finally:
            stream.seek(0)
            if os.name == "nt":
                msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(stream.fileno(), fcntl.LOCK_UN)


def run(command, binary=False):
    try:
        result = subprocess.run(
            [str(part) for part in command], stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
    except OSError as error:
        raise EngineError(f"Cannot run {command[0]}: {error}") from error
    if result.returncode:
        message = result.stderr.decode("utf-8", errors="replace").strip()
        raise EngineError(f"{command[0]} exited {result.returncode}: {message[-6000:]}")
    return result.stdout if binary else result.stdout.decode("utf-8", errors="replace")


def number(value):
    try:
        result = float(value)
    except (ValueError, TypeError):
        return None
    return result if math.isfinite(result) else None


def probe(path, ffprobe):
    return json.loads(run([
        ffprobe, "-v", "error", "-show_format", "-show_streams",
        "-of", "json", path,
    ]))


def first_packet(path, stream_index, ffprobe):
    data = json.loads(run([
        ffprobe, "-v", "error", "-select_streams", f"a:{stream_index}",
        "-read_intervals", "%+#1", "-show_packets", "-of", "json", path,
    ]))
    packets = data.get("packets", [])
    return packets[0] if packets else {}


def audible_start(packet, stream):
    pts = number(packet.get("pts_time"))
    if pts is None:
        pts = number(stream.get("start_time"))
    if pts is None:
        raise EngineError("Selected audio has no first-packet PTS or stream start timestamp")
    rate = number(stream.get("sample_rate"))
    skip = sum(int(item.get("skip_samples", 0)) for item in packet.get("side_data_list", []))
    return pts + (skip / rate if rate else 0.0)


def timeline(metadata, audio_index, packet):
    streams = metadata.get("streams", [])
    audios = [stream for stream in streams if stream.get("codec_type") == "audio"]
    if audio_index < 0 or audio_index >= len(audios):
        raise EngineError(
            f"Requested audio stream a:{audio_index}; source has {len(audios)} audio stream(s)"
        )
    audio = audios[audio_index]
    videos = [stream for stream in streams if stream.get("codec_type") == "video"]
    if not videos:
        raise EngineError("Input has no video stream; this command accepts videos only")
    origin = number(metadata.get("format", {}).get("start_time"))
    if origin is None:
        starts = [number(stream.get("start_time")) for stream in streams]
        origin = min((value for value in starts if value is not None), default=None)
    if origin is None:
        raise EngineError("Cannot establish source playback origin")
    start = audible_start(packet, audio)
    duration = number(metadata.get("format", {}).get("duration"))
    video_ends = []
    for video in videos:
        length = number(video.get("duration"))
        video_start = number(video.get("start_time"))
        if length is not None and video_start is not None:
            video_ends.append(video_start + length - origin)
    if video_ends:
        duration = max(video_ends)
    if duration is None or duration <= 0:
        raise EngineError("Source has no positive, finite video duration")
    audio_duration = number(audio.get("duration"))
    return {
        "source_playback_origin": origin, "source_audio_first_packet": packet,
        "source_audio_stream_start": number(audio.get("start_time")),
        "source_audio_audible_start": start, "video_duration": duration,
        "expected_audio_duration": audio_duration,
        "audio_offset": start - origin, "audio_stream": audio_index,
        "absolute_stream_index": audio.get("index"), "codec": audio.get("codec_name"),
        "source_sample_rate": audio.get("sample_rate"),
    }


def packet_audio_duration(path, audio_index, audible_origin, ffprobe):
    # Video can outlast its audio. With absent stream duration, measure packets
    # instead of assuming speech continues to the end of the video container.
    command = [
        str(ffprobe), "-v", "error", "-select_streams", f"a:{audio_index}",
        "-show_entries", "packet=pts_time,duration_time", "-of", "csv=p=0", str(path),
    ]
    last_end = None
    with tempfile.TemporaryFile() as errors:
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=errors,
                              stdin=subprocess.DEVNULL, text=True, encoding="utf-8") as process:
            for line in process.stdout:
                fields = line.strip().split(",")
                pts = number(fields[0]) if fields else None
                length = number(fields[1]) if len(fields) > 1 else None
                if pts is not None:
                    last_end = max(last_end if last_end is not None else pts,
                                   pts + (length if length is not None else 0))
            code = process.wait()
            if code:
                errors.seek(0)
                raise EngineError(f"Audio packet scan failed: {errors.read().decode('utf-8', errors='replace')[-6000:]}")
    if last_end is None or last_end <= audible_origin:
        raise EngineError(f"Cannot measure selected audio duration: {path}")
    return last_end - audible_origin


def extraction_command(source, destination, mapping, args):
    codec = mapping["codec"]
    if codec not in ("aac", "alac") and not args.allow_aac_encode:
        raise EngineError(
            f"Selected audio codec {codec!r} cannot be losslessly copied to M4A. "
            "Use --allow-aac-encode to explicitly permit AAC 192k encoding."
        )
    command = [
        args.ffmpeg, "-v", "error", "-nostdin", "-y", "-copyts", "-i", source,
        "-map", f"0:a:{args.audio_stream}", "-vn", "-sn", "-dn", "-map_metadata", "-1",
    ]
    command += ["-c:a", "copy"] if codec in ("aac", "alac") else ["-c:a", "aac", "-b:a", "192k"]
    command += [
        "-output_ts_offset", str(-mapping["source_audio_audible_start"]),
        "-avoid_negative_ts", "disabled", "-use_editlist", "1",
        "-movflags", "+faststart", "-f", "ipod", destination,
    ]
    return command


def verify_audio(path, mapping, args):
    data = probe(path, args.ffprobe)
    streams = data.get("streams", [])
    audios = [s for s in streams if s.get("codec_type") == "audio"]
    if len(audios) != 1 or len(streams) != 1:
        raise EngineError(f"Extracted M4A must contain exactly one audio stream: {path}")
    expected_codec = mapping["codec"] if mapping["codec"] in ("aac", "alac") else "aac"
    if audios[0].get("codec_name") != expected_codec:
        raise EngineError(f"Extracted M4A has unexpected codec: {path}")
    duration = number(data.get("format", {}).get("duration"))
    expected = mapping["expected_audio_duration"]
    if expected is None or expected <= 0:
        raise EngineError("Source audio duration must be measured before extraction verification")
    if duration is None or duration <= 0 or abs(duration - expected) > max(3, expected * 0.01):
        raise EngineError(f"Extracted duration {duration} differs from source audio {expected}: {path}")
    packet = first_packet(path, 0, args.ffprobe)
    first = audible_start(packet, audios[0])
    origin = number(data.get("format", {}).get("start_time"))
    if origin is None:
        raise EngineError(f"Extracted M4A has no playback start time: {path}")
    # ffmpeg -ss is relative to the M4A playback origin. Account for edit lists
    # and AAC priming rather than assuming that its first packet is audible zero.
    mapping = dict(mapping)
    mapping.update(
        m4a_first_packet=packet, m4a_audible_start=first,
        m4a_playback_origin=origin, m4a_duration=duration,
        decode_to_video_offset=mapping["audio_offset"] + origin - first,
        extraction_mode="copy" if mapping["codec"] in ("aac", "alac") else "aac_192k",
        timestamp_method="copyts + explicit output_ts_offset; edit-list/skip-samples compensation",
    )
    return mapping


def decode(path, start, seconds, args, np):
    raw = run([
        args.ffmpeg, "-v", "error", "-nostdin", "-ss", f"{start:.6f}", "-i", path,
        "-t", f"{seconds:.6f}", "-map", "0:a:0", "-vn", "-ac", "1",
        "-ar", str(RATE), "-af", "aresample=async=1:first_pts=0",
        "-c:a", "pcm_f32le", "-f", "f32le", "pipe:1",
    ], binary=True)
    samples = np.frombuffer(raw, dtype="<f4")
    if not len(samples):
        raise EngineError(f"No decoded audio at {start:.3f}s: {path}")
    if len(samples) > (seconds + 1) * RATE:
        raise EngineError("Decoder exceeded the bounded chunk size")
    return samples


def required_models(model_dir, skip_music, backend="sensevoice"):
    result = [model_dir / "silero_vad.onnx"]
    if backend == "sensevoice":
        result += [model_dir / ASR_DIRECTORY / "model.int8.onnx",
                   model_dir / ASR_DIRECTORY / "tokens.txt"]
    elif backend == "whisper":
        result += [model_dir / WHISPER_DIRECTORY / name for name in WHISPER_FILES]
    else:
        raise EngineError(f"Unresolved ASR backend: {backend}")
    if not skip_music:
        result += [model_dir / TAG_DIRECTORY / "model.int8.onnx",
                   model_dir / TAG_DIRECTORY / "class_labels_indices.csv"]
    return result


def runtime_signature(args):
    backend = resolve_backend(args.backend, args.language)
    validate_device(args.device, backend)
    models = required_models(Path(args.model_dir), args.skip_music, backend)
    for path in models:
        if not path.is_file() or path.stat().st_size == 0:
            raise EngineError(f"Missing local model file: {path}. Run the skill setup/model-fetch step first.")
    versions = {}
    packages = ["sherpa-onnx", "numpy"]
    if args.device != "cpu":
        packages += ["onnx", "kaldi-native-fbank"]
    if args.device in ("npu", "intel-gpu"):
        packages += ["openvino"]
    if args.device == "amd-gpu":
        packages += ["onnxruntime-directml"]
    for package in packages:
        try:
            versions[package] = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError as error:
            raise EngineError(f"Missing Python dependency {package}; run the skill setup first") from error
    if versions["sherpa-onnx"] != "1.13.8":
        raise EngineError(f"Expected sherpa-onnx 1.13.8, found {versions['sherpa-onnx']}; run setup")
    acceleration = {"device": args.device}
    if args.device != "cpu":
        acceleration.update(
            device_name=args.accelerator_name,
            device_id=args.gpu_device_id,
            adapter_sha256=file_hash(Path(__file__).with_name("accelerated_sensevoice.py")),
        )
    return {
        "packages": versions, "python": sys.version,
        "engine_sha256": file_hash(Path(__file__)),
        "routing_sha256": file_hash(Path(__file__).with_name("asr_backends.py")),
        "backend": backend,
        "acceleration": acceleration,
        "models": [source_signature(path) for path in models],
        "ffmpeg": run([args.ffmpeg, "-version"]).splitlines()[0],
        "ffprobe": run([args.ffprobe, "-version"]).splitlines()[0],
    }


def create_recognizer(so, args, backend):
    root = Path(args.model_dir)
    device = getattr(args, "device", "cpu")
    validate_device(device, backend)
    if device != "cpu":
        from accelerated_sensevoice import AcceleratedSenseVoice
        return AcceleratedSenseVoice(
            root / ASR_DIRECTORY / "model.int8.onnx",
            root / ASR_DIRECTORY / "tokens.txt", args.language,
            root.parent / "openvino-cache",
            device, args.gpu_device_id, args.accelerator_name,
        )
    language = "" if args.language == "auto" else args.language
    if backend == "sensevoice":
        return so.OfflineRecognizer.from_sense_voice(
            model=str(root / ASR_DIRECTORY / "model.int8.onnx"),
            tokens=str(root / ASR_DIRECTORY / "tokens.txt"),
            language=language, use_itn=True, num_threads=args.threads, provider="cpu",
        )
    if backend == "whisper":
        return so.OfflineRecognizer.from_whisper(
            encoder=str(root / WHISPER_DIRECTORY / WHISPER_FILES[0]),
            decoder=str(root / WHISPER_DIRECTORY / WHISPER_FILES[1]),
            tokens=str(root / WHISPER_DIRECTORY / WHISPER_FILES[2]),
            language=language, task="transcribe", num_threads=args.threads,
            provider="cpu", enable_token_timestamps=False, enable_segment_timestamps=False,
        )
    raise EngineError(f"Unresolved ASR backend: {backend}")


class LocalModels:
    def __init__(self, args):
        import numpy as np
        import sherpa_onnx as so
        self.np, self.so, self.args = np, so, args
        root = Path(args.model_dir)
        self.backend = resolve_backend(args.backend, args.language)
        self.recognizer = create_recognizer(so, args, self.backend)
        self.tagger = None
        if not args.skip_music:
            self.tagger = so.AudioTagging(so.AudioTaggingConfig(
                model=so.AudioTaggingModelConfig(
                    zipformer=so.OfflineZipformerAudioTaggingModelConfig(
                        model=str(root / TAG_DIRECTORY / "model.int8.onnx")),
                    num_threads=args.threads, provider="cpu"),
                labels=str(root / TAG_DIRECTORY / "class_labels_indices.csv"), top_k=527,
            ))

    def vad(self, audio):
        config = self.so.VadModelConfig()
        config.sample_rate, config.num_threads = RATE, self.args.threads
        config.silero_vad.model = str(Path(self.args.model_dir) / "silero_vad.onnx")
        config.silero_vad.threshold = POLICY["vad_threshold"]
        config.silero_vad.min_silence_duration = POLICY["min_silence"]
        config.silero_vad.min_speech_duration = POLICY["min_speech"]
        config.silero_vad.max_speech_duration = POLICY["max_speech"]
        detector = self.so.VoiceActivityDetector(config, buffer_size_in_seconds=120)
        regions = []

        def drain():
            while not detector.empty():
                segment = detector.front
                left = max(0, segment.start - int(0.12 * RATE))
                right = min(len(audio), segment.start + len(segment.samples) + int(0.18 * RATE))
                detector.pop()
                for start in range(left, right, RATE * 25):
                    regions.append((start, min(start + RATE * 25, right)))

        window = config.silero_vad.window_size
        for start in range(0, len(audio), window):
            frame = audio[start:start + window]
            if len(frame) < window:
                frame = self.np.pad(frame, (0, window - len(frame)))
            detector.accept_waveform(frame)
            drain()
        detector.flush()
        drain()
        return regions

    def recognize(self, audio, regions, source, progress):
        ordered = sorted(regions, key=lambda span: span[1] - span[0])
        rows = []
        for index in range(0, len(ordered), POLICY["batch_size"]):
            batch = ordered[index:index + POLICY["batch_size"]]
            streams = []
            for left, right in batch:
                stream = self.recognizer.create_stream()
                stream.accept_waveform(RATE, audio[left:right])
                streams.append(stream)
            if self.backend == "whisper":
                # Whisper is autoregressive; avoid concurrent padded decoder
                # batches on a CPU. The VAD regions stay below 30 seconds.
                for stream in streams:
                    self.recognizer.decode_stream(stream)
            else:
                self.recognizer.decode_streams(streams)
            for (left, right), stream in zip(batch, streams):
                result = stream.result
                rows.append({
                    "start": left / RATE, "end": right / RATE,
                    "text": result.text, "language": result.lang,
                    "emotion": result.emotion if self.backend == "sensevoice" else None,
                    "event": result.event if self.backend == "sensevoice" else None,
                    "tokens": list(result.tokens),
                    "token_times": [left / RATE + float(t) for t in result.timestamps],
                    "source": source,
                    "backend": self.backend,
                })
            progress(source, min(index + len(batch), len(ordered)), len(ordered))
        return sorted(rows, key=lambda row: (row["start"], row["end"]))

    def classify(self, audio, decode_start, progress):
        if self.tagger is None:
            return []
        rows = []
        # Global five-second grid: overlapping decoded context does not shift
        # classification boundaries or produce overlapping published windows.
        first = math.ceil((decode_start - 1e-8) / 5) * 5
        end = decode_start + len(audio) / RATE
        total = max(0, math.ceil((end - first) / 5))
        for index in range(total):
            global_start = first + index * 5
            left = max(0, round((global_start - decode_start) * RATE))
            samples = audio[left:left + RATE * 5]
            if len(samples) < 16:
                continue
            right = left + len(samples)
            if len(samples) < RATE:
                samples = self.np.pad(samples, (0, RATE - len(samples)))
            stream = self.tagger.create_stream()
            stream.accept_waveform(RATE, samples)
            events = self.tagger.compute(stream, top_k=10000)
            scores = {event.name: float(event.prob) for event in events}
            if not all(name in scores for name in ("Speech", "Music", "Singing")):
                raise EngineError("Audio tagger is missing required Speech/Music/Singing classes")
            rows.append({
                "start": left / RATE, "end": right / RATE,
                "speech": scores["Speech"], "music": scores["Music"],
                "singing": scores["Singing"],
                "top_events": [{"name": e.name, "probability": float(e.prob)} for e in events[:5]],
            })
            if index % 12 == 0 or index + 1 == total:
                progress("tagging", index + 1, total)
        return rows

    def analyze(self, audio, decode_start, progress):
        rows = self.recognize(audio, self.vad(audio), "vad", progress)
        windows = self.classify(audio, decode_start, progress)
        gaps = recovery_regions(rows, windows, len(audio) / RATE)
        rows += self.recognize(audio, gaps, "acoustic_gap_recovery", progress)
        return sorted(rows, key=lambda row: (row["start"], row["end"])), windows

    def execution_details(self):
        return {
            **getattr(self.recognizer, "execution", {
                "asr_device": "CPU", "asr_runtime": "sherpa-onnx",
            }),
            "vad_device": "CPU",
            "music_device": None if self.args.skip_music else "CPU",
        }


def recovery_regions(segments, windows, duration):
    covered = sorted((row["start"], row["end"]) for row in segments if clean_text(row["text"]))
    cursor, gaps = 0.0, []
    for start, end in covered + [(duration, duration)]:
        if start - cursor >= 0.8:
            gaps.append((cursor, start))
        cursor = max(cursor, end)
    regions = []
    for start, end in gaps:
        merged = []
        for window in windows:
            if window["speech"] < 0.65 and window["singing"] < 0.5:
                continue
            left, right = max(start, window["start"]), min(end, window["end"])
            if right <= left:
                continue
            if merged and left <= merged[-1][1] + 0.05:
                merged[-1] = (merged[-1][0], max(right, merged[-1][1]))
            else:
                merged.append((left, right))
        for left, right in merged:
            if right - left < 0.8:
                continue
            sample_start = max(0, int((left - 0.08) * RATE))
            sample_end = min(round(duration * RATE), int((right + 0.08) * RATE))
            for offset in range(sample_start, sample_end, RATE * 20):
                limit = min(offset + RATE * 20, sample_end)
                if limit - offset >= int(0.8 * RATE):
                    regions.append((offset, limit))
    return regions


def clean_text(text):
    text = re.sub(r"<\|[^>]*\|>|<[^>]*>", "", str(text))
    text = " ".join(text.replace("-->", "→").split())
    return text if any(character.isalnum() for character in text) else ""


def timestamp(value):
    milliseconds = max(0, round(value * 1000))
    hours, milliseconds = divmod(milliseconds, 3600000)
    minutes, milliseconds = divmod(milliseconds, 60000)
    seconds, milliseconds = divmod(milliseconds, 1000)
    return f"{hours:02}:{minutes:02}:{seconds:02},{milliseconds:03}"


def text_parts(text, count, maximum=None):
    # Split at whitespace/punctuation when possible; CJK also permits character
    # boundaries. This is a readability heuristic, never forced alignment.
    pieces = []
    maximum = maximum or max(1, len(text))
    while text:
        if len(pieces) >= count - 1 and len(text) <= maximum:
            pieces.append(text)
            break
        target = min(maximum, max(1, math.ceil(len(text) / max(1, count - len(pieces)))))
        candidates = [i + 1 for i, c in enumerate(text[:min(maximum, target + 10)])
                      if i + 1 >= max(1, target - 10) and (c.isspace() or c in "。！？.!?，,；;")]
        cut = min(candidates, key=lambda x: abs(x - target)) if candidates else target
        pieces.append(text[:cut].strip())
        text = text[cut:].strip()
    return [piece for piece in pieces if clean_text(piece)]


def remove_boundary_duplicate(previous, current):
    """Only called for overlapping rows from different context chunks."""
    if previous == current:
        return ""
    for length in range(min(len(previous), len(current)), 1, -1):
        if previous[-length:].casefold() == current[:length].casefold():
            return current[length:].lstrip(" ,，。.!！?？")
    return current


def comparable_text(text):
    characters, positions = [], []
    for index, character in enumerate(text):
        if character.isalnum():
            folded = character.casefold()
            characters.extend(folded)
            positions.extend([index] * len(folded))
    return "".join(characters), positions


def reconcile_chunk_rows(segments):
    """Reconcile a whole overlapping group, including one-to-many VAD splits."""
    accepted = []
    for row in sorted(segments, key=lambda r: (r.get("chunk", 0), r["start"], r["end"])):
        row = {**row, "text": clean_text(row["text"])}
        if not row["text"]:
            continue
        overlaps = [
            prior for prior in accepted
            if row.get("chunk") is not None and prior.get("chunk") != row.get("chunk")
            and prior["end"] > row["start"] and prior["start"] < row["end"]
        ]
        overlaps.sort(key=lambda prior: (prior["start"], prior["end"]))
        if overlaps:
            earlier, _ = comparable_text(" ".join(prior["text"] for prior in overlaps))
            current, positions = comparable_text(row["text"])
            if current and current in earlier:
                continue
            for length in range(min(len(earlier), len(current)), 1, -1):
                if earlier[-length:] == current[:length]:
                    row["text"] = row["text"][positions[length]:].lstrip() if length < len(positions) else ""
                    boundary = max(prior["end"] for prior in overlaps)
                    if row["end"] <= boundary:
                        overlaps[-1]["text"] += " " + row["text"]
                        row["text"] = ""
                    else:
                        row["start"] = max(row["start"], boundary)
                    break
        if row["text"]:
            accepted.append(row)
    return sorted(accepted, key=lambda row: (row["start"], row["end"]))


def make_cues(segments, duration):
    rows = []
    for row in reconcile_chunk_rows(segments):
        text = clean_text(row["text"])
        start, end = max(0, row["start"]), min(duration, row["end"])
        if not text or end <= start:
            continue
        if rows:
            previous = rows[-1]
            overlap = start < previous["end"] + 0.05
            if overlap and previous.get("chunk") != row.get("chunk"):
                original_text = text
                text = remove_boundary_duplicate(previous["text"], text)
                if not text:
                    previous["end"] = max(previous["end"], end)
                    continue
                if text != original_text:
                    if end <= previous["end"]:
                        previous["text"] += " " + text
                        continue
                    start = max(start, previous["end"])
            # Do not discard an early utterance merely because padding overlaps.
            # Divide the overlap, retaining both complete texts.
            if start < previous["end"]:
                if end <= previous["start"]:
                    previous["text"] += " " + text
                    continue
                boundary = max(previous["start"] + 0.001, (start + previous["end"]) / 2)
                boundary = min(boundary, end - 0.001)
                previous["end"] = boundary
                start = boundary
        rows.append({**row, "start": start, "end": end, "text": text})
    cues = []
    for row in rows:
        start, end, text = row["start"], row["end"], row["text"]
        cjk = sum(unicodedata.east_asian_width(c) in ("W", "F") for c in text) > len(text) / 3
        maximum = 42 if cjk else POLICY["cue_max_characters"]
        count = max(1, math.ceil(len(text) / maximum), math.ceil((end - start) / 7))
        parts = text_parts(text, min(len(text), count), maximum)
        for index, part in enumerate(parts):
            left = start + (end - start) * index / len(parts)
            right = min(start + (end - start) * (index + 1) / len(parts), left + 7)
            left_ms, right_ms = round(left * 1000), min(math.floor(duration * 1000), round(right * 1000))
            if cues:
                left_ms = max(left_ms, cues[-1]["end_ms"])
            if right_ms <= left_ms:
                # Preserve text when rounding very short adjacent cues.
                if cues:
                    cues[-1]["text"] += " " + part
                continue
            line_limit = 21 if cjk else 42
            lines = text_parts(part, max(1, math.ceil(len(part) / line_limit)), line_limit)
            cues.append({"start_ms": left_ms, "end_ms": right_ms, "text": "\n".join(lines)})
    return cues


def render_srt(cues):
    return "\n".join(
        f"{index}\n{timestamp(cue['start_ms'] / 1000)} --> "
        f"{timestamp(cue['end_ms'] / 1000)}\n{cue['text']}\n"
        for index, cue in enumerate(cues, 1)
    )


def music_intervals(windows):
    result = {}
    for label, key, threshold in (
        ("music_detected", "music", 0.35),
        ("speech_detected", "speech", 0.35),
        ("singing_detected", "singing", 0.25),
    ):
        spans = []
        for window in windows:
            if window[key] < threshold:
                continue
            if spans and window["start"] <= spans[-1]["end"] + 0.01:
                spans[-1]["end"] = max(spans[-1]["end"], window["end"])
            else:
                spans.append({"start": window["start"], "end": window["end"]})
        result[label] = spans
    return result


def plan_inputs(input_path, output_dir, recurse=False):
    source = Path(input_path).resolve()
    output = Path(output_dir).resolve()
    if not source.exists():
        raise EngineError(f"Input does not exist: {source}")
    if source.is_file():
        files, root = [source], source.parent
    else:
        files = sorted(
            (path for path in (source.rglob("*") if recurse else source.glob("*"))
             if path.is_file() and path.suffix.lower() in VIDEO_EXTENSIONS),
            key=lambda path: str(path).casefold(),
        )
        root = source
    if not files:
        raise EngineError(f"No supported video inputs found: {source}")
    destinations, result = {}, []
    input_names = {canonical(path) for path in files}
    for path in files:
        if path.suffix.lower() not in VIDEO_EXTENSIONS:
            raise EngineError(f"Unsupported video extension: {path}")
        relative = path.relative_to(root)
        base = output / relative.parent / path.stem
        outputs = {kind: base.with_name(base.name + suffix) for kind, suffix in (
            ("m4a", ".m4a"), ("srt", ".srt"), ("asr", ".asr.json"),
            ("music", ".music.json"), ("manifest", ".manifest.json"),
        )}
        for destination in outputs.values():
            key = canonical(destination)
            if key in input_names or (destination.exists() and os.path.samefile(path, destination)):
                raise EngineError(f"Output would overwrite an input: {destination}")
            if key in destinations:
                raise EngineError(f"Output collision: {path} and {destinations[key]} -> {destination}")
            destinations[key] = path
        result.append((path, outputs))
    return result


def ensure_owned(outputs, state, force, key):
    artifacts = state.get("artifacts", {}) if state else {}
    existing = False
    for kind, path in outputs.items():
        if not path.exists():
            continue
        existing = True
        record = artifacts.get(kind)
        if path.is_symlink() or not path.is_file() or not record or (
            canonical(path) != record["path"] or file_hash(path) != record["sha256"]
        ):
            raise EngineError(
                f"Refusing to overwrite unrelated or modified output (even with --force): {path}"
            )
    if existing and state.get("key") != key and not force:
        raise EngineError("Source/model/settings changed; use --force to replace only verified generated artifacts")


def publish(path, staged, kind, state, state_path):
    # Inference may take hours: another application could have created or
    # edited a subtitle since preflight. Never rely only on the initial check.
    ensure_owned({kind: path}, state, False, state["key"])
    # Journal the intended hash before rename so a crash after rename is
    # resumable. Keep the old hash too until publication succeeds.
    previous = state["artifacts"].get(kind)
    record = {"path": canonical(path), "sha256": file_hash(staged)}
    state["pending"] = {"kind": kind, "record": record, "previous": previous}
    save_json(state_path, state)
    os.replace(staged, path)
    state["artifacts"][kind] = record
    state.pop("pending", None)
    save_json(state_path, state)


def reconcile_pending(state, outputs, state_path):
    pending = state.get("pending")
    if pending:
        kind = pending["kind"]
        path = outputs[kind]
        if path.is_file() and file_hash(path) == pending["record"]["sha256"]:
            state["artifacts"][kind] = pending["record"]
        elif pending["previous"]:
            state["artifacts"][kind] = pending["previous"]
        state.pop("pending")
        save_json(state_path, state)


def process_file(source, outputs, args, runtime, get_models):
    started = time.monotonic()
    performance = {"cached_chunks": 0, "computed_chunks": 0,
                   "model_load_seconds": 0.0, "decode_seconds": 0.0,
                   "analysis_seconds": 0.0}
    models = None
    cache = outputs["m4a"].parent / ".video-srt" / digest(canonical(outputs["m4a"]))[:24]
    cache.mkdir(parents=True, exist_ok=True)
    with file_lock(cache / "output.lock"):
        signature = source_signature(source)
        info = probe(source, args.ffprobe)
        # Validate selection before packet probing or any output publication.
        audios = [s for s in info.get("streams", []) if s.get("codec_type") == "audio"]
        if args.audio_stream >= len(audios):
            raise EngineError(f"Requested a:{args.audio_stream}; source has {len(audios)} audio stream(s)")
        mapping = timeline(info, args.audio_stream, first_packet(source, args.audio_stream, args.ffprobe))
        extraction_command(source, cache / "audio.partial.m4a", mapping, args)
        if mapping["expected_audio_duration"] is None:
            mapping["expected_audio_duration"] = packet_audio_duration(
                source, args.audio_stream, mapping["source_audio_audible_start"], args.ffprobe)
        config = {
            "source": signature, "runtime": runtime, "policy": POLICY,
            "audio_stream": args.audio_stream, "language": args.language,
            "backend": resolve_backend(args.backend, args.language),
            "device": args.device,
            "threads": args.threads, "chunk_seconds": args.chunk_seconds,
            "skip_music": args.skip_music, "allow_aac_encode": args.allow_aac_encode,
            "source_mapping": mapping,
        }
        key = digest(config)
        state_path = cache / "ownership.json"
        state = load_json(state_path) if state_path.exists() else {
            "tool": TOOL, "schema": SCHEMA, "key": key, "artifacts": {},
        }
        if state.get("tool") != TOOL or state.get("schema") != SCHEMA:
            raise EngineError(f"Unrecognized ownership journal: {state_path}")
        reconcile_pending(state, outputs, state_path)
        ensure_owned(outputs, state, args.force, key)
        if outputs["manifest"].exists():
            manifest = load_json(outputs["manifest"])
            if manifest.get("key") == key and manifest.get("status") in ("completed", "no_speech"):
                expected = manifest["outputs"]
                if all(outputs[k].is_file() and file_hash(outputs[k]) == value["sha256"]
                       for k, value in expected.items()):
                    print(f"{source}: reuse verified {manifest['status']}", flush=True)
                    return manifest["status"]
            outputs["manifest"].unlink()
        if state["key"] != key:
            state.update(key=key)
            # An owned extraction is stale when any input/config changed.
            state.pop("audio_key", None)
        save_json(state_path, state)
        chunks = cache / key
        chunks.mkdir(exist_ok=True)
        chunk_number, chunk_count = 0, 0

        def progress(stage, done, total):
            value = {
                "source": str(source), "key": key, "stage": stage,
                "done": done, "total": total, "chunk": chunk_number,
                "chunks": chunk_count, "elapsed_seconds": round(time.monotonic() - started, 1),
            }
            save_json(cache / "progress.json", value)
            print(f"{source.name}: chunk {chunk_number}/{chunk_count} {stage} "
                  f"{done}/{total}, {value['elapsed_seconds']}s", flush=True)

        progress("extracting", 0, 1)
        extraction_started = time.monotonic()
        if not outputs["m4a"].exists() or state.get("audio_key") != key:
            staged = cache / "audio.partial.m4a"
            run(extraction_command(source, staged, mapping, args))
            mapping = verify_audio(staged, mapping, args)
            check_source_unchanged(source, signature)
            publish(outputs["m4a"], staged, "m4a", state, state_path)
            state["audio_key"] = key
            save_json(state_path, state)
        else:
            mapping = verify_audio(outputs["m4a"], mapping, args)
        audio_duration = mapping["m4a_duration"]
        performance["extraction_seconds"] = time.monotonic() - extraction_started
        chunk_count = math.ceil(audio_duration / args.chunk_seconds)
        segments, windows = [], []
        for index in range(chunk_count):
            chunk_number = index + 1
            core_start = index * args.chunk_seconds
            core_end = min(audio_duration, core_start + args.chunk_seconds)
            # Decode context is aligned to the tag grid and extends at least
            # three seconds either side (up to seven because of the grid).
            left = max(0, math.floor((core_start - POLICY["context_seconds"]) / 5) * 5)
            right = min(audio_duration, math.ceil((core_end + POLICY["context_seconds"]) / 5) * 5)
            checkpoint_path = chunks / f"chunk-{index:06}.json"
            checkpoint = load_json(checkpoint_path) if checkpoint_path.exists() else None
            chunk_key = digest({"key": key, "index": index, "left": left, "right": right, "mapping": mapping})
            if checkpoint and checkpoint.get("key") == chunk_key and checkpoint.get("complete"):
                performance["cached_chunks"] += 1
                progress("cached", 1, 1)
                rows, tags = checkpoint["segments"], checkpoint["windows"]
            else:
                performance["computed_chunks"] += 1
                tick = time.monotonic()
                models = get_models()
                performance["model_load_seconds"] += time.monotonic() - tick
                progress("decoding", 0, 1)
                tick = time.monotonic()
                audio = decode(outputs["m4a"], left, right - left, args, models.np)
                performance["decode_seconds"] += time.monotonic() - tick
                tick = time.monotonic()
                rows, tags = models.analyze(audio, left, progress)
                performance["analysis_seconds"] += time.monotonic() - tick
                del audio
                for row in rows:
                    row.update(
                        start=row["start"] + left, end=row["end"] + left,
                        token_times=[value + left for value in row["token_times"]],
                    )
                for tag in tags:
                    tag.update(start=tag["start"] + left, end=tag["end"] + left)
                check_source_unchanged(source, signature)
                save_json(checkpoint_path, {
                    "key": chunk_key, "complete": True, "decode_start": left,
                    "decode_end": right, "core_start": core_start, "core_end": core_end,
                    "segments": rows, "windows": tags,
                })
            offset = mapping["decode_to_video_offset"]
            for row in rows:
                if row["end"] > core_start and row["start"] < core_end:
                    segments.append({
                        **row, "chunk": index,
                        "audio_start": row["start"], "audio_end": row["end"],
                        "start": row["start"] + offset, "end": row["end"] + offset,
                        "core_start": core_start + offset, "core_end": core_end + offset,
                        "token_times": [value + offset for value in row["token_times"]],
                    })
            for tag in tags:
                if core_start <= tag["start"] < core_end:
                    start, end = max(0, tag["start"] + offset), min(mapping["video_duration"], tag["end"] + offset)
                    if end > start:
                        windows.append({**tag, "start": start, "end": end})
        cues = make_cues(segments, mapping["video_duration"])
        status = "completed" if cues else "no_speech"
        if not cues:
            print(f"WARNING {source}: no usable speech recognized; publishing explicit no_speech and empty SRT", flush=True)
        metadata = {
            "tool": TOOL, "schema": SCHEMA, "key": key, "status": status,
            "source": str(source), "source_signature": signature,
            "policy": POLICY, "timeline": mapping,
            "backend": config["backend"],
            "device": args.device,
            "asr_capabilities": {
                "emotion_and_event_tags": config["backend"] == "sensevoice",
                "token_timestamps": config["backend"] == "sensevoice",
                "task": "transcribe",
            },
            "timing_caveat": POLICY["timing"],
            "gap_recovery": "disabled with --skip-music" if args.skip_music else "acoustic speech/singing scores",
        }
        publications = {
            "srt": render_srt(cues).encode("utf-8"),
            "asr": json_bytes({**metadata, "segments": segments, "cue_count": len(cues),
                               "music_intervals": music_intervals(windows)}),
        }
        if not args.skip_music:
            publications["music"] = json_bytes({**metadata, "windows": windows, "intervals": music_intervals(windows)})
        check_source_unchanged(source, signature)
        progress("publishing", 0, len(publications))
        if args.skip_music and outputs["music"].exists():
            ensure_owned({"music": outputs["music"]}, state, False, key)
            outputs["music"].unlink()
            state["artifacts"].pop("music", None)
            save_json(state_path, state)
        for kind, data in publications.items():
            staged = cache / (kind + ".publish")
            atomic_bytes(staged, data)
            publish(outputs[kind], staged, kind, state, state_path)
        manifest = {
            **metadata, "configuration": config, "outputs": {
                kind: state["artifacts"][kind] for kind in ["m4a", *publications]
            },
            "performance": {
                **performance, "elapsed_seconds": time.monotonic() - started,
                "media_seconds": mapping["video_duration"],
                "note": "This invocation only; cached chunks are not inference benchmarks. Excludes setup and final manifest write.",
            },
            "execution": models.execution_details() if models is not None and hasattr(models, "execution_details") else None,
        }
        staged = cache / "manifest.publish"
        save_json(staged, manifest)
        publish(outputs["manifest"], staged, "manifest", state, state_path)
        progress(status, chunk_count, chunk_count)
        return status


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("input", "output-dir", "model-dir", "ffmpeg", "ffprobe"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--language", choices=LANGUAGES, default="auto")
    parser.add_argument("--backend", choices=BACKENDS, default="auto")
    parser.add_argument("--device", choices=DEVICES, default="cpu")
    parser.add_argument("--gpu-device-id", type=int, default=-1)
    parser.add_argument("--accelerator-name", default="CPU")
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--audio-stream", type=int, default=0)
    parser.add_argument("--chunk-seconds", type=int, default=300)
    for name in ("recurse", "allow-aac-encode", "skip-music", "force"):
        parser.add_argument("--" + name, action="store_true")
    args = parser.parse_args(argv)
    if args.threads < 1 or args.audio_stream < 0 or not 1 <= args.chunk_seconds <= 3600:
        parser.error("threads must be positive, audio-stream nonnegative, chunk-seconds between 1 and 3600")
    try:
        args.backend = resolve_backend(args.backend, args.language)
        validate_device(args.device, args.backend)
    except ValueError as error:
        parser.error(str(error))
    return args


def main(argv=None):
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = parse_args(argv)
    current = args.input
    try:
        planned = plan_inputs(args.input, args.output_dir, args.recurse)
        runtime = runtime_signature(args)
        loaded = []

        def get_models():
            if not loaded:
                loaded.append(LocalModels(args))
            return loaded[0]

        for source, outputs in planned:
            current = source
            process_file(source, outputs, args, runtime, get_models)
        return 0
    except (RuntimeError, OSError, ValueError, ImportError) as error:
        print(f"ERROR [{current}]: {error}", file=sys.stderr, flush=True)
        return 1
    except KeyboardInterrupt:
        print(f"Interrupted [{current}]; completed chunks are resumable; no completion manifest published",
              file=sys.stderr, flush=True)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
