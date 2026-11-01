# 本地 Qwen 配音与硬件测试经验

以下是一次 Windows 实机测试的可复用经验，不是所有设备的永久兼容结论。
升级运行库、模型、驱动或更换硬件后，需要重新验证。
不要复制任务私有视频、文案、权重、虚拟环境或绝对工作目录到技能仓库。

## 已验证的 CPU 配音

使用 `qwen-tts==0.1.1`、`torch==2.8.0+cpu`、
`torchaudio==2.8.0+cpu`，Qwen 包对应
`transformers==4.57.3`、`accelerate==1.12.0`。
在 Intel Core Ultra 7 165H 上以 FP32、8 Torch 线程、2 interop 线程运行。
应先核对安装版本，不在工作的 ASR 环境里覆盖 Torch。

```python
import torch
from qwen_tts import Qwen3TTSModel

model = Qwen3TTSModel.from_pretrained(
    model_dir,
    device_map="cpu",
    dtype=torch.float32,
    attn_implementation="sdpa",
)
print(model.get_supported_speakers())
with torch.inference_mode():
    waves, rate = model.generate_custom_voice(
        text=text,
        language="Chinese",
        speaker="Dylan",
        instruct="用年轻清晰自然的中文男声解说。普通话，不加背景音。",
        max_new_tokens=512,
        temperature=0.75,
        top_p=0.9,
    )
```

CustomVoice 成功生成时虽有缺失 SoX／flash-attn 警告，但该路径没有因此失败；
不要仅为消除无关警告安装额外工具。其他 API 是否需要它们应单独验证。

1.7B CustomVoice 的一次下载约 4.52 GB：
主权重约 3.83 GB，语音 tokenizer 约 0.68 GB。
这不是 GPU 显存占用，磁盘权重大小不能用于保证 FP32 能装入显存。

12 句中文、最终拟合为 60 秒的历史合成记录：

| 声音 | 保留句子的合成耗时 | 原始语音长度 |
|---|---:|---:|
| Serena | 270.343 秒 | 48.24 秒 |
| Dylan | 245.329 秒 | 45.04 秒 |

以上是历史 CPU 合成累计值，不是重新进行的受控跨硬件基准；
不含加载、被替换的重试音频、ASR、混音及合轨。
成熟男声的另一次记录包含原因不明的长时间间隔，不适合宣称稳定速度。
如需完整任务耗时，应另记任务起止，不把逐句累计值当作总墙钟时间。

## AMD DirectML：实机失败而非普遍不支持

测试设备为 AMD Radeon RX 7600M XT。
隔离环境使用 `torch-directml==0.2.5.dev240914`，对应 Torch／torchaudio
2.4.1；该旧 Torch 组合使用 `numpy<2`。不要把不同版本的 torchaudio
装到同一 Torch 环境，也不要为实验降级已工作的 CPU 环境。

- FP32 在模型搬到 GPU 时显存分配失败。
- FP16 权重成功搬到明确选择的 AMD 设备，但生成遇到 inference tensor
  `version_counter` 兼容错误。
- 用等价 no-grad 执行继续测试后，token gather／concat 等步骤仍失败。
  某些底层错误以 `UnicodeDecodeError` 表现，不能简单认定是文案编码问题。
- 显式在 CPU 做 logits 处理与采样并记录次数后，仍未产生完整样音。
  这类尝试属于 AMD 模型计算＋CPU 控制，不得标成全 GPU 推理。

这证明被测试的 DirectML 路径未跑通，不证明该 GPU 在所有后端都不能 TTS。
查阅时 RX 7600M XT 不在 AMD Windows ROCm 7.2.1 官方支持表；
社区声称支持“RX 7000 系列”不能替代精确型号与驱动验证。

## Intel NPU：识别和导出不等于成功加速

OpenVINO 2026.1.0 能识别 Intel AI Boost NPU 和 Intel Arc iGPU。
官方 OpenVINO notebook 的 Qwen helper 成功把现有 CustomVoice 权重导出
为 IR，转换约 113 秒；这是转换时间，不是语音合成时间。

- 显式使用 NPU 加载完整流水线，在动态输入 encoder 的 Pad 编译中失败，
  编译器可能原生中止进程，未必留下 Python 异常报告。
- 单独给语音 decoder 固定输入 `[1, 64, 16]` 后仍编译失败；
  NPU 编译器报告内部 Equal 操作的 i8 类型不支持。
- 尝试在 IR 中提升比较输入类型没有解决编译器内部转换问题，
  因而没有可报告的完整 NPU 合成耗时。

CustomVoice 并不需要参考音频 encoder。未来适配应避免无谓编译未使用组件，
并重新导出 NPU 支持的静态图；不要把当前失败永久写成“Qwen 不支持 NPU”。
社区实现的 Intel GPU＋NPU streaming decoder 卸载是另一条路径，
与纯 NPU 不同，仍需严格验证实际组件设备和端到端时间。

## 实验报告必须保留

记录设备名称、驱动／运行库、模型与精度、实际参数或编译组件设备、
CPU 控制操作、加载与编译时间、合成时间、原始音频长度、退出码、
异常日志、检查结果和最终是否添加音轨。
异常被捕获后 shell 退出 0 不代表通过，必须读取报告的 `status`。
禁止静默回退后把 CPU 音频命名为 AMD GPU 或 Intel NPU。

## 上游资料

- [Qwen3-TTS 官方实现](https://github.com/QwenLM/Qwen3-TTS)
- [官方 OpenVINO Qwen notebook](https://github.com/openvinotoolkit/openvino_notebooks/tree/latest/notebooks/qwen3-tts)
- [AMD Windows ROCm 支持表](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityrad/windows/windows_compatibility.html)
- [Microsoft PyTorch DirectML](https://learn.microsoft.com/en-us/windows/ai/directml/pytorch-windows)
- [社区 Intel GPU＋NPU 卸载路径](https://github.com/wangtong10086/qwen3-tts-openvino/blob/main/docs/windows_gpu_npu_zh.md)
