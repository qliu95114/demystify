"""Shared language routing for setup and inference; no native imports."""

SENSEVOICE_LANGUAGES = ("zh", "en", "ja", "ko", "yue")
ADDED_LANGUAGES = ("fr", "de", "es", "pt", "it")
LANGUAGES = ("auto", *SENSEVOICE_LANGUAGES, *ADDED_LANGUAGES)
BACKENDS = ("auto", "sensevoice", "whisper")
DEVICES = ("cpu", "npu", "intel-gpu", "amd-gpu")
WHISPER_DIRECTORY = "sherpa-onnx-whisper-small"
WHISPER_FILES = ("small-encoder.int8.onnx", "small-decoder.int8.onnx", "small-tokens.txt")


def resolve_backend(backend, language):
    if backend not in BACKENDS or language not in LANGUAGES:
        raise ValueError(f"Unsupported backend/language: {backend}/{language}")
    if backend == "auto":
        backend = "whisper" if language in ADDED_LANGUAGES else "sensevoice"
    if backend == "sensevoice" and language not in ("auto", *SENSEVOICE_LANGUAGES):
        raise ValueError(f"SenseVoiceSmall does not support {language}; use -Backend whisper or auto.")
    if backend == "whisper" and language == "yue":
        raise ValueError("This original Whisper small export has no yue language token; use SenseVoice for Cantonese.")
    return backend


def validate_device(device, backend):
    if device not in DEVICES:
        raise ValueError(f"Unsupported device: {device}")
    if device != "cpu" and backend != "sensevoice":
        raise ValueError("Hardware accelerators currently support SenseVoice only; use -Device cpu for Whisper.")
