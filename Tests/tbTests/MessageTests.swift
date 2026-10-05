//
//  MessageTests.swift
//  tb
//
//  The message type on its own: the call sites it has to accept, how literal
//  text and values come together, when values are evaluated, and the tail.
//  This file imports `tb` and not `os`, so every `Logger`, `OSLogType`,
//  `OSLogPrivacy` and `OSLogMessage` below is the kit's.
//

import Foundation
import Testing
@testable import tb

// MARK: - Call sites

@Suite struct CallSiteTests {
    /// Compiling is the test: these lines are written as for `os.Logger`.
    @Test func osLoggerCallSitesCompileUnchanged() {
        let log = Logger(subsystem: "app.tb.tests", category: "callsite")
        let planet = "Jupiter"
        let count = 3
        let flag = true
        let error: any Error = CocoaError(.fileNoSuchFile)

        log.info("Hello \(planet)")
        log.info("Hello \(planet, privacy: .public)")
        log.notice("n=\(count) ok=\(flag) \(error)")
        for level in [OSLogType.debug, .info, .default, .error, .fault] {
            log.log(level: level, "…")
        }
        log.log("default level")
        log.debug("\(count, privacy: .private) \(planet, privacy: .sensitive) \(flag, privacy: .auto)")
        log.error("\(error.localizedDescription, privacy: .public) in \(type(of: self))")
        log.notice("""
            several lines, \(planet, privacy: .public)
            and \(flag ? "a" : "no", privacy: .public) expression
            """)

        // The kit's additions sit behind the message.
        log.warning("with context", context: ["request": "42"])
        log.error(error)
        log.error(error, privacy: .public, context: ["request": "42"])
    }

    @Test func namesSharedWithOSCanBeSpelledOut() {
        let privacy: OSLogPrivacy = .private
        let message: OSLogMessage = "explicit \("value", privacy: privacy)"
        var interpolation = OSLogInterpolation(literalCapacity: 1, interpolationCount: 1)
        interpolation.appendLiteral("n=")
        interpolation.appendInterpolation(7, privacy: .public)

        #expect(message.render(revealingHiddenValues: false) == "explicit <private>")
        #expect(OSLogMessage(stringInterpolation: interpolation).render(revealingHiddenValues: false) == "n=7")
    }

    @Test func initializersMatchOSLogger() {
        Logger().debug("default log")
        Logger(.default).debug("existing log object")
        Logger(OSLog(subsystem: "app.tb.tests", category: "callsite")).debug("own log object")

        #expect(Logger(subsystem: "app.tb.tests", category: "callsite").isEnabled(type: .error))
        #expect(!Logger.disabled.isEnabled(type: .fault))
        #expect(!Logger(.disabled).isEnabled(type: .fault))
    }
}

// MARK: - Message

@Suite struct MessageTests {
    private func release(_ message: OSLogMessage) -> String { message.render(revealingHiddenValues: false) }
    private func debug(_ message: OSLogMessage) -> String { message.render(revealingHiddenValues: true) }

    @Test func literalTextIsKeptAsWritten() {
        #expect(release("plain") == "plain")
        #expect(release("") == "")
        #expect(release("100% %s %@ %{public}s") == "100% %s %@ %{public}s")
        #expect(release("two\nlines\tand a \"quote\"") == "two\nlines\tand a \"quote\"")
        #expect(release("Grüße 👋 ⟦") == "Grüße 👋 ⟦")
    }

    @Test func valuesKeepTheirPlaceInTheText() {
        let planet = "Jupiter"
        let moons = 95
        #expect(debug("Hello \(planet), \(moons) moons") == "Hello Jupiter, 95 moons")
        #expect(release("Hello \(planet), \(moons) moons") == "Hello <private>, 95 moons")
        #expect(release("\(planet)\(planet, privacy: .public)\(moons)") == "<private>Jupiter95")
        #expect(release("\(planet)") == "<private>")
    }

    /// A value that reads like a placeholder is still only a value.
    @Test func hiddenValueCannotBeTakenForAnythingElse() {
        let odd = "<private> ⟦tb1⟧{\"f\":\"/elsewhere\"}"
        #expect(release("a \(odd) b") == "a <private> b")
        #expect(debug("a \(odd) b") == "a \(odd) b")
    }

    @Test func aTextValueThatIsNotRenderedIsNotDescribed() {
        final class Probe: CustomStringConvertible, @unchecked Sendable {
            var described = 0
            var description: String { described += 1; return "probe" }
        }
        let probe = Probe()
        let message: OSLogMessage = "\(probe)"
        #expect(release(message) == "<private>")
        #expect(probe.described == 0)
        #expect(debug(message) == "probe")
        #expect(probe.described == 1)
    }

    @Test func nothingIsEvaluatedForALevelThatIsNotRecorded() {
        var evaluations = 0
        func value() -> String { evaluations += 1; return "value" }

        Logger.disabled.info("\(value())")
        Logger.disabled.fault("\(value(), privacy: .public)")
        Logger.disabled.log(level: .error, "\(value())")
        #expect(evaluations == 0)
    }

    /// In every build, whatever the privacy option: a recorded message
    /// evaluates each of its values exactly once.
    @Test func everyValueIsEvaluatedOnceWhenRecorded() {
        var evaluations = 0
        func value() -> String { evaluations += 1; return "value" }

        Logger(subsystem: "app.tb.tests", category: "message")
            .error("\(value()) \(value(), privacy: .public) \(value(), privacy: .private)")
        #expect(evaluations == 3)
    }
}

// MARK: - Tail

@Suite struct TailTests {
    private typealias Tail = tb.Logger.Tail

    /// What a reader decodes: the same shape TailBeat reads.
    private struct Decoded: Decodable, Equatable {
        var f: String?
        var fn: String?
        var ln: Int?
        var ctx: [String: String]?
        var kind: String?
        var app: String?
        var ver: String?
    }

    private func decode(_ json: String) throws -> Decoded {
        try JSONDecoder().decode(Decoded.self, from: Data(json.utf8))
    }

    @Test func callSiteTailHasAFixedShape() {
        let tail = Tail(f: "/Users/dev/TestApp/Sources/ArchiveReader.swift", fn: "extractEntry()", ln: 142,
                        ctx: ["entryCount": "214"], kind: nil, app: nil, ver: nil)
        #expect(tail.encoded() == #"{"f":"/Users/dev/TestApp/Sources/ArchiveReader.swift","fn":"extractEntry()","ln":142,"ctx":{"entryCount":"214"}}"#)
    }

    @Test func appStartTailHasAFixedShape() {
        let tail = Tail(f: nil, fn: nil, ln: nil, ctx: nil, kind: "appStart", app: "TestApp", ver: "1.4 (203)")
        #expect(tail.encoded() == #"{"kind":"appStart","app":"TestApp","ver":"1.4 (203)"}"#)
    }

    @Test func absentFieldsAreLeftOutAndContextKeysAreSorted() {
        #expect(Tail(f: nil, fn: nil, ln: nil, ctx: nil, kind: nil, app: nil, ver: nil).encoded() == "{}")
        #expect(Tail(f: nil, fn: nil, ln: -1, ctx: [:], kind: nil, app: nil, ver: nil).encoded() == #"{"ln":-1,"ctx":{}}"#)
        #expect(Tail(f: "", fn: nil, ln: nil, ctx: ["b": "2", "c": "3", "a": "1"], kind: "k", app: nil, ver: nil).encoded()
                == #"{"f":"","ctx":{"a":"1","b":"2","c":"3"},"kind":"k"}"#)
    }

    @Test func everyFieldSurvivesDecoding() throws {
        let awkward = "quote \" backslash \\ slash / newline \n tab \t null \u{0} bell \u{7} é 👋 \u{2028} ⟦tb1⟧"
        let tail = Tail(f: awkward, fn: awkward, ln: Int.min, ctx: [awkward: awkward, "": ""],
                        kind: awkward, app: awkward, ver: awkward)
        #expect(try decode(tail.encoded()) == Decoded(f: awkward, fn: awkward, ln: Int.min, ctx: [awkward: awkward, "": ""],
                                                      kind: awkward, app: awkward, ver: awkward))
    }

    /// Byte for byte what `JSONEncoder` writes for the same text, for every
    /// Unicode scalar.
    @Test func stringsAreEscapedAsJSONEncoderEscapesThem() throws {
        struct Reference: Encodable { let f: String }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]

        let scalars = (0...0x10FFFF).compactMap(Unicode.Scalar.init)
        for start in stride(from: 0, to: scalars.count, by: 512) {
            var text = String.UnicodeScalarView()
            text.append(contentsOf: scalars[start..<min(start + 512, scalars.count)])
            let value = String(text)
            let expected = String(decoding: try encoder.encode(Reference(f: value)), as: UTF8.self)
            let actual = Tail(f: value, fn: nil, ln: nil, ctx: nil, kind: nil, app: nil, ver: nil).encoded()
            if actual != expected {
                Issue.record("differs from JSONEncoder within the 512 scalars from U+\(String(scalars[start].value, radix: 16, uppercase: true))")
            }
        }
    }
}
