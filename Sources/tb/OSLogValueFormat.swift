//
//  OSLogValueFormat.swift
//  tb
//
//  os_log's special formats: a whole number written as a byte count, a
//  bitrate, a point in time, an error, a file mode, a signal or an address,
//  and raw memory written as a UUID, an address or a point in time.
//
//  os_log knows each of these under a name, which it stores in the placeholder
//  of the value: `%{bytes}ld`, `%{uuid_t}.*P`. The `format:` options below
//  stand for those names, and the `attributes:` text of a value may spell one
//  out. Either way the value ends up in `OSLogValueFormat`, which writes the
//  text os_log writes.
//

import Foundation

// MARK: - The options of a call

/// A special format for an `Int`: `"\(size, format: .byteCount)"`.
public enum OSLogIntExtendedFormat: Sendable {
    /// Bits per second in steps of 1000: `1.54 Mbps`.
    case bitrate
    /// Bits per second in steps of 1024: `1.46 Mibps`.
    case bitrateIEC
    /// Bytes in steps of 1000: `1.54 MB`.
    case byteCount
    /// Bytes in steps of 1024: `1.46 MiB`.
    case byteCountIEC
    /// Seconds since 1970 as a date and time in the local time zone:
    /// `2026-10-03 06:00:00+0200`.
    case secondsSince1970

    var name: String {
        switch self {
        case .bitrate: "bitrate"
        case .bitrateIEC: "iec-bitrate"
        case .byteCount: "bytes"
        case .byteCountIEC: "iec-bytes"
        case .secondsSince1970: "time_t"
        }
    }
}

/// A special format for an `Int32`: `"\(code, format: .darwinErrno)"`.
public enum OSLogInt32ExtendedFormat: Sendable {
    /// The four bytes of an IPv4 address: `192.168.0.1`.
    case ipv4Address
    /// Seconds since 1970 as a date and time in the local time zone:
    /// `2026-10-03 06:00:00+0200`.
    case secondsSince1970
    /// An `errno` value with its description: `[2: No such file or directory]`.
    case darwinErrno
    /// The mode of a file as `ls -l` shows it: `-rw-r--r--`.
    case darwinMode
    /// A signal with its name and description: `[sigterm: Terminated]`.
    case darwinSignal
    /// A Mach error with its description: `[0x5: (os/kern) failure]`.
    case machErrno
    /// Bits per second in steps of 1000: `1.54 Mbps`.
    case bitrate
    /// Bits per second in steps of 1024: `1.46 Mibps`.
    case bitrateIEC
    /// Bytes in steps of 1000: `1.54 MB`.
    case byteCount
    /// Bytes in steps of 1024: `1.46 MiB`.
    case byteCountIEC
    /// `true` for any number but zero, `false` for zero.
    case truth
    /// `YES` for any number but zero, `NO` for zero.
    case answer

    var name: String {
        switch self {
        case .ipv4Address: "network:in_addr"
        case .secondsSince1970: "time_t"
        case .darwinErrno: "darwin.errno"
        case .darwinMode: "darwin.mode"
        case .darwinSignal: "darwin.signal"
        case .machErrno: "mach.errno"
        case .bitrate: "bitrate"
        case .bitrateIEC: "iec-bitrate"
        case .byteCount: "bytes"
        case .byteCountIEC: "iec-bytes"
        case .truth: "bool"
        case .answer: "BOOL"
        }
    }
}

/// What raw memory holds: `"\(bytes, format: .uuid)"`.
///
/// Memory whose size does not fit the format is written as its bytes, as with
/// `.none`.
public enum OSLogPointerFormat: Sendable {
    /// The 16 bytes of an IPv6 address: `2001:db8::1`.
    case ipv6Address
    /// A `timeval` as a date and time in the local time zone, to the microsecond.
    case timeval
    /// A `timespec` as a date and time in the local time zone, to the nanosecond.
    case timespec
    /// The 16 bytes of a UUID: `E621E1F8-C36C-495A-93FC-0C247A3E6E5F`.
    case uuid
    /// A socket address: `192.168.0.1:8080`.
    case sockaddr
    /// The bytes themselves: `'DE AD BE EF 01'`.
    case none

    var name: String {
        switch self {
        case .ipv6Address: "network:in6_addr"
        case .timeval: "timeval"
        case .timespec: "timespec"
        case .uuid: "uuid_t"
        case .sockaddr: "network:sockaddr"
        case .none: ""
        }
    }
}

// MARK: - The formats

/// One of os_log's special formats, under the name os_log gives it.
enum OSLogValueFormat: String {
    case bytes
    case iecBytes = "iec-bytes"
    case bitrate
    case iecBitrate = "iec-bitrate"
    case time = "time_t"
    case truth = "bool"
    case answer = "BOOL"
    case ipv4 = "network:in_addr"
    case errno = "darwin.errno"
    case mode = "darwin.mode"
    case signal = "darwin.signal"
    case machError = "mach.errno"
    case uuid = "uuid_t"
    case ipv6 = "network:in6_addr"
    case sockaddr = "network:sockaddr"
    case timeval
    case timespec

    /// The format that the text in a placeholder names, read as os_log reads
    /// it: a list separated by commas, of which the last item counts that is
    /// neither a privacy option nor a `key=value` pair. `nil` if that item is
    /// not the name of a format — os_log then writes the value as usual.
    init?(named list: String) {
        guard !list.isEmpty else { return nil }
        var name: Substring?
        for item in list.split(separator: ",") {
            let item = item.drop { $0 == " " }
            if item.isEmpty || item.contains("=") || item.hasPrefix("mask.")
                || item == "public" || item == "private" || item == "sensitive" { continue }
            name = item
        }
        switch name {
        case "errno": self = .errno
        case "uuid": self = .uuid
        default:
            guard let name, let format = OSLogValueFormat(rawValue: String(name)) else { return nil }
            self = format
        }
    }

    /// Whether os_log applies the format to a whole number of `size` bytes.
    func fits(integerOfSize size: Int) -> Bool {
        switch self {
        case .bytes, .iecBytes, .bitrate, .iecBitrate, .truth, .answer, .ipv4: true
        case .time: size == 4 || size == 8
        case .errno, .mode, .signal, .machError: size == 4
        case .uuid, .ipv6, .sockaddr, .timeval, .timespec: false
        }
    }

    /// A whole number the format fits, as text.
    func text<T: FixedWidthInteger>(_ number: T) -> String {
        // Widened as C widens it: by its sign, or by zeros if it has none.
        let wide = Int64(truncatingIfNeeded: number)
        let narrow = Int32(truncatingIfNeeded: number)
        switch self {
        case .bytes: return Self.scaled(wide, by: 1000, units: ["B", "kB", "MB", "GB", "TB", "PB", "EB"])
        case .iecBytes: return Self.scaled(wide, by: 1024, units: ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB"])
        case .bitrate: return Self.scaled(wide, by: 1000, units: ["bps", "kbps", "Mbps", "Gbps", "Tbps"])
        case .iecBitrate: return Self.scaled(wide, by: 1024, units: ["bps", "Kibps", "Mibps", "Gibps", "Tibps"])
        case .time: return Self.timestamp(MemoryLayout<T>.size == 4 ? Int(narrow) : Int(wide))
        case .truth: return number != 0 ? "true" : "false"
        case .answer: return number != 0 ? "YES" : "NO"
        case .ipv4: return withUnsafeBytes(of: narrow) { Self.address(Array($0), family: AF_INET) } ?? ""
        case .errno: return Self.errno(narrow)
        case .mode: return Self.mode(narrow)
        case .signal: return Self.signal(narrow)
        case .machError: return Self.machError(narrow)
        case .uuid, .ipv6, .sockaddr, .timeval, .timespec: return number.description
        }
    }

    /// Raw memory as text, or `nil` if the format is not one for memory of
    /// this size.
    func text(_ bytes: [UInt8]) -> String? {
        switch self {
        case .uuid where bytes.count == MemoryLayout<uuid_t>.size:
            return withUnsafeTemporaryAllocation(of: CChar.self, capacity: 37) { text in
                uuid_unparse_upper(bytes, text.baseAddress!)
                return String(cString: text.baseAddress!)
            }
        case .ipv6: return Self.address(bytes, family: AF_INET6)
        case .ipv4: return Self.address(bytes, family: AF_INET)
        case .timeval where bytes.count == MemoryLayout<Darwin.timeval>.size:
            let time = bytes.withUnsafeBytes { $0.loadUnaligned(as: Darwin.timeval.self) }
            return Self.timestamp(time.tv_sec, fraction: String(format: ".%06d", time.tv_usec))
        case .timespec where bytes.count == MemoryLayout<Darwin.timespec>.size:
            let time = bytes.withUnsafeBytes { $0.loadUnaligned(as: Darwin.timespec.self) }
            return Self.timestamp(time.tv_sec, fraction: String(format: ".%09ld", time.tv_nsec))
        case .sockaddr: return Self.socketAddress(bytes)
        default: return nil
        }
    }
}

// MARK: - Their text

extension OSLogValueFormat {
    /// The most bytes of raw memory the kit keeps for one value. os_log has
    /// about 1 KB for all the values of a message together, so it never
    /// stores more than this either.
    static let maximumBytes = 1024

    /// Raw memory as os_log writes it without a format: `'DE AD BE EF 01'`,
    /// with `…` after the last byte when there was more than is written.
    static func bytes(_ bytes: [UInt8], truncated: Bool = false) -> String {
        let digits = Array("0123456789ABCDEF".utf8)
        var text: [UInt8] = [UInt8(ascii: "'")]
        text.reserveCapacity(3 * bytes.count + 5)
        for (index, byte) in bytes.enumerated() {
            if index > 0 { text.append(UInt8(ascii: " ")) }
            text.append(digits[Int(byte >> 4)])
            text.append(digits[Int(byte & 0x0F)])
        }
        return String(decoding: text, as: UTF8.self) + (truncated ? "…'" : "'")
    }

    /// A count in the largest unit that leaves it under 1000, with up to three
    /// digits: `1.54 MB`, `10.0 kB`, `999 B`.
    ///
    /// This is os_log's arithmetic, found by comparing with what it writes:
    /// the count is taken as unsigned, divided in whole steps of `base`, and
    /// only the remainder of the last step makes the digits after the point.
    static func scaled(_ count: Int64, by base: UInt64, units: [String]) -> String {
        var whole = UInt64(bitPattern: count), remainder: UInt64 = 0, unit = 0
        while whole >= 1000, unit < units.count - 1 {
            remainder = whole % base
            whole /= base
            unit += 1
        }
        let hundredths = whole * 100 + (remainder * 100 + base / 2) / base
        let fraction = hundredths % 100
        whole = hundredths / 100
        let number: String
        if fraction == 0 || whole >= 100 {
            number = "\(whole)"
        } else if whole >= 10 || fraction % 10 == 0 {
            number = "\(whole).\(fraction / 10)"
        } else {
            number = "\(whole).\(fraction / 10)\(fraction % 10)"
        }
        return number + " " + units[unit]
    }

    /// Seconds since 1970 as a date and time in the local time zone of this
    /// process: `2026-10-03 06:00:00+0200`, with `fraction` after the seconds.
    /// Empty for a time the calendar cannot express, as in os_log.
    static func timestamp(_ seconds: Int, fraction: String = "") -> String {
        var time = time_t(seconds)
        var parts = tm()
        guard localtime_r(&time, &parts) != nil else { return "" }
        return timestamp(parts, fraction: fraction)
    }

    /// A calendar time with the offset of its time zone from UTC, in hours and
    /// minutes.
    static func timestamp(_ parts: tm, fraction: String) -> String {
        let offset = abs(parts.tm_gmtoff)
        return String(format: "%04d-%02d-%02d %02d:%02d:%02d", parts.tm_year &+ 1900, parts.tm_mon + 1, parts.tm_mday,
                      parts.tm_hour, parts.tm_min, parts.tm_sec)
            + fraction
            + String(format: "%@%02ld%02ld", parts.tm_gmtoff < 0 ? "-" : "+", offset / 3600, offset % 3600 / 60)
    }

    /// `[2: No such file or directory]`
    static func errno(_ code: Int32) -> String {
        let text = code == 0 ? "Success" : withUnsafeTemporaryAllocation(of: CChar.self, capacity: 256) { text in
            _ = strerror_r(code, text.baseAddress!, 256)
            return String(cString: text.baseAddress!)
        }
        return "[\(code): \(text)]"
    }

    /// `-rw-r--r--`: the type of the file, then what its owner, its group and
    /// everyone else may do.
    static func mode(_ mode: Int32) -> String {
        let bits = UInt32(bitPattern: mode)
        func access(_ bit: UInt32, _ letter: Character) -> Character { bits & bit != 0 ? letter : "-" }
        func execute(_ bit: UInt32, special: UInt32, _ letter: Character) -> Character {
            switch (bits & bit != 0, bits & special != 0) {
            case (true, true): letter
            case (false, true): Character(letter.uppercased())
            case (true, false): "x"
            case (false, false): "-"
            }
        }
        let type: Character = switch bits & 0o170000 {
        case 0, 0o100000: "-"
        case 0o010000: "p"
        case 0o020000: "c"
        case 0o040000: "d"
        case 0o060000: "b"
        case 0o120000: "l"
        case 0o140000: "s"
        case 0o160000: "w"
        default: "#"
        }
        return String([type,
                       access(0o400, "r"), access(0o200, "w"), execute(0o100, special: 0o4000, "s"),
                       access(0o040, "r"), access(0o020, "w"), execute(0o010, special: 0o2000, "s"),
                       access(0o004, "r"), access(0o002, "w"), execute(0o001, special: 0o1000, "t")])
    }

    /// `[sigterm: Terminated]`
    static func signal(_ number: Int32) -> String {
        guard number >= 0, number < NSIG else { return "[\(number): Unknown signal]" }
        func entry<Table>(of table: Table) -> String {
            withUnsafeBytes(of: table) { $0.bindMemory(to: UnsafePointer<CChar>?.self)[Int(number)] }
                .map { String(cString: $0) } ?? ""
        }
        return "[sig\(entry(of: sys_signame)): \(entry(of: sys_siglist))]"
    }

    /// `[0x5: (os/kern) failure]`, with the description `mach_error_string`
    /// has for the code.
    static func machError(_ code: Int32) -> String {
        let text = mach_error_string(code).map { String(cString: $0) } ?? "(null)"
        return "[\(code == 0 ? "0" : "0x" + String(UInt32(bitPattern: code), radix: 16)): \(text)]"
    }

    /// An IPv4 or IPv6 address from its bytes, or `nil` if their number is not
    /// that of an address of the family.
    static func address(_ bytes: [UInt8], family: Int32) -> String? {
        guard bytes.count == (family == AF_INET ? 4 : 16) else { return nil }
        return withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(INET6_ADDRSTRLEN)) { text in
            inet_ntop(family, bytes, text.baseAddress!, socklen_t(INET6_ADDRSTRLEN)).map { String(cString: $0) }
        }
    }

    /// A `sockaddr`: an IPv4 address as `192.168.0.1:8080`, an IPv6 address as
    /// `2001:db8::1.8080`, each without a port that is zero; a local socket as
    /// `AF_UNIX:"/path"`; a link-level address as `2:0:0:0:0:1%en0`. `nil` for
    /// any other family and for memory too short to hold the address.
    static func socketAddress(_ bytes: [UInt8]) -> String? {
        guard bytes.count >= 2, Int(bytes[0]) <= bytes.count else { return nil }
        let length = Int(bytes[0])
        switch Int32(bytes[1]) {
        case AF_UNIX:
            let path = bytes[min(2, length)..<length].prefix { $0 != 0 }
            return "AF_UNIX:\"" + String(decoding: path, as: UTF8.self) + "\""

        case AF_LINK:
            // A `sockaddr_dl`: the name of the interface, then its address.
            guard length >= 8, 8 + Int(bytes[5]) + Int(bytes[6]) <= length else { return nil }
            let name = bytes[8..<8 + Int(bytes[5])]
            let address = bytes[name.endIndex..<name.endIndex + Int(bytes[6])]
            guard !name.isEmpty || !address.isEmpty else { return nil }
            let interface = name.isEmpty ? String(UInt16(bytes[2]) | UInt16(bytes[3]) << 8) : String(decoding: name, as: UTF8.self)
            return address.isEmpty ? interface : address.map { String($0, radix: 16) }.joined(separator: ":") + "%" + interface

        case let family where family == AF_INET && length >= MemoryLayout<sockaddr_in>.size
                || family == AF_INET6 && length >= MemoryLayout<sockaddr_in6>.size:
            let host: String? = withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(NI_MAXHOST)) { text in
                bytes.withUnsafeBytes { address in
                    getnameinfo(address.baseAddress!.assumingMemoryBound(to: Darwin.sockaddr.self), socklen_t(length),
                                text.baseAddress!, socklen_t(NI_MAXHOST), nil, 0, NI_NUMERICHOST) == 0
                        ? String(cString: text.baseAddress!) : nil
                }
            }
            let port = Int(bytes[2]) << 8 | Int(bytes[3])
            guard let host, port != 0 else { return host }
            return host + (family == AF_INET ? ":" : ".") + String(port)

        default:
            return nil
        }
    }
}
