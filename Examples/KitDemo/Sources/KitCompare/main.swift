//
//  KitCompare
//
//  The kit next to `os.Logger`.
//
//      swift run -c release KitCompare levels <subsystem>
//          Logs through every method of both loggers — category `os` and
//          category `tb` — so the level of each line can be compared:
//
//          /usr/bin/log show --last 1m --info --debug --style ndjson --predicate 'subsystem == "<subsystem>"'
//
//      swift run -c release KitCompare time [subsystem]
//          Times 20,000 calls with two interpolated values through each logger.
//          A live `log stream` anywhere on the system makes every call slower.
//

import Foundation
import os
import tb

let arguments = CommandLine.arguments.dropFirst()
let subsystem = arguments.dropFirst().first ?? "app.tb.compare"
let reference = os.Logger(subsystem: subsystem, category: "os")
let kit = tb.Logger(subsystem: subsystem, category: "tb")

func levels() {
    reference.trace("trace");           kit.trace("trace")
    reference.debug("debug");           kit.debug("debug")
    reference.info("info");             kit.info("info")
    reference.notice("notice");         kit.notice("notice")
    reference.warning("warning");       kit.warning("warning")
    reference.error("error");           kit.error("error")
    reference.critical("critical");     kit.critical("critical")
    reference.fault("fault");           kit.fault("fault")
    reference.log("log");               kit.log("log")
    reference.log(level: .info, "log(level: .info)")
    kit.log(level: .info, "log(level: .info)")
}

func time() {
    let calls = 20_000
    let name = "Jupiter"

    /// Microseconds per call: the median of several rounds.
    func measure(_ body: () -> Void) -> Double {
        let rounds = (0..<9).map { _ in
            let start = DispatchTime.now().uptimeNanoseconds
            body()
            return Double(DispatchTime.now().uptimeNanoseconds - start) / Double(calls) / 1000
        }
        return rounds.sorted()[rounds.count / 2]
    }

    let disabled = tb.Logger.disabled
    let results = [
        ("tb.Logger            ", measure { for i in 0..<calls { kit.info("Hello \(name) count=\(i)") } }),
        ("os.Logger            ", measure { for i in 0..<calls { reference.info("Hello \(name) count=\(i)") } }),
        ("tb.Logger, .public   ", measure { for i in 0..<calls { kit.info("Hello \(name, privacy: .public) count=\(i, privacy: .public)") } }),
        ("os.Logger, .public   ", measure { for i in 0..<calls { reference.info("Hello \(name, privacy: .public) count=\(i, privacy: .public)") } }),
        ("tb.Logger, not recorded", measure { for i in 0..<calls { disabled.info("Hello \(name) count=\(i)") } }),
    ]
    print("\(calls) calls with two interpolated values, median of 9 rounds")
    for (label, microseconds) in results {
        print("  \(label)  \(String(format: "%7.3f", microseconds)) µs per call")
    }
}

switch arguments.first {
case "levels": levels()
case "time": time()
default: print("usage: KitCompare levels <subsystem> | KitCompare time [subsystem]")
}
