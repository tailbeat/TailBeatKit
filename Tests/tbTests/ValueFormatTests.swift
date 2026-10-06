//
//  ValueFormatTests.swift
//  tb
//
//  os_log's special formats, raw memory, attributes and masks.
//
//  The table continues the one in OptionTests.swift: every entry was first
//  logged through `os.Logger`, and its `text` is what the log store gave back.
//  The suites below add what a table of single calls cannot show: many values
//  through the same format, and what the kit does where it has to differ.
//

import Foundation
import os
import Testing
@testable import tb

/// Raw memory for the fixtures.
enum Memory {
    static let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x01]
    static let uuid: [UInt8] = [0xE6, 0x21, 0xE1, 0xF8, 0xC3, 0x6C, 0x49, 0x5A, 0x93, 0xFC, 0x0C, 0x24, 0x7A, 0x3E, 0x6E, 0x5F]
    /// 2001:db8::1
    static let ipv6: [UInt8] = [0x20, 0x01, 0x0D, 0xB8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    /// ::ffff:192.168.0.1
    static let ipv6Mapped: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF, 192, 168, 0, 1]
    /// fe80::f:86ff:fee9:5c16
    static let ipv6LinkLocal: [UInt8] = [0xFE, 0x80, 0, 0, 0, 0, 0, 0, 0x00, 0x0F, 0x86, 0xFF, 0xFE, 0xE9, 0x5C, 0x16]
    /// 192.168.0.1
    static let ipv4: [UInt8] = [192, 168, 0, 1]
    static let timeval = of(Darwin.timeval(tv_sec: 1_791_000_000, tv_usec: 250_000))
    static let timespec = of(Darwin.timespec(tv_sec: 1_791_000_000, tv_nsec: 250_000_000))
    /// 192.168.0.1, port 8080
    static let sockaddrIn: [UInt8] = [16, UInt8(AF_INET), 0x1F, 0x90] + ipv4 + [0, 0, 0, 0, 0, 0, 0, 0]
    /// 192.168.0.1, no port
    static let sockaddrInNoPort: [UInt8] = [16, UInt8(AF_INET), 0, 0] + ipv4 + [0, 0, 0, 0, 0, 0, 0, 0]
    /// 2001:db8::1, port 8080
    static let sockaddrIn6: [UInt8] = [28, UInt8(AF_INET6), 0x1F, 0x90, 0, 0, 0, 0] + ipv6 + [0, 0, 0, 0]
    /// fe80::f:86ff:fee9:5c16 on the interface with index 1, no port
    static let sockaddrIn6Scoped: [UInt8] = [28, UInt8(AF_INET6), 0, 0, 0, 0, 0, 0] + ipv6LinkLocal + [1, 0, 0, 0]
    /// The local socket /tmp/tb.sock
    static let sockaddrUnix: [UInt8] = [15, UInt8(AF_UNIX)] + Array("/tmp/tb.sock".utf8) + [0]
    /// The interface en0 with the link-level address 2:0:0:0:0:1
    static let sockaddrLink: [UInt8] = [20, UInt8(AF_LINK), 4, 0, 6, 3, 6, 0] + Array("en0".utf8) + [2, 0, 0, 0, 0, 1, 0, 0, 0]
    /// The interface lo0, which has no link-level address
    static let sockaddrLinkNoAddress: [UInt8] = [20, UInt8(AF_LINK), 1, 0, 24, 3, 0, 0] + Array("lo0".utf8) + [0, 0, 0, 0, 0, 0, 0, 0, 0]
    /// As much as os_log stores of one value even with a second one beside it
    static let thousand = (0..<1000).map { UInt8(truncatingIfNeeded: $0) }

    static func of<Value>(_ value: Value) -> [UInt8] { withUnsafeBytes(of: value) { Array($0) } }

    /// `bytes` as os_log writes raw memory, up to but without the closing quote.
    static func dump(_ bytes: [UInt8]) -> String {
        "'" + bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Runs `body` with `bytes` as raw memory.
    static func with<Result>(_ bytes: [UInt8], _ body: (UnsafeRawBufferPointer) -> Result) -> Result {
        bytes.withUnsafeBytes(body)
    }
}

/// A point in time as os_log writes it, in the time zone the tests run in.
/// This goes through `DateFormatter`, not through the kit's own arithmetic.
func localTime(_ seconds: Int, fraction: String = "") -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss" + (fraction.isEmpty ? "" : "'\(fraction)'") + "Z"
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
}

extension Option {
    /// An `Int` in a special format. `os` itself has the time format for an
    /// `Int` only from version 26 on, hence the check around those calls.
    static let specialInt: [Option] = [
        Option("int.byteCount", "1.54 MB",
               { "\(1_536_000, format: .byteCount, privacy: $0)" },
               { $0.notice("option.int.byteCount|\(1_536_000, format: .byteCount, privacy: .public)|") }),
        Option("int.byteCount.zero", "0 B",
               { "\(0, format: .byteCount, privacy: $0)" },
               { $0.notice("option.int.byteCount.zero|\(0, format: .byteCount, privacy: .public)|") }),
        Option("int.byteCount.999", "999 B",
               { "\(999, format: .byteCount, privacy: $0)" },
               { $0.notice("option.int.byteCount.999|\(999, format: .byteCount, privacy: .public)|") }),
        Option("int.byteCount.1000", "1 kB",
               { "\(1000, format: .byteCount, privacy: $0)" },
               { $0.notice("option.int.byteCount.1000|\(1000, format: .byteCount, privacy: .public)|") }),
        Option("int.byteCount.tenths", "10.0 kB",
               { "\(10_040, format: .byteCount, privacy: $0)" },
               { $0.notice("option.int.byteCount.tenths|\(10_040, format: .byteCount, privacy: .public)|") }),
        Option("int.byteCount.rounded.up", "1000 kB",
               { "\(999_999, format: .byteCount, privacy: $0)" },
               { $0.notice("option.int.byteCount.rounded.up|\(999_999, format: .byteCount, privacy: .public)|") }),
        Option("int.byteCount.largest.unit", "9.22 EB",
               { "\(Int.max, format: .byteCount, privacy: $0)" },
               { $0.notice("option.int.byteCount.largest.unit|\(Int.max, format: .byteCount, privacy: .public)|") }),
        Option("int.byteCount.negative", "18.4 EB",
               { "\(-1, format: .byteCount, privacy: $0)" },
               { $0.notice("option.int.byteCount.negative|\(-1, format: .byteCount, privacy: .public)|") }),
        Option("int.byteCountIEC", "1.46 MiB",
               { "\(1_536_000, format: .byteCountIEC, privacy: $0)" },
               { $0.notice("option.int.byteCountIEC|\(1_536_000, format: .byteCountIEC, privacy: .public)|") }),
        Option("int.byteCountIEC.1000", "0.98 KiB",
               { "\(1000, format: .byteCountIEC, privacy: $0)" },
               { $0.notice("option.int.byteCountIEC.1000|\(1000, format: .byteCountIEC, privacy: .public)|") }),
        Option("int.byteCountIEC.1024", "1 KiB",
               { "\(1024, format: .byteCountIEC, privacy: $0)" },
               { $0.notice("option.int.byteCountIEC.1024|\(1024, format: .byteCountIEC, privacy: .public)|") }),
        Option("int.byteCountIEC.whole.steps", "2.57 MiB",
               { "\(2_700_123, format: .byteCountIEC, privacy: $0)" },
               { $0.notice("option.int.byteCountIEC.whole.steps|\(2_700_123, format: .byteCountIEC, privacy: .public)|") }),
        Option("int.bitrate", "1.54 Mbps",
               { "\(1_536_000, format: .bitrate, privacy: $0)" },
               { $0.notice("option.int.bitrate|\(1_536_000, format: .bitrate, privacy: .public)|") }),
        Option("int.bitrate.largest.unit", "1125 Tbps",
               { "\(1_125_899_906_842_624, format: .bitrate, privacy: $0)" },
               { $0.notice("option.int.bitrate.largest.unit|\(1_125_899_906_842_624, format: .bitrate, privacy: .public)|") }),
        Option("int.bitrateIEC", "1.46 Mibps",
               { "\(1_536_000, format: .bitrateIEC, privacy: $0)" },
               { $0.notice("option.int.bitrateIEC|\(1_536_000, format: .bitrateIEC, privacy: .public)|") }),
        Option("int.bitrateIEC.largest.unit", "1024 Tibps",
               { "\(1_125_899_906_842_624, format: .bitrateIEC, privacy: $0)" },
               { $0.notice("option.int.bitrateIEC.largest.unit|\(1_125_899_906_842_624, format: .bitrateIEC, privacy: .public)|") }),
        Option("int.secondsSince1970", localTime(1_791_000_000),
               { "\(1_791_000_000, format: .secondsSince1970, privacy: $0)" },
               { log in if #available(macOS 26, iOS 26, *) { log.notice("option.int.secondsSince1970|\(1_791_000_000, format: .secondsSince1970, privacy: .public)|") } }),
        Option("int.secondsSince1970.zero", localTime(0),
               { "\(0, format: .secondsSince1970, privacy: $0)" },
               { log in if #available(macOS 26, iOS 26, *) { log.notice("option.int.secondsSince1970.zero|\(0, format: .secondsSince1970, privacy: .public)|") } }),
        Option("int.secondsSince1970.winter", localTime(1_801_368_000),
               { "\(1_801_368_000, format: .secondsSince1970, privacy: $0)" },
               { log in if #available(macOS 26, iOS 26, *) { log.notice("option.int.secondsSince1970.winter|\(1_801_368_000, format: .secondsSince1970, privacy: .public)|") } }),
        Option("int.secondsSince1970.out.of.range", "",
               { "\(Int.max, format: .secondsSince1970, privacy: $0)" },
               { log in if #available(macOS 26, iOS 26, *) { log.notice("option.int.secondsSince1970.out.of.range|\(Int.max, format: .secondsSince1970, privacy: .public)|") } }),
    ]

    /// An `Int32` in a special format.
    static let specialInt32: [Option] = [
        Option("int32.byteCount", "1.54 MB",
               { "\(Int32(1_536_000), format: .byteCount, privacy: $0)" },
               { $0.notice("option.int32.byteCount|\(Int32(1_536_000), format: .byteCount, privacy: .public)|") }),
        Option("int32.byteCount.negative", "18.4 EB",
               { "\(Int32(-1), format: .byteCount, privacy: $0)" },
               { $0.notice("option.int32.byteCount.negative|\(Int32(-1), format: .byteCount, privacy: .public)|") }),
        Option("int32.byteCountIEC", "1.46 MiB",
               { "\(Int32(1_536_000), format: .byteCountIEC, privacy: $0)" },
               { $0.notice("option.int32.byteCountIEC|\(Int32(1_536_000), format: .byteCountIEC, privacy: .public)|") }),
        Option("int32.bitrate", "1.54 Mbps",
               { "\(Int32(1_536_000), format: .bitrate, privacy: $0)" },
               { $0.notice("option.int32.bitrate|\(Int32(1_536_000), format: .bitrate, privacy: .public)|") }),
        Option("int32.bitrateIEC", "1.46 Mibps",
               { "\(Int32(1_536_000), format: .bitrateIEC, privacy: $0)" },
               { $0.notice("option.int32.bitrateIEC|\(Int32(1_536_000), format: .bitrateIEC, privacy: .public)|") }),
        Option("int32.secondsSince1970", localTime(1_791_000_000),
               { "\(Int32(1_791_000_000), format: .secondsSince1970, privacy: $0)" },
               { $0.notice("option.int32.secondsSince1970|\(Int32(1_791_000_000), format: .secondsSince1970, privacy: .public)|") }),
        Option("int32.darwinErrno", "[2: No such file or directory]",
               { "\(Int32(2), format: .darwinErrno, privacy: $0)" },
               { $0.notice("option.int32.darwinErrno|\(Int32(2), format: .darwinErrno, privacy: .public)|") }),
        Option("int32.darwinErrno.literal", "[2: No such file or directory]",
               { "\(2, format: .darwinErrno, privacy: $0)" },
               { $0.notice("option.int32.darwinErrno.literal|\(2, format: .darwinErrno, privacy: .public)|") }),
        Option("int32.darwinErrno.zero", "[0: Success]",
               { "\(Int32(0), format: .darwinErrno, privacy: $0)" },
               { $0.notice("option.int32.darwinErrno.zero|\(Int32(0), format: .darwinErrno, privacy: .public)|") }),
        Option("int32.darwinErrno.unknown", "[200: Unknown error: 200]",
               { "\(Int32(200), format: .darwinErrno, privacy: $0)" },
               { $0.notice("option.int32.darwinErrno.unknown|\(Int32(200), format: .darwinErrno, privacy: .public)|") }),
        Option("int32.darwinErrno.negative", "[-1: Unknown error: -1]",
               { "\(Int32(-1), format: .darwinErrno, privacy: $0)" },
               { $0.notice("option.int32.darwinErrno.negative|\(Int32(-1), format: .darwinErrno, privacy: .public)|") }),
        Option("int32.darwinMode", "-rw-r--r--",
               { "\(Int32(0o100644), format: .darwinMode, privacy: $0)" },
               { $0.notice("option.int32.darwinMode|\(Int32(0o100644), format: .darwinMode, privacy: .public)|") }),
        Option("int32.darwinMode.directory", "drwxr-xr-x",
               { "\(Int32(0o040755), format: .darwinMode, privacy: $0)" },
               { $0.notice("option.int32.darwinMode.directory|\(Int32(0o040755), format: .darwinMode, privacy: .public)|") }),
        Option("int32.darwinMode.link", "lrwxrwxrwx",
               { "\(Int32(0o120777), format: .darwinMode, privacy: $0)" },
               { $0.notice("option.int32.darwinMode.link|\(Int32(0o120777), format: .darwinMode, privacy: .public)|") }),
        Option("int32.darwinMode.setuid", "-rwsr-xr-x",
               { "\(Int32(0o104755), format: .darwinMode, privacy: $0)" },
               { $0.notice("option.int32.darwinMode.setuid|\(Int32(0o104755), format: .darwinMode, privacy: .public)|") }),
        Option("int32.darwinMode.setgid.no.execute", "-rw-r-Sr--",
               { "\(Int32(0o102644), format: .darwinMode, privacy: $0)" },
               { $0.notice("option.int32.darwinMode.setgid.no.execute|\(Int32(0o102644), format: .darwinMode, privacy: .public)|") }),
        Option("int32.darwinMode.sticky", "drwxrwxrwt",
               { "\(Int32(0o041777), format: .darwinMode, privacy: $0)" },
               { $0.notice("option.int32.darwinMode.sticky|\(Int32(0o041777), format: .darwinMode, privacy: .public)|") }),
        Option("int32.darwinMode.sticky.no.execute", "-rw-r--r-T",
               { "\(Int32(0o101644), format: .darwinMode, privacy: $0)" },
               { $0.notice("option.int32.darwinMode.sticky.no.execute|\(Int32(0o101644), format: .darwinMode, privacy: .public)|") }),
        Option("int32.darwinMode.devices", "brw-rw---- crw--w---- prw-r--r-- srwxr-xr-x", hidden: "<private> <private> <private> <private>",
               { "\(Int32(0o060660), format: .darwinMode, privacy: $0) \(Int32(0o020620), format: .darwinMode, privacy: $0) \(Int32(0o010644), format: .darwinMode, privacy: $0) \(Int32(0o140755), format: .darwinMode, privacy: $0)" },
               { $0.notice("option.int32.darwinMode.devices|\(Int32(0o060660), format: .darwinMode, privacy: .public) \(Int32(0o020620), format: .darwinMode, privacy: .public) \(Int32(0o010644), format: .darwinMode, privacy: .public) \(Int32(0o140755), format: .darwinMode, privacy: .public)|") }),
        Option("int32.darwinMode.no.type", "-rw-r--r--",
               { "\(Int32(0o644), format: .darwinMode, privacy: $0)" },
               { $0.notice("option.int32.darwinMode.no.type|\(Int32(0o644), format: .darwinMode, privacy: .public)|") }),
        Option("int32.darwinMode.unknown.type", "#---------",
               { "\(Int32(0o170000), format: .darwinMode, privacy: $0)" },
               { $0.notice("option.int32.darwinMode.unknown.type|\(Int32(0o170000), format: .darwinMode, privacy: .public)|") }),
        Option("int32.darwinSignal", "[sigterm: Terminated]",
               { "\(Int32(15), format: .darwinSignal, privacy: $0)" },
               { $0.notice("option.int32.darwinSignal|\(Int32(15), format: .darwinSignal, privacy: .public)|") }),
        Option("int32.darwinSignal.kill", "[sigkill: Killed]",
               { "\(Int32(9), format: .darwinSignal, privacy: $0)" },
               { $0.notice("option.int32.darwinSignal.kill|\(Int32(9), format: .darwinSignal, privacy: .public)|") }),
        Option("int32.darwinSignal.zero", "[sigSignal 0: Signal 0]",
               { "\(Int32(0), format: .darwinSignal, privacy: $0)" },
               { $0.notice("option.int32.darwinSignal.zero|\(Int32(0), format: .darwinSignal, privacy: .public)|") }),
        Option("int32.darwinSignal.unknown", "[32: Unknown signal]",
               { "\(Int32(32), format: .darwinSignal, privacy: $0)" },
               { $0.notice("option.int32.darwinSignal.unknown|\(Int32(32), format: .darwinSignal, privacy: .public)|") }),
        Option("int32.darwinSignal.negative", "[-1: Unknown signal]",
               { "\(Int32(-1), format: .darwinSignal, privacy: $0)" },
               { $0.notice("option.int32.darwinSignal.negative|\(Int32(-1), format: .darwinSignal, privacy: .public)|") }),
        Option("int32.machErrno", "[0x5: (os/kern) failure]",
               { "\(Int32(5), format: .machErrno, privacy: $0)" },
               { $0.notice("option.int32.machErrno|\(Int32(5), format: .machErrno, privacy: .public)|") }),
        Option("int32.machErrno.zero", "[0: (os/kern) successful]",
               { "\(Int32(0), format: .machErrno, privacy: $0)" },
               { $0.notice("option.int32.machErrno.zero|\(Int32(0), format: .machErrno, privacy: .public)|") }),
        Option("int32.machErrno.message", "[0x10000003: (ipc/send) invalid destination port]",
               { "\(Int32(0x10000003), format: .machErrno, privacy: $0)" },
               { $0.notice("option.int32.machErrno.message|\(Int32(0x10000003), format: .machErrno, privacy: .public)|") }),
        Option("int32.machErrno.unknown", "[0x64: unknown error code]",
               { "\(Int32(100), format: .machErrno, privacy: $0)" },
               { $0.notice("option.int32.machErrno.unknown|\(Int32(100), format: .machErrno, privacy: .public)|") }),
        Option("int32.machErrno.no.text", "[0xffffffff: (null)]",
               { "\(Int32(-1), format: .machErrno, privacy: $0)" },
               { $0.notice("option.int32.machErrno.no.text|\(Int32(-1), format: .machErrno, privacy: .public)|") }),
        Option("int32.ipv4Address", "192.168.0.1",
               { "\(Int32(0x0100A8C0), format: .ipv4Address, privacy: $0)" },
               { $0.notice("option.int32.ipv4Address|\(Int32(0x0100A8C0), format: .ipv4Address, privacy: .public)|") }),
        Option("int32.ipv4Address.negative", "255.255.255.255",
               { "\(Int32(-1), format: .ipv4Address, privacy: $0)" },
               { $0.notice("option.int32.ipv4Address.negative|\(Int32(-1), format: .ipv4Address, privacy: .public)|") }),
        Option("int32.truth", "true false true", hidden: "<private> <private> <private>",
               { "\(Int32(1), format: .truth, privacy: $0) \(Int32(0), format: .truth, privacy: $0) \(Int32(-7), format: .truth, privacy: $0)" },
               { $0.notice("option.int32.truth|\(Int32(1), format: .truth, privacy: .public) \(Int32(0), format: .truth, privacy: .public) \(Int32(-7), format: .truth, privacy: .public)|") }),
        Option("int32.answer", "YES NO YES", hidden: "<private> <private> <private>",
               { "\(Int32(1), format: .answer, privacy: $0) \(Int32(0), format: .answer, privacy: $0) \(Int32(-7), format: .answer, privacy: $0)" },
               { $0.notice("option.int32.answer|\(Int32(1), format: .answer, privacy: .public) \(Int32(0), format: .answer, privacy: .public) \(Int32(-7), format: .answer, privacy: .public)|") }),
    ]

    /// Raw memory, as bytes and in the formats that say what the bytes hold.
    static let memory: [Option] = [
        Option("memory", "'DE AD BE EF 01'",
               { p in Memory.with(Memory.bytes) { "\($0, privacy: p)" } },
               { log in Memory.with(Memory.bytes) { log.notice("option.memory|\($0, privacy: .public)|") } }),
        Option("memory.none", "'DE AD BE EF 01'",
               { p in Memory.with(Memory.bytes) { "\($0, format: .none, privacy: p)" } },
               { log in Memory.with(Memory.bytes) { log.notice("option.memory.none|\($0, format: .none, privacy: .public)|") } }),
        Option("memory.pointer", "'DE AD BE EF 01'",
               { p in Memory.with(Memory.bytes) { "\($0.baseAddress!, bytes: 5, privacy: p)" } },
               { log in Memory.with(Memory.bytes) { log.notice("option.memory.pointer|\($0.baseAddress!, bytes: 5, privacy: .public)|") } }),
        Option("memory.pointer.part", "'DE AD BE'",
               { p in Memory.with(Memory.bytes) { "\($0.baseAddress!, bytes: 3, format: .none, privacy: p)" } },
               { log in Memory.with(Memory.bytes) { log.notice("option.memory.pointer.part|\($0.baseAddress!, bytes: 3, format: .none, privacy: .public)|") } }),
        Option("memory.pointer.nothing", "''",
               { p in Memory.with(Memory.bytes) { "\($0.baseAddress!, bytes: 0, privacy: p)" } },
               { log in Memory.with(Memory.bytes) { log.notice("option.memory.pointer.nothing|\($0.baseAddress!, bytes: 0, privacy: .public)|") } }),
        Option("memory.pointer.negative", "''",
               { p in Memory.with(Memory.bytes) { "\($0.baseAddress!, bytes: -1, privacy: p)" } },
               { log in Memory.with(Memory.bytes) { log.notice("option.memory.pointer.negative|\($0.baseAddress!, bytes: -1, privacy: .public)|") } }),
        Option("memory.thousand", Memory.dump(Memory.thousand) + "'",
               { p in Memory.with(Memory.thousand) { "\($0, privacy: p)" } },
               { log in Memory.with(Memory.thousand) { log.notice("option.memory.thousand|\($0, privacy: .public)|") } }),
        Option("memory.uuid", "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
               { p in Memory.with(Memory.uuid) { "\($0, format: .uuid, privacy: p)" } },
               { log in Memory.with(Memory.uuid) { log.notice("option.memory.uuid|\($0, format: .uuid, privacy: .public)|") } }),
        Option("memory.uuid.pointer", "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
               { p in Memory.with(Memory.uuid) { "\($0.baseAddress!, bytes: 16, format: .uuid, privacy: p)" } },
               { log in Memory.with(Memory.uuid) { log.notice("option.memory.uuid.pointer|\($0.baseAddress!, bytes: 16, format: .uuid, privacy: .public)|") } }),
        Option("memory.ipv6Address", "2001:db8::1",
               { p in Memory.with(Memory.ipv6) { "\($0, format: .ipv6Address, privacy: p)" } },
               { log in Memory.with(Memory.ipv6) { log.notice("option.memory.ipv6Address|\($0, format: .ipv6Address, privacy: .public)|") } }),
        Option("memory.ipv6Address.mapped", "::ffff:192.168.0.1",
               { p in Memory.with(Memory.ipv6Mapped) { "\($0, format: .ipv6Address, privacy: p)" } },
               { log in Memory.with(Memory.ipv6Mapped) { log.notice("option.memory.ipv6Address.mapped|\($0, format: .ipv6Address, privacy: .public)|") } }),
        Option("memory.ipv6Address.link.local", "fe80::f:86ff:fee9:5c16",
               { p in Memory.with(Memory.ipv6LinkLocal) { "\($0, format: .ipv6Address, privacy: p)" } },
               { log in Memory.with(Memory.ipv6LinkLocal) { log.notice("option.memory.ipv6Address.link.local|\($0, format: .ipv6Address, privacy: .public)|") } }),
        Option("memory.timeval", localTime(1_791_000_000, fraction: ".250000"),
               { p in Memory.with(Memory.timeval) { "\($0, format: .timeval, privacy: p)" } },
               { log in Memory.with(Memory.timeval) { log.notice("option.memory.timeval|\($0, format: .timeval, privacy: .public)|") } }),
        Option("memory.timespec", localTime(1_791_000_000, fraction: ".250000000"),
               { p in Memory.with(Memory.timespec) { "\($0, format: .timespec, privacy: p)" } },
               { log in Memory.with(Memory.timespec) { log.notice("option.memory.timespec|\($0, format: .timespec, privacy: .public)|") } }),
        Option("memory.sockaddr", "192.168.0.1:8080",
               { p in Memory.with(Memory.sockaddrIn) { "\($0, format: .sockaddr, privacy: p)" } },
               { log in Memory.with(Memory.sockaddrIn) { log.notice("option.memory.sockaddr|\($0, format: .sockaddr, privacy: .public)|") } }),
        Option("memory.sockaddr.no.port", "192.168.0.1",
               { p in Memory.with(Memory.sockaddrInNoPort) { "\($0, format: .sockaddr, privacy: p)" } },
               { log in Memory.with(Memory.sockaddrInNoPort) { log.notice("option.memory.sockaddr.no.port|\($0, format: .sockaddr, privacy: .public)|") } }),
        Option("memory.sockaddr.ipv6", "2001:db8::1.8080",
               { p in Memory.with(Memory.sockaddrIn6) { "\($0, format: .sockaddr, privacy: p)" } },
               { log in Memory.with(Memory.sockaddrIn6) { log.notice("option.memory.sockaddr.ipv6|\($0, format: .sockaddr, privacy: .public)|") } }),
        Option("memory.sockaddr.ipv6.scoped", "fe80::f:86ff:fee9:5c16%lo0",
               { p in Memory.with(Memory.sockaddrIn6Scoped) { "\($0, format: .sockaddr, privacy: p)" } },
               { log in Memory.with(Memory.sockaddrIn6Scoped) { log.notice("option.memory.sockaddr.ipv6.scoped|\($0, format: .sockaddr, privacy: .public)|") } }),
        Option("memory.sockaddr.local", "AF_UNIX:\"/tmp/tb.sock\"",
               { p in Memory.with(Memory.sockaddrUnix) { "\($0, format: .sockaddr, privacy: p)" } },
               { log in Memory.with(Memory.sockaddrUnix) { log.notice("option.memory.sockaddr.local|\($0, format: .sockaddr, privacy: .public)|") } }),
        Option("memory.sockaddr.link", "2:0:0:0:0:1%en0",
               { p in Memory.with(Memory.sockaddrLink) { "\($0, format: .sockaddr, privacy: p)" } },
               { log in Memory.with(Memory.sockaddrLink) { log.notice("option.memory.sockaddr.link|\($0, format: .sockaddr, privacy: .public)|") } }),
        Option("memory.sockaddr.link.no.address", "lo0",
               { p in Memory.with(Memory.sockaddrLinkNoAddress) { "\($0, format: .sockaddr, privacy: p)" } },
               { log in Memory.with(Memory.sockaddrLinkNoAddress) { log.notice("option.memory.sockaddr.link.no.address|\($0, format: .sockaddr, privacy: .public)|") } }),
    ]

    /// Attributes: without effect on the text, unless the last one names a special format.
    static let attributes: [Option] = [
        Option("attributes.text", "Jupiter",
               { "\("Jupiter", privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.text|\("Jupiter", privacy: .public, attributes: "foo")|") }),
        Option("attributes.text.aligned", "     Jupiter",
               { "\("Jupiter", align: .right(columns: 12), privacy: $0, attributes: "xcode:size-in-bytes")" },
               { $0.notice("option.attributes.text.aligned|\("Jupiter", align: .right(columns: 12), privacy: .public, attributes: "xcode:size-in-bytes")|") }),
        Option("attributes.text.empty", "Jupiter",
               { "\("Jupiter", privacy: $0, attributes: "")" },
               { $0.notice("option.attributes.text.empty|\("Jupiter", privacy: .public, attributes: "")|") }),
        Option("attributes.describable", "file:///tmp   ",
               { "\(URL(fileURLWithPath: "/tmp"), align: .left(columns: 14), privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.describable|\(URL(fileURLWithPath: "/tmp"), align: .left(columns: 14), privacy: .public, attributes: "foo")|") }),
        Option("attributes.type", "Int",
               { "\(Int.self, privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.type|\(Int.self, privacy: .public, attributes: "foo")|") }),
        Option("attributes.object", "7",
               { "\(NSNumber(value: 7), privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.object|\(NSNumber(value: 7), privacy: .public, attributes: "foo")|") }),
        Option("attributes.object.nil", "(null)",
               { "\(nil as NSObject?, privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.object.nil|\(nil as NSObject?, privacy: .public, attributes: "foo")|") }),
        Option("attributes.error", #"Error Domain=app.tb.tests Code=7 "(null)""#,
               { "\(NSError(domain: "app.tb.tests", code: 7), privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.error|\(NSError(domain: "app.tb.tests", code: 7), privacy: .public, attributes: "foo")|") }),
        Option("attributes.double", "    0.50",
               { "\(0.5, format: .fixed(precision: 2), align: .right(columns: 8), privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.double|\(0.5, format: .fixed(precision: 2), align: .right(columns: 8), privacy: .public, attributes: "foo")|") }),
        Option("attributes.float", "2.500000",
               { "\(Float(2.5), privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.float|\(Float(2.5), privacy: .public, attributes: "foo")|") }),
        Option("attributes.int", "42",
               { "\(42, privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.int|\(42, privacy: .public, attributes: "foo")|") }),
        Option("attributes.int.layout", "    0042",
               { "\(42, format: .decimal(minDigits: 4), align: .right(columns: 8), privacy: $0, attributes: "name=answer")" },
               { $0.notice("option.attributes.int.layout|\(42, format: .decimal(minDigits: 4), align: .right(columns: 8), privacy: .public, attributes: "name=answer")|") }),
        Option("attributes.uint8", "0x7", hidden: "0x<private>",
               { "\(UInt8(7), format: .hex(includePrefix: true), privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.uint8|\(UInt8(7), format: .hex(includePrefix: true), privacy: .public, attributes: "foo")|") }),
        Option("attributes.int.bytes", "1.54 MB",
               { "\(1_536_000, privacy: $0, attributes: "bytes")" },
               { $0.notice("option.attributes.int.bytes|\(1_536_000, privacy: .public, attributes: "bytes")|") }),
        Option("attributes.int.bytes.after.other", "1.54 MB",
               { "\(1_536_000, privacy: $0, attributes: "foo,bytes")" },
               { $0.notice("option.attributes.int.bytes.after.other|\(1_536_000, privacy: .public, attributes: "foo,bytes")|") }),
        Option("attributes.int.bytes.after.space", "1.54 MB",
               { "\(1_536_000, privacy: $0, attributes: "foo, bytes")" },
               { $0.notice("option.attributes.int.bytes.after.space|\(1_536_000, privacy: .public, attributes: "foo, bytes")|") }),
        Option("attributes.int.bytes.before.other", "1536000",
               { "\(1_536_000, privacy: $0, attributes: "bytes,foo")" },
               { $0.notice("option.attributes.int.bytes.before.other|\(1_536_000, privacy: .public, attributes: "bytes,foo")|") }),
        Option("attributes.int.bytes.before.space", "1536000",
               { "\(1_536_000, privacy: $0, attributes: "bytes ")" },
               { $0.notice("option.attributes.int.bytes.before.space|\(1_536_000, privacy: .public, attributes: "bytes ")|") }),
        Option("attributes.int.bytes.before.pair", "1.54 MB",
               { "\(1_536_000, privacy: $0, attributes: "bytes,name=x")" },
               { $0.notice("option.attributes.int.bytes.before.pair|\(1_536_000, privacy: .public, attributes: "bytes,name=x")|") }),
        Option("attributes.int.bytes.before.privacy", "1.54 MB",
               { "\(1_536_000, privacy: $0, attributes: "bytes,sensitive,mask.hash")" },
               { $0.notice("option.attributes.int.bytes.before.privacy|\(1_536_000, privacy: .public, attributes: "bytes,sensitive,mask.hash")|") }),
        Option("attributes.int.bytes.capital", "1536000",
               { "\(1_536_000, privacy: $0, attributes: "Bytes")" },
               { $0.notice("option.attributes.int.bytes.capital|\(1_536_000, privacy: .public, attributes: "Bytes")|") }),
        Option("attributes.int.bytes.twice", "1.46 MiB",
               { "\(1_536_000, privacy: $0, attributes: "bytes,iec-bytes")" },
               { $0.notice("option.attributes.int.bytes.twice|\(1_536_000, privacy: .public, attributes: "bytes,iec-bytes")|") }),
        Option("attributes.int.bytes.drops.layout", "1.54 MB",
               { "\(1_536_000, format: .decimal(explicitPositiveSign: true, minDigits: 9), align: .right(columns: 12), privacy: $0, attributes: "bytes")" },
               { $0.notice("option.attributes.int.bytes.drops.layout|\(1_536_000, format: .decimal(explicitPositiveSign: true, minDigits: 9), align: .right(columns: 12), privacy: .public, attributes: "bytes")|") }),
        Option("attributes.uint.bytes.keeps.prefix", "+0x1.54 MB", hidden: "+0x<private>",
               { "\(UInt(1_536_000), format: .hex(explicitPositiveSign: true, includePrefix: true), privacy: $0, attributes: "bytes")" },
               { $0.notice("option.attributes.uint.bytes.keeps.prefix|\(UInt(1_536_000), format: .hex(explicitPositiveSign: true, includePrefix: true), privacy: .public, attributes: "bytes")|") }),
        Option("attributes.int.iec-bytes", "1.46 MiB",
               { "\(1_536_000, privacy: $0, attributes: "iec-bytes")" },
               { $0.notice("option.attributes.int.iec-bytes|\(1_536_000, privacy: .public, attributes: "iec-bytes")|") }),
        Option("attributes.int.bitrate", "1.54 Mbps",
               { "\(1_536_000, privacy: $0, attributes: "bitrate")" },
               { $0.notice("option.attributes.int.bitrate|\(1_536_000, privacy: .public, attributes: "bitrate")|") }),
        Option("attributes.int.iec-bitrate", "1.46 Mibps",
               { "\(1_536_000, privacy: $0, attributes: "iec-bitrate")" },
               { $0.notice("option.attributes.int.iec-bitrate|\(1_536_000, privacy: .public, attributes: "iec-bitrate")|") }),
        Option("attributes.int.time_t", localTime(1_791_000_000),
               { "\(1_791_000_000, privacy: $0, attributes: "time_t")" },
               { $0.notice("option.attributes.int.time_t|\(1_791_000_000, privacy: .public, attributes: "time_t")|") }),
        Option("attributes.int.bool", "true",
               { "\(1, privacy: $0, attributes: "bool")" },
               { $0.notice("option.attributes.int.bool|\(1, privacy: .public, attributes: "bool")|") }),
        Option("attributes.int.BOOL", "NO",
               { "\(0, privacy: $0, attributes: "BOOL")" },
               { $0.notice("option.attributes.int.BOOL|\(0, privacy: .public, attributes: "BOOL")|") }),
        Option("attributes.int.in_addr", "192.168.0.1",
               { "\(0x0100A8C0, privacy: $0, attributes: "network:in_addr")" },
               { $0.notice("option.attributes.int.in_addr|\(0x0100A8C0, privacy: .public, attributes: "network:in_addr")|") }),
        Option("attributes.int8.bytes", "18.4 EB",
               { "\(Int8(-1), privacy: $0, attributes: "bytes")" },
               { $0.notice("option.attributes.int8.bytes|\(Int8(-1), privacy: .public, attributes: "bytes")|") }),
        Option("attributes.uint16.bytes", "65.5 kB",
               { "\(UInt16.max, privacy: $0, attributes: "bytes")" },
               { $0.notice("option.attributes.uint16.bytes|\(UInt16.max, privacy: .public, attributes: "bytes")|") }),
        Option("attributes.uint.bytes", "16 EiB",
               { "\(UInt.max, privacy: $0, attributes: "iec-bytes")" },
               { $0.notice("option.attributes.uint.bytes|\(UInt.max, privacy: .public, attributes: "iec-bytes")|") }),
        Option("attributes.int16.in_addr", "2.1.0.0",
               { "\(Int16(0x0102), privacy: $0, attributes: "network:in_addr")" },
               { $0.notice("option.attributes.int16.in_addr|\(Int16(0x0102), privacy: .public, attributes: "network:in_addr")|") }),
        Option("attributes.uint8.bool", "true",
               { "\(UInt8(1), privacy: $0, attributes: "bool")" },
               { $0.notice("option.attributes.uint8.bool|\(UInt8(1), privacy: .public, attributes: "bool")|") }),
        Option("attributes.int32.errno", "[2: No such file or directory]",
               { "\(Int32(2), privacy: $0, attributes: "darwin.errno")" },
               { $0.notice("option.attributes.int32.errno|\(Int32(2), privacy: .public, attributes: "darwin.errno")|") }),
        Option("attributes.int32.errno.short", "[2: No such file or directory]",
               { "\(Int32(2), privacy: $0, attributes: "errno")" },
               { $0.notice("option.attributes.int32.errno.short|\(Int32(2), privacy: .public, attributes: "errno")|") }),
        Option("attributes.uint32.errno", "[-1: Unknown error: -1]",
               { "\(UInt32.max, privacy: $0, attributes: "darwin.errno")" },
               { $0.notice("option.attributes.uint32.errno|\(UInt32.max, privacy: .public, attributes: "darwin.errno")|") }),
        Option("attributes.int32.mode", "-rw-r--r--",
               { "\(Int32(0o100644), privacy: $0, attributes: "darwin.mode")" },
               { $0.notice("option.attributes.int32.mode|\(Int32(0o100644), privacy: .public, attributes: "darwin.mode")|") }),
        Option("attributes.int32.signal", "[sigterm: Terminated]",
               { "\(Int32(15), privacy: $0, attributes: "darwin.signal")" },
               { $0.notice("option.attributes.int32.signal|\(Int32(15), privacy: .public, attributes: "darwin.signal")|") }),
        Option("attributes.int32.mach", "[0x5: (os/kern) failure]",
               { "\(Int32(5), privacy: $0, attributes: "mach.errno")" },
               { $0.notice("option.attributes.int32.mach|\(Int32(5), privacy: .public, attributes: "mach.errno")|") }),
        Option("attributes.int32.time_t", localTime(1_791_000_000),
               { "\(Int32(1_791_000_000), privacy: $0, attributes: "time_t")" },
               { $0.notice("option.attributes.int32.time_t|\(Int32(1_791_000_000), privacy: .public, attributes: "time_t")|") }),
        Option("attributes.uint32.time_t", localTime(-1),
               { "\(UInt32.max, privacy: $0, attributes: "time_t")" },
               { $0.notice("option.attributes.uint32.time_t|\(UInt32.max, privacy: .public, attributes: "time_t")|") }),
        Option("attributes.format.then.other", "1536000",
               { "\(1_536_000, format: .byteCount, privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.format.then.other|\(1_536_000, format: .byteCount, privacy: .public, attributes: "foo")|") }),
        Option("attributes.format.then.format", "1.46 MiB",
               { "\(1_536_000, format: .byteCount, privacy: $0, attributes: "iec-bytes")" },
               { $0.notice("option.attributes.format.then.format|\(1_536_000, format: .byteCount, privacy: .public, attributes: "iec-bytes")|") }),
        Option("attributes.format.then.pair", "1.54 MB",
               { "\(1_536_000, format: .byteCount, privacy: $0, attributes: "name=size")" },
               { $0.notice("option.attributes.format.then.pair|\(1_536_000, format: .byteCount, privacy: .public, attributes: "name=size")|") }),
        Option("attributes.int32.format.then.other", "2",
               { "\(Int32(2), format: .darwinErrno, privacy: $0, attributes: "foo")" },
               { $0.notice("option.attributes.int32.format.then.other|\(Int32(2), format: .darwinErrno, privacy: .public, attributes: "foo")|") }),
        Option("attributes.int32.format.then.format", "[sigint: Interrupt]",
               { "\(Int32(2), format: .darwinErrno, privacy: $0, attributes: "darwin.signal")" },
               { $0.notice("option.attributes.int32.format.then.format|\(Int32(2), format: .darwinErrno, privacy: .public, attributes: "darwin.signal")|") }),
        Option("attributes.memory", "'DE AD BE EF 01'",
               { p in Memory.with(Memory.bytes) { "\($0, privacy: p, attributes: "foo")" } },
               { log in Memory.with(Memory.bytes) { log.notice("option.attributes.memory|\($0, privacy: .public, attributes: "foo")|") } }),
        Option("attributes.memory.uuid_t", "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
               { p in Memory.with(Memory.uuid) { "\($0, privacy: p, attributes: "uuid_t")" } },
               { log in Memory.with(Memory.uuid) { log.notice("option.attributes.memory.uuid_t|\($0, privacy: .public, attributes: "uuid_t")|") } }),
        Option("attributes.memory.uuid", "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
               { p in Memory.with(Memory.uuid) { "\($0.baseAddress!, bytes: 16, privacy: p, attributes: "uuid")" } },
               { log in Memory.with(Memory.uuid) { log.notice("option.attributes.memory.uuid|\($0.baseAddress!, bytes: 16, privacy: .public, attributes: "uuid")|") } }),
        Option("attributes.memory.format.then.other", "'E6 21 E1 F8 C3 6C 49 5A 93 FC 0C 24 7A 3E 6E 5F'",
               { p in Memory.with(Memory.uuid) { "\($0, format: .uuid, privacy: p, attributes: "foo")" } },
               { log in Memory.with(Memory.uuid) { log.notice("option.attributes.memory.format.then.other|\($0, format: .uuid, privacy: .public, attributes: "foo")|") } }),
        Option("attributes.memory.format.then.format", "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
               { p in Memory.with(Memory.uuid) { "\($0, format: .ipv6Address, privacy: p, attributes: "uuid_t")" } },
               { log in Memory.with(Memory.uuid) { log.notice("option.attributes.memory.format.then.format|\($0, format: .ipv6Address, privacy: .public, attributes: "uuid_t")|") } }),
        Option("attributes.memory.in_addr", "192.168.0.1",
               { p in Memory.with(Memory.ipv4) { "\($0, privacy: p, attributes: "network:in_addr")" } },
               { log in Memory.with(Memory.ipv4) { log.notice("option.attributes.memory.in_addr|\($0, privacy: .public, attributes: "network:in_addr")|") } }),
        Option("attributes.memory.in6_addr", "2001:db8::1",
               { p in Memory.with(Memory.ipv6) { "\($0, privacy: p, attributes: "network:in6_addr")" } },
               { log in Memory.with(Memory.ipv6) { log.notice("option.attributes.memory.in6_addr|\($0, privacy: .public, attributes: "network:in6_addr")|") } }),
        Option("attributes.memory.sockaddr", "192.168.0.1:8080",
               { p in Memory.with(Memory.sockaddrIn) { "\($0, privacy: p, attributes: "network:sockaddr")" } },
               { log in Memory.with(Memory.sockaddrIn) { log.notice("option.attributes.memory.sockaddr|\($0, privacy: .public, attributes: "network:sockaddr")|") } }),
        Option("attributes.memory.timeval", localTime(1_791_000_000, fraction: ".250000"),
               { p in Memory.with(Memory.timeval) { "\($0, privacy: p, attributes: "timeval")" } },
               { log in Memory.with(Memory.timeval) { log.notice("option.attributes.memory.timeval|\($0, privacy: .public, attributes: "timeval")|") } }),
        Option("attributes.memory.timespec", localTime(1_791_000_000, fraction: ".250000000"),
               { p in Memory.with(Memory.timespec) { "\($0, privacy: p, attributes: "timespec")" } },
               { log in Memory.with(Memory.timespec) { log.notice("option.attributes.memory.timespec|\($0, privacy: .public, attributes: "timespec")|") } }),
    ]

}

// MARK: - Many values through one format

/// Values that go through a format one after the other, to compare the kit's
/// arithmetic and tables with os_log's own.
enum Sweep {
    /// Counts around every step of the units and around the places where the
    /// digits are rounded or cut.
    static let counts: [Int] = {
        var counts = [0, 1, 999, Int.max, Int.min, -1, -1000]
        for base in [1000, 1024] {
            for unit in sequence(first: base, next: { $0 < 1_000_000_000_000_000_000 / base ? $0 * base : nil }) {
                for thousandths in [994, 995, 999, 1000, 1004, 1005, 1095, 9994, 9995, 10_000, 10_040, 99_949, 99_950, 100_000, 100_600, 999_499, 999_500, 999_994, 999_999] {
                    counts.append(unit / 1000 * thousandths)
                }
            }
        }
        // Counts whose digits differ if the steps are not taken one at a time.
        return counts + [2_700_123, 2_002_663_925, 99_960_000_000, 6_448_719_702_939, 29_380_510_534_543_491]
    }()

    static let errors: [Int32] = Array(-2...45) + [102, 106, 107, 200, .max, .min]
    static let signals: [Int32] = Array(-1...33) + [.max, .min]
    static let modes: [Int32] = (0..<16).flatMap { type in [0, 0o644, 0o755, 0o4755, 0o2644, 0o1777, 0o7000].map { type << 12 | $0 } } + [-1]
    /// The codes of the kernel and of Mach messages, where os_log and
    /// `mach_error_string` have the same names.
    static let machErrors: [Int32] = Array(0...56) + Array(0x1000_0001...0x1000_0015) + Array(0x1000_4001...0x1000_400C) + [100]
    static let addresses: [Int32] = [0, 1, -1, 0x0100_A8C0, 0x0100_007F, .max, .min]

    /// Logs every value through `os.Logger`, as `sweep.<format>.<value>|<text>|`.
    static func reference(_ log: os.Logger) {
        var lines = 0
        func pace() {
            lines += 1
            if lines % 50 == 0 { Thread.sleep(forTimeInterval: 0.05) }      // leave the log some air
        }
        for count in counts {
            log.notice("sweep.count.\(count, privacy: .public)|\(count, format: .byteCount, privacy: .public) \(count, format: .byteCountIEC, privacy: .public) \(count, format: .bitrate, privacy: .public) \(count, format: .bitrateIEC, privacy: .public)|")
            pace()
        }
        for code in errors { log.notice("sweep.errno.\(code, privacy: .public)|\(code, format: .darwinErrno, privacy: .public)|"); pace() }
        for signal in signals { log.notice("sweep.signal.\(signal, privacy: .public)|\(signal, format: .darwinSignal, privacy: .public)|"); pace() }
        for mode in modes { log.notice("sweep.mode.\(mode, privacy: .public)|\(mode, format: .darwinMode, privacy: .public)|"); pace() }
        for code in machErrors { log.notice("sweep.mach.\(code, privacy: .public)|\(code, format: .machErrno, privacy: .public)|"); pace() }
        for address in addresses { log.notice("sweep.ipv4.\(address, privacy: .public)|\(address, format: .ipv4Address, privacy: .public)|"); pace() }
    }
}

@Suite struct SweepTests {
    private func text(_ message: tb.OSLogMessage) -> String { message.render(revealingHiddenValues: false) }

    @Test func countsReadAsOSLoggerWritesThem() throws {
        for count in Sweep.counts {
            let expected = try #require(try Recorded.reference("sweep.count.\(count)"), "\(count)")
            #expect(text("\(count, format: .byteCount) \(count, format: .byteCountIEC) \(count, format: .bitrate) \(count, format: .bitrateIEC)") == expected, "\(count)")
        }
    }

    @Test func codesReadAsOSLoggerWritesThem() throws {
        for code in Sweep.errors {
            #expect(text("\(code, format: .darwinErrno)") == (try #require(try Recorded.reference("sweep.errno.\(code)"))), "errno \(code)")
        }
        for signal in Sweep.signals {
            #expect(text("\(signal, format: .darwinSignal)") == (try #require(try Recorded.reference("sweep.signal.\(signal)"))), "signal \(signal)")
        }
        for mode in Sweep.modes {
            #expect(text("\(mode, format: .darwinMode)") == (try #require(try Recorded.reference("sweep.mode.\(mode)"))), "mode \(String(mode, radix: 8))")
        }
        for code in Sweep.machErrors {
            #expect(text("\(code, format: .machErrno)") == (try #require(try Recorded.reference("sweep.mach.\(code)"))), "mach \(code)")
        }
        for address in Sweep.addresses {
            #expect(text("\(address, format: .ipv4Address)") == (try #require(try Recorded.reference("sweep.ipv4.\(address)"))), "address \(address)")
        }
    }
}

// MARK: - Where the kit goes its own way

@Suite struct ValueFormatTests {
    private func text(_ message: tb.OSLogMessage) -> String { message.render(revealingHiddenValues: false) }

    /// The name of a format is read out of an attribute text as os_log reads it.
    @Test func attributesNameAFormatTheWayOSLogReadsThem() {
        let names: [(String, OSLogValueFormat?)] = [
            ("", nil), ("foo", nil), ("bytes", .bytes), ("iec-bytes", .iecBytes), ("bitrate", .bitrate), ("iec-bitrate", .iecBitrate),
            ("time_t", .time), ("bool", .truth), ("BOOL", .answer), ("network:in_addr", .ipv4),
            ("darwin.errno", .errno), ("errno", .errno), ("darwin.mode", .mode), ("darwin.signal", .signal), ("mach.errno", .machError),
            ("uuid_t", .uuid), ("uuid", .uuid), ("network:in6_addr", .ipv6), ("network:sockaddr", .sockaddr),
            ("timeval", .timeval), ("timespec", .timespec),
            // The last item counts …
            ("foo,bytes", .bytes), ("bytes,foo", nil), ("bytes,iec-bytes", .iecBytes),
            // … unless it is a privacy option, a mask or a pair.
            ("bytes,public", .bytes), ("bytes,private", .bytes), ("bytes,sensitive,mask.hash", .bytes), ("bytes,name=size", .bytes),
            ("public", nil), ("name=size", nil),
            // Spaces are skipped in front of an item, and nowhere else.
            ("foo, bytes", .bytes), ("  bytes", .bytes), ("bytes ", nil), ("\tbytes", nil),
            ("Bytes", nil), ("bytes,,", .bytes), (",", nil), ("multichar", nil), ("signpost.telemetry:number1", nil),
        ]
        for (list, format) in names {
            #expect(OSLogValueFormat(named: list) == format, "\(list.debugDescription)")
        }
    }

    /// os_log writes a note about the mismatch in these places. The kit writes
    /// the value as if no format had been named.
    @Test func aFormatThatDoesNotFitIsLeftOut() {
        // Raw memory of the wrong size for the format.
        #expect(Memory.with(Memory.bytes) { text("\($0, format: .uuid, privacy: .public)") } == "'DE AD BE EF 01'")
        #expect(Memory.with(Memory.bytes) { text("\($0, format: .ipv6Address, privacy: .public)") } == "'DE AD BE EF 01'")
        #expect(Memory.with(Memory.bytes) { text("\($0, format: .timeval, privacy: .public)") } == "'DE AD BE EF 01'")
        #expect(Memory.with(Memory.bytes) { text("\($0, format: .timespec, privacy: .public)") } == "'DE AD BE EF 01'")
        #expect(Memory.with(Memory.bytes) { text("\($0, format: .sockaddr, privacy: .public)") } == "'DE AD BE EF 01'")
        #expect(Memory.with(Array(Memory.sockaddrIn.prefix(8))) { text("\($0, format: .sockaddr, privacy: .public)") } == "'10 02 1F 90 C0 A8 00 01'")
        #expect(Memory.with([16, 99] + [UInt8](repeating: 0, count: 14)) { text("\($0, format: .sockaddr, privacy: .public)") }
                == "'10 63 00 00 00 00 00 00 00 00 00 00 00 00 00 00'")
        // A format for four bytes named for a number of another size, and one for raw memory named for a number.
        #expect(text("\(2, format: .decimal(minDigits: 3), align: .right(columns: 5), attributes: "darwin.errno")") == "  002")
        #expect(text("\(Int16(1000), attributes: "time_t")") == "1000")
        #expect(text("\(42, attributes: "uuid_t")") == "42")
        // A format named for a value that is not a whole number.
        #expect(text("\(1_536_000.0, attributes: "bytes")") == "1536000.000000")
        #expect(text("\("Jupiter", privacy: .public, attributes: "uuid_t")") == "Jupiter")
        #expect(text("\(NSNumber(value: 1_536_000), privacy: .public, attributes: "bytes")") == "1536000")
    }

    /// The memory may be gone once the log call returns; the message keeps
    /// its own copy.
    @Test func rawMemoryIsCopiedWhenTheMessageIsBuilt() {
        var bytes = Memory.bytes
        let message: tb.OSLogMessage = bytes.withUnsafeBytes { "\($0, privacy: .public)" }
        bytes = [0, 0, 0, 0, 0]
        #expect(text(message) == "'DE AD BE EF 01'")
        #expect(text("\(UnsafeRawBufferPointer(start: nil, count: 0), privacy: .public)") == "''")
    }

    /// os_log has about 1 KB for all the values of one message and cuts raw
    /// memory that does not fit, marking the cut. How much fits depends on
    /// the other values; the kit keeps the most os_log could ever store.
    @Test func rawMemoryIsCutWhereOSLogCouldNotStoreIt() {
        let most = (0..<1024).map { UInt8(truncatingIfNeeded: $0) }
        #expect(Memory.with(most) { text("\($0, privacy: .public)") } == Memory.dump(most) + "'")
        #expect(Memory.with(most + [0xFF]) { text("\($0, privacy: .public)") } == Memory.dump(most) + "…'")
        #expect(Memory.with(most + most) { text("\($0.baseAddress!, bytes: 2048, privacy: .public)") } == Memory.dump(most) + "…'")
    }

    /// A link-level address without a name for its interface carries the
    /// number of the interface; one with neither is written as bytes.
    @Test func linkLevelAddressesNeedAnInterfaceOrAnAddress() {
        let unnamed: [UInt8] = [20, UInt8(AF_LINK), 4, 0, 6, 0, 6, 0, 0xAB, 0x0C, 0xDE, 0x00, 0x10, 0xFF, 0, 0, 0, 0, 0, 0]
        let empty: [UInt8] = [8, UInt8(AF_LINK), 4, 0, 6, 0, 0, 0]
        #expect(Memory.with(unnamed) { text("\($0, format: .sockaddr, privacy: .public)") } == "ab:c:de:0:10:ff%4")
        #expect(Memory.with(empty) { text("\($0, format: .sockaddr, privacy: .public)") } == "'08 12 04 00 06 00 00 00'")
    }

    /// A time is written in the time zone of the process that logs it. The
    /// log store can only show how os_log writes the offset of the zone the
    /// tests run in; for other zones this holds the kit to the same pattern.
    @Test func aTimeCarriesTheOffsetOfItsZone() {
        #expect(text("\(1_791_000_000, format: .secondsSince1970)") == localTime(1_791_000_000))
        #expect(OSLogValueFormat.timestamp(.max) == "")

        var time = tm()
        (time.tm_year, time.tm_mon, time.tm_mday, time.tm_hour, time.tm_min, time.tm_sec) = (126, 9, 3, 1, 30, 7)
        func written(offset: Int) -> String {
            time.tm_gmtoff = offset
            return OSLogValueFormat.timestamp(time, fraction: ".250000")
        }
        #expect(written(offset: 2 * 3600) == "2026-10-03 01:30:07.250000+0200")
        #expect(written(offset: 0) == "2026-10-03 01:30:07.250000+0000")
        #expect(written(offset: -(2 * 3600 + 30 * 60)) == "2026-10-03 01:30:07.250000-0230")
        #expect(written(offset: 5 * 3600 + 45 * 60) == "2026-10-03 01:30:07.250000+0545")
        #expect(written(offset: -8 * 3600) == "2026-10-03 01:30:07.250000-0800")
        #expect(written(offset: 14 * 3600) == "2026-10-03 01:30:07.250000+1400")
        #expect(written(offset: 53 * 60 + 28) == "2026-10-03 01:30:07.250000+0053")     // seconds are left out
        time.tm_year = 10_000 - 1900
        #expect(written(offset: 3600) == "10000-10-03 01:30:07.250000+0100")
        time.tm_year = -69 - 1900
        #expect(written(offset: 3600) == "-069-10-03 01:30:07.250000+0100")
    }
}

// MARK: - Masks

@Suite struct PrivacyMaskTests {
    private func release(_ message: tb.OSLogMessage) -> String { message.render(revealingHiddenValues: false) }
    private func debug(_ message: tb.OSLogMessage) -> String { message.render(revealingHiddenValues: true) }

    /// The 16 bytes of a fingerprint, or `nil` if `text` is not one.
    private func fingerprint(_ text: String) -> Data? {
        guard text.hasPrefix("<mask.hash: '"), text.hasSuffix("'>") else { return nil }
        let data = Data(base64Encoded: String(text.dropFirst(13).dropLast(2)))
        return data?.count == 16 ? data : nil
    }

    @Test func aHiddenValueWithTheHashMaskIsWrittenAsAFingerprint() {
        let user = "jane@example.com"
        #expect(fingerprint(release("\(user, privacy: .private(mask: .hash))")) != nil)
        #expect(fingerprint(release("\(user, privacy: .sensitive(mask: .hash))")) != nil)
        #expect(fingerprint(release("\(user, privacy: .auto(mask: .hash))")) != nil)
        #expect(fingerprint(release("\(42, privacy: .private(mask: .hash))")) != nil)
        #expect(fingerprint(release("\(nil as NSObject?, privacy: .private(mask: .hash))")) != nil)
        #expect(Memory.with(Memory.uuid) { fingerprint(release("\($0, format: .uuid, privacy: .auto(mask: .hash))")) } != nil)
    }

    @Test func equalValuesHaveOneFingerprintAndOtherValuesAnother() {
        let user = "jane@example.com", copy = "jane@" + "example.com", other = "john@example.com"
        let first = release("\(user, privacy: .private(mask: .hash))")
        #expect(release("\(copy, privacy: .private(mask: .hash))") == first)
        #expect(release("\(user, privacy: .sensitive(mask: .hash))") == first)
        #expect(release("\(user as NSString, privacy: .auto(mask: .hash))") == first)
        #expect(release("\(user, align: .right(columns: 60), privacy: .private(mask: .hash), attributes: "foo")") == first)
        #expect(release("\(other, privacy: .private(mask: .hash))") != first)
        #expect(release("\("", privacy: .private(mask: .hash))") != first)
        #expect(release("a \(user, privacy: .private(mask: .hash)) b \(user, privacy: .private(mask: .hash))") == "a \(first) b \(first)")
    }

    @Test func aMaskOnlyReplacesWhatIsHidden() {
        let user = "jane@example.com"
        // Shown by its type, or by the build: written out.
        #expect(release("\(42, privacy: .auto(mask: .hash))") == "42")
        #expect(debug("\(user, privacy: .private(mask: .hash))") == user)
        #expect(debug("\(user, align: .right(columns: 20), privacy: .auto(mask: .hash))") == "    jane@example.com")
        // Sensitive: hidden in every build, so the fingerprint is there in every build.
        #expect(debug("\(user, privacy: .sensitive(mask: .hash))") == release("\(user, privacy: .sensitive(mask: .hash))"))
        #expect(fingerprint(debug("\(user, privacy: .sensitive(mask: .hash))")) != nil)
    }

    @Test func noMaskMeansPrivate() {
        let user = "jane@example.com"
        #expect(release("\(user, privacy: .private(mask: .none))") == "<private>")
        #expect(release("\(user, privacy: .sensitive(mask: .none))") == "<private>")
        #expect(release("\(user, privacy: .auto(mask: .none))") == "<private>")
        #expect(release("\(42, privacy: .auto(mask: .none))") == "42")
        #expect(debug("\(user, privacy: .private(mask: .none))") == user)
    }

    /// What os_log makes part of the message stays in front of the fingerprint,
    /// and the fingerprint is not put into a column.
    @Test func aFingerprintIsNotLaidOut() throws {
        let hashed = release("\(UInt(255), format: .hex(explicitPositiveSign: true, includePrefix: true), align: .right(columns: 60), privacy: .private(mask: .hash))")
        #expect(hashed.hasPrefix("+0x<mask.hash: '"))
        #expect(fingerprint(String(hashed.dropFirst(3))) != nil)
    }

    /// The fingerprint needs the value, so the value is described — once.
    @Test func aHashedValueIsDescribedOnce() {
        final class Probe: CustomStringConvertible, @unchecked Sendable {
            var described = 0
            var description: String { described += 1; return "probe" }
        }
        let probe = Probe()
        #expect(fingerprint(release("\(probe, privacy: .private(mask: .hash))")) != nil)
        #expect(probe.described == 1)
    }
}

// MARK: - The two builds against the two ways a system can be set up

@Suite struct PrivacyModelTests {
    /// `text` with every fingerprint replaced by `#`: os_log's and the kit's
    /// are made with different keys.
    private func withoutFingerprints(_ text: String) -> String {
        var parts = text.components(separatedBy: "<mask.hash: '")
        for index in parts.indices.dropFirst() {
            guard let end = parts[index].range(of: "'>"),
                  Data(base64Encoded: String(parts[index][..<end.lowerBound]))?.count == 16 else { continue }
            parts[index] = "#" + parts[index][end.lowerBound...]
        }
        return parts.joined(separator: "<mask.hash: '")
    }

    /// A system either records private data or it does not, and os_log writes
    /// a hidden value accordingly. A debug build of the kit writes what os_log
    /// writes on a system that records private data, and every other build
    /// what it writes on one that does not. The test finds out which kind of
    /// system it runs on and compares with the build that matches.
    @Test func aBuildWritesWhatOSLogWritesOnTheMatchingSystem() throws {
        let secret = Recorded.secret
        let recordsPrivateData = try #require(try Recorded.reference("privacy.private")) == secret
        let cases: [(String, tb.OSLogMessage)] = [
            ("privacy.private", "\(secret, privacy: .private)"),
            ("privacy.sensitive", "\(secret, privacy: .sensitive)"),
            ("privacy.sensitive.number", "\(42, privacy: .sensitive)"),
            ("privacy.private.hash", "\(secret, privacy: .private(mask: .hash))"),
            ("privacy.sensitive.hash", "\(secret, privacy: .sensitive(mask: .hash))"),
            ("privacy.auto.hash", "\(secret, privacy: .auto(mask: .hash))"),
            ("privacy.sensitive.aligned", "\(secret, align: .right(columns: 12), privacy: .sensitive)"),
            ("privacy.sensitive.prefix", "\(UInt(255), format: .hex(explicitPositiveSign: true, includePrefix: true), privacy: .sensitive)"),
            ("privacy.sensitive.hash.prefix", "\(UInt(255), format: .hex(includePrefix: true), privacy: .sensitive(mask: .hash))"),
            ("privacy.sensitive.hash.aligned", "\(secret, align: .right(columns: 40), privacy: .sensitive(mask: .hash))"),
        ]
        for (key, message) in cases {
            let expected = try #require(try Recorded.reference(key), "\(key)")
            #expect(withoutFingerprints(message.render(revealingHiddenValues: recordsPrivateData)) == withoutFingerprints(expected), "\(key)")
        }
        // os_log, too, gives equal values one fingerprint and other values another.
        let fingerprints = try #require(try Recorded.reference("privacy.sensitive.hash.three")).components(separatedBy: "|")
        #expect(fingerprints.count == 3 && fingerprints[0] == fingerprints[1] && fingerprints[0] != fingerprints[2])
        #expect(withoutFingerprints(fingerprints[0]) == "<mask.hash: '#'>")
    }
}
