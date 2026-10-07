//
//  KitDemo
//
//  Log calls written exactly as for `os.Logger`. The only import is `tb`.
//
//      swift run KitDemo [subsystem]               debug build: hidden values are written out
//      swift run -c release KitDemo [subsystem]    release build: hidden values become <private>
//
//  The last lines come from `EveryOption.swift`, which holds a call for every
//  option and is also compiled against `os.Logger`; see there.
//
//  Read the lines back with
//
//      /usr/bin/log show --last 1m --info --debug --style ndjson --predicate 'subsystem == "<subsystem>"'
//

import tb

let subsystem = CommandLine.arguments.dropFirst().first ?? "app.tb.demo"
let log = Logger(subsystem: subsystem, category: "demo")

enum DemoError: Error {
    case offCourse
}

struct Coordinates: CustomStringConvertible {
    let latitude, longitude: Double
    var description: String { "\(latitude), \(longitude)" }
}

func greet(_ planet: String) {
    log.info("Hello \(planet)")
    log.info("Hello \(planet, privacy: .public)")
}

func report(count: Int, flag: Bool, error: any Error) {
    log.notice("n=\(count) ok=\(flag) \(error)")
}

func privacyOptions(user: String, attempts: Int) {
    log.notice("user \(user, privacy: .auto) after \(attempts, privacy: .auto) attempts")
    log.notice("user \(user, privacy: .public) after \(attempts, privacy: .public) attempts")
    log.notice("user \(user, privacy: .private) after \(attempts, privacy: .private) attempts")
    log.notice("user \(user, privacy: .sensitive) after \(attempts, privacy: .sensitive) attempts")
}

func valueTypes() {
    let text = "a string"
    let ratio = 0.5
    let small: UInt8 = 255
    let position = Coordinates(latitude: 48.137, longitude: 11.575)
    log.notice("text \(text)")
    log.notice("whole numbers \(42) \(small) \(Int64.min)")
    log.notice("floating point \(ratio) \(Float(2.5))")
    log.notice("boolean \(true)")
    log.notice("error \(DemoError.offCourse)")
    log.notice("type \(Coordinates.self)")
    log.notice("describable \(position)")
    log.notice("no values, 100% literal")
}

func layoutAndFormats(file: String, size: Int, seconds: Double) {
    log.notice("|\(file, align: .left(columns: 16))|\(size, align: .right(columns: 10))|")
    log.notice("read \(size, format: .byteCount) in \(seconds, format: .fixed(precision: 2)) s, flags \(UInt8(0x2A), format: .hex(includePrefix: true))")
    log.notice("mode \(Int32(0o100644), format: .darwinMode), failed with \(Int32(2), format: .darwinErrno) after \(Int32(15), format: .darwinSignal)")
    log.notice("hidden, but laid out: |\(file, align: .right(columns: 16), privacy: .private)| \(UInt16(0x2A), format: .hex(includePrefix: true, minDigits: 4), privacy: .private)")
}

func masks(user: String, token: String) {
    log.notice("login \(user, privacy: .private(mask: .hash)), once more \(user, privacy: .private(mask: .hash))")
    log.notice("token \(token, privacy: .sensitive) or \(token, privacy: .sensitive(mask: .hash))")
}

func rawMemory() {
    let request: [UInt8] = [0xE6, 0x21, 0xE1, 0xF8, 0xC3, 0x6C, 0x49, 0x5A, 0x93, 0xFC, 0x0C, 0x24, 0x7A, 0x3E, 0x6E, 0x5F]
    request.withUnsafeBytes { bytes in
        log.notice("request \(bytes, format: .uuid), first bytes \(bytes.baseAddress!, bytes: 4, privacy: .public)")
    }
}

func attributes(size: Int, user: String) {
    log.notice("\(size, attributes: "bytes") for \(user, attributes: "name=user")")
}

func levels(runtime level: OSLogType) {
    log.trace("trace")
    log.debug("debug")
    log.info("info")
    log.notice("notice")
    log.warning("warning")
    log.error("error")
    log.critical("critical")
    log.fault("fault")
    log.log("log")
    log.log(level: level, "log at a level chosen at run time")
}

func kitAdditions(error: any Error) {
    log.notice("with context", context: ["request": "42"])
    log.error(error)
    log.error(error, privacy: .public)
}

/// A line that is longer than os_log stores: the text is cut, the call site stays.
func longLines() {
    let listing = String(repeating: "entry ", count: 400)
    log.notice("long text \(listing, privacy: .public)")
    log.fault("long text at the fault level \(listing, privacy: .public)")
    log.notice("long context", context: ["listing": listing])
}

greet("Jupiter")
report(count: 3, flag: true, error: DemoError.offCourse)
privacyOptions(user: "jane@example.com", attempts: 3)
valueTypes()
layoutAndFormats(file: "report.pdf", size: 1_536_000, seconds: 0.8215)
masks(user: "jane@example.com", token: "s3cr3t")
rawMemory()
attributes(size: 1_536_000, user: "jane@example.com")
levels(runtime: CommandLine.arguments.count > 2 ? .debug : .info)
kitAdditions(error: DemoError.offCourse)
longLines()
everyOption(log)
everyPrivacyOption(log)
