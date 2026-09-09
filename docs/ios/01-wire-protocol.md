# iOS · 线上协议规范

> 事实来源：`tauri-app/crates/micyou-protocol/proto/network.proto` +
> `composeApp/.../network/Protocol.kt` + `composeApp/.../audio/AudioEngine.kt`。
> iOS 端必须逐字节、逐字段号对齐。本文件是 iOS 实现的协议契约。

## 1. 常量

| 常量 | 值 | 含义 | 来源 |
|---|---|---|---|
| `PACKET_MAGIC` | `0x4D696359`（ASCII `"MicY"`） | TCP 帧魔数 | `Protocol.kt:121` |
| `UDP_PACKET_MAGIC` | `0x4D696355`（ASCII `"MicU"`） | UDP 帧魔数 | `Protocol.kt:122` |
| `UDP_CUSTOM_HEADER_SIZE` | `8` | UDP 自定义头长度 | `Protocol.kt:123` |
| `UDP_MAX_DATAGRAM_SIZE` | `1472` | UDP 数据报上限 | `Protocol.kt:124` |
| `UDP_PCM_PAYLOAD_SIZE` | `1320` | UDP PCM 载荷预算 | `Protocol.kt:126` |
| `CODEC_PCM` | `0` | buffer 编码：PCM | `Protocol.kt:129` |
| `CODEC_OPUS` | `1` | buffer 编码：Opus | `Protocol.kt:130` |
| `UDP_PORT_OFFSET` | `1` | UDP 端口 = TCP + 1 | `Protocol.kt:133` |
| `DEFAULT_TCP_PORT` | `8554` | 默认 TCP 端口 | `Constants.kt:34` |
| `DEFAULT_UDP_PORT` | `8555` | 默认 UDP 端口 | `Constants.kt:37` |
| `MAX_PACKET_SIZE` | `2 MiB` | TCP 包上限 | `Constants.kt:28` |
| `FEC_GROUP_SIZE` | `12` | 每 12 包一组 FEC | `AudioEngine.kt:291` |
| `MAX_UDP_CONSECUTIVE_FAILURES` | `500` | UDP 熔断阈值 | `AudioEngine.kt:285` |
| `HEARTBEAT_TIMEOUT_MS` | `5000` | 心跳超时 | `AudioEngine.kt:286` |

> 端口计算 `calculateUdpPort(tcp)` = `tcp + 1`，越界（>65535）抛错。

## 2. 握手（TCP，必经）

1. 客户端 → 服务端：ASCII 字符串 `"MicYouCheck1"`（12 字节，无长度前缀）。
2. 服务端 → 客户端：ASCII 字符串 `"MicYouCheck2"`（12 字节）。不匹配则握手失败。
3. 客户端 → 服务端：`ConnectMessage{sessionId}`，按 §3 TCP 帧封装。
   - `sessionId`：进程级单调递增 `Int64`，初始 `>= 1`（`AudioEngine.kt:294` 用 `System.currentTimeMillis()` 起步）。
4. 握手成功后进入流式。

> UDP-only 模式无握手（iOS 不实现 UDP-only；Wi-Fi 走 Both=TCP+UDP，USB/Web 走 TCP/wss）。

## 3. TCP 帧格式

```
+-------------------+-------------------+---------------------------+
| PACKET_MAGIC (4B) | length     (4B)   | protobuf MessageWrapper    |
|   big-endian      |   big-endian      |   (length 字节)            |
+-------------------+-------------------+---------------------------+
```

- `length` = 后续 protobuf 字节数。
- 写：`writeInt(BE, PACKET_MAGIC) → writeInt(BE, length) → writeFully(bytes)`。
- 读：`readInt → 校验 == PACKET_MAGIC → readInt(length) → readFully(length)`。
- `length > MAX_PACKET_SIZE` 视为非法。

## 4. UDP 帧格式（仅 Wi-Fi + Both 模式，音频包）

```
+---------------------+---------------------+---------------------------+
| UDP_PACKET_MAGIC(4B)| length       (4B)   | protobuf MessageWrapper    |
|    big-endian       |    big-endian       |   (length 字节)            |
+---------------------+---------------------+---------------------------+
```

- 总长 `8 + length <= 1472`，否则拒绝发送。
- 控制消息（connect/mute/ping/pong）**不走 UDP**，只走 TCP。
- 音频包（`audioPacket != null` 且非控制消息）在 Wi-Fi+Both 下走 UDP。

## 5. Protobuf 消息（`network.proto`）

### 5.1 MessageWrapper（顶层信封）

| 字段 | proto# | 类型 | 用途 |
|---|---|---|---|
| audioPacket | 1 | `AudioPacketMessageOrdered?` | 音频包（TCP-only 模式用） |
| connect | 2 | `ConnectMessage?` | 连接建立 |
| mute | 3 | `MuteMessage?` | 静音切换 |
| (4) | — | reserved | — |
| ping | 5 | `PingMessage?` | 延迟探测 |
| pong | 6 | `PongMessage?` | 延迟应答 |
| pluginMessage | 7 | `PluginMessage?` | 跨设备插件消息（iOS 初版可忽略） |

> `hasControlMessage()` = `connect != null || mute != null || ping != null || pong != null`。
> 控制消息走 TCP；音频包在 Wi-Fi+Both 走 UDP。

### 5.2 ConnectMessage

| 字段 | proto# | 类型 | 说明 |
|---|---|---|---|
| sessionId | 1 | `int64` | 0 = 旧版客户端（无会话隔离） |

### 5.3 MuteMessage

| 字段 | proto# | 类型 | 说明 |
|---|---|---|---|
| isMuted | 1 | `optional bool` | 静音状态 |

### 5.4 PingMessage / PongMessage

| 字段 | proto# | 类型 |
|---|---|---|
| timestamp | 1 | `int64` |

> 收到 `ping` 立即回 `pong`（相同 timestamp）。5s 无 ping 视为断连。

### 5.5 AudioPacketMessageOrdered

| 字段 | proto# | 类型 | 说明 |
|---|---|---|---|
| sequenceNumber | 1 | `int32` | 音频序号（单调递增） |
| audioPacket | 2 | `AudioPacketMessage` | 音频载荷 |
| timestamp | 3 | `int64` | 发送时刻（ms） |
| fecBuffer | 4 | `bytes?` | FEC 包标记：非空（如 `[0x01]`）= FEC 包 |
| fecSequenceNumber | 5 | `int32` | FEC 组起始序号；常规包为 -1（proto3 默认省略） |
| sessionId | 6 | `int64` | 会话 ID |
| fecPacketLengths | 7 | `repeated uint32` | FEC 组内各原始包长度（变长 Opus 恢复用） |

### 5.6 AudioPacketMessage

| 字段 | proto# | 类型 | 说明 |
|---|---|---|---|
| buffer | 1 | `bytes` | 音频载荷（Opus 压缩 或 PCM） |
| sampleRate | 2 | `int32` | 采样率 |
| channelCount | 3 | `int32` | 1=Mono, 2=Stereo |
| audioFormat | 4 | `int32` | 线上格式值：2=PCM16, 3=PCM8, 4=PCM_FLOAT, 6=PCM24 |
| codec | 5 | `int32` | 0=PCM, 1=Opus |

> `audioFormat` 描述**采集格式**仅供遥测；Opus 载荷解码不依赖它。

## 6. Opus 编码参数

| 参数 | 值 | 来源 |
|---|---|---|
| 帧长 | 20 ms | `AudioEngine.kt:854` |
| 应用类型 | `OPUS_APPLICATION_VOIP` | `AudioEngine.kt:855` |
| 支持采样率 | 8000 / 12000 / 16000 / 24000 / 48000 | `OPUS_SAMPLE_RATES` |
| 44.1kHz 映射 | → 48000 | `AudioEngine.kt:547` |
| 输出缓冲 | >= 4000 字节 | `AudioEngine.kt:856` |
| 输入 | 16-bit LE Short（PCM 采集先转换） | `convertPcmToShort` |

采集 PCM（8-bit / 16-bit / float32）→ 统一转 16-bit LE Short → 累积到 20ms 帧 →
`opus_encode` → `buffer`，`codec=1`。

## 7. FEC（前向纠错）

- 每 `FEC_GROUP_SIZE=12` 个 Opus 包生成 1 个 FEC 包。
- FEC = 组内 12 个包 buffer 的 **XOR**（变长以最长为准，短包 0 填充）。
- FEC 包字段：`fecBuffer=[0x01]`（非空标记）、`fecSequenceNumber=组起始序号`、
  `fecPacketLengths=[各包原长]`、`sequenceNumber=下一序号`（不制造音频间隙）。
- FEC 包与常规包一样经 UDP 帧发送。
- iOS 端**只发送 FEC**（发送端职责）；接收/恢复在桌面端 `jitter_buffer`。

## 8. 静音

- `isMuted=true` 时：丢弃累积的 PCM（`opusPendingSamples=0`），不发音频包。
- 静音状态变化时发 `MuteMessage`（经 TCP）通知服务端。
- 桌面端也可下发 `MuteMessage` 控制客户端静音（iOS 需处理入站 mute）。

## 9. 与 Android 对应关系

| Android (`Protocol.kt` / `AudioEngine.kt`) | iOS |
|---|---|
| `ProtoBuf{}.encodeToByteArray` / `decodeFromByteArray` | SwiftProtobuf `SerializertoBytes()` / `try MessageWrapper(serializedData:)` |
| `out.writeInt(PACKET_MAGIC)` (BE) | `Data` big-endian `packInt32` |
| `DatagramPacket(header + bytes)` | `NWConnection.send(.content(data))` on `.udp` |
| `OpusEncoder` (Concentus) | `MicYouOpus` C 桥接 `opus_encoder_create/encode` |
| `xorBuffers` | Swift `Array<UInt8>` XOR |

## 10. iOS 实现要点

- 帧编解码集中在一个 `FrameCodec`，提供 `encodeTcp(wrapper) -> Data`、
  `decodeTcp(stream) -> MessageWrapper?`、`encodeUdp(wrapper) -> Data`。
- 所有整数按 **big-endian** 序列化（`Data` with `ByteOrder`/手动移位）。
- SwiftProtobuf 生成的 `MessageWrapper` 是 `SwiftProtobuf.Message`，`try serializedData()` / `init(serializedData:)`。
- `sessionId` 用 `AtomicInt64`/`OSAtomicIncrement64` 风格的进程级计数器。
