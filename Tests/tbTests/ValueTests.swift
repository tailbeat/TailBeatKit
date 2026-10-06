//
//  ValueTests.swift
//  tb
//
//  Every kind of value a message can interpolate, checked from two sides: the
//  kit against a table of expectations, and that table against what `os.Logger`
//  itself writes for the same values. The second half reads the lines back from
//  the log store, so it also covers the levels and the finished log line.
//

import Foundation
import OSLog
import os
import Testing
@testable import tb

enum PlainError: Error { case boom }

enum DescribedError: Error, CustomStringConvertible {
    case boom
    var description: String { "described boom" }
}

struct Point: CustomStringConvertible {
    let x, y: Int
    var description: String { "(\(x), \(y))" }
}

/// One kind of interpolated value.
struct Sample: Sendable, CustomTestStringConvertible {
    /// Names the sample in test output and in the lines it logs.
    let name: String
    /// The value as text.
    let text: String
    /// Whether the value is shown when no privacy option is given.
    let shownByDefault: Bool
    /// A kit message made of the value alone — with the given option, or with none.
    let message: @Sendable (tb.OSLogPrivacy?) -> tb.OSLogMessage
    /// Logs the value through `os.Logger`, as `auto.<name> <value>` with no
    /// option and as `public.<name> <value>` with `.public`.
    let reference: @Sendable (os.Logger) -> Void

    var testDescription: String { name }

    static let all: [Sample] = [
        // Text and describable values
        Sample(name: "String", text: "Jupiter", shownByDefault: false,
               message: { p in let v = "Jupiter"; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = "Jupiter"; log.notice("auto.String \(v)"); log.notice("public.String \(v, privacy: .public)") }),
        Sample(name: "Substring", text: "Jup", shownByDefault: false,
               message: { p in let v = "Jupiter".prefix(3); return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = "Jupiter".prefix(3); log.notice("auto.Substring \(v)"); log.notice("public.Substring \(v, privacy: .public)") }),
        Sample(name: "CustomStringConvertible", text: "(1, 2)", shownByDefault: false,
               message: { p in let v = Point(x: 1, y: 2); return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = Point(x: 1, y: 2); log.notice("auto.CustomStringConvertible \(v)"); log.notice("public.CustomStringConvertible \(v, privacy: .public)") }),
        Sample(name: "URL", text: "file:///tmp/report.txt", shownByDefault: false,
               message: { p in let v = URL(fileURLWithPath: "/tmp/report.txt"); return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = URL(fileURLWithPath: "/tmp/report.txt"); log.notice("auto.URL \(v)"); log.notice("public.URL \(v, privacy: .public)") }),
        Sample(name: "Any.Type", text: "Point", shownByDefault: false,
               message: { p in let v: Any.Type = Point.self; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v: Any.Type = Point.self; log.notice("auto.Any.Type \(v)"); log.notice("public.Any.Type \(v, privacy: .public)") }),

        // Objects and errors
        Sample(name: "NSObject", text: "7", shownByDefault: false,
               message: { p in let v: NSObject = NSNumber(value: 7); return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v: NSObject = NSNumber(value: 7); log.notice("auto.NSObject \(v)"); log.notice("public.NSObject \(v, privacy: .public)") }),
        Sample(name: "NSObject.subclass", text: "file:///tmp/report.txt", shownByDefault: false,
               message: { p in let v = NSURL(fileURLWithPath: "/tmp/report.txt"); return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = NSURL(fileURLWithPath: "/tmp/report.txt"); log.notice("auto.NSObject.subclass \(v)"); log.notice("public.NSObject.subclass \(v, privacy: .public)") }),
        Sample(name: "NSObject.nil", text: "(null)", shownByDefault: false,
               message: { p in let v: NSObject? = nil; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v: NSObject? = nil; log.notice("auto.NSObject.nil \(v)"); log.notice("public.NSObject.nil \(v, privacy: .public)") }),
        Sample(name: "Error", text: "tbTests.PlainError.boom", shownByDefault: false,
               message: { p in let v: any Error = PlainError.boom; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v: any Error = PlainError.boom; log.notice("auto.Error \(v)"); log.notice("public.Error \(v, privacy: .public)") }),
        Sample(name: "Error.concrete", text: "tbTests.PlainError.boom", shownByDefault: false,
               message: { p in let v = PlainError.boom; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = PlainError.boom; log.notice("auto.Error.concrete \(v)"); log.notice("public.Error.concrete \(v, privacy: .public)") }),
        Sample(name: "Error.describable", text: "described boom", shownByDefault: false,
               message: { p in let v = DescribedError.boom; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = DescribedError.boom; log.notice("auto.Error.describable \(v)"); log.notice("public.Error.describable \(v, privacy: .public)") }),
        Sample(name: "Error.optional", text: "tbTests.PlainError.boom", shownByDefault: false,
               message: { p in let v: (any Error)? = PlainError.boom; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v: (any Error)? = PlainError.boom; log.notice("auto.Error.optional \(v)"); log.notice("public.Error.optional \(v, privacy: .public)") }),
        Sample(name: "Error.nil", text: "(null)", shownByDefault: false,
               message: { p in let v: (any Error)? = nil; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v: (any Error)? = nil; log.notice("auto.Error.nil \(v)"); log.notice("public.Error.nil \(v, privacy: .public)") }),
        Sample(name: "NSError", text: #"Error Domain=app.tb.tests Code=7 "(null)""#, shownByDefault: false,
               message: { p in let v = NSError(domain: "app.tb.tests", code: 7); return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = NSError(domain: "app.tb.tests", code: 7); log.notice("auto.NSError \(v)"); log.notice("public.NSError \(v, privacy: .public)") }),
        Sample(name: "NSError.optional", text: #"Error Domain=app.tb.tests Code=7 "(null)""#, shownByDefault: false,
               message: { p in let v: NSError? = NSError(domain: "app.tb.tests", code: 7); return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v: NSError? = NSError(domain: "app.tb.tests", code: 7); log.notice("auto.NSError.optional \(v)"); log.notice("public.NSError.optional \(v, privacy: .public)") }),

        // Whole numbers
        Sample(name: "Int", text: "-42", shownByDefault: true,
               message: { p in let v = -42; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = -42; log.notice("auto.Int \(v)"); log.notice("public.Int \(v, privacy: .public)") }),
        Sample(name: "Int8", text: "-128", shownByDefault: true,
               message: { p in let v = Int8.min; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = Int8.min; log.notice("auto.Int8 \(v)"); log.notice("public.Int8 \(v, privacy: .public)") }),
        Sample(name: "Int16", text: "-32768", shownByDefault: true,
               message: { p in let v = Int16.min; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = Int16.min; log.notice("auto.Int16 \(v)"); log.notice("public.Int16 \(v, privacy: .public)") }),
        Sample(name: "Int32", text: "-2147483648", shownByDefault: true,
               message: { p in let v = Int32.min; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = Int32.min; log.notice("auto.Int32 \(v)"); log.notice("public.Int32 \(v, privacy: .public)") }),
        Sample(name: "Int64", text: "-9223372036854775808", shownByDefault: true,
               message: { p in let v = Int64.min; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = Int64.min; log.notice("auto.Int64 \(v)"); log.notice("public.Int64 \(v, privacy: .public)") }),
        Sample(name: "UInt", text: "18446744073709551615", shownByDefault: true,
               message: { p in let v = UInt.max; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = UInt.max; log.notice("auto.UInt \(v)"); log.notice("public.UInt \(v, privacy: .public)") }),
        Sample(name: "UInt8", text: "255", shownByDefault: true,
               message: { p in let v = UInt8.max; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = UInt8.max; log.notice("auto.UInt8 \(v)"); log.notice("public.UInt8 \(v, privacy: .public)") }),
        Sample(name: "UInt16", text: "65535", shownByDefault: true,
               message: { p in let v = UInt16.max; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = UInt16.max; log.notice("auto.UInt16 \(v)"); log.notice("public.UInt16 \(v, privacy: .public)") }),
        Sample(name: "UInt32", text: "4294967295", shownByDefault: true,
               message: { p in let v = UInt32.max; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = UInt32.max; log.notice("auto.UInt32 \(v)"); log.notice("public.UInt32 \(v, privacy: .public)") }),
        Sample(name: "UInt64", text: "18446744073709551615", shownByDefault: true,
               message: { p in let v = UInt64.max; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = UInt64.max; log.notice("auto.UInt64 \(v)"); log.notice("public.UInt64 \(v, privacy: .public)") }),

        // Floating point and booleans
        Sample(name: "Double", text: "3.140000", shownByDefault: true,
               message: { p in let v = 3.14; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = 3.14; log.notice("auto.Double \(v)"); log.notice("public.Double \(v, privacy: .public)") }),
        Sample(name: "Double.large", text: "100000000000000000000.000000", shownByDefault: true,
               message: { p in let v = 1e20; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = 1e20; log.notice("auto.Double.large \(v)"); log.notice("public.Double.large \(v, privacy: .public)") }),
        Sample(name: "Double.nan", text: "nan", shownByDefault: true,
               message: { p in let v = Double.nan; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = Double.nan; log.notice("auto.Double.nan \(v)"); log.notice("public.Double.nan \(v, privacy: .public)") }),
        Sample(name: "Double.infinity", text: "-inf", shownByDefault: true,
               message: { p in let v = -Double.infinity; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = -Double.infinity; log.notice("auto.Double.infinity \(v)"); log.notice("public.Double.infinity \(v, privacy: .public)") }),
        Sample(name: "Float", text: "2.500000", shownByDefault: true,
               message: { p in let v: Float = 2.5; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v: Float = 2.5; log.notice("auto.Float \(v)"); log.notice("public.Float \(v, privacy: .public)") }),
        Sample(name: "Bool.true", text: "true", shownByDefault: true,
               message: { p in let v = true; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = true; log.notice("auto.Bool.true \(v)"); log.notice("public.Bool.true \(v, privacy: .public)") }),
        Sample(name: "Bool.false", text: "false", shownByDefault: true,
               message: { p in let v = false; return p.map { "\(v, privacy: $0)" } ?? "\(v)" },
               reference: { log in let v = false; log.notice("auto.Bool.false \(v)"); log.notice("public.Bool.false \(v, privacy: .public)") }),
    ]
}

// MARK: - The kit against the table

@Suite struct RenderingTests {
    /// Both builds, from one test run: `revealingHiddenValues` is what a debug
    /// build passes as `true` and every other build as `false`.
    @Test(arguments: Sample.all)
    func everyPrivacyOptionInBothBuilds(sample: Sample) {
        let options: [(privacy: tb.OSLogPrivacy?, shown: Bool)] = [
            (nil, sample.shownByDefault),
            (.auto, sample.shownByDefault),
            (.public, true),
            (.private, false),
            (.sensitive, false),
        ]
        for option in options {
            let message = sample.message(option.privacy)
            #expect(message.render(revealingHiddenValues: true) == sample.text)
            #expect(message.render(revealingHiddenValues: false) == (option.shown ? sample.text : "<private>"))
        }
    }
}

// MARK: - The table, and the kit's log lines, against os.Logger

/// What `os.Logger` and the kit wrote for this test run, read back from the
/// log store once.
enum Recorded {
    struct Line: Sendable {
        let category: String
        let level: OSLogEntryLog.Level
        /// The format string os_log stored, e.g. `auto.Int %ld`.
        let format: String
        let message: String

        /// The message without the kit's tail.
        var text: String { message.components(separatedBy: " ⟦tb1⟧")[0] }
        /// The kit's tail, decoded.
        var tail: [String: Any]? {
            let parts = message.components(separatedBy: " ⟦tb1⟧")
            guard parts.count == 2 else { return nil }
            return try? JSONSerialization.jsonObject(with: Data(parts[1].utf8)) as? [String: Any]
        }
        /// Everything after the first word.
        func rest(of string: String) -> String {
            String(string.drop { $0 != " " }.dropFirst())
        }
    }

    static let secret = "Jupiter"

    /// Logs a line that states its own call site, to compare with its tail.
    static func logCallSite(_ kit: tb.Logger) {
        kit.error("kit.tail \(#line) \(#function, privacy: .public)", context: ["request": "42", "attempt": "2"])
    }

    static let lines: Result<[Line], any Error> = Result {
        let subsystem = "app.tb.tests.values.\(UUID().uuidString)"
        let reference = os.Logger(subsystem: subsystem, category: "os")
        let kit = tb.Logger(subsystem: subsystem, category: "tb")
        let since = Date().addingTimeInterval(-1)

        for sample in Sample.all { sample.reference(reference) }
        for (index, option) in Option.all.enumerated() {
            option.reference(reference)
            if index % 50 == 49 { Thread.sleep(forTimeInterval: 0.05) }     // leave the log some air
        }

        kit.error("kit.hidden \(secret)")
        kit.error("kit.public \(secret, privacy: .public)")
        kit.error("kit.literal 100% %s %@ %{public}s %d")
        logCallSite(kit)
        tb.Logger(subsystem: subsystem, category: "tb.error").error(CocoaError(.fileNoSuchFile))
        tb.Logger(subsystem: subsystem, category: "tb.error.public").error(CocoaError(.fileNoSuchFile), privacy: .public)

        reference.trace("level.trace");         kit.trace("level.trace")
        reference.debug("level.debug");         kit.debug("level.debug")
        reference.info("level.info");           kit.info("level.info")
        reference.notice("level.notice");       kit.notice("level.notice")
        reference.warning("level.warning");     kit.warning("level.warning")
        reference.error("level.error");         kit.error("level.error")
        reference.critical("level.critical");   kit.critical("level.critical")
        reference.fault("level.fault");         kit.fault("level.fault")
        reference.log("level.log");             kit.log("level.log")
        for level in [OSLogType.debug, .info, .default, .error, .fault] {
            reference.log(level: level, "level.log.\(level.rawValue, privacy: .public)")
            kit.log(level: level, "level.log.\(level.rawValue)")
        }
        reference.fault("end");                 kit.fault("end")

        // The store takes a moment to show new entries.
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let deadline = Date().addingTimeInterval(30)
        while true {
            let lines = try store.getEntries(at: store.position(date: since))
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == subsystem }
                .map { Line(category: $0.category, level: $0.level, format: $0.formatString, message: $0.composedMessage) }
            let complete = ["os", "tb"].allSatisfy { category in
                lines.contains { $0.category == category && $0.text == "end" }
            }
            if complete || Date() > deadline { return lines }
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    /// The line in `category` whose message starts with the word `key`.
    static func line(_ category: String, _ key: String) throws -> Line? {
        try lines.get().first { $0.category == category && ($0.text == key || $0.text.hasPrefix(key + " ")) }
    }

    /// What `os.Logger` wrote for the value of the option called `name`: the
    /// text between the bars of `option.<name>|<value>|`.
    static func option(_ name: String) throws -> String? {
        let start = "option.\(name)|"
        return try lines.get().first { $0.category == "os" && $0.message.hasPrefix(start) }
            .map { String($0.message.dropFirst(start.count).dropLast()) }
    }
}

@Suite struct OSLoggerParityTests {
    /// os_log leaves a value unredacted when the format carries no privacy flag
    /// and the value is a number; text (`%s`) and objects (`%@`) are redacted
    /// unless flagged public. `.auto` has to agree for every kind of value.
    @Test(arguments: Sample.all)
    func autoShowsWhatOSLoggerLeavesUnredacted(sample: Sample) throws {
        let line = try #require(try Recorded.line("os", "auto.\(sample.name)"))
        let placeholder = line.rest(of: line.format)
        #expect(!placeholder.contains("public") && !placeholder.contains("private") && !placeholder.contains("sensitive"),
                "os.Logger stores no privacy flag for a value without an option")
        let redactedByOSLog = placeholder.hasSuffix("s") || placeholder.hasSuffix("@")
        #expect(sample.shownByDefault == !redactedByOSLog, "os.Logger stores \(placeholder)")
    }

    @Test(arguments: Sample.all)
    func shownValueReadsAsOSLoggerWritesIt(sample: Sample) throws {
        let line = try #require(try Recorded.line("os", "public.\(sample.name)"))
        #expect(line.rest(of: line.message) == sample.text)
    }

    @Test func everyMethodLogsAtTheLevelOfItsOSLoggerNamesake() throws {
        let methods = ["trace", "debug", "info", "notice", "warning", "error", "critical", "fault", "log"]
            + [OSLogType.debug, .info, .default, .error, .fault].map { "log.\($0.rawValue)" }
        var compared: [String] = []
        for method in methods {
            let expected = try Recorded.line("os", "level.\(method)")
            let actual = try Recorded.line("tb", "level.\(method)")
            // A level the process does not record leaves no line from either logger.
            #expect((actual == nil) == (expected == nil), "\(method)")
            if let expected, let actual {
                #expect(actual.level == expected.level, "\(method)")
                compared.append(method)
            }
        }
        // The store always has notice and above. Debug and info lines are only
        // there when the process records them, as under OS_ACTIVITY_MODE=debug.
        for method in ["notice", "warning", "error", "critical", "fault", "log"] {
            #expect(compared.contains(method), "\(method)")
        }
        if ProcessInfo.processInfo.environment["OS_ACTIVITY_MODE"] == "debug" {
            #expect(compared == methods)
        }
    }

    /// The one place the build type matters: this test passes in a debug build
    /// and in a release build, with different expectations.
    @Test func theBuildDecidesWhetherAHiddenValueIsWritten() throws {
        let hidden = try #require(try Recorded.line("tb", "kit.hidden"))
        let shown = try #require(try Recorded.line("tb", "kit.public"))
        let error = try #require(try Recorded.lines.get().first { $0.category == "tb.error" })
        let publicError = try #require(try Recorded.lines.get().first { $0.category == "tb.error.public" })
        let description = CocoaError(.fileNoSuchFile).localizedDescription
        #if DEBUG
        #expect(hidden.text == "kit.hidden Jupiter")
        #expect(error.text == description)
        #else
        #expect(hidden.text == "kit.hidden <private>")
        #expect(error.text == "<private>")
        #endif
        #expect(shown.text == "kit.public Jupiter")
        #expect(publicError.text == description)
        #expect(error.level == .error)
    }

    /// The finished text travels as an argument, never as os_log's format.
    @Test func messageTextIsNeverAFormatString() throws {
        let literal = try #require(try Recorded.line("tb", "kit.literal"))
        #expect(literal.text == "kit.literal 100% %s %@ %{public}s %d")
        for line in try Recorded.lines.get() where line.category.hasPrefix("tb") {
            #expect(line.format == "%{public}s ⟦tb1⟧%{public}s")
        }
    }

    @Test func tailCarriesTheCallSiteAndTheContext() throws {
        let line = try #require(try Recorded.line("tb", "kit.tail"))
        let tail = try #require(line.tail)
        #if DEBUG
        #expect(tail["f"] as? String == #filePath)
        #else
        #expect(tail["f"] as? String == #fileID)
        #endif
        let stated = line.text.split(separator: " ")       // kit.tail <line> <function>
        #expect(tail["ln"] as? Int == Int(stated[1]))
        #expect(tail["fn"] as? String == String(stated[2]))
        #expect(tail["fn"] as? String == "logCallSite(_:)")
        #expect(tail["ctx"] as? [String: String] == ["request": "42", "attempt": "2"])
        #expect(Set(tail.keys) == ["f", "fn", "ln", "ctx"])
    }
}
