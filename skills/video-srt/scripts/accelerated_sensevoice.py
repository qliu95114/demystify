"""Explicit SenseVoice acceleration with verified device execution and no truncation."""

import hashlib
import json
from pathlib import Path
import time
from types import SimpleNamespace

BUCKETS = (128, 432)


def select_openvino_device(core, device, requested_index=-1):
    if device == "npu":
        if "NPU" not in core.available_devices:
            raise RuntimeError(
                f"Intel NPU unavailable to OpenVINO (devices: {core.available_devices}). "
                "Check the Intel NPU driver, or explicitly use -Device cpu."
            )
        return "NPU", core.get_property("NPU", "FULL_DEVICE_NAME")
    if device != "intel-gpu":
        raise ValueError(f"OpenVINO device routing does not support {device}")
    candidates = []
    for target in core.available_devices:
        if not target.startswith("GPU"):
            continue
        name = core.get_property(target, "FULL_DEVICE_NAME")
        if "intel" in name.casefold():
            candidates.append((target, name))
    if requested_index >= 0:
        target = f"GPU.{requested_index}"
        candidates = [item for item in candidates if item[0] == target]
    if len(candidates) != 1:
        raise RuntimeError(
            f"Expected one Intel OpenVINO GPU target, found {candidates}; "
            "select its OpenVINO index with -GpuDeviceId."
        )
    return candidates[0]


def check_openvino_execution(compiled, target):
    devices = compiled.get_property("EXECUTION_DEVICES")
    devices = [devices] if isinstance(devices, str) else list(devices)
    if not devices or any(item != target for item in devices):
        raise RuntimeError(f"Refusing unexpected OpenVINO execution: requested {target}, got {devices}")
    return devices


def select_bucket(frames):
    if frames < 1:
        raise ValueError("SenseVoice requires at least one feature frame")
    for bucket in BUCKETS:
        if frames <= bucket:
            return bucket
    raise ValueError(f"{frames} feature frames exceed accelerator capacity {BUCKETS[-1]}; refusing truncation")


def stack_frames(frames, window, shift):
    import numpy as np
    if len(frames) == 0 or window < 1 or shift < 1:
        raise ValueError("Invalid filterbank frames or LFR configuration")
    centers = np.arange(0, len(frames), shift)[:, None]
    offsets = np.arange(window)[None, :] - (window - 1) // 2
    indices = np.clip(centers + offsets, 0, len(frames) - 1)
    return frames[indices].reshape(len(centers), -1)


def decode_ctc(ids, symbols, frame_shift, blank=0):
    selected, times = [], []
    previous = None
    for frame, token in enumerate(ids):
        token = int(token)
        if token != blank and token != previous:
            selected.append(symbols[token])
            times.append(frame)
        previous = token
    if len(selected) < 4:
        raise RuntimeError("SenseVoice output is missing language/emotion/event/ITN control tokens")
    if not all(token.startswith("<|") and token.endswith("|>") for token in selected[:4]):
        raise RuntimeError("Unexpected SenseVoice control tokens; refusing a corrupt transcript")
    return SimpleNamespace(
        text="".join(selected[4:]).replace("\u2581", " ").strip(),
        lang=selected[0], emotion=selected[1], event=selected[2],
        tokens=selected[4:], timestamps=[(t - 4) * frame_shift for t in times[4:]],
    )


def static_openvino_model(model, frames, language, text_norm):
    import numpy as np
    import openvino as ov
    candidate = model.clone()
    names = {port.any_name for port in candidate.inputs}
    if names != {"x", "x_length", "language", "text_norm"}:
        raise ValueError(f"Unsupported SenseVoice model inputs: {names}")
    candidate.reshape({"x": [1, frames, 560], "x_length": [1],
                       "language": [1], "text_norm": [1]})
    ranges = [op for op in candidate.get_ordered_ops()
              if op.friendly_name == "/encoder/Range" and op.get_type_name() == "Range"]
    if len(ranges) != 1:
        raise ValueError("Unsupported SenseVoice attention-mask graph")
    dtype = ranges[0].get_output_element_type(0).to_dtype()
    positions = ov.opset13.constant(np.arange(frames + 4, dtype=dtype))
    ranges[0].output(0).replace(positions.output(0))
    for name, value in (("language", language), ("text_norm", text_norm)):
        parameter = candidate.input(name).get_node()
        constant = ov.opset13.constant(np.array([value], dtype=np.int32))
        parameter.output(0).replace(constant.output(0))
        candidate.remove_parameter(parameter)
    candidate.validate_nodes_and_infer_types()
    return candidate


def file_hash(path):
    result = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def static_directml_model(model_path, destination, frames, language, text_norm):
    import numpy as np
    import onnx
    from onnx import numpy_helper
    destination = Path(destination)
    if destination.is_file():
        return destination
    model = onnx.load(str(model_path))
    inputs = {value.name: value for value in model.graph.input}
    for name, shape in {
        "x": [1, frames, 560], "x_length": [1],
        "language": [1], "text_norm": [1],
    }.items():
        dimensions = inputs[name].type.tensor_type.shape.dim
        del dimensions[:]
        for size in shape:
            dimensions.add().dim_value = size
    ranges = [node for node in model.graph.node
              if node.name == "/encoder/Range" and node.op_type == "Range"]
    if len(ranges) != 1:
        raise ValueError("Unsupported SenseVoice attention-mask graph")
    range_output = ranges[0].output[0]
    model.graph.node.remove(ranges[0])
    model.graph.initializer.append(
        numpy_helper.from_array(np.arange(frames + 4, dtype=np.int64), range_output))
    for name, value in (("language", language), ("text_norm", text_norm)):
        model.graph.initializer.append(
            numpy_helper.from_array(np.array([value], dtype=np.int32), name))
        model.graph.input.remove(inputs[name])
    onnx.checker.check_model(model)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".partial")
    onnx.save(model, str(temporary))
    temporary.replace(destination)
    return destination


def directml_session(model_path, device_id, profile_dir):
    import numpy as np
    import onnxruntime as ort
    if "DmlExecutionProvider" not in ort.get_available_providers():
        raise RuntimeError("DirectMLExecutionProvider is unavailable; rerun setup with -InstallMissing")
    options = ort.SessionOptions()
    options.enable_mem_pattern = False
    options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    options.enable_profiling = True
    options.profile_file_prefix = str(Path(profile_dir) / "directml-profile")
    options.add_session_config_entry("session.disable_cpu_ep_fallback", "1")
    session = ort.InferenceSession(
        str(model_path), sess_options=options,
        providers=[("DmlExecutionProvider", {"device_id": device_id})],
    )
    shape = session.get_inputs()[0].shape
    frames = int(shape[1])
    session.run(None, {
        "x": np.zeros((1, frames, 560), dtype=np.float32),
        "x_length": np.array([1], dtype=np.int32),
    })
    profile_path = Path(session.end_profiling())
    try:
        profile = json.loads(profile_path.read_text(encoding="utf-8"))
    finally:
        profile_path.unlink(missing_ok=True)
    providers = {
        event.get("args", {}).get("provider")
        for event in profile if event.get("cat") == "Node"
        and event.get("args", {}).get("provider")
    }
    if providers != {"DmlExecutionProvider"}:
        raise RuntimeError(f"Refusing DirectML session with non-GPU nodes: {sorted(providers)}")
    return session


class AcceleratorStream:
    def accept_waveform(self, rate, samples):
        if rate != 16000:
            raise ValueError("Accelerated SenseVoice requires 16 kHz audio")
        self.samples = samples


class AcceleratedSenseVoice:
    def __init__(self, model_path, tokens_path, language, cache_dir,
                 device, gpu_device_id=-1, accelerator_name=None):
        import kaldi_native_fbank as knf
        import numpy as np
        import onnx
        self.np, self.knf = np, knf
        self.device = device
        metadata = {p.key: p.value for p in onnx.load(str(model_path)).metadata_props}
        if metadata.get("model_type") != "sense_voice_ctc" or metadata.get("version") != "2":
            raise ValueError("Accelerator adapter requires the pinned SenseVoiceSmall v2 export")
        self.window = int(metadata["lfr_window_size"])
        self.shift = int(metadata["lfr_window_shift"])
        self.scale = 1.0 if int(metadata["normalize_samples"]) else 32768.0
        self.mean = np.fromstring(metadata["neg_mean"], sep=",", dtype=np.float32)
        self.inv_std = np.fromstring(metadata["inv_stddev"], sep=",", dtype=np.float32)
        if self.mean.size != 560 or self.inv_std.size != 560 or self.window != 7:
            raise ValueError("Unexpected SenseVoice normalization dimensions")
        self.blank = int(metadata.get("blank_id", 0))
        self.language = int(metadata[f"lang_{language}"])
        self.text_norm = int(metadata["with_itn"])
        self.symbols = {}
        for line in Path(tokens_path).read_text(encoding="utf-8").splitlines():
            token, index = line.rsplit(" ", 1)
            self.symbols[int(index)] = token
        if len(self.symbols) != int(metadata["vocab_size"]):
            raise ValueError("SenseVoice token vocabulary size mismatch")
        cache_dir = Path(cache_dir) / device
        cache_dir.mkdir(parents=True, exist_ok=True)
        self.execution = {
            "asr_device": device, "cpu_fallback": False,
            "feature_extraction_device": "CPU", "ctc_decode_device": "CPU",
            "static_frame_buckets": list(BUCKETS),
            "compilation_seconds": 0.0, "inference_seconds": 0.0,
            "feature_seconds": 0.0, "inference_calls": 0,
        }
        self.runners = {}
        if device in ("npu", "intel-gpu"):
            self._initialize_openvino(
                model_path, cache_dir, device, gpu_device_id, accelerator_name)
        elif device == "amd-gpu":
            self._initialize_directml(
                model_path, cache_dir, gpu_device_id, accelerator_name)
        else:
            raise ValueError(f"Unsupported accelerator: {device}")

    def _initialize_openvino(self, model_path, cache_dir, device,
                             gpu_device_id, accelerator_name):
        import openvino as ov
        core = ov.Core()
        target, detected_name = select_openvino_device(core, device, gpu_device_id)
        if accelerator_name and accelerator_name != detected_name:
            raise RuntimeError(
                f"Accelerator identity changed: expected {accelerator_name}, found {detected_name}")
        core.set_property({"CACHE_DIR": str(cache_dir)})
        model = core.read_model(str(model_path))
        config = ({"NPU_COMPILATION_MODE_PARAMS": "optimization-level=0"}
                  if device == "npu" else {"INFERENCE_PRECISION_HINT": "f32"})
        self.execution.update(
            asr_runtime="openvino", device_name=detected_name,
            device_id=target, openvino_version=ov.__version__,
            compilation_mode=("optimization-level=0" if device == "npu" else "FP32"),
        )
        for frames in BUCKETS:
            print(f"Preparing SenseVoice {device} bucket {frames} frames...", flush=True)
            started = time.perf_counter()
            candidate = static_openvino_model(
                model, frames, self.language, self.text_norm)
            compiled = core.compile_model(candidate, target, config)
            self.execution["execution_devices"] = check_openvino_execution(compiled, target)
            self.runners[frames] = compiled
            self.execution["compilation_seconds"] += time.perf_counter() - started

    def _initialize_directml(self, model_path, cache_dir,
                             gpu_device_id, accelerator_name):
        import importlib.metadata
        if gpu_device_id < 0:
            raise RuntimeError("AMD DirectML requires an auto-detected or explicit -GpuDeviceId")
        model_key = file_hash(model_path)[:16]
        self.execution.update(
            asr_runtime="directml", device_name=accelerator_name or "DirectML adapter",
            device_id=gpu_device_id,
            onnxruntime_directml_version=importlib.metadata.version("onnxruntime-directml"),
            execution_devices=["DmlExecutionProvider"],
            profiled_node_providers=["DmlExecutionProvider"],
        )
        for frames in BUCKETS:
            print(f"Preparing SenseVoice AMD DirectML bucket {frames} frames...", flush=True)
            started = time.perf_counter()
            static_path = static_directml_model(
                model_path, cache_dir / (
                    f"sensevoice-{model_key}-lang{self.language}-itn{self.text_norm}-{frames}.onnx"),
                frames, self.language, self.text_norm)
            self.runners[frames] = directml_session(
                static_path, gpu_device_id, cache_dir)
            self.execution["compilation_seconds"] += time.perf_counter() - started

    def create_stream(self):
        return AcceleratorStream()

    def features(self, samples):
        np, knf = self.np, self.knf
        options = knf.FbankOptions()
        options.frame_opts.samp_freq = 16000
        options.frame_opts.dither = 0
        options.frame_opts.snip_edges = True
        options.frame_opts.window_type = "hamming"
        options.mel_opts.num_bins = 80
        options.mel_opts.low_freq = 20
        options.mel_opts.high_freq = 0
        bank = knf.OnlineFbank(options)
        bank.accept_waveform(16000, np.asarray(samples, dtype=np.float32) * self.scale)
        bank.input_finished()
        if bank.num_frames_ready == 0:
            raise ValueError("Audio segment is too short for a filterbank frame")
        frames = np.stack([bank.get_frame(i) for i in range(bank.num_frames_ready)])
        return (stack_frames(frames, self.window, self.shift) + self.mean) * self.inv_std

    def decode_streams(self, streams):
        np = self.np
        for stream in streams:
            started = time.perf_counter()
            features = self.features(stream.samples)
            self.execution["feature_seconds"] += time.perf_counter() - started
            length = len(features)
            bucket = select_bucket(length)
            padded = np.zeros((1, bucket, 560), dtype=np.float32)
            padded[0, :length] = features
            feed = {"x": padded, "x_length": np.array([length], dtype=np.int32)}
            started = time.perf_counter()
            runner = self.runners[bucket]
            logits = (runner.run(None, feed)[0] if self.device == "amd-gpu"
                      else runner(feed)[0])
            self.execution["inference_seconds"] += time.perf_counter() - started
            self.execution["inference_calls"] += 1
            logits = logits[0, :length + 4]
            if not np.isfinite(logits).all():
                raise RuntimeError(
                    f"{self.device} returned non-finite logits; no transcript published")
            stream.result = decode_ctc(logits.argmax(axis=-1), self.symbols,
                                       self.shift * 0.01, self.blank)
