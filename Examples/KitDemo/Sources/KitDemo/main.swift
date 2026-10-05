//
//  KitDemo
//
//  Log calls written exactly as for `os.Logger`. The only import is `tb`.
//
//      swift run KitDemo [subsystem]               debug build: hidden values are written out
//      swift run -c release KitDemo [subsystem]    release build: hidden values become <private>
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

greet("Jupiter")
report(count: 3, flag: true, error: DemoError.offCourse)
privacyOptions(user: "jane@example.com", attempts: 3)
valueTypes()
levels(runtime: CommandLine.arguments.count > 2 ? .debug : .info)
kitAdditions(error: DemoError.offCourse)
