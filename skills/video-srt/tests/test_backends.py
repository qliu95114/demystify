import importlib.util
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import asr_backends as routing

SPEC = importlib.util.spec_from_file_location("multilingual_engine", SCRIPTS / "transcribe.py")
engine = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(engine)


class BackendTests(unittest.TestCase):
    def args(self, language="auto"):
        return SimpleNamespace(model_dir="models", language=language, threads=2)

    def test_original_defaults_are_preserved(self):
        for language in ("auto", *routing.SENSEVOICE_LANGUAGES):
            self.assertEqual(routing.resolve_backend("auto", language), "sensevoice")

    def test_five_new_languages_route_to_whisper(self):
        self.assertEqual(set(routing.ADDED_LANGUAGES), {"fr", "de", "es", "pt", "it"})
        for language in routing.ADDED_LANGUAGES:
            self.assertEqual(routing.resolve_backend("auto", language), "whisper")
            self.assertEqual(routing.resolve_backend("whisper", language), "whisper")

    def test_unsupported_model_language_pairs_are_explicit_errors(self):
        for language in routing.ADDED_LANGUAGES:
            with self.assertRaisesRegex(ValueError, "does not support"):
                routing.resolve_backend("sensevoice", language)
        with self.assertRaisesRegex(ValueError, "no yue language token"):
            routing.resolve_backend("whisper", "yue")
        with self.assertRaises(ValueError):
            routing.resolve_backend("auto", "unknown")

    def test_whisper_factory_passes_native_language_and_transcribes(self):
        for language in (*routing.ADDED_LANGUAGES, "auto"):
            with self.subTest(language=language):
                native = mock.Mock()
                engine.create_recognizer(native, self.args(language), "whisper")
                kwargs = native.OfflineRecognizer.from_whisper.call_args.kwargs
                self.assertEqual(kwargs["language"], "" if language == "auto" else language)
                self.assertEqual(kwargs["task"], "transcribe")
                self.assertEqual(kwargs["provider"], "cpu")
                self.assertIn("small-encoder.int8.onnx", kwargs["encoder"])
                self.assertNotIn("small.en", kwargs["encoder"])
                self.assertFalse(kwargs["enable_token_timestamps"])
                native.OfflineRecognizer.from_sense_voice.assert_not_called()

    def test_original_factory_keeps_sensevoice_itn(self):
        native = mock.Mock()
        engine.create_recognizer(native, self.args("yue"), "sensevoice")
        kwargs = native.OfflineRecognizer.from_sense_voice.call_args.kwargs
        self.assertEqual(kwargs["language"], "yue")
        self.assertTrue(kwargs["use_itn"])
        native.OfflineRecognizer.from_whisper.assert_not_called()

    def test_required_models_include_only_selected_asr(self):
        whisper = engine.required_models(Path("models"), False, "whisper")
        sensevoice = engine.required_models(Path("models"), True, "sensevoice")
        self.assertEqual(len(whisper), 6)
        self.assertEqual(len(sensevoice), 3)
        self.assertFalse(any(engine.ASR_DIRECTORY in str(path) for path in whisper))
        self.assertFalse(any(routing.WHISPER_DIRECTORY in str(path) for path in sensevoice))

    def test_direct_cli_auto_and_explicit_selection(self):
        base = ["--input", "a.mkv", "--output-dir", "out", "--model-dir", "models",
                "--ffmpeg", "ffmpeg", "--ffprobe", "ffprobe"]
        self.assertEqual(engine.parse_args(base).backend, "sensevoice")
        for language in routing.ADDED_LANGUAGES:
            self.assertEqual(engine.parse_args(base + ["--language", language]).backend, "whisper")
        args = engine.parse_args(base + ["--backend", "whisper", "--language", "auto"])
        self.assertEqual((args.backend, args.language), ("whisper", "auto"))
        with mock.patch("sys.stderr"), self.assertRaises(SystemExit):
            engine.parse_args(base + ["--backend", "sensevoice", "--language", "fr"])


if __name__ == "__main__":
    unittest.main()
