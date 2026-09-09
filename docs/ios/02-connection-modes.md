# iOS · 三种连接模式

> 对齐 Android `ConnectionMode`（`MainViewModel.kt:48`，仅 Wifi/Usb）+
> 桌面 `web_server.rs`（Web 模式）。iOS 新增 Web 模式。

## 1. 模式总览

| 模式 | 传输 | 目标地址 | 发现 | UDP 音频 | 对齐 |
|---|---|---|---|---|---|
| **Wi-Fi** | TCP 8554 + UDP 8555 | 用户/mDNS 给的 LAN IP | mDNS `_micyou._tcp.` | 是（Both 模式） | Android `Wifi` |
| **USB** | TCP 8554 + UDP 8555 | `127.0.0.1` | 无（iproxy 转发） | 是（Both 模式） | Android `Usb`（adb reverse → iproxy） |
| **Web** | `wss://<ip>:8443/ws` | 用户给的主机:webPort | 无（手填） | 否（WebSocket 二进制） | 桌面 `web_server.rs` |

> `TransportProtocol`：`Tcp`（仅 TCP）/ `Both`（TCP+UDP）。UDP 音频仅
> `mode == Wi-Fi && transport == Both`（与 `AudioEngine.kt:672` 一致）。USB 模式
> 走 `127.0.0.1`，UDP 同样可用（iproxy 转发两端口）。

## 2. Wi-Fi 模式

### 2.1 流程
1. （可选）mDNS 浏览 `_micyou._tcp.`，解析出 `{name, host, port}`，用户点选填入 IP/端口。
2. TCP 连 `host:port`，完成 §2 握手（`01-wire-protocol.md`）。
3. UDP 连 `host:(port+1)`（`DatagramSocket` → `NWConnection(.udp)`）。
4. 启动采集 → Opus → 音频包经 **UDP** 发送，控制消息（mute/ping/pong）经 **TCP**。
5. TCP reader 收 mute/ping，回 pong。

### 2.2 mDNS 发现（iOS）
- 用 `NetServiceBrowser` 浏览 `_micyou._tcp.`（`NetService` 解析 host/port）。
- 对齐 Android `DeviceDiscoveryManager`（`DeviceDiscovery.kt`）：维护
  `[DiscoveredDevice]` 列表 + `isDiscovering` 状态，服务 lost 时移除。
- 本地网络权限：iOS 14+ 首次 mDNS 浏览触发 **本地网络隐私** 提示，需
  `Info.plist` `NSBonjourServices = ["_micyou._tcp"]` + `NSLocalNetworkUsageDescription`。

### 2.3 与 Android 对应
| Android (`DeviceDiscovery.kt`) | iOS |
|---|---|
| `NsdManager.discoverServices("_micyou._tcp.", ...)` | `NetServiceBrowser` + service type `_micyou._tcp.` |
| `ResolveListener.onServiceResolved` | `NetService.addressResolution` / `netServiceDidResolveAddress` |
| `MutableStateFlow<List<DiscoveredDevice>>` | `@Published var discoveredDevices` |

## 3. USB 模式（iproxy）

### 3.1 背景
Android USB 模式靠桌面端 `adb reverse <port> <port>` 把手机端口转发到桌面，手机连
`127.0.0.1:port`。**iOS 无 adb**，等价物是 **`iproxy`**（libimobiledevice 工具）：
Mac 端运行 `iproxy <port> <port>` 把 Mac 的 `127.0.0.1:port` 转发到 USB 连接的 iPhone 的 `port`。
iPhone 端代码与 Wi-Fi 完全相同，只是目标 IP 固定 `127.0.0.1`（`AudioEngine.kt:646`）。

### 3.2 Mac 端一次性设置（文档说明，非 iOS 代码）
```bash
brew install libimobiledevice          # 提供 iproxy
iproxy 8554 8554 &                     # 转发 TCP
iproxy 8555 8555 &                     # 转发 UDP（若用 Both）
```
然后 iPhone 在 app 里选 USB 模式，端口 8554，点开始。

### 3.3 备选：USB 个人热点 IP
USB tethering 会给 iPhone 分配 `172.20.10.x`，Mac 是网关 `172.20.10.1`。若不装 iproxy，
用户可直接在 Wi-Fi 模式填 Mac 的 `172.20.10.1`（本质走 tethered 路由，非真 USB 转发）。
文档提供两种方式，**推荐 iproxy**（与 Android 模型一致、延迟更低）。

### 3.4 iOS 实现
- `ConnectionMode.usb` 时，连接目标 IP 强制 `127.0.0.1`（与 `AudioEngine.kt:646` 一致）。
- 其余握手/传输/采集逻辑与 Wi-Fi 共用。

## 4. Web 模式（wss + Float32）

### 4.1 协议（来源 `web_server.rs:297-331`）
- 端点：`wss://<host>:<webPort>/ws`（默认 `webPort=8443`，`app_config.rs:166`）。
- **无 protobuf、无 magic、无握手**。
- 音频 = **二进制 WebSocket 帧**，内容为 **Float32 little-endian PCM**，48000 Hz，mono。
- 约束：`data.count <= 64 * 1024` 且 `data.count % 4 == 0`，否则桌面端丢弃。
- 桌面端把 Float32 → PCM16 后送入音频管线（`float32_to_pcm16`）。

### 4.2 iOS 实现
- `URLSessionWebSocketTask`（iOS 13+，满足 15 目标）连 `wss://` URL。
- 采集 Float32 PCM（`AVAudioPCMBuffer.floatChannelData`），按帧切片，`URLSessionWebSocketTask.send(.data(data))`。
- **自签证书**：桌面 web server 用自签 TLS。需 `URLSession` delegate 实现
  `urlSession(_:didReceive:completionHandler:)` 跳过证书校验（**仅 web 模式**，文档警示安全含义）。
- Web 模式**不发 Opus、不发 protobuf、不走 FEC**——桌面端直接消费 Float32。

### 4.3 与桌面对应
| 桌面 (`web_server.rs`) | iOS |
|---|---|
| `Message::Binary(data)` | `URLSessionWebSocketTask.send(.data(float32Data))` |
| `float32_to_pcm16(&data)` | （桌面侧做，iOS 只发 Float32） |
| `sample_rate:48000, channel_count:1, audio_format:2, codec:0` | iOS 固定 48k/mono/float 源 |

## 5. 状态流转（三模式共用）

```
Idle ──start──▶ Connecting ──handshake/WS ok──▶ Streaming
  ▲                  │                              │
  │                  │ fail                         │ mute/ping/pong
  └── stop ──────────┴── Error ─────────────────────┘
```

- `StreamState`：`idle / connecting / streaming / error`（对齐 `MainViewModel.kt:58`）。
- 任何模式失败 → `error` + 本地化错误文案（见 `04-architecture.md` 错误映射）。
- `stop()` 干净释放：关 TCP/UDP/WS、停 AVAudioEngine tap、释放 Opus encoder。

## 6. 模式选择 UI
- 三选一 segmented/Picker：Wi-Fi / USB / Web。
- Wi-Fi/USB 显示 IP（USB 灰显固定 `127.0.0.1`）+ 端口 + 传输协议（TCP/TCP+UDP）。
- Web 显示主机 + webPort（默认 8443），无传输协议选项。
- Wi-Fi 额外显示"扫描设备"按钮 + 已发现设备列表。

## 7. USB 模式排障

| 症状 | 原因 | 解决 |
|---|---|---|
| 连接超时 | iproxy 未启动 / 端口不匹配 | 确认 `iproxy 8554 8554` 正在运行；`lsof -i :8554` 检查 |
| 「信任此电脑」循环 | iOS 未信任 Mac | 设置 → 通用 → VPN与设备管理 → 信任 |
| iproxy 报 `Could not start` | 端口被占用 | `lsof -i :8554` 找占用进程，或换端口 |
| UDP 音频断续 | iproxy 仅转发 TCP | Both 模式需额外 `iproxy 8555 8555` |
| 连接成功但无声音 | 桌面端未启动 / 未选输出设备 | 确认桌面 app 已启动并选了虚拟麦克风 |

### 7.1 验证 iproxy 转发
```bash
# Mac 端检查 iproxy 进程
ps aux | grep iproxy

# 检查端口监听
lsof -i :8554    # TCP
lsof -i :8555    # UDP（Both 模式）

# 用 nc 测试 TCP 连通性（Mac 本地）
nc -z 127.0.0.1 8554 && echo "TCP OK"
```

### 7.2 iproxy vs adb reverse 对照
| Android (adb reverse) | iOS (iproxy) |
|---|---|
| `adb reverse tcp:8554 tcp:8554` | `iproxy 8554 8554` |
| 手机端 `adb` 自动管理 | Mac 端手动启动（或写 launchd plist 开机自启） |
| 转发方向：桌面→手机 | 转发方向：Mac→iPhone |
| 无需额外安装 | `brew install libimobiledevice` |

### 7.3 iproxy 开机自启（launchd）
```xml
<!-- ~/Library/LaunchAgents/top.micyou.iproxy.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>top.micyou.iproxy</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/iproxy</string>
    <string>8554</string><string>8554</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
```
```bash
launchctl load ~/Library/LaunchAgents/top.micyou.iproxy.plist
```
