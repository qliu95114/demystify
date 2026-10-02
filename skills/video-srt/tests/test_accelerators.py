import importlib.util
from pathlib import Path
import sys
import unittest
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import asr_backends
import accelerated_sensevoice as accelerator
import transcribe
import setup_models


class AcceleratorTests(unittest.TestCase):
    def test_only_sensevoice_supports_accelerators(self):
        for device in ("npu", "intel-gpu", "amd-gpu"):
            asr_backends.validate_device(device, "sensevoice")
        asr_backends.validate_device("cpu", "whisper")
        with self.assertRaisesRegex(ValueError, "SenseVoice only"):
            asr_backends.validate_device("amd-gpu", "whisper")
        with self.assertRaisesRegex(ValueError, "Unsupported device"):
            asr_backends.validate_device("gpu", "sensevoice")

    def test_cli_is_opt_in_and_rejects_whisper_acceleration(self):
        base = ["--input", "a.mkv", "--output-dir", "out", "--model-dir", "models",
                "--ffmpeg", "ffmpeg", "--ffprobe", "ffprobe"]
        self.assertEqual(transcribe.parse_args(base).device, "cpu")
        for device in ("npu", "intel-gpu", "amd-gpu"):
            self.assertEqual(transcribe.parse_args(base + ["--device", device]).device, device)
            with mock.patch("sys.stderr"), self.assertRaises(SystemExit):
                transcribe.parse_args(base + ["--device", device, "--language", "fr"])

    def test_missing_npu_is_not_cpu_fallback(self):
        core = mock.Mock(available_devices=["CPU", "GPU.0"])
        with self.assertRaisesRegex(RuntimeError, "NPU unavailable"):
            accelerator.select_openvino_device(core, "npu")
        core.get_property.assert_not_called()

    def test_openvino_execution_must_match_exact_target(self):
        compiled = mock.Mock()
        for devices in (["CPU"], ["GPU.0", "CPU"], [], "GPU.1"):
            compiled.get_property.return_value = devices
            with self.assertRaisesRegex(RuntimeError, "unexpected OpenVINO"):
                accelerator.check_openvino_execution(compiled, "GPU.0")
        for devices in ("GPU.0", ["GPU.0"]):
            compiled.get_property.return_value = devices
            self.assertTrue(accelerator.check_openvino_execution(compiled, "GPU.0"))

    def test_intel_gpu_selection_checks_vendor_and_index(self):
        core = mock.Mock(available_devices=["CPU", "GPU.0", "GPU.1"])
        core.get_property.side_effect = lambda target, prop: {
            "GPU.0": "Intel Arc", "GPU.1": "gfx1102",
        }[target]
        self.assertEqual(accelerator.select_openvino_device(core, "intel-gpu"), ("GPU.0", "Intel Arc"))
        self.assertEqual(accelerator.select_openvino_device(core, "intel-gpu", 0), ("GPU.0", "Intel Arc"))
        with self.assertRaisesRegex(RuntimeError, "Expected one Intel"):
            accelerator.select_openvino_device(core, "intel-gpu", 1)

    def test_buckets_never_truncate(self):
        for length in (1, 64, 128, 129, 256, 432):
            self.assertGreaterEqual(accelerator.select_bucket(length), length)
        for length in (0, -1, 433):
            with self.assertRaises(ValueError):
                accelerator.select_bucket(length)

    def test_ctc_controls_blanks_repeats_and_timestamps(self):
        symbols = {0: "<unk>", 1: "<|zh|>", 2: "<|NEUTRAL|>",
                   3: "<|Speech|>", 4: "<|withitn|>", 5: "A", 6: "\u2581B"}
        result = accelerator.decode_ctc([1, 2, 3, 4, 5, 5, 0, 5, 6], symbols, 0.06)
        self.assertEqual(result.text, "AA B")
        self.assertEqual(result.lang, "<|zh|>")
        self.assertEqual(result.event, "<|Speech|>")
        self.assertEqual(result.timestamps, [0, 0.18, 0.24])
        self.assertEqual(result.tokens, ["A", "A", "\u2581B"])

    def test_control_only_no_speech_is_empty(self):
        symbols = {1: "<|nospeech|>", 2: "<|NEUTRAL|>",
                   3: "<|Silence|>", 4: "<|withitn|>"}
        self.assertEqual(accelerator.decode_ctc([1, 2, 3, 4], symbols, 0.06).text, "")
        with self.assertRaisesRegex(RuntimeError, "missing"):
            accelerator.decode_ctc([], symbols, 0.06)

    def test_missing_optional_package_is_reported(self):
        with mock.patch("builtins.print") as output, \
                mock.patch.object(setup_models.importlib, "import_module", side_effect=ImportError("missing")):
            self.assertFalse(setup_models.check_accelerator_runtime("npu"))
            self.assertIn("Missing or unusable accelerator", output.call_args.args[0])

    def test_directml_runtime_requires_the_dml_provider(self):
        imported = mock.Mock()
        imported.get_available_providers.return_value = ["CPUExecutionProvider"]
        with mock.patch.object(setup_models.importlib, "import_module", return_value=imported), \
                mock.patch.object(setup_models.importlib.metadata, "version",
                                  side_effect=lambda package: {
                                      "onnx": "1.23.1", "kaldi-native-fbank": "1.22.3",
                                      "onnxruntime-directml": "1.24.4",
                                  }[package]), mock.patch("builtins.print"):
            self.assertFalse(setup_models.check_accelerator_runtime("amd-gpu"))

    def test_accelerator_factory_never_constructs_cpu_recognizer(self):
        for device in ("npu", "intel-gpu", "amd-gpu"):
            args = transcribe.parse_args([
                "--input", "a.mkv", "--output-dir", "out", "--model-dir", "models",
                "--ffmpeg", "ffmpeg", "--ffprobe", "ffprobe", "--device", device,
            ])
            native = mock.Mock()
            with mock.patch.object(accelerator, "AcceleratedSenseVoice") as factory:
                result = transcribe.create_recognizer(native, args, "sensevoice")
            self.assertIs(result, factory.return_value)
            native.OfflineRecognizer.from_sense_voice.assert_not_called()

    @unittest.skipUnless(importlib.util.find_spec("numpy"), "numpy not installed")
    def test_lfr_repeats_edges_and_keeps_last_frame(self):
        import numpy as np
        frames = np.arange(10, dtype=np.float32).reshape(10, 1)
        result = accelerator.stack_frames(frames, 7, 6)
        np.testing.assert_array_equal(result, [[0, 0, 0, 0, 1, 2, 3], [3, 4, 5, 6, 7, 8, 9]])
        np.testing.assert_array_equal(accelerator.stack_frames(frames[:1], 7, 6), [[0] * 7])


@unittest.skipUnless(importlib.util.find_spec("openvino"), "optional OpenVINO not installed")
class StaticGraphTests(unittest.TestCase):
    def test_runtime_length_mask_is_preserved(self):
        import numpy as np
        import openvino as ov
        ops = ov.opset13
        x = ops.parameter([-1, -1, 560], np.float32, name="x")
        length = ops.parameter([-1], np.int32, name="x_length")
        language = ops.parameter([-1], np.int32, name="language")
        text_norm = ops.parameter([-1], np.int32, name="text_norm")
        for p in (x, length, language, text_norm):
            p.output(0).get_tensor().set_names({p.friendly_name})
        bound = ops.reduce_max(ops.add(length, ops.constant(np.int32(4))), [0], False)
        positions = ops.range(ops.constant(np.int32(0)), bound, ops.constant(np.int32(1)),
                              "i32", name="/encoder/Range")
        mask = ops.less(positions, ops.add(length, ops.constant(np.int32(4))))
        model = ov.Model([mask], [x, length, language, text_norm])
        transformed = accelerator.static_openvino_model(model, 8, 3, 14)
        self.assertEqual({p.any_name for p in transformed.inputs}, {"x", "x_length"})
        compiled = ov.Core().compile_model(transformed, "CPU", {"INFERENCE_NUM_THREADS": 1})
        for actual in (1, 5, 8):
            result = compiled({"x": np.zeros((1, 8, 560), np.float32),
                               "x_length": np.array([actual], np.int32)})[0]
            np.testing.assert_array_equal(result, np.arange(12) < actual + 4)


if __name__ == "__main__":
    unittest.main()
