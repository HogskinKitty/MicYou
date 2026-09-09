import XCTest
@testable import MicYou

/// FEC 编码器单测。对齐 Android `xorBuffers` + FEC 组逻辑。
final class FecEncoderTests: XCTestCase {

    /// 序列号递增：0, 1, 2, ...
    func testSequenceNumberIncrement() {
        let fec = FecEncoder()
        XCTAssertEqual(fec.nextSequenceNumber(), 0)
        XCTAssertEqual(fec.nextSequenceNumber(), 1)
        XCTAssertEqual(fec.nextSequenceNumber(), 2)
        XCTAssertEqual(fec.currentSequenceNumber(), 3)
    }

    /// 满 12 包生成 FEC，序列号正确。
    func testFecGroupGeneration() {
        let fec = FecEncoder()
        var fecGroups: [FecEncoder.FecGroup] = []

        for i in 0..<12 {
            let seq = fec.nextSequenceNumber()
            XCTAssertEqual(seq, Int32(i))
            let encoded = Data([UInt8(i), UInt8(i + 1)])   // 2 字节
            if let group = fec.processPacket(encoded) {
                fecGroups.append(group)
            }
        }

        XCTAssertEqual(fecGroups.count, 1)
        let group = fecGroups[0]
        XCTAssertEqual(group.fecSequenceNumber, 0, "首组 fecSequenceNumber 应为 0")
        XCTAssertEqual(group.fecBuffer, Data([0x01]), "FEC 标记应为 [0x01]")
        XCTAssertEqual(group.fecPacketLengths.count, 12)
        XCTAssertTrue(group.fecPacketLengths.allSatisfy { $0 == 2 }, "各包长度应为 2")
    }

    /// 第二组 FEC 的 fecSequenceNumber = 12。
    func testSecondFecGroup() {
        let fec = FecEncoder()
        var fecGroups: [FecEncoder.FecGroup] = []

        for i in 0..<24 {
            _ = fec.nextSequenceNumber()
            let encoded = Data([UInt8(i)])
            if let group = fec.processPacket(encoded) {
                fecGroups.append(group)
            }
        }

        XCTAssertEqual(fecGroups.count, 2)
        XCTAssertEqual(fecGroups[0].fecSequenceNumber, 0)
        XCTAssertEqual(fecGroups[1].fecSequenceNumber, 12)
    }

    /// XOR 正确性：两个不同缓冲区异或。
    func testXorCorrectness() {
        let fec = FecEncoder()
        // 手动喂 12 个已知缓冲区
        let buffers: [Data] = (0..<12).map { i in
            Data([UInt8(i), UInt8(i * 2), UInt8(i * 3)])
        }
        var fecGroup: FecEncoder.FecGroup?

        for buf in buffers {
            _ = fec.nextSequenceNumber()
            fecGroup = fec.processPacket(buf)
        }

        guard let group = fecGroup else {
            return XCTFail("应生成 FEC 组")
        }

        // 手动计算 XOR 验证
        var expected = Data(count: 3)
        for buf in buffers {
            for i in 0..<buf.count {
                expected[i] ^= buf[i]
            }
        }
        XCTAssertEqual(group.xorPayload, expected)
    }

    /// XOR 处理变长缓冲区（结果长度 = 最长）。
    func testXorVariableLength() {
        let fec = FecEncoder()
        let buffers: [Data] = [
            Data([0x01, 0x02, 0x03]),
            Data([0x10, 0x20]),
            Data([0xFF])
        ]
        // 补齐到 12 个
        let allBuffers = buffers + (3..<12).map { _ in Data([0x00]) }

        var fecGroup: FecEncoder.FecGroup?
        for buf in allBuffers {
            _ = fec.nextSequenceNumber()
            fecGroup = fec.processPacket(buf)
        }

        guard let group = fecGroup else {
            return XCTFail("应生成 FEC 组")
        }
        XCTAssertEqual(group.xorPayload.count, 3, "XOR 结果长度应 = 最长缓冲区(3)")

        // 验证前 3 字节
        // buf0: [01,02,03], buf1: [10,20,00], buf2: [FF,00,00], rest: [00,...]
        // XOR: [01^10^FF, 02^20^00^00, 03^00^00^00]
        XCTAssertEqual(group.xorPayload[0], 0x01 ^ 0x10 ^ 0xFF)
        XCTAssertEqual(group.xorPayload[1], 0x02 ^ 0x20)
        XCTAssertEqual(group.xorPayload[2], 0x03)
    }

    /// reset 清零。
    func testReset() {
        let fec = FecEncoder()
        _ = fec.nextSequenceNumber()
        _ = fec.nextSequenceNumber()
        fec.reset()
        XCTAssertEqual(fec.nextSequenceNumber(), 0)
        XCTAssertEqual(fec.currentSequenceNumber(), 1)
    }

    /// FEC 包的 sequenceNumber = 当前序列号（不递增）。
    func testFecSequenceNumberNotIncremented() {
        let fec = FecEncoder()
        // 发 12 个常规包（seq 0-11），之后 sequenceNumber = 12
        for _ in 0..<12 {
            _ = fec.nextSequenceNumber()
            _ = fec.processPacket(Data([0x01]))
        }
        // FEC 包的 sequenceNumber 应为 12（current），且不递增
        XCTAssertEqual(fec.currentSequenceNumber(), 12)
        // 下一个常规包仍从 12 开始
        XCTAssertEqual(fec.nextSequenceNumber(), 12)
        XCTAssertEqual(fec.nextSequenceNumber(), 13)
    }
}
