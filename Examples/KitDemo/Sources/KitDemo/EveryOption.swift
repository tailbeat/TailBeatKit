//
//  EveryOption
//
//  A call for every kind of interpolated value and every option of os_log's
//  message syntax, written as for `os.Logger`.
//
//  This file is compiled twice. In `KitDemo` it is compiled as it stands, with
//  `import tb`. In `OSLoggerReference` the same file — a symbolic link to this
//  one — is compiled with the flag `REFERENCE`, which turns that import into
//  `import os`. Nothing else differs, so the two programs show what each
//  logger makes of the same call:
//
//      swift run KitDemo <subsystem>              the kit, category "demo"
//      swift run OSLoggerReference <subsystem>    os.Logger, category "os"
//      /usr/bin/log show --last 1m --style ndjson --predicate 'subsystem == "<subsystem>"'
//
//  Each line is `<name>|<value>|`, so that spaces around a value can be seen.
//

#if REFERENCE
import os
#else
import tb
#endif
import Foundation

struct Position: CustomStringConvertible {
    let latitude, longitude: Double
    var description: String { "\(latitude), \(longitude)" }
}

/// Values that are shown, so both loggers write them out on every system.
func everyOption(_ log: Logger) {
    let text = "Jupiter"
    let count = 42
    let ratio = 3.14159
    let columns = 12

    // Text, describable values and types: alignment
    log.notice("text|\(text, privacy: .public)|")
    log.notice("text.left|\(text, align: .left(columns: columns), privacy: .public)|")
    log.notice("text.right|\(text, align: .right(columns: columns), privacy: .public)|")
    log.notice("text.none|\(text, align: .none, privacy: .public)|")
    log.notice("text.attributes|\(text, align: .right(columns: columns), privacy: .public, attributes: "name=planet")|")
    log.notice("describable|\(Position(latitude: 48.137, longitude: 11.575), align: .right(columns: 16), privacy: .public)|")
    log.notice("describable.attributes|\(Position(latitude: 48.137, longitude: 11.575), align: .none, privacy: .public, attributes: "name=position")|")
    log.notice("type|\(Position.self, align: .left(columns: columns), privacy: .public)|")
    log.notice("type.attributes|\(Position.self, align: .none, privacy: .public, attributes: "name=type")|")

    // Objects and errors
    let object: NSObject = NSNumber(value: 7)
    let missing: NSObject? = nil
    let error: any Error = NSError(domain: "app.tb.demo", code: 7)
    let noError: (any Error)? = nil
    log.notice("object|\(object, privacy: .public)|")
    log.notice("object.attributes|\(object, privacy: .public, attributes: "name=object")|")
    log.notice("object.optional|\(missing, privacy: .public)|\(missing, privacy: .public, attributes: "name=object")|")
    log.notice("error|\(error, privacy: .public)|\(error, privacy: .public, attributes: "name=error")|")
    log.notice("error.optional|\(noError, privacy: .public)|\(noError, privacy: .public, attributes: "name=error")|")
    log.notice("error.object|\(NSError(domain: "app.tb.demo", code: 8), privacy: .public)|")

    // Whole numbers of every type: base 10
    log.notice("int|\(count, privacy: .public)|\(count, format: .decimal, align: .none, privacy: .public)|")
    log.notice("int.sign|\(count, format: .decimal(explicitPositiveSign: true), privacy: .public)|")
    log.notice("int.digits|\(-5, format: .decimal(explicitPositiveSign: true, minDigits: 4), align: .right(columns: 8), privacy: .public)|")
    log.notice("int8|\(Int8.min, format: .decimal(minDigits: 5), privacy: .public)|")
    log.notice("int16|\(Int16.min, format: .decimal(explicitPositiveSign: true), privacy: .public)|")
    log.notice("int32|\(Int32.max, format: .decimal(explicitPositiveSign: true), align: .left(columns: columns), privacy: .public)|")
    log.notice("int64|\(Int64.min, format: .decimal, privacy: .public)|")
    log.notice("uint|\(UInt.max, format: .decimal(explicitPositiveSign: true), privacy: .public)|")
    log.notice("int.attributes|\(Int16(7), format: .decimal(minDigits: 3), align: .right(columns: 6), privacy: .public, attributes: "name=count")|")

    // Unsigned whole numbers: base 16 and base 8
    log.notice("uint.hex|\(UInt(255), format: .hex, privacy: .public)|")
    log.notice("uint.hex.options|\(UInt(255), format: .hex(explicitPositiveSign: true, includePrefix: true, uppercase: true, minDigits: 8), privacy: .public)|")
    log.notice("uint.hex.prefix|\(UInt(255), format: .hex(includePrefix: true), align: .right(columns: 8), privacy: .public)|")
    log.notice("uint8.hex|\(UInt8(0xAB), format: .hex(uppercase: true), privacy: .public)|")
    log.notice("uint16.hex|\(UInt16.max, format: .hex(includePrefix: true), privacy: .public)|")
    log.notice("uint32.hex|\(UInt32.max, format: .hex(minDigits: 10), privacy: .public)|")
    log.notice("uint64.hex|\(UInt64.max, format: .hex(includePrefix: true, uppercase: true), privacy: .public)|")
    log.notice("uint.octal|\(UInt(8), format: .octal, privacy: .public)|")
    log.notice("uint.octal.options|\(UInt(8), format: .octal(explicitPositiveSign: true, includePrefix: true, uppercase: true, minDigits: 6), privacy: .public)|")
    log.notice("uint.octal.prefix|\(UInt8.max, format: .octal(includePrefix: true), privacy: .public)|")

    // Floating-point numbers
    log.notice("double|\(ratio, privacy: .public)|\(ratio, format: .fixed, align: .none, privacy: .public)|")
    log.notice("double.fixed|\(ratio, format: .fixed(precision: 2), privacy: .public)|\(ratio, format: .fixed(explicitPositiveSign: true, uppercase: true), privacy: .public)|")
    log.notice("double.exponential|\(ratio, format: .exponential, privacy: .public)|\(ratio, format: .exponential(precision: 2, explicitPositiveSign: true, uppercase: true), privacy: .public)|\(ratio, format: .exponential(uppercase: true), privacy: .public)|")
    log.notice("double.hybrid|\(ratio, format: .hybrid, privacy: .public)|\(31_415_926.5, format: .hybrid(precision: 3), privacy: .public)|\(0.5, format: .hybrid(explicitPositiveSign: true), privacy: .public)|\(0.00001234, format: .hybrid(explicitPositiveSign: true, uppercase: true), privacy: .public)|")
    log.notice("double.hex|\(ratio, format: .hex, privacy: .public)|\(ratio, format: .hex(explicitPositiveSign: true, uppercase: true), privacy: .public)|")
    log.notice("double.aligned|\(ratio, format: .fixed(precision: 1), align: .right(columns: 8), privacy: .public)|\(Double.nan, format: .fixed(uppercase: true), align: .left(columns: 6), privacy: .public)|")
    log.notice("double.attributes|\(ratio, format: .fixed(precision: 3), align: .none, privacy: .public, attributes: "name=ratio")|")
    log.notice("float|\(Float(2.5), privacy: .public)|\(Float(0.1), format: .fixed(precision: 10), align: .right(columns: 14), privacy: .public)|")
    log.notice("float.attributes|\(Float(2.5), format: .exponential, align: .none, privacy: .public, attributes: "name=ratio")|")

    // Booleans
    log.notice("bool|\(true, privacy: .public)|\(false, format: .truth, privacy: .public)|\(true, format: .answer, privacy: .public)|\(false, format: .answer, privacy: .public)|")

    // An Int in a special format
    log.notice("int.byteCount|\(1_536_000, format: .byteCount, privacy: .public)|\(1_536_000, format: .byteCountIEC, privacy: .public)|")
    log.notice("int.bitrate|\(1_536_000, format: .bitrate, privacy: .public)|\(1_536_000, format: .bitrateIEC, privacy: .public)|")
    log.notice("int.special.attributes|\(1_536_000, format: .byteCount, privacy: .public, attributes: "name=size")|")
    if #available(macOS 26, iOS 26, *) {        // `os` has this one from version 26 on
        log.notice("int.secondsSince1970|\(1_791_000_000, format: .secondsSince1970, privacy: .public)|")
    }

    // An Int32 in a special format
    log.notice("int32.byteCount|\(Int32(1_536_000), format: .byteCount, privacy: .public)|\(Int32(1_536_000), format: .byteCountIEC, privacy: .public)|")
    log.notice("int32.bitrate|\(Int32(1_536_000), format: .bitrate, privacy: .public)|\(Int32(1_536_000), format: .bitrateIEC, privacy: .public)|")
    log.notice("int32.secondsSince1970|\(Int32(1_791_000_000), format: .secondsSince1970, privacy: .public)|")
    log.notice("int32.darwinErrno|\(Int32(2), format: .darwinErrno, privacy: .public)|")
    log.notice("int32.darwinMode|\(Int32(0o100644), format: .darwinMode, privacy: .public)|")
    log.notice("int32.darwinSignal|\(Int32(15), format: .darwinSignal, privacy: .public)|")
    log.notice("int32.machErrno|\(Int32(5), format: .machErrno, privacy: .public)|")
    log.notice("int32.ipv4Address|\(Int32(0x0100_A8C0), format: .ipv4Address, privacy: .public)|")
    log.notice("int32.truth|\(Int32(1), format: .truth, privacy: .public)|\(Int32(0), format: .answer, privacy: .public)|")
    log.notice("int32.special.attributes|\(Int32(2), format: .darwinErrno, privacy: .public, attributes: "name=code")|")

    // Raw memory
    let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x01]
    bytes.withUnsafeBytes { memory in
        log.notice("memory|\(memory, privacy: .public)|\(memory, format: .none, privacy: .public)|")
        log.notice("memory.pointer|\(memory.baseAddress!, bytes: 3, privacy: .public)|\(memory.baseAddress!, bytes: 5, format: .none, privacy: .public)|")
        log.notice("memory.attributes|\(memory, format: .none, privacy: .public, attributes: "name=bytes")|\(memory.baseAddress!, bytes: 2, format: .none, privacy: .public, attributes: "name=bytes")|")
    }
    let uuid: [UInt8] = [0xE6, 0x21, 0xE1, 0xF8, 0xC3, 0x6C, 0x49, 0x5A, 0x93, 0xFC, 0x0C, 0x24, 0x7A, 0x3E, 0x6E, 0x5F]
    uuid.withUnsafeBytes { log.notice("memory.uuid|\($0, format: .uuid, privacy: .public)|") }
    let address: [UInt8] = [0x20, 0x01, 0x0D, 0xB8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    address.withUnsafeBytes { log.notice("memory.ipv6Address|\($0, format: .ipv6Address, privacy: .public)|") }
    let socket: [UInt8] = [16, 2, 0x1F, 0x90, 192, 168, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]
    socket.withUnsafeBytes { log.notice("memory.sockaddr|\($0, format: .sockaddr, privacy: .public)|") }
    var moment = timeval(tv_sec: 1_791_000_000, tv_usec: 250_000)
    withUnsafeBytes(of: &moment) { log.notice("memory.timeval|\($0, format: .timeval, privacy: .public)|") }
    var instant = timespec(tv_sec: 1_791_000_000, tv_nsec: 250_000_000)
    withUnsafeBytes(of: &instant) { log.notice("memory.timespec|\($0, format: .timespec, privacy: .public)|") }

    // An attribute that names a special format
    log.notice("attributes.format|\(1_536_000, privacy: .public, attributes: "bytes")|\(Int32(15), privacy: .public, attributes: "darwin.signal")|")
    uuid.withUnsafeBytes { log.notice("attributes.format.memory|\($0, privacy: .public, attributes: "uuid_t")|") }

    // The options, with their types spelled out
    log.log(level: OSLogType.default, "spelled.out|\(UInt8(7), format: OSLogIntegerFormatting.hex(minDigits: 2), align: OSLogStringAlignment.right(columns: 4), privacy: OSLogPrivacy.public)|\(ratio, format: OSLogFloatFormatting.fixed(precision: 1), privacy: .public)|\(true, format: OSLogBoolFormat.answer, privacy: .public)|\(1000, format: OSLogIntExtendedFormat.byteCount, privacy: .public)|\(Int32(9), format: OSLogInt32ExtendedFormat.darwinSignal, privacy: .public)|")
}

/// Values that are hidden, one way or another. What `os.Logger` makes of
/// these depends on the system that reads the log; what the kit makes of them
/// depends on the build.
func everyPrivacyOption(_ log: Logger) {
    let text = "Jupiter"
    let count = 42
    log.notice("privacy.none|\(text)|\(count)|")
    log.notice("privacy.auto|\(text, privacy: .auto)|\(count, privacy: .auto)|")
    log.notice("privacy.public|\(text, privacy: .public)|\(count, privacy: .public)|")
    log.notice("privacy.private|\(text, privacy: .private)|\(count, privacy: .private)|")
    log.notice("privacy.sensitive|\(text, privacy: .sensitive)|\(count, privacy: .sensitive)|")
    log.notice("privacy.auto.mask|\(text, privacy: .auto(mask: .hash))|\(count, privacy: .auto(mask: .hash))|\(text, privacy: .auto(mask: .none))|")
    log.notice("privacy.private.mask|\(text, privacy: .private(mask: .hash))|\(text, privacy: .private(mask: OSLogPrivacy.Mask.none))|")
    log.notice("privacy.sensitive.mask|\(text, privacy: .sensitive(mask: .hash))|\(text, privacy: .sensitive(mask: .hash))|\("Saturn", privacy: .sensitive(mask: .hash))|\(text, privacy: .sensitive(mask: .none))|")
    log.notice("privacy.layout|\(text, align: .right(columns: 12), privacy: .sensitive)|\(UInt(255), format: .hex(explicitPositiveSign: true, includePrefix: true), privacy: .sensitive)|\(UInt(255), format: .hex(includePrefix: true), privacy: .sensitive(mask: .hash))|")
    [UInt8]([0xDE, 0xAD]).withUnsafeBytes { log.notice("privacy.memory|\($0)|\($0, privacy: .private)|\($0, privacy: .sensitive)|") }
}
