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

        // Layout and number options.
        log.info("\(planet, align: .left(columns: 12)) \(count, format: .decimal(minDigits: 3), align: .right(columns: 6))")
        log.info("\(UInt8(count), format: .hex(includePrefix: true)) \(0.5, format: .fixed(precision: 2)) \(flag, format: .answer)")
        log.info("\(UInt16(count), format: .octal, align: .none, privacy: .public) \(Float(0.5), format: .exponential, privacy: .private)")

        // Masks, special formats, raw memory and attributes.
        log.info("\(planet, privacy: .private(mask: .hash)) \(planet, privacy: .sensitive(mask: .hash)) \(count, privacy: .auto(mask: .none))")
        log.info("\(count, format: .byteCount) \(Int32(count), format: .darwinErrno, privacy: .public) \(2, format: .darwinSignal)")
        withUnsafeBytes(of: count) { bytes in
            log.info("\(bytes) \(bytes, format: .none, privacy: .public) \(bytes.baseAddress!, bytes: 4, format: .uuid, privacy: .private)")
        }
        log.info("\(planet, attributes: "name=planet") \(count, format: .decimal, align: .none, privacy: .public, attributes: "bytes")")
        log.info("\(error, privacy: .public, attributes: "x") \(type(of: self), attributes: "x") \(0.5, attributes: "x") \(count, format: .bitrate, attributes: "x")")

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

        let aligned: OSLogMessage = "\(7, format: OSLogIntegerFormatting.decimal(minDigits: 3), align: OSLogStringAlignment.right(columns: 5))"
        let formatted: OSLogMessage = "\(UInt(255), format: OSLogIntegerFormatting.hex) \(0.5, format: OSLogFloatFormatting.hybrid) \(true, format: OSLogBoolFormat.answer)"

        #expect(message.render(revealingHiddenValues: false) == "explicit <private>")
        #expect(OSLogMessage(stringInterpolation: interpolation).render(revealingHiddenValues: false) == "n=7")
        let masked: OSLogMessage = "\("value", privacy: OSLogPrivacy.private(mask: OSLogPrivacy.Mask.none))"
        let special: OSLogMessage = "\(1000, format: OSLogIntExtendedFormat.byteCount) \(Int32(2), format: OSLogInt32ExtendedFormat.truth)"
        let memory: OSLogMessage = withUnsafeBytes(of: UInt8(7)) { "\($0, format: OSLogPointerFormat.none, privacy: .public)" }

        #expect(aligned.render(revealingHiddenValues: false) == "  007")
        #expect(formatted.render(revealingHiddenValues: false) == "ff 0.5 YES")
        #expect(masked.render(revealingHiddenValues: false) == "<private>")
        #expect(special.render(revealingHiddenValues: false) == "1 kB true")
        #expect(memory.render(revealingHiddenValues: false) == "'07'")
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

// MARK: - Lines that are too long

@Suite struct LongLineTests {
    private typealias Tail = tb.Logger.Tail

    private let mark = "<…>"
    private let callSite = Tail(f: "App/Reader.swift", fn: "read(_:)", ln: 12, ctx: nil, kind: nil, app: nil, ver: nil)

    private func callSite(context: [String: String]) -> Tail {
        Tail(f: "App/Reader.swift", fn: "read(_:)", ln: 12, ctx: context, kind: nil, app: nil, ver: nil)
    }

    @Test func theCapacityIsWhatOSLogWasMeasuredToStore() {
        for level in [OSLogType.debug, .info, .default, .error] {
            #expect(Logger.capacity(for: level) == 1008)
        }
        // A fault shares its room with the call stack os_log stores with it.
        #expect(Logger.capacity(for: .fault) == 786)
    }

    @Test func aLineThatFitsIsLeftAlone() {
        let tail = callSite.encoded()
        for text in ["", "short", String(repeating: "x", count: 1008 - tail.utf8.count), String(repeating: "é", count: (1008 - tail.utf8.count) / 2)] {
            let line = Logger.fitted(text: text, tail: callSite, capacity: 1008)
            #expect(line.text == text)
            #expect(line.tail == tail)
        }
    }

    @Test func aLongTextIsCutToTheByteAndMarked() {
        let tail = callSite.encoded()
        for capacity in [1008, 786] {
            for length in [capacity - tail.utf8.count + 1, capacity, 5000, 100_000] {
                let line = Logger.fitted(text: String(repeating: "x", count: length), tail: callSite, capacity: capacity)
                #expect(line.tail == tail)
                #expect(line.text.utf8.count + line.tail.utf8.count == capacity)
                #expect(line.text.hasSuffix(mark))
                #expect(line.text.dropLast(mark.count).allSatisfy { $0 == "x" })
            }
        }
    }

    /// Characters of two, three and four bytes, and characters made of
    /// several: the cut never falls inside one.
    @Test func aCutFallsBehindAWholeCharacter() {
        let tail = callSite.encoded()
        let characters: [Character] = ["é", "日", "👋", "e\u{301}", "👨‍👩‍👧‍👦", "🇩🇪", "\r\n"]
        for character in characters {
            for offset in 0..<character.utf8.count {
                let text = String(repeating: "x", count: offset) + String(repeating: String(character), count: 1000)
                let line = Logger.fitted(text: text, tail: callSite, capacity: 1008)
                let kept = line.text.dropLast(mark.count)
                #expect(line.text.hasSuffix(mark))
                #expect(text.hasPrefix(kept), "\(character.debugDescription) at \(offset)")
                #expect(kept.dropFirst(offset).allSatisfy { $0 == character }, "\(character.debugDescription) at \(offset)")
                // As much as fits: one more character would be too many.
                let used = line.text.utf8.count + tail.utf8.count
                #expect(used <= 1008 && used > 1008 - character.utf8.count, "\(character.debugDescription) at \(offset): \(used)")
            }
        }
    }

    /// A context that makes the tail longer than half the line is left out
    /// and noted; the tail stays one JSON object and the text keeps its room.
    @Test func aLongContextGivesWayBeforeTheText() throws {
        let context = ["request": String(repeating: "r", count: 400), "user": String(repeating: "u", count: 300)]
        let text = String(repeating: "x", count: 600)
        let line = Logger.fitted(text: text, tail: callSite(context: context), capacity: 1008)
        let tail = try #require(try JSONSerialization.jsonObject(with: Data(line.tail.utf8)) as? [String: Any])
        #expect(line.text == text)
        #expect(tail["ctx"] as? [String: String] == [mark: "711 bytes of context left out"])
        #expect(tail["f"] as? String == "App/Reader.swift" && tail["fn"] as? String == "read(_:)" && tail["ln"] as? Int == 12)

        // Still too long without the context: then the text is cut as well.
        let long = Logger.fitted(text: String(repeating: "x", count: 5000), tail: callSite(context: context), capacity: 1008)
        #expect(long.tail == line.tail)
        #expect(long.text.hasSuffix(mark) && long.text.utf8.count + long.tail.utf8.count == 1008)
    }

    /// A context that leaves the text half the line stays, and the text is
    /// cut around it.
    @Test func aContextOfModestSizeStays() throws {
        let context = ["request": String(repeating: "r", count: 300)]
        let line = Logger.fitted(text: String(repeating: "x", count: 5000), tail: callSite(context: context), capacity: 1008)
        let tail = try #require(try JSONSerialization.jsonObject(with: Data(line.tail.utf8)) as? [String: Any])
        #expect(tail["ctx"] as? [String: String] == context)
        #expect(line.text.hasSuffix(mark) && line.text.utf8.count + line.tail.utf8.count == 1008)
        // And where everything fits, a long context is nobody's business.
        let fits = Logger.fitted(text: "short", tail: callSite(context: ["request": String(repeating: "r", count: 800)]), capacity: 1008)
        #expect(fits.text == "short" && fits.tail.contains(String(repeating: "r", count: 800)))
    }

    /// The tail is never cut by the kit. A call site that is longer than a
    /// line on its own leaves only the mark of the text; what os_log then
    /// does to the tail is out of the kit's hands.
    @Test func aCallSiteLongerThanALineIsNotCut() {
        let endless = Tail(f: String(repeating: "/directory", count: 150), fn: "read(_:)", ln: 12, ctx: ["k": "v"], kind: nil, app: nil, ver: nil)
        let line = Logger.fitted(text: "some text", tail: endless, capacity: 1008)
        #expect(line.text == mark)
        #expect(line.tail.contains(String(repeating: "/directory", count: 150)) && line.tail.hasSuffix("}"))
        #expect(Logger.cut("some text", toUTF8Count: 3) == mark)
        #expect(Logger.cut("some text", toUTF8Count: 0) == mark)
        #expect(Logger.cut("some text", toUTF8Count: 9) == "some text")
        #expect(Logger.cut("some text", toUTF8Count: 8) == "som" + mark)
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
