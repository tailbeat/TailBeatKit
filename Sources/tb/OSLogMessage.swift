//
//  OSLogMessage.swift
//  tb
//
//  The message type behind `Logger`. It gives log calls os_log's call form —
//  `"\(value)"`, `"\(value, privacy: .public)"` and the other options of an
//  interpolated value — through Swift's custom string interpolation, and keeps
//  every value apart from the literal text until the message is rendered.
//
//  Rendering is where a value is either written out or replaced by
//  `<private>`. The kit does this itself, so what a log line contains is
//  decided by the build that wrote it, not by the system that reads it.
//
//  The type names match the `os` module on purpose: a file that spells out
//  `OSLogMessage`, `OSLogPrivacy` or `OSLogType` compiles with only
//  `import tb`.
//

import CryptoKit
import Foundation
import os

/// The level of a log message. This is Apple's own type under its own name.
public typealias OSLogType = os.OSLogType

/// A log object, as accepted by `Logger.init(_:)`. This is Apple's own type
/// under its own name.
public typealias OSLog = os.OSLog

// MARK: - Privacy

/// The privacy of an interpolated value, written as for os_log:
/// `"\(value, privacy: .public)"`.
///
/// A value is either *shown* or *hidden*. A shown value is always written as
/// text. A hidden value is not written: `<private>` takes its place, or a
/// fingerprint of the value if the option carries the `.hash` mask.
///
/// A debug build writes out what `.private` hides, and what `.auto` hides for
/// the type of the value. What `.sensitive` hides stays hidden in every build.
public struct OSLogPrivacy: Sendable {
    enum Option: Sendable {
        case auto, `public`, `private`, sensitive
    }

    /// What is written in place of a hidden value.
    public enum Mask: Sendable {
        /// A fingerprint of the value, as `<mask.hash: '…'>`. Equal values get
        /// the same fingerprint for as long as the process runs, so they can
        /// be told apart and followed through the log without being readable.
        case hash
        /// `<private>`.
        case none
    }

    let option: Option
    var mask = Mask.none

    /// The default. Numbers and booleans are shown; everything else — text,
    /// objects, errors, describable values, raw memory — is hidden.
    public static var auto: OSLogPrivacy { OSLogPrivacy(option: .auto) }

    /// As `.auto`, with `mask` in place of a value that is hidden.
    public static func auto(mask: Mask) -> OSLogPrivacy { OSLogPrivacy(option: .auto, mask: mask) }

    /// The value is always shown.
    public static var `public`: OSLogPrivacy { OSLogPrivacy(option: .public) }

    /// The value is hidden, except in a debug build.
    public static var `private`: OSLogPrivacy { OSLogPrivacy(option: .private) }

    /// As `.private`, with `mask` in place of the hidden value.
    public static func `private`(mask: Mask) -> OSLogPrivacy { OSLogPrivacy(option: .private, mask: mask) }

    /// The value is hidden in every build.
    public static var sensitive: OSLogPrivacy { OSLogPrivacy(option: .sensitive) }

    /// As `.sensitive`, with `mask` in place of the hidden value.
    public static func sensitive(mask: Mask) -> OSLogPrivacy { OSLogPrivacy(option: .sensitive, mask: mask) }

    /// Whether a value with this option is written out. `shownByDefault` is
    /// what `.auto` means for the value's type, and `reveal` whether the build
    /// writes out what it can.
    func shows(byDefault shownByDefault: Bool, revealing reveal: Bool) -> Bool {
        switch option {
        case .auto: shownByDefault || reveal
        case .public: true
        case .private: reveal
        case .sensitive: false
        }
    }

    /// The key of this launch's fingerprints. It is made when the first one is
    /// needed and never leaves the process, so a fingerprint cannot be traced
    /// back to its value, and the same value has another one after a relaunch
    /// — as with os_log.
    private static let fingerprintKey = SymmetricKey(size: .bits256)

    /// What the `.hash` mask writes for a value with this text. The shape is
    /// os_log's: 16 bytes in Base64.
    static func fingerprint(of text: String) -> String {
        let code = HMAC<SHA256>.authenticationCode(for: Data(text.utf8), using: fingerprintKey)
        return "<mask.hash: '" + Data(code.prefix(16)).base64EncodedString() + "'>"
    }
}

// MARK: - Interpolation

/// Collects the pieces of a log message: literal text and interpolated values.
///
/// The compiler drives this type for every string literal passed to a `Logger`
/// method; it is not meant to be used directly.
public struct OSLogInterpolation: StringInterpolationProtocol {
    /// An interpolated value, kept apart from the text around it.
    ///
    /// Everything that decides how a value appears in the log lives here:
    /// formatting belongs in `render`, and a new option becomes a new property.
    struct Value {
        /// The option written at the call site.
        var privacy: OSLogPrivacy
        /// What `.auto` means for a value of this type.
        var shownByDefault: Bool
        /// Text in front of the value that os_log makes part of the message
        /// rather than of the value — the `+` and `0x` of an unsigned number.
        /// It is written for a hidden value too, and stays outside the column
        /// of an aligned one.
        var prefix = ""
        var align = OSLogStringAlignment.none
        /// The value as text, without `prefix` and not yet aligned. Not called
        /// for a value that is written as `<private>`.
        var render: () -> String

        func text(revealingHiddenValues reveal: Bool) -> String {
            let text: String
            if privacy.shows(byDefault: shownByDefault, revealing: reveal) {
                text = align.apply(to: render())
            } else if privacy.mask == .hash {
                text = OSLogPrivacy.fingerprint(of: render())
            } else {
                text = OSLogMessage.hiddenValue
            }
            // What stands for a hidden value is not aligned, as in os_log.
            return prefix.isEmpty ? text : prefix + text
        }
    }

    enum Segment {
        case literal(String)
        case value(Value)
    }

    var segments: [Segment] = []
    /// A guess at the length of the rendered text, to size its buffer once.
    var capacity: Int

    public init(literalCapacity: Int, interpolationCount: Int) {
        capacity = literalCapacity + 16 * interpolationCount
        segments.reserveCapacity(2 * interpolationCount + 1)
    }

    public mutating func appendLiteral(_ literal: String) {
        if !literal.isEmpty { segments.append(.literal(literal)) }
    }

    /// Every `appendInterpolation` ends here.
    mutating func appendValue(_ privacy: OSLogPrivacy, shownByDefault: Bool, prefix: String = "",
                              align: OSLogStringAlignment = .none, _ render: @escaping () -> String) {
        segments.append(.value(Value(privacy: privacy, shownByDefault: shownByDefault, prefix: prefix,
                                     align: align, render: render)))
    }
}

// MARK: Text — hidden by default
//
// `attributes` is the text os_log stores in the placeholder of a value, for
// tools that read the log. It only changes what is written where it names a
// special format for a whole number or for raw memory; see `appendInteger`.

extension OSLogInterpolation {
    public mutating func appendInterpolation(_ string: String, align: OSLogStringAlignment = .none,
                                             privacy: OSLogPrivacy = .auto, attributes: String = "") {
        appendValue(privacy, shownByDefault: false, align: align) { string }
    }

    /// Any describable value, written as its `description`.
    public mutating func appendInterpolation<T: CustomStringConvertible>(
        _ value: T, align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto, attributes: String = "") {
        appendValue(privacy, shownByDefault: false, align: align) { value.description }
    }

    /// A type, written as its unqualified name.
    public mutating func appendInterpolation(_ type: any Any.Type, align: OSLogStringAlignment = .none,
                                             privacy: OSLogPrivacy = .auto, attributes: String = "") {
        appendValue(privacy, shownByDefault: false, align: align) { String(describing: type) }
    }
}

// MARK: Objects and errors — hidden by default

extension OSLogInterpolation {
    public mutating func appendInterpolation(_ object: NSObject, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendValue(privacy, shownByDefault: false) { object.description }
    }

    public mutating func appendInterpolation(_ object: NSObject?, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendValue(privacy, shownByDefault: false) { object?.description ?? "(null)" }
    }

    // The error overloads are generic so that a value which is both an object
    // and an error — an `NSError` — has one best match: the object overload
    // above, which is not generic.

    /// An error, written as os_log writes it: the description of its `NSError` form.
    public mutating func appendInterpolation<E: Error>(_ error: E, privacy: OSLogPrivacy = .auto,
                                                       attributes: String = "") {
        appendValue(privacy, shownByDefault: false) { (error as NSError).description }
    }

    public mutating func appendInterpolation<E: Error>(_ error: E?, privacy: OSLogPrivacy = .auto,
                                                       attributes: String = "") {
        appendValue(privacy, shownByDefault: false) { (error as NSError?)?.description ?? "(null)" }
    }

    /// An error that is also describable is written as an error. Without this
    /// overload such a value would match the error overload and the describable
    /// one equally well.
    public mutating func appendInterpolation<E: Error & CustomStringConvertible>(
        _ error: E, privacy: OSLogPrivacy = .auto, attributes: String = "") {
        appendValue(privacy, shownByDefault: false) { (error as NSError).description }
    }
}

// MARK: Numbers and booleans — shown by default

extension OSLogInterpolation {
    public mutating func appendInterpolation(_ number: Int, format: OSLogIntegerFormatting<Int> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInteger(number, format, align, privacy, attributes)
    }

    public mutating func appendInterpolation(_ number: Int8, format: OSLogIntegerFormatting<Int8> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInteger(number, format, align, privacy, attributes)
    }

    public mutating func appendInterpolation(_ number: Int16, format: OSLogIntegerFormatting<Int16> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInteger(number, format, align, privacy, attributes)
    }

    public mutating func appendInterpolation(_ number: Int32, format: OSLogIntegerFormatting<Int32> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInteger(number, format, align, privacy, attributes)
    }

    public mutating func appendInterpolation(_ number: Int64, format: OSLogIntegerFormatting<Int64> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInteger(number, format, align, privacy, attributes)
    }

    public mutating func appendInterpolation(_ number: UInt, format: OSLogIntegerFormatting<UInt> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInteger(number, format, align, privacy, attributes)
    }

    public mutating func appendInterpolation(_ number: UInt8, format: OSLogIntegerFormatting<UInt8> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInteger(number, format, align, privacy, attributes)
    }

    public mutating func appendInterpolation(_ number: UInt16, format: OSLogIntegerFormatting<UInt16> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInteger(number, format, align, privacy, attributes)
    }

    public mutating func appendInterpolation(_ number: UInt32, format: OSLogIntegerFormatting<UInt32> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInteger(number, format, align, privacy, attributes)
    }

    public mutating func appendInterpolation(_ number: UInt64, format: OSLogIntegerFormatting<UInt64> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInteger(number, format, align, privacy, attributes)
    }

    /// os_log refuses `.hex` and `.octal` for a signed number, with this
    /// message, when the call is compiled. This overload is what such a call
    /// resolves to, so the kit refuses it in the same way.
    @available(*, unavailable, message: "Signed integers must be formatted using .decimal")
    public mutating func appendInterpolation<T: FixedWidthInteger & SignedInteger>(
        _ number: T, format: OSLogIntegerFormatting<UInt>, align: OSLogStringAlignment = .none,
        privacy: OSLogPrivacy = .auto, attributes: String = "") {}

    /// An `Int` in one of os_log's special formats.
    public mutating func appendInterpolation(_ number: Int, format: OSLogIntExtendedFormat,
                                             privacy: OSLogPrivacy = .auto, attributes: String = "") {
        appendInteger(number, .decimal, .none, privacy, attributes.isEmpty ? format.name : format.name + "," + attributes)
    }

    /// An `Int32` in one of os_log's special formats.
    public mutating func appendInterpolation(_ number: Int32, format: OSLogInt32ExtendedFormat,
                                             privacy: OSLogPrivacy = .auto, attributes: String = "") {
        appendInteger(number, .decimal, .none, privacy, attributes.isEmpty ? format.name : format.name + "," + attributes)
    }

    /// `attributes` is what os_log stores next to the privacy option in the
    /// placeholder of the value. If it names a special format that fits the
    /// number, os_log writes the number in that format and drops `format` and
    /// `align`; so does the kit.
    mutating func appendInteger<T: FixedWidthInteger>(_ number: T, _ format: OSLogIntegerFormatting<T>,
                                                      _ align: OSLogStringAlignment, _ privacy: OSLogPrivacy,
                                                      _ attributes: String) {
        if let special = OSLogValueFormat(named: attributes), special.fits(integerOfSize: MemoryLayout<T>.size) {
            appendValue(privacy, shownByDefault: true, prefix: format.prefix) { special.text(number) }
        } else {
            appendValue(privacy, shownByDefault: true, prefix: format.prefix, align: align) { format.text(number) }
        }
    }

    /// Written with six decimal places unless `format` says otherwise, as
    /// os_log's default `%f`.
    public mutating func appendInterpolation(_ number: Double, format: OSLogFloatFormatting = .fixed,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendValue(privacy, shownByDefault: true, align: align) { format.text(number) }
    }

    public mutating func appendInterpolation(_ number: Float, format: OSLogFloatFormatting = .fixed,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInterpolation(Double(number), format: format, align: align, privacy: privacy)
    }

    /// Written as `true` or `false` unless `format` says otherwise.
    public mutating func appendInterpolation(_ boolean: Bool, format: OSLogBoolFormat = .truth,
                                             privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: true) { format.text(boolean) }
    }
}

// MARK: Raw memory — hidden by default

extension OSLogInterpolation {
    /// Raw memory, written as its bytes unless `format` says what they hold.
    ///
    /// The bytes are copied when the message is built, so the memory has to
    /// live no longer than the log call.
    public mutating func appendInterpolation(_ pointer: UnsafeRawBufferPointer, format: OSLogPointerFormat = .none,
                                             privacy: OSLogPrivacy = .auto, attributes: String = "") {
        let bytes = Array(pointer.prefix(OSLogValueFormat.maximumBytes))
        let truncated = pointer.count > bytes.count
        let special = OSLogValueFormat(named: attributes.isEmpty ? format.name : format.name + "," + attributes)
        appendValue(privacy, shownByDefault: false) {
            special?.text(bytes) ?? OSLogValueFormat.bytes(bytes, truncated: truncated)
        }
    }

    /// `bytes` bytes of raw memory from `pointer` on.
    public mutating func appendInterpolation(_ pointer: UnsafeRawPointer, bytes: Int,
                                             format: OSLogPointerFormat = .none, privacy: OSLogPrivacy = .auto,
                                             attributes: String = "") {
        appendInterpolation(UnsafeRawBufferPointer(start: pointer, count: max(bytes, 0)), format: format,
                            privacy: privacy, attributes: attributes)
    }
}

// MARK: - Message

/// A log message: literal text with interpolated values.
///
/// Create one by passing a string literal to a `Logger` method. A `String`
/// variable is passed as an interpolated value: `log.info("\(text)")`.
public struct OSLogMessage: ExpressibleByStringInterpolation {
    /// What is written in place of a hidden value.
    static let hiddenValue = "<private>"

    let interpolation: OSLogInterpolation

    public init(stringInterpolation: OSLogInterpolation) {
        interpolation = stringInterpolation
    }

    public init(stringLiteral value: String) {
        var interpolation = OSLogInterpolation(literalCapacity: value.utf8.count, interpolationCount: 0)
        interpolation.appendLiteral(value)
        self.interpolation = interpolation
    }

    /// The message as text. Hidden values are written out when `reveal` is
    /// true and as `<private>` otherwise.
    func render(revealingHiddenValues reveal: Bool) -> String {
        var text = ""
        text.reserveCapacity(interpolation.capacity)
        for segment in interpolation.segments {
            switch segment {
            case .literal(let literal): text += literal
            case .value(let value): text += value.text(revealingHiddenValues: reveal)
            }
        }
        return text
    }
}
