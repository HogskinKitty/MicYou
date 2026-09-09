import Foundation

/// 最小自包含 protobuf 编解码器，逐字段对齐 `network.proto`。
///
/// 设计说明：本环境无 `protoc`，故手写 prost 兼容的 proto3 编解码，保证工程无需
/// 生成步骤即可编译。`ios/scripts/generate-proto.sh` + SwiftProtobuf SPM 依赖保留为
/// 可选的"官方生成"路径；app 实际使用本手写编解码。prost（桌面端）能正确解码本格式。
///
/// 线类型：0=Varint, 1=I64, 2=LEN, 5=I32。Varint = LEB128。
public struct ProtoWriter {
    private var buffer = Data()

    public init() {}

    public func result() -> Data { buffer }

    // MARK: - primitives
    @discardableResult
    public mutating func writeVarint(_ value: UInt64) {
        var v = value
        while v >= 0x80 {
            buffer.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        buffer.append(UInt8(v))
    }

    @inline(__always)
    private static func varintSize(_ value: UInt64) -> Int {
        var v = value; var n = 1
        while v >= 0x80 { v >>= 7; n += 1 }
        return n
    }

    @inline(__always)
    private mutating func writeTag(_ field: Int, _ wire: Int) {
        writeVarint(UInt64(field) << 3 | UInt64(wire))
    }

    // MARK: - typed fields
    @discardableResult
    public mutating func writeInt32(_ field: Int, _ value: Int32) {
        writeTag(field, 0)
        writeVarint(UInt64(bitPattern: Int64(value)))   // 负数符号扩展到 64 位
    }

    @discardableResult
    public mutating func writeInt64(_ field: Int, _ value: Int64) {
        writeTag(field, 0)
        writeVarint(UInt64(bitPattern: value))
    }

    @discardableResult
    public mutating func writeBool(_ field: Int, _ value: Bool) {
        writeTag(field, 0)
        writeVarint(value ? 1 : 0)
    }

    @discardableResult
    public mutating func writeBytes(_ field: Int, _ value: Data) {
        writeTag(field, 2)
        writeVarint(UInt64(value.count))
        buffer.append(value)
    }

    @discardableResult
    public mutating func writeMessage(_ field: Int, _ inner: Data) {
        writeTag(field, 2)
        writeVarint(UInt64(inner.count))
        buffer.append(inner)
    }

    @discardableResult
    public mutating func writePackedUInt32(_ field: Int, _ values: [UInt32]) {
        guard !values.isEmpty else { return }
        writeTag(field, 2)
        var len = 0
        for v in values { len += Self.varintSize(UInt64(v)) }
        writeVarint(UInt64(len))
        for v in values { writeVarint(UInt64(v)) }
    }
}

/// protobuf 读取器。
public struct ProtoReader {
    private let data: Data
    private var pos: Int

    public init(_ data: Data) {
        self.data = data
        self.pos = 0
    }

    public var isAtEnd: Bool { pos >= data.count }

    public mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard pos < data.count else { throw WireError.truncated }
            let b = data[data.startIndex + pos]
            pos += 1
            result |= UInt64(b & 0x7F) << shift
            if b & 0x80 == 0 { break }
            shift += 7
            if shift > 63 { throw WireError.decodeFailed("varint 太长") }
        }
        return result
    }

    public mutating func readTag() throws -> (field: Int, wire: Int) {
        let v = try readVarint()
        return (Int(v >> 3), Int(v & 7))
    }

    public mutating func readInt32() throws -> Int32 {
        let v = try readVarint()
        return Int32(truncatingIfNeeded: Int64(bitPattern: v))
    }

    public mutating func readInt64() throws -> Int64 {
        let v = try readVarint()
        return Int64(bitPattern: v)
    }

    public mutating func readBool() throws -> Bool {
        try readVarint() != 0
    }

    public mutating func readData() throws -> Data {
        let len = Int(try readVarint())
        guard pos + len <= data.count else { throw WireError.truncated }
        let slice = data.subdata(in: (data.startIndex + pos)..<(data.startIndex + pos + len))
        pos += len
        return slice
    }

    /// 跳过未知字段。
    public mutating func skip(_ wire: Int) throws {
        switch wire {
        case 0: _ = try readVarint()
        case 1:
            guard pos + 8 <= data.count else { throw WireError.truncated }
            pos += 8
        case 2:
            let len = Int(try readVarint())
            guard pos + len <= data.count else { throw WireError.truncated }
            pos += len
        case 5:
            guard pos + 4 <= data.count else { throw WireError.truncated }
            pos += 4
        default:
            throw WireError.decodeFailed("未知线类型 \(wire)")
        }
    }
}
