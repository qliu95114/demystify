"""Check the local runtime and fetch only hash-pinned model files, never media."""

import argparse
import hashlib
import importlib
import importlib.metadata
import json
from pathlib import Path, PurePosixPath
import shutil
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.request

from asr_backends import BACKENDS, LANGUAGES, resolve_backend

MANIFEST = Path(__file__).with_name("models.json")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def relative_path(value):
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "\\" in value or ":" in value:
        raise ValueError(f"Unsafe model path: {value}")
    return Path(*path.parts)


def valid(path, expected):
    return path.is_file() and not path.is_symlink() and sha256(path) == expected


def check_runtime():
    missing = []
    for name in ("numpy", "sherpa_onnx"):
        try:
            importlib.import_module(name)
        except (ImportError, OSError) as error:
            missing.append(f"{name}: {error}")
    if missing:
        print("Missing or unusable runtime: " + "; ".join(missing))
        return False
    sherpa = importlib.metadata.version("sherpa-onnx")
    numpy = importlib.metadata.version("numpy")
    major, minor = map(int, numpy.split(".")[:2])
    if sherpa != "1.13.8" or not ((1, 26) <= (major, minor) < (3, 0)):
        print(f"Runtime version mismatch: sherpa-onnx={sherpa}, numpy={numpy}")
        return False
    print(f"Local runtime ready: sherpa-onnx={sherpa}, numpy={numpy}")
    return True


def download(url, target):
    if not url.startswith("https://github.com/k2-fsa/sherpa-onnx/releases/download/"):
        raise ValueError(f"Unexpected model download source: {url}")
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "video-srt-setup"})
            with urllib.request.urlopen(request, timeout=90) as response, target.open("wb") as output:
                if not response.geturl().startswith("https://"):
                    raise ValueError("Model download redirected to an insecure URL")
                shutil.copyfileobj(response, output, length=1024 * 1024)
            return
        except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
            target.unlink(missing_ok=True)
            if attempt == 2:
                raise
            print(f"Download failed ({error}); retrying {attempt + 1}/2...", flush=True)
            time.sleep(2 ** (attempt + 1))


def extract_required(archive_path, files, staging):
    """Read named regular members only; never extract archive paths or links."""
    with tarfile.open(archive_path, mode="r:bz2") as archive:
        members = {}
        for member in archive.getmembers():
            name = member.name.removeprefix("./")
            if name in files:
                if name in members or not member.isfile() or member.size > 1024 ** 3:
                    raise ValueError(f"Unsafe or duplicate model archive member: {name}")
                members[name] = member
        if set(members) != set(files):
            raise ValueError("Model archive is missing required files")
        for name, member in members.items():
            target = staging / relative_path(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.extractfile(member) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output, length=1024 * 1024)


def provision(destination, allow_download=False, source=None, skip_music=False,
              backend="auto", language="auto"):
    backend = resolve_backend(backend, language)
    models = json.loads(MANIFEST.read_text(encoding="utf-8"))["models"]
    for model in models:
        if backend not in model.get("backends", ("sensevoice", "whisper")):
            continue
        if skip_music and model["optional_music"]:
            continue
        files = model["files"]
        if all(valid(destination / relative_path(name), checksum) for name, checksum in files.items()):
            print(f"Verified cached model: {model['name']}", flush=True)
            continue
        if not allow_download and source is None:
            raise FileNotFoundError(f"Missing/invalid model {model['name']}. Rerun with -InstallMissing.")
        destination.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=".model-stage-", dir=destination) as work:
            staging = Path(work)
            can_import = source is not None and all(
                valid(source / relative_path(name), checksum) for name, checksum in files.items())
            if can_import:
                print(f"Importing verified local model: {model['name']}", flush=True)
                for name in files:
                    target = staging / relative_path(name)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source / relative_path(name), target)
            else:
                if not allow_download:
                    raise FileNotFoundError(f"No verified local files for {model['name']}; download permission required.")
                print(f"Downloading {model['name']} (model files only)...", flush=True)
                payload = staging / "download"
                download(model["url"], payload)
                if model["archive"]:
                    extract_required(payload, files, staging)
                else:
                    if len(files) != 1:
                        raise ValueError("Non-archive model must contain exactly one file")
                    payload.replace(staging / relative_path(next(iter(files))))
            for name, checksum in files.items():
                if not valid(staging / relative_path(name), checksum):
                    raise ValueError(f"SHA-256 mismatch for {name}; refusing the model")
            for name in files:
                target = destination / relative_path(name)
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.is_symlink():
                    raise ValueError(f"Refusing model symlink: {target}")
                (staging / relative_path(name)).replace(target)
        print(f"Installed verified model: {model['name']}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-runtime", action="store_true")
    parser.add_argument("--model-dir", type=Path)
    parser.add_argument("--import-from", type=Path)
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--skip-music", action="store_true")
    parser.add_argument("--backend", choices=BACKENDS, default="auto")
    parser.add_argument("--language", choices=LANGUAGES, default="auto")
    parser.add_argument("--resolve-backend", action="store_true")
    args = parser.parse_args()
    if args.check_runtime:
        return 0 if check_runtime() else 1
    backend = resolve_backend(args.backend, args.language)
    if args.resolve_backend:
        print(backend)
        return 0
    if args.model_dir is None:
        parser.error("--model-dir is required")
    provision(args.model_dir.resolve(), args.download, args.import_from, args.skip_music,
              backend, args.language)
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    raise SystemExit(main())
