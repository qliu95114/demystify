import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import unittest
from unittest import mock
import uuid


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "transcribe.py"
sys.path.insert(0, str(SCRIPT.parent))
SPEC = importlib.util.spec_from_file_location("video_srt_transcribe", SCRIPT)
engine = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(engine)


class FileTest(unittest.TestCase):
    def setUp(self):
        self.root = Path(__file__).parent / (".test-" + uuid.uuid4().hex)
        self.root.mkdir()
        self.addCleanup(shutil.rmtree, self.root)

    def args(self, **updates):
        values = dict(
            ffmpeg="ffmpeg", ffprobe="ffprobe", input=str(self.root),
            output_dir=str(self.root / "output"), model_dir=str(self.root / "models"),
            language="auto", backend="auto", device="cpu", gpu_device_id=-1,
            accelerator_name="CPU", threads=4, audio_stream=0, chunk_seconds=10,
            recurse=False, skip_music=True, force=False, allow_aac_encode=False,
        )
        values.update(updates)
        return type("Args", (), values)()

    def source(self, name="sample.mp4"):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"source video fixture")
        return path


class FormattingTests(unittest.TestCase):
    def test_timestamp_beyond_day(self):
        self.assertEqual(engine.timestamp(90061.123), "25:01:01,123")
        self.assertEqual(engine.timestamp(59.9996), "00:01:00,000")
        self.assertEqual(engine.timestamp(-1), "00:00:00,000")

    def test_punctuation_unicode_markup_arrow(self):
        self.assertEqual(engine.clean_text("……！ --><|zh|>"), "")
        self.assertEqual(engine.clean_text("<i>你好</i> --> 世界"), "你好 → 世界")
        self.assertEqual(engine.clean_text("こんにちは 안녕 café"), "こんにちは 안녕 café")

    def test_overlap_preserves_early_words(self):
        cues = engine.make_cues([
            {"start": -1, "end": 3, "text": "early words"},
            {"start": 2, "end": 4, "text": "later words"},
            {"start": 4, "end": 5, "text": "？！"},
            {"start": 7, "end": 9, "text": "outside"},
        ], 6)
        self.assertEqual(len(cues), 2)
        self.assertIn("early", cues[0]["text"])
        self.assertIn("later", cues[1]["text"])
        self.assertLessEqual(cues[0]["end_ms"], cues[1]["start_ms"])
        self.assertEqual(cues[0]["start_ms"], 0)

    def test_context_duplicate_and_long_cues(self):
        rows = [
            {"start": 0, "end": 4, "text": "你好世界", "chunk": 0},
            {"start": 2, "end": 6, "text": "你好世界", "chunk": 1},
            {"start": 6, "end": 27, "text": "这是较长的字幕。" * 20, "chunk": 1},
        ]
        cues = engine.make_cues(rows, 25)
        self.assertEqual(sum("你好世界" in row["text"] for row in cues), 1)
        for cue in cues:
            self.assertGreater(cue["end_ms"], cue["start_ms"])
            self.assertLessEqual(cue["end_ms"], 25000)
            self.assertLessEqual(cue["end_ms"] - cue["start_ms"], 7000)
            self.assertTrue(all(len(line) <= 21 for line in cue["text"].splitlines()))
        self.assertEqual(engine.render_srt([]), "")

    def test_partial_boundary_duplicate_keeps_later_words(self):
        cues = engine.make_cues([
            {"start": 298, "end": 305, "text": "hello world", "chunk": 0},
            {"start": 298, "end": 310, "text": "hello world again", "chunk": 1},
        ], 320)
        self.assertEqual(cues[0]["text"], "hello world")
        self.assertEqual(cues[1]["text"], "again")
        self.assertEqual(cues[1]["start_ms"], 305000)

    def test_one_to_many_chunk_segmentation_does_not_repeat_text(self):
        cues = engine.make_cues([
            {"start": 290, "end": 305, "text": "one two three four five six", "chunk": 0},
            {"start": 295, "end": 301, "text": "three four", "chunk": 1},
            {"start": 301, "end": 310, "text": "five six seven eight", "chunk": 1},
        ], 320)
        actual = " ".join(" ".join(cue["text"].split()) for cue in cues)
        self.assertEqual(actual, "one two three four five six seven eight")

    def test_many_to_one_chunk_segmentation_ignores_punctuation(self):
        cues = engine.make_cues([
            {"start": 290, "end": 299, "text": "One, two three four.", "chunk": 0},
            {"start": 299, "end": 305, "text": "Five six.", "chunk": 0},
            {"start": 295, "end": 310, "text": "three four five six seven eight.", "chunk": 1},
        ], 320)
        text, _ = engine.comparable_text(" ".join(cue["text"] for cue in cues))
        self.assertEqual(text, "onetwothreefourfivesixseveneight")

    def test_nonoverlapping_repeated_speech_is_not_removed(self):
        cues = engine.make_cues([
            {"start": 1, "end": 2, "text": "Yes.", "chunk": 0},
            {"start": 3, "end": 4, "text": "Yes.", "chunk": 1},
        ], 10)
        self.assertEqual(len(cues), 2)


class TimelineTests(unittest.TestCase):
    def metadata(self, origin=0, audio_start=0):
        return {
            "format": {"start_time": str(origin), "duration": "20"},
            "streams": [
                {"codec_type": "video", "start_time": str(origin), "duration": "20"},
                {"codec_type": "audio", "index": 1, "start_time": str(audio_start),
                 "duration": "18", "codec_name": "aac", "sample_rate": "48000"},
            ],
        }

    def test_positive_and_negative_origin(self):
        for origin, start, expected in [(10, 12, 2), (-5, -3, 2), (0, -0.2, -0.2)]:
            with self.subTest(origin=origin):
                value = engine.timeline(self.metadata(origin, start), 0, {"pts_time": str(start)})
                self.assertAlmostEqual(value["audio_offset"], expected)
                self.assertEqual(value["video_duration"], 20)

    def test_priming(self):
        packet = {"pts_time": "-0.0213333333333", "side_data_list": [{"skip_samples": 1024}]}
        self.assertAlmostEqual(engine.audible_start(packet, {"sample_rate": "48000"}), 0)

    def test_stream_fallback_and_rejection(self):
        value = engine.timeline(self.metadata(10, 12), 0, {})
        self.assertEqual(value["audio_offset"], 2)
        with self.assertRaises(engine.EngineError):
            engine.timeline(self.metadata(), 1, {})
        data = self.metadata()
        data["streams"] = data["streams"][:1]
        with self.assertRaises(engine.EngineError):
            engine.timeline(data, 0, {})

    def test_gap_recovery_only_acoustic_uncovered(self):
        rows = [{"start": 0, "end": 2, "text": "speech"}]
        tags = [{"start": 0, "end": 5, "speech": 0.8, "singing": 0}]
        regions = engine.recovery_regions(rows, tags, 10)
        self.assertEqual(len(regions), 1)
        self.assertGreaterEqual(regions[0][0], int(1.9 * engine.RATE))
        self.assertEqual(engine.recovery_regions(rows, [], 10), [])


class SafetyTests(FileTest):
    def test_duplicate_stems_case_insensitive(self):
        self.source("movie.mp4")
        self.source("movie.mkv")
        with self.assertRaisesRegex(engine.EngineError, "collision"):
            engine.plan_inputs(self.root, self.root / "out")

    def test_recursion_preserves_folders(self):
        self.source("one/movie.mp4")
        self.source("two/movie.mkv")
        planned = engine.plan_inputs(self.root, self.root / "out", True)
        self.assertEqual(len(planned), 2)
        self.assertEqual({item[1]["srt"].parent.name for item in planned}, {"one", "two"})

    def test_hardlinked_input_protection(self):
        source = self.source()
        output = self.root / "out"
        output.mkdir()
        os.link(source, output / "sample.m4a")
        with self.assertRaisesRegex(engine.EngineError, "overwrite an input"):
            engine.plan_inputs(source, output)

    def test_content_change_invalidates_even_same_stat(self):
        source = self.source()
        before = engine.source_signature(source)
        stat = source.stat()
        source.write_bytes(b"X" * stat.st_size)
        os.utime(source, ns=(stat.st_atime_ns, stat.st_mtime_ns))
        after = engine.source_signature(source)
        self.assertNotEqual(before["sha256"], after["sha256"])
        self.assertNotEqual(engine.digest(before), engine.digest(after))

    def test_unrelated_and_modified_outputs_refused_even_force(self):
        output = self.root / "sample.srt"
        output.write_text("user subtitle", encoding="utf-8")
        with self.assertRaisesRegex(engine.EngineError, "unrelated"):
            engine.ensure_owned({"srt": output}, {"key": "x"}, True, "x")
        state = {"key": "x", "artifacts": {
            "srt": {"path": engine.canonical(output), "sha256": engine.file_hash(output)}
        }}
        engine.ensure_owned({"srt": output}, state, False, "x")
        with self.assertRaisesRegex(engine.EngineError, "settings changed"):
            engine.ensure_owned({"srt": output}, state, False, "new")
        engine.ensure_owned({"srt": output}, state, True, "new")
        output.write_text("modified", encoding="utf-8")
        with self.assertRaisesRegex(engine.EngineError, "modified"):
            engine.ensure_owned({"srt": output}, state, True, "x")

    def test_unsupported_audio_requires_consent(self):
        args = self.args()
        mapping = {"codec": "opus", "source_audio_audible_start": 10}
        with self.assertRaisesRegex(engine.EngineError, "--allow-aac-encode"):
            engine.extraction_command("input", "output", mapping, args)
        args.allow_aac_encode = True
        command = engine.extraction_command("input", "output", mapping, args)
        self.assertIn("192k", command)
        mapping["codec"] = "aac"
        command = engine.extraction_command("input", "output", mapping, args)
        self.assertIn("copy", command)
        self.assertNotIn("192k", command)
        self.assertIn("-10", command)

    def test_atomic_and_pending_journal(self):
        destination = self.root / "result.srt"
        staged = self.root / "staged"
        state_path = self.root / "ownership.json"
        state = {"key": "test", "artifacts": {}}
        engine.atomic_bytes(staged, b"subtitle")
        engine.publish(destination, staged, "srt", state, state_path)
        self.assertEqual(destination.read_bytes(), b"subtitle")
        self.assertNotIn("pending", engine.load_json(state_path))
        state["pending"] = {
            "kind": "srt", "record": state["artifacts"]["srt"], "previous": None,
        }
        state["artifacts"] = {}
        engine.reconcile_pending(state, {"srt": destination}, state_path)
        self.assertIn("srt", state["artifacts"])

    def test_publication_rechecks_new_user_subtitle(self):
        destination = self.root / "result.srt"
        staged = self.root / "staged"
        state = {"key": "test", "artifacts": {}}
        engine.ensure_owned({"srt": destination}, state, False, "test")
        destination.write_text("created during inference", encoding="utf-8")
        staged.write_text("generated subtitle", encoding="utf-8")
        with self.assertRaisesRegex(engine.EngineError, "unrelated"):
            engine.publish(destination, staged, "srt", state, self.root / "ownership.json")
        self.assertEqual(destination.read_text(), "created during inference")

    def test_lock_exclusion(self):
        lock = self.root / "lock"
        with engine.file_lock(lock):
            with self.assertRaises(engine.EngineError):
                with engine.file_lock(lock):
                    self.fail("second lock acquired")

    def test_mocked_no_speech_completion_and_reuse(self):
        source = self.source()
        args = self.args()
        outputs = engine.plan_inputs(source, args.output_dir)[0][1]
        metadata = TimelineTests().metadata()
        mapping = {
            **engine.timeline(metadata, 0, {"pts_time": "0"}),
            "m4a_duration": 1, "decode_to_video_offset": 0,
        }
        model = mock.Mock()
        model.execution_details.return_value = {"asr_device": "CPU"}
        model.analyze.return_value = ([], [])

        def fake_run(command, binary=False):
            Path(command[-1]).write_bytes(b"generated audio")
            return ""

        with mock.patch.object(engine, "probe", return_value=metadata), \
                mock.patch.object(engine, "first_packet", return_value={"pts_time": "0"}), \
                mock.patch.object(engine, "verify_audio", return_value=mapping), \
                mock.patch.object(engine, "run", side_effect=fake_run), \
                mock.patch.object(engine, "decode", return_value=[0.0]), \
                mock.patch("builtins.print"):
            result = engine.process_file(source, outputs, args, {"test": 1}, lambda: model)
            self.assertEqual(result, "no_speech")
            self.assertEqual(outputs["srt"].read_text(), "")
            self.assertEqual(engine.load_json(outputs["manifest"])["status"], "no_speech")
            performance = engine.load_json(outputs["manifest"])["performance"]
            self.assertEqual(performance["computed_chunks"], 1)
            self.assertEqual(performance["cached_chunks"], 0)
            model.analyze.assert_called_once()
            engine.process_file(source, outputs, args, {"test": 1}, lambda: self.fail("loaded on reuse"))
            self.assertEqual(engine.load_json(outputs["manifest"])["backend"], "sensevoice")
            args.backend = "whisper"
            with self.assertRaisesRegex(engine.EngineError, "settings changed"):
                engine.process_file(source, outputs, args, {"test": 1}, lambda: self.fail("loaded stale backend"))
            args.backend = "sensevoice"
            args.device = "npu"
            with self.assertRaisesRegex(engine.EngineError, "settings changed"):
                engine.process_file(source, outputs, args, {"test": 1}, lambda: self.fail("reused CPU results as NPU"))

    def test_interrupted_chunk_resumes_without_completed_manifest(self):
        source = self.source()
        args = self.args()
        outputs = engine.plan_inputs(source, args.output_dir)[0][1]
        metadata = TimelineTests().metadata()
        mapping = {**engine.timeline(metadata, 0, {"pts_time": "0"}),
                   "m4a_duration": 20, "decode_to_video_offset": 0}
        model = mock.Mock()
        model.execution_details.return_value = {"asr_device": "CPU"}
        model.analyze.side_effect = [([], []), KeyboardInterrupt()]

        def fake_run(command, binary=False):
            Path(command[-1]).write_bytes(b"generated audio")
            return ""

        with mock.patch.object(engine, "probe", return_value=metadata), \
                mock.patch.object(engine, "first_packet", return_value={"pts_time": "0"}), \
                mock.patch.object(engine, "verify_audio", return_value=mapping), \
                mock.patch.object(engine, "run", side_effect=fake_run), \
                mock.patch.object(engine, "decode", return_value=[0.0]), \
                mock.patch("builtins.print"):
            with self.assertRaises(KeyboardInterrupt):
                engine.process_file(source, outputs, args, {"test": 1}, lambda: model)
            self.assertFalse(outputs["manifest"].exists())
            self.assertFalse(outputs["srt"].exists())
            model.analyze.side_effect = None
            model.analyze.return_value = ([], [])
            model.analyze.reset_mock()
            engine.process_file(source, outputs, args, {"test": 1}, lambda: model)
            model.analyze.assert_called_once()
            self.assertTrue(outputs["manifest"].exists())
            performance = engine.load_json(outputs["manifest"])["performance"]
            self.assertEqual(performance["computed_chunks"], 1)
            self.assertEqual(performance["cached_chunks"], 1)


@unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "ffmpeg/ffprobe not installed")
class MediaIntegrationTests(FileTest):
    def fixture(self, name, offset=0, codec="aac"):
        source = self.root / name
        engine.run([
            "ffmpeg", "-v", "error", "-nostdin", "-y",
            "-f", "lavfi", "-i", "color=c=black:s=32x32:r=10:d=3",
            "-itsoffset", "0.5", "-f", "lavfi", "-i", "sine=frequency=500:duration=2",
            "-map", "0:v:0", "-map", "1:a:0", "-c:v", "mpeg4",
            "-c:a", codec, "-output_ts_offset", str(offset), source,
        ])
        return source

    def extract(self, source, args):
        metadata = engine.probe(source, args.ffprobe)
        packet = engine.first_packet(source, 0, args.ffprobe)
        mapping = engine.timeline(metadata, 0, packet)
        if mapping["expected_audio_duration"] is None:
            mapping["expected_audio_duration"] = engine.packet_audio_duration(
                source, 0, mapping["source_audio_audible_start"], args.ffprobe)
        output = self.root / "audio.m4a"
        engine.run(engine.extraction_command(source, output, mapping, args))
        return engine.verify_audio(output, mapping, args)

    def test_real_copy_delayed_audio_and_nonzero_origin(self):
        for offset in (0, 10):
            with self.subTest(offset=offset):
                source = self.fixture(f"sample-{offset}.mp4", offset)
                mapping = self.extract(source, self.args())
                self.assertEqual(mapping["extraction_mode"], "copy")
                self.assertAlmostEqual(mapping["decode_to_video_offset"], 0.5, delta=0.04)
                self.assertAlmostEqual(mapping["m4a_audible_start"], 0, delta=0.03)
                self.assertAlmostEqual(mapping["video_duration"], 3, delta=0.1)

    def test_real_explicit_non_aac_encode(self):
        source = self.fixture("sample.mkv", codec="pcm_s16le")
        args = self.args(allow_aac_encode=True)
        mapping = self.extract(source, args)
        self.assertEqual(mapping["extraction_mode"], "aac_192k")
        self.assertAlmostEqual(mapping["decode_to_video_offset"], 0.5, delta=0.04)

    def test_unknown_duration_measures_shorter_audio_not_video(self):
        source = self.root / "long-video-short-audio.mkv"
        engine.run([
            "ffmpeg", "-v", "error", "-nostdin", "-y",
            "-f", "lavfi", "-i", "color=c=black:s=32x32:r=10:d=10",
            "-itsoffset", "2", "-f", "lavfi", "-i", "sine=frequency=500:duration=2",
            "-map", "0:v:0", "-map", "1:a:0", "-c:v", "mpeg4", "-c:a", "aac", source,
        ])
        metadata = engine.probe(source, "ffprobe")
        initial = engine.timeline(metadata, 0, engine.first_packet(source, 0, "ffprobe"))
        self.assertIsNone(initial["expected_audio_duration"])
        mapping = self.extract(source, self.args())
        self.assertAlmostEqual(mapping["expected_audio_duration"], 2, delta=0.1)
        self.assertAlmostEqual(mapping["m4a_duration"], 2, delta=0.1)
        self.assertAlmostEqual(mapping["video_duration"], 10, delta=0.1)
        self.assertAlmostEqual(mapping["decode_to_video_offset"], 2, delta=0.04)


if __name__ == "__main__":
    unittest.main()
