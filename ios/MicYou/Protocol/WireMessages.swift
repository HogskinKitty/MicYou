import Foundation

/// protobuf 消息模型，逐字段对齐 `network.proto` + Android `Protocol.kt`。
///
/// 编码策略：仅写入已设置（非 nil）字段；prost（桌面端）按 proto3 解码缺失字段为默认值，
/// 与本编码完全兼容。`optional` 字段用 `Optional` 跟踪显式存在性。

// MARK: - ConnectMessage  { int64 sessionId = 1; }
public struct ConnectMessage: Equatable {
    public var sessionId: Int64

    public init(sessionId: Int64 = 0) {
        self.sessionId = sessionId
    }

    public func serializedData() -> Data {
        var w = ProtoWriter()
        w.writeInt64(1, sessionId)
        return w.result()
    }

    public init(serializedData data: Data) throws {
        var r = ProtoReader(data)
        var sessionId: Int64 = 0
        while !r.isAtEnd {
            let (field, wire) = try r.readTag()
            switch field {
            case 1 where wire == 0: sessionId = try r.readInt64()
            default: try r.skip(wire)
            }
        }
        self.sessionId = sessionId
    }
}

// MARK: - MuteMessage  { optional bool isMuted = 1; }
public struct MuteMessage: Equatable {
    public var isMuted: Bool?

    public init(isMuted: Bool? = nil) {
        self.isMuted = isMuted
    }

    public func serializedData() -> Data {
        var w = ProtoWriter()
        if let v = isMuted { w.writeBool(1, v) }
        return w.result()
    }

    public init(serializedData data: Data) throws {
        var r = ProtoReader(data)
        var isMuted: Bool? = nil
        while !r.isAtEnd {
            let (field, wire) = try r.readTag()
            switch field {
            case 1 where wire == 0: isMuted = try r.readBool()
            default: try r.skip(wire)
            }
        }
        self.isMuted = isMuted
    }
}

// MARK: - PingMessage / PongMessage  { int64 timestamp = 1; }
public struct PingMessage: Equatable {
    public var timestamp: Int64

    public init(timestamp: Int64 = 0) {
        self.timestamp = timestamp
    }

    public func serializedData() -> Data {
        var w = ProtoWriter()
        w.writeInt64(1, timestamp)
        return w.result()
    }

    public init(serializedData data: Data) throws {
        var r = ProtoReader(data)
        var timestamp: Int64 = 0
        while !r.isAtEnd {
            let (field, wire) = try r.readTag()
            switch field {
            case 1 where wire == 0: timestamp = try r.readInt64()
            default: try r.skip(wire)
            }
        }
        self.timestamp = timestamp
    }
}

public struct PongMessage: Equatable {
    public var timestamp: Int64

    public init(timestamp: Int64 = 0) {
        self.timestamp = timestamp
    }

    public func serializedData() -> Data {
        var w = ProtoWriter()
        w.writeInt64(1, timestamp)
        return w.result()
    }

    public init(serializedData data: Data) throws {
        var r = ProtoReader(data)
        var timestamp: Int64 = 0
        while !r.isAtEnd {
            let (field, wire) = try r.readTag()
            switch field {
            case 1 where wire == 0: timestamp = try r.readInt64()
            default: try r.skip(wire)
            }
        }
        self.timestamp = timestamp
    }
}

// MARK: - AudioPacketMessage
// { bytes buffer=1; int32 sampleRate=2; int32 channelCount=3; int32 audioFormat=4; int32 codec=5; }
public struct AudioPacketMessage: Equatable {
    public var buffer: Data
    public var sampleRate: Int32
    public var channelCount: Int32
    public var audioFormat: Int32
    public var codec: Int32

    public init(buffer: Data, sampleRate: Int32, channelCount: Int32,
                audioFormat: Int32, codec: Int32 = WireConstants.codecPCM) {
        self.buffer = buffer
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.audioFormat = audioFormat
        self.codec = codec
    }

    public func serializedData() -> Data {
        var w = ProtoWriter()
        w.writeBytes(1, buffer)
        w.writeInt32(2, sampleRate)
        w.writeInt32(3, channelCount)
        w.writeInt32(4, audioFormat)
        w.writeInt32(5, codec)
        return w.result()
    }

    public init(serializedData data: Data) throws {
        var r = ProtoReader(data)
        var buffer = Data()
        var sampleRate: Int32 = 0
        var channelCount: Int32 = 0
        var audioFormat: Int32 = 0
        var codec: Int32 = 0
        while !r.isAtEnd {
            let (field, wire) = try r.readTag()
            switch field {
            case 1 where wire == 2: buffer = try r.readData()
            case 2 where wire == 0: sampleRate = try r.readInt32()
            case 3 where wire == 0: channelCount = try r.readInt32()
            case 4 where wire == 0: audioFormat = try r.readInt32()
            case 5 where wire == 0: codec = try r.readInt32()
            default: try r.skip(wire)
            }
        }
        self.buffer = buffer
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.audioFormat = audioFormat
        self.codec = codec
    }
}

// MARK: - AudioPacketMessageOrdered
// { int32 sequenceNumber=1; AudioPacketMessage audioPacket=2; int64 timestamp=3;
//   bytes fecBuffer=4; int32 fecSequenceNumber=5; int64 sessionId=6;
//   repeated uint32 fecPacketLengths=7; }
public struct AudioPacketMessageOrdered: Equatable {
    public var sequenceNumber: Int32
    public var audioPacket: AudioPacketMessage
    public var timestamp: Int64
    public var fecBuffer: Data?
    public var fecSequenceNumber: Int32
    public var sessionId: Int64
    public var fecPacketLengths: [UInt32]

    public init(sequenceNumber: Int32, audioPacket: AudioPacketMessage,
                timestamp: Int64 = 0, fecBuffer: Data? = nil,
                fecSequenceNumber: Int32 = -1, sessionId: Int64 = 0,
                fecPacketLengths: [UInt32] = []) {
        self.sequenceNumber = sequenceNumber
        self.audioPacket = audioPacket
        self.timestamp = timestamp
        self.fecBuffer = fecBuffer
        self.fecSequenceNumber = fecSequenceNumber
        self.sessionId = sessionId
        self.fecPacketLengths = fecPacketLengths
    }

    /// 是否为 FEC 包：fecBuffer 非空。对齐 `AudioEngine.kt:992`。
    public var isFec: Bool { fecBuffer != nil && !fecBuffer!.isEmpty }

    public func serializedData() -> Data {
        var w = ProtoWriter()
        w.writeInt32(1, sequenceNumber)
        w.writeMessage(2, audioPacket.serializedData())
        w.writeInt64(3, timestamp)
        if let fb = fecBuffer { w.writeBytes(4, fb) }
        w.writeInt32(5, fecSequenceNumber)
        w.writeInt64(6, sessionId)
        w.writePackedUInt32(7, fecPacketLengths)
        return w.result()
    }

    public init(serializedData data: Data) throws {
        var r = ProtoReader(data)
        var sequenceNumber: Int32 = 0
        var audioPacket: AudioPacketMessage?
        var timestamp: Int64 = 0
        var fecBuffer: Data? = nil
        var fecSequenceNumber: Int32 = -1
        var sessionId: Int64 = 0
        var fecPacketLengths: [UInt32] = []
        while !r.isAtEnd {
            let (field, wire) = try r.readTag()
            switch field {
            case 1 where wire == 0: sequenceNumber = try r.readInt32()
            case 2 where wire == 2: audioPacket = try AudioPacketMessage(serializedData: try r.readData())
            case 3 where wire == 0: timestamp = try r.readInt64()
            case 4 where wire == 2: fecBuffer = try r.readData()
            case 5 where wire == 0: fecSequenceNumber = try r.readInt32()
            case 6 where wire == 0: sessionId = try r.readInt64()
            case 7 where wire == 2:
                // packed repeated uint32
                let payload = try r.readData()
                var pr = ProtoReader(payload)
                while !pr.isAtEnd {
                    fecPacketLengths.append(UInt32(try pr.readVarint()))
                }
            default: try r.skip(wire)
            }
        }
        guard let ap = audioPacket else { throw WireError.decodeFailed("AudioPacketMessageOrdered 缺 audioPacket") }
        self.sequenceNumber = sequenceNumber
        self.audioPacket = ap
        self.timestamp = timestamp
        self.fecBuffer = fecBuffer
        self.fecSequenceNumber = fecSequenceNumber
        self.sessionId = sessionId
        self.fecPacketLengths = fecPacketLengths
    }
}

// MARK: - MessageWrapper
// { AudioPacketMessageOrdered audioPacket=1; ConnectMessage connect=2; MuteMessage mute=3;
//   reserved 4; PingMessage ping=5; PongMessage pong=6; PluginMessage pluginMessage=7; }
public struct MessageWrapper: Equatable {
    public var audioPacket: AudioPacketMessageOrdered?
    public var connect: ConnectMessage?
    public var mute: MuteMessage?
    public var ping: PingMessage?
    public var pong: PongMessage?

    public init(audioPacket: AudioPacketMessageOrdered? = nil,
                connect: ConnectMessage? = nil,
                mute: MuteMessage? = nil,
                ping: PingMessage? = nil,
                pong: PongMessage? = nil) {
        self.audioPacket = audioPacket
        self.connect = connect
        self.mute = mute
        self.ping = ping
        self.pong = pong
    }

    /// 是否为控制消息（应走 TCP）。对齐 `Protocol.kt:150`。
    public var hasControlMessage: Bool {
        connect != nil || mute != nil || ping != nil || pong != nil
    }

    public func serializedData() -> Data {
        var w = ProtoWriter()
        if let ap = audioPacket { w.writeMessage(1, ap.serializedData()) }
        if let c = connect { w.writeMessage(2, c.serializedData()) }
        if let m = mute { w.writeMessage(3, m.serializedData()) }
        if let p = ping { w.writeMessage(5, p.serializedData()) }
        if let pg = pong { w.writeMessage(6, pg.serializedData()) }
        return w.result()
    }

    public init(serializedData data: Data) throws {
        var r = ProtoReader(data)
        var audioPacket: AudioPacketMessageOrdered?
        var connect: ConnectMessage?
        var mute: MuteMessage?
        var ping: PingMessage?
        var pong: PongMessage?
        while !r.isAtEnd {
            let (field, wire) = try r.readTag()
            switch field {
            case 1 where wire == 2: audioPacket = try AudioPacketMessageOrdered(serializedData: try r.readData())
            case 2 where wire == 2: connect = try ConnectMessage(serializedData: try r.readData())
            case 3 where wire == 2: mute = try MuteMessage(serializedData: try r.readData())
            case 5 where wire == 2: ping = try PingMessage(serializedData: try r.readData())
            case 6 where wire == 2: pong = try PongMessage(serializedData: try r.readData())
            default: try r.skip(wire)   // 含 pluginMessage(7) 与 reserved(4)
            }
        }
        self.audioPacket = audioPacket
        self.connect = connect
        self.mute = mute
        self.ping = ping
        self.pong = pong
    }
}
