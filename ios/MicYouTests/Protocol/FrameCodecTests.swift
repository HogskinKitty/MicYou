import XCTest
@testable import MicYou

/// 线上协议层单测：消息编解码往返、TCP/UDP 帧编解码、端口边界、校验。
/// 对齐 `micyou-protocol` 内联测试 + `Protocol.kt` 行为。
final class FrameCodecTests: XCTestCase {

    // MARK: - 消息往返
    func testConnectMessageRoundtrip() throws {
        let original = ConnectMessage(sessionId: 1_700_000_000_000)
        let data = original.serializedData()
        let restored = try ConnectMessage(serializedData: data)
        XCTAssertEqual(restored, original)
    }

    func testMuteMessageRoundtrip() throws {
        let on = MuteMessage(isMuted: true)
        XCTAssertEqual(try MuteMessage(serializedData: on.serializedData()), on)
        let off = MuteMessage(isMuted: false)
        XCTAssertEqual(try MuteMessage(serializedData: off.serializedData()), off)
        let absent = MuteMessage(isMuted: nil)
        let restored = try MuteMessage(serializedData: absent.serializedData())
        XCTAssertNil(restored.isMuted)
    }

    func testPingPongRoundtrip() throws {
        let ping = PingMessage(timestamp: 1234567890)
        XCTAssertEqual(try PingMessage(serializedData: ping.serializedData()), ping)
        let pong = PongMessage(timestamp: -42)
        XCTAssertEqual(try PongMessage(serializedData: pong.serializedData()), pong)
    }

    func testAudioPacketRoundtrip() throws {
        let payload = Data([0x01, 0x02, 0x03, 0x04])
        let original = AudioPacketMessage(buffer: payload, sampleRate: 48000,
                                          channelCount: 1, audioFormat: 2,
                                          codec: WireConstants.codecOpus)
        let restored = try AudioPacketMessage(serializedData: original.serializedData())
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.codec, WireConstants.codecOpus)
    }

    func testOrderedPacketWithFecRoundtrip() throws {
        let ap = AudioPacketMessage(buffer: Data(repeating: 0xAB, count: 80),
                                    sampleRate: 48000, channelCount: 1,
                                    audioFormat: 2, codec: WireConstants.codecOpus)
        let original = AudioPacketMessageOrdered(
            sequenceNumber: 42, audioPacket: ap, timestamp: 9_999,
            fecBuffer: Data([0x01]), fecSequenceNumber: 30,
            sessionId: 12345, fecPacketLengths: [80, 76, 80]
        )
        let restored = try AudioPacketMessageOrdered(serializedData: original.serializedData())
        XCTAssertEqual(restored, original)
        XCTAssertTrue(restored.isFec)
        XCTAssertEqual(restored.fecPacketLengths, [80, 76, 80])
    }

    func testOrderedPacketRegularNotFec() throws {
        let ap = AudioPacketMessage(buffer: Data([0x01]), sampleRate: 48000,
                                    channelCount: 1, audioFormat: 2, codec: 1)
        let original = AudioPacketMessageOrdered(sequenceNumber: 0, audioPacket: ap)
        let restored = try AudioPacketMessageOrdered(serializedData: original.serializedData())
        XCTAssertFalse(restored.isFec)
        XCTAssertEqual(restored.fecSequenceNumber, -1)   // 默认
    }

    func testMessageWrapperAudioRoundtrip() throws {
        let ap = AudioPacketMessage(buffer: Data(repeating: 0x77, count: 10),
                                    sampleRate: 16000, channelCount: 2,
                                    audioFormat: 4, codec: 1)
        let ordered = AudioPacketMessageOrdered(sequenceNumber: 7, audioPacket: ap,
                                                timestamp: 555, sessionId: 99)
        let original = MessageWrapper(audioPacket: ordered)
        let restored = try MessageWrapper(serializedData: original.serializedData())
        XCTAssertEqual(restored, original)
        XCTAssertFalse(restored.hasControlMessage)
    }

    func testMessageWrapperControlRoundtrip() throws {
        let original = MessageWrapper(connect: ConnectMessage(sessionId: 1),
                                      mute: MuteMessage(isMuted: true))
        let restored = try MessageWrapper(serializedData: original.serializedData())
        XCTAssertEqual(restored, original)
        XCTAssertTrue(restored.hasControlMessage)
    }

    // MARK: - TCP 帧
    func testTcpFrameRoundtrip() throws {
        let wrapper = MessageWrapper(ping: PingMessage(timestamp: 42))
        let frame = try FrameCodec.encodeTcp(wrapper)
        // 帧头 8 字节 + payload
        let magic = frame.readBE(at: 0)
        XCTAssertEqual(magic, WireConstants.packetMagic)
        let length = Int(frame.readBE(at: 4))
        XCTAssertEqual(frame.count, 8 + length)

        let reader = TcpFrameReader()
        reader.append(frame)
        let frames = try reader.popFrames()
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0], wrapper)
    }

    func testTcpFrameSplitAcrossChunks() throws {
        let wrapper = MessageWrapper(pong: PongMessage(timestamp: 7))
        let frame = try FrameCodec.encodeTcp(wrapper)
        let split = frame.count / 2
        let reader = TcpFrameReader()
        reader.append(frame.subdata(in: 0..<split))
        XCTAssertEqual(try reader.popFrames().count, 0)   // 不完整
        reader.append(frame.subdata(in: split..<frame.count))
        let frames = try reader.popFrames()
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0], wrapper)
    }

    func testTcpFrameInvalidMagic() {
        let reader = TcpFrameReader()
        var bad = Data()
        bad.appendBE(0xDEADBEEF)
        bad.appendBE(0)
        reader.append(bad)
        XCTAssertThrowsError(try reader.popFrames()) { err in
            guard case WireError.invalidMagic(let exp, let act) = err else {
                return XCTFail("期望 invalidMagic，得到 \(err)")
            }
            XCTAssertEqual(exp, WireConstants.packetMagic)
            XCTAssertEqual(act, 0xDEADBEEF)
        }
    }

    // MARK: - UDP 帧
    func testUdpFrameRoundtrip() throws {
        let ap = AudioPacketMessage(buffer: Data(repeating: 0x33, count: 100),
                                    sampleRate: 48000, channelCount: 1,
                                    audioFormat: 2, codec: 1)
        let wrapper = MessageWrapper(audioPacket: AudioPacketMessageOrdered(
            sequenceNumber: 1, audioPacket: ap, sessionId: 5))
        let datagram = try FrameCodec.encodeUdp(wrapper)
        let restored = try FrameCodec.decodeUdp(datagram)
        XCTAssertEqual(restored, wrapper)
    }

    // MARK: - 端口边界
    func testCalculateUdpPort() throws {
        XCTAssertEqual(try calculateUdpPort(8554), 8555)
        XCTAssertEqual(try calculateUdpPort(0), 1)
        XCTAssertEqual(try calculateUdpPort(65534), 65535)
        XCTAssertThrowsError(try calculateUdpPort(65535)) { err in
            guard case WireError.portOverflow = err else {
                return XCTFail("期望 portOverflow，得到 \(err)")
            }
        }
    }
}
