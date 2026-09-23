import hashlib
import importlib.util
import io
import json
import sys
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "setup_models.py"
sys.path.insert(0, str(SCRIPT.parent))
SPEC = importlib.util.spec_from_file_location("setup_models", SCRIPT)
setup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(setup)


class ModelSetupTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.data = b"synthetic model, not executable"
        self.checksum = hashlib.sha256(self.data).hexdigest()
        self.files = {"package/model.onnx": self.checksum}
        self.manifest = self.root / "models.json"
        self.manifest.write_text(json.dumps({"models": [{
            "name": "fixture", "url": "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/test",
            "archive": True, "optional_music": False, "files": self.files,
        }]}), encoding="utf-8")
        self.patch = patch.object(setup, "MANIFEST", self.manifest)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def archive(self, name="package/model.onnx", payload=None, link=False, duplicate=False):
        path = self.root / "fixture.tar.bz2"
        with tarfile.open(path, "w:bz2") as archive:
            entry = tarfile.TarInfo(name)
            data = self.data if payload is None else payload
            entry.size = len(data)
            if link:
                entry.type = tarfile.SYMTYPE
                entry.linkname = "..\\outside"
            archive.addfile(entry, io.BytesIO(data))
            if duplicate:
                archive.addfile(entry, io.BytesIO(data))
            ignored = tarfile.TarInfo("../unrequested.txt")
            ignored.size = 7
            archive.addfile(ignored, io.BytesIO(b"ignored"))
        return path

    def test_reject_unsafe_manifest_paths(self):
        for value in ("../model", "/root/model", "C:/model", "pkg\\model"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                setup.relative_path(value)

    def test_only_expected_regular_files_extracted(self):
        staging = self.root / "stage"
        staging.mkdir()
        setup.extract_required(self.archive(), self.files, staging)
        self.assertEqual((staging / "package" / "model.onnx").read_bytes(), self.data)
        self.assertFalse((self.root / "unrequested.txt").exists())

    def test_link_duplicate_and_missing_rejected(self):
        for settings in ({"link": True}, {"duplicate": True}, {"name": "unrelated"}):
            with self.subTest(settings=settings), self.assertRaises(ValueError):
                setup.extract_required(self.archive(**settings), self.files, self.root)

    def test_import_then_no_network_cache_reuse(self):
        source = self.root / "existing"
        (source / "package").mkdir(parents=True)
        (source / "package" / "model.onnx").write_bytes(self.data)
        target = self.root / "cache"
        with patch.object(setup, "download") as download:
            setup.provision(target, source=source)
            setup.provision(target)
            download.assert_not_called()
        self.assertTrue(setup.valid(target / "package" / "model.onnx", self.checksum))

    def test_missing_model_requires_permission(self):
        with self.assertRaises(FileNotFoundError):
            setup.provision(self.root / "cache")

    def test_backend_scopes_model_requirements(self):
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        manifest["models"][0]["backends"] = ["sensevoice"]
        manifest["models"].append({
            "name": "whisper-fixture", "backends": ["whisper"], "archive": True,
            "optional_music": False, "url": manifest["models"][0]["url"],
            "files": {"whisper/model.onnx": self.checksum},
        })
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")
        source = self.root / "existing"
        (source / "whisper").mkdir(parents=True)
        (source / "whisper" / "model.onnx").write_bytes(self.data)
        target = self.root / "cache"
        with patch.object(setup, "download") as download:
            setup.provision(target, source=source, language="fr")
            download.assert_not_called()
        self.assertTrue((target / "whisper" / "model.onnx").is_file())
        self.assertFalse((target / "package").exists())
        with self.assertRaises(FileNotFoundError):
            setup.provision(target, backend="sensevoice")

    def test_mismatched_download_does_not_replace_existing(self):
        target = self.root / "cache"
        (target / "package").mkdir(parents=True)
        model = target / "package" / "model.onnx"
        model.write_bytes(b"existing invalid but must survive failed replacement")
        archive = self.archive(payload=b"tampered")

        def fake_download(url, destination):
            destination.write_bytes(archive.read_bytes())

        with patch.object(setup, "download", side_effect=fake_download), self.assertRaises(ValueError):
            setup.provision(target, allow_download=True)
        self.assertEqual(model.read_bytes(), b"existing invalid but must survive failed replacement")
        self.assertEqual(list(target.glob(".model-stage-*")), [])

    def test_reject_unexpected_download_origin(self):
        with self.assertRaises(ValueError):
            setup.download("https://example.com/model", self.root / "out")


if __name__ == "__main__":
    unittest.main()
