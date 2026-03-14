# 豆包 API 配置说明

豆包支持**一个 API Key 调用多服务**（视觉 + Chat + TTS）。参数需从火山引擎控制台获取，请勿使用他人或过期的示例值。

## 官方获取渠道

| 参数 | 获取位置 |
|------|----------|
| **DOUBAO_API_KEY** | [火山方舟](https://console.volcengine.com/ark) → API-KEY 管理 → 创建 Key |
| **DOUBAO_ARK_MODEL** | [火山方舟](https://console.volcengine.com/ark) → 快捷 API 接入 → 选择模型后，Rest API 中的 `model` 值，如 `doubao-seed-2-0-pro-260215` |
| **DOUBAO_ASR_APPID** | [豆包语音控制台](https://console.volcengine.com/speech) → 应用管理 |
| **DOUBAO_ASR_ACCESS_KEY** | 同上，与 APPID 配套 |

## 必填参数（AI 引导问题 / 视觉 / Chat）

```bash
export DOUBAO_API_KEY=你的豆包API_Key
export DOUBAO_ARK_MODEL=doubao-seed-2-0-pro-260215   # 快捷 API 接入页选择模型后自动填入
```

## 边说边识别（大模型流式 ASR）

使用 [大模型流式语音识别 API](https://www.volcengine.com/docs/6561/1354869)，鉴权与录音转写相同（App ID + Access Key）：

```bash
export DOUBAO_ASR_APPID=xxx
export DOUBAO_ASR_ACCESS_KEY=xxx
# 可选，默认 volc.seedasr.sauc.duration（2.0 小时版）
# export DOUBAO_ASR_RESOURCE_ID=volc.seedasr.sauc.duration
```

配置后，Web 端录音时会自动使用豆包大模型流式识别实现边说边显示。未配置时则回退到浏览器 Web Speech API。

## 录音转写（ASR，录完后识别）

需在 [豆包语音控制台](https://console.volcengine.com/speech) 开通**录音文件识别大模型**标准版或极速版：

```bash
export DOUBAO_ASR_APPID=xxx
export DOUBAO_ASR_ACCESS_KEY=xxx
```

## 启动示例

```bash
export DOUBAO_API_KEY=你的Key
export DOUBAO_ARK_ENDPOINT_ID=ep-xxxxxxxx
export DOUBAO_ASR_APPID=xxx
export DOUBAO_ASR_ACCESS_KEY=xxx

./run_all.sh
```

## 若 TTS 需单独配置

若豆包语音 TTS 需单独 AppID/Token/Cluster：

```bash
export DOUBAO_TTS_APPID=xxx
export DOUBAO_TTS_TOKEN=xxx
export DOUBAO_TTS_CLUSTER=xxx
```

## 兼容旧配置

- `DOUBAO_ARK_API_KEY` 等同于 `DOUBAO_API_KEY`

## 常见问题

- **参数报错**：请核对控制台中的实际格式，勿使用 demo 或过期示例值  
- **服务端报错**：可联系豆包技术支持（火山引擎）协助排查
