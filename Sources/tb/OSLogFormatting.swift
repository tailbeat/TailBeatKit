//
//  OSLogFormatting.swift
//  tb
//
//  os_log's layout and number options: `align:`, and the `format:` of whole
//  numbers, floating-point numbers and booleans.
//
//  The types and their members carry the names they have in the `os` module,
//  so a call written for `os.Logger` compiles unchanged. The text they produce
//  is the text os_log produces — which, for these options, is what C's
//  `printf` writes for the conversion os_log puts into its format string.
//

import Foundation

/// The most padding one value gets. os_log cuts a message at about 1 KB, so
/// nothing beyond this would be stored anyway.
private let maximumPadding = 1024

// MARK: - Alignment

/// The alignment of a value in a column of a minimum width:
/// `"\(name, align: .left(columns: 12))"`.
///
/// A value that is narrower than the column is padded with spaces; a wider
/// one is written in full. The width counts UTF-8 bytes, as os_log's does.
public struct OSLogStringAlignment: Sendable {
    /// The minimum width, or `nil` for a value that is not aligned.
    var columns: Int?
    var left: Bool

    /// The value is written as it is.
    public static var none: OSLogStringAlignment { OSLogStringAlignment(columns: nil, left: false) }

    /// The value is moved to the right end of the column.
    public static func right(columns: Int) -> OSLogStringAlignment {
        OSLogStringAlignment(columns: columns, left: false)
    }

    /// The value is moved to the left end of the column.
    public static func left(columns: Int) -> OSLogStringAlignment {
        OSLogStringAlignment(columns: columns, left: true)
    }

    /// `text` in its column, as `%*s` and `%-*s` write it. A negative width
    /// aligns to the left, whichever side was asked for.
    func apply(to text: String) -> String {
        guard let columns else { return text }
        let padding = Int(min(columns.magnitude, UInt(maximumPadding))) - text.utf8.count
        guard padding > 0 else { return text }
        let spaces = String(repeating: " ", count: padding)
        return left || columns < 0 ? text + spaces : spaces + text
    }
}

// MARK: - Whole numbers

/// The format of a whole number: `"\(mask, format: .hex(includePrefix: true))"`.
///
/// `.decimal` is there for every whole number. `.hex` and `.octal` are there
/// for unsigned numbers only: os_log refuses them for a signed number when the
/// call is compiled, and so does the kit.
///
/// `Integer` is the type of the number that is formatted. The compiler fills
/// it in at every call.
public struct OSLogIntegerFormatting<Integer: FixedWidthInteger>: Sendable {
    var radix = 10
    var explicitPositiveSign = false
    var includePrefix = false
    var uppercase = false
    var minDigits: Int?

    /// The number in base 10.
    public static var decimal: OSLogIntegerFormatting { OSLogIntegerFormatting() }

    /// The number in base 10 with at least `minDigits` digits, and with a `+`
    /// in front of a number that is not negative if `explicitPositiveSign` is set.
    public static func decimal(explicitPositiveSign: Bool = false, minDigits: Int) -> OSLogIntegerFormatting {
        OSLogIntegerFormatting(explicitPositiveSign: explicitPositiveSign, minDigits: minDigits)
    }

    /// The number in base 10, with a `+` in front of a number that is not
    /// negative if `explicitPositiveSign` is set.
    public static func decimal(explicitPositiveSign: Bool = false) -> OSLogIntegerFormatting {
        OSLogIntegerFormatting(explicitPositiveSign: explicitPositiveSign)
    }

    /// What os_log writes as literal text in front of an unsigned number: the
    /// `+`, then `0x` or `0o`. It is part of the message, not of the value, so
    /// it stays when the value is hidden and outside the column when the value
    /// is aligned.
    var prefix: String {
        guard !Integer.isSigned, explicitPositiveSign || includePrefix else { return "" }
        let sign = explicitPositiveSign ? "+" : ""
        guard includePrefix else { return sign }
        return sign + (radix == 16 ? "0x" : radix == 8 ? "0o" : "")
    }

    /// The number as text, without `prefix`.
    func text(_ number: Integer) -> String {
        if radix == 10, !explicitPositiveSign, minDigits == nil { return number.description }
        var digits = String(number.magnitude, radix: radix, uppercase: uppercase)
        if let minDigits {
            // The precision of `%.*d`: zero digits for a zero, zeros in front otherwise.
            if minDigits == 0, number == 0 {
                digits = ""
            } else if digits.utf8.count < minDigits {
                digits = String(repeating: "0", count: min(minDigits, maximumPadding) - digits.utf8.count) + digits
            }
        }
        if number < 0 { return "-" + digits }
        return explicitPositiveSign && Integer.isSigned ? "+" + digits : digits
    }
}

extension OSLogIntegerFormatting where Integer: UnsignedInteger {
    /// The number in base 16.
    public static var hex: OSLogIntegerFormatting { OSLogIntegerFormatting(radix: 16) }

    /// The number in base 16 with at least `minDigits` digits. `includePrefix`
    /// writes `0x` in front of it, `uppercase` its letters as capitals, and
    /// `explicitPositiveSign` a `+` in front of everything.
    public static func hex(explicitPositiveSign: Bool = false, includePrefix: Bool = false,
                           uppercase: Bool = false, minDigits: Int) -> OSLogIntegerFormatting {
        OSLogIntegerFormatting(radix: 16, explicitPositiveSign: explicitPositiveSign, includePrefix: includePrefix,
                               uppercase: uppercase, minDigits: minDigits)
    }

    /// The number in base 16. `includePrefix` writes `0x` in front of it,
    /// `uppercase` its letters as capitals, and `explicitPositiveSign` a `+`
    /// in front of everything.
    public static func hex(explicitPositiveSign: Bool = false, includePrefix: Bool = false,
                           uppercase: Bool = false) -> OSLogIntegerFormatting {
        OSLogIntegerFormatting(radix: 16, explicitPositiveSign: explicitPositiveSign, includePrefix: includePrefix,
                               uppercase: uppercase)
    }

    /// The number in base 8.
    public static var octal: OSLogIntegerFormatting { OSLogIntegerFormatting(radix: 8) }

    /// The number in base 8 with at least `minDigits` digits. `includePrefix`
    /// writes `0o` in front of it and `explicitPositiveSign` a `+` in front of
    /// everything. `uppercase` changes nothing: base 8 has no letters.
    public static func octal(explicitPositiveSign: Bool = false, includePrefix: Bool = false,
                             uppercase: Bool = false, minDigits: Int) -> OSLogIntegerFormatting {
        OSLogIntegerFormatting(radix: 8, explicitPositiveSign: explicitPositiveSign, includePrefix: includePrefix,
                               uppercase: uppercase, minDigits: minDigits)
    }

    /// The number in base 8. `includePrefix` writes `0o` in front of it and
    /// `explicitPositiveSign` a `+` in front of everything. `uppercase`
    /// changes nothing: base 8 has no letters.
    public static func octal(explicitPositiveSign: Bool = false, includePrefix: Bool = false,
                             uppercase: Bool = false) -> OSLogIntegerFormatting {
        OSLogIntegerFormatting(radix: 8, explicitPositiveSign: explicitPositiveSign, includePrefix: includePrefix,
                               uppercase: uppercase)
    }
}

// MARK: - Floating-point numbers

/// The format of a floating-point number: `"\(ratio, format: .fixed(precision: 2))"`.
public struct OSLogFloatFormatting: Sendable {
    /// The conversion of C's `printf` that writes the notation.
    var conversion: String
    var precision: Int?
    var explicitPositiveSign = false
    var uppercase = false

    /// Digits after the decimal point, six of them: `3.141590`.
    public static var fixed: OSLogFloatFormatting { OSLogFloatFormatting(conversion: "f") }

    /// `precision` digits after the decimal point. `explicitPositiveSign`
    /// writes a `+` in front of a number that is not negative, and `uppercase`
    /// writes `INF` and `NAN` in capitals.
    public static func fixed(precision: Int, explicitPositiveSign: Bool = false,
                             uppercase: Bool = false) -> OSLogFloatFormatting {
        OSLogFloatFormatting(conversion: "f", precision: precision, explicitPositiveSign: explicitPositiveSign,
                             uppercase: uppercase)
    }

    /// Six digits after the decimal point. `explicitPositiveSign` writes a `+`
    /// in front of a number that is not negative, and `uppercase` writes `INF`
    /// and `NAN` in capitals.
    public static func fixed(explicitPositiveSign: Bool = false, uppercase: Bool = false) -> OSLogFloatFormatting {
        OSLogFloatFormatting(conversion: "f", explicitPositiveSign: explicitPositiveSign, uppercase: uppercase)
    }

    /// The exact value in base 16: `0x1.921f9f01b866ep+1`.
    public static var hex: OSLogFloatFormatting { OSLogFloatFormatting(conversion: "a") }

    /// The exact value in base 16. `explicitPositiveSign` writes a `+` in
    /// front of a number that is not negative, and `uppercase` writes the
    /// letters as capitals.
    public static func hex(explicitPositiveSign: Bool = false, uppercase: Bool = false) -> OSLogFloatFormatting {
        OSLogFloatFormatting(conversion: "a", explicitPositiveSign: explicitPositiveSign, uppercase: uppercase)
    }

    /// One digit before the decimal point and a power of ten: `3.141590e+04`.
    public static var exponential: OSLogFloatFormatting { OSLogFloatFormatting(conversion: "e") }

    /// One digit before the decimal point, `precision` digits after it, and a
    /// power of ten. `explicitPositiveSign` writes a `+` in front of a number
    /// that is not negative, and `uppercase` writes the letters as capitals.
    public static func exponential(precision: Int, explicitPositiveSign: Bool = false,
                                   uppercase: Bool = false) -> OSLogFloatFormatting {
        OSLogFloatFormatting(conversion: "e", precision: precision, explicitPositiveSign: explicitPositiveSign,
                             uppercase: uppercase)
    }

    /// One digit before the decimal point, six digits after it, and a power of
    /// ten. `explicitPositiveSign` writes a `+` in front of a number that is
    /// not negative, and `uppercase` writes the letters as capitals.
    public static func exponential(explicitPositiveSign: Bool = false,
                                   uppercase: Bool = false) -> OSLogFloatFormatting {
        OSLogFloatFormatting(conversion: "e", explicitPositiveSign: explicitPositiveSign, uppercase: uppercase)
    }

    /// Whichever of `.fixed` and `.exponential` is shorter, without trailing
    /// zeros: `0.5`, `3.14159e+07`.
    public static var hybrid: OSLogFloatFormatting { OSLogFloatFormatting(conversion: "g") }

    /// Whichever of `.fixed` and `.exponential` is shorter, with `precision`
    /// significant digits. `explicitPositiveSign` writes a `+` in front of a
    /// number that is not negative, and `uppercase` writes the letters as
    /// capitals.
    public static func hybrid(precision: Int, explicitPositiveSign: Bool = false,
                              uppercase: Bool = false) -> OSLogFloatFormatting {
        OSLogFloatFormatting(conversion: "g", precision: precision, explicitPositiveSign: explicitPositiveSign,
                             uppercase: uppercase)
    }

    /// Whichever of `.fixed` and `.exponential` is shorter, with six
    /// significant digits. `explicitPositiveSign` writes a `+` in front of a
    /// number that is not negative, and `uppercase` writes the letters as
    /// capitals.
    public static func hybrid(explicitPositiveSign: Bool = false, uppercase: Bool = false) -> OSLogFloatFormatting {
        OSLogFloatFormatting(conversion: "g", explicitPositiveSign: explicitPositiveSign, uppercase: uppercase)
    }

    /// The number as text: the conversion os_log would store, run here.
    func text(_ number: Double) -> String {
        var specification = explicitPositiveSign ? "%+" : "%"
        if precision != nil { specification += ".*" }
        specification += uppercase ? conversion.uppercased() : conversion
        guard let precision else { return String(format: specification, number) }
        return String(format: specification, Int32(clamping: min(precision, maximumPadding)), number)
    }
}

// MARK: - Booleans

/// The format of a boolean: `"\(isOn, format: .answer)"`.
public enum OSLogBoolFormat: Sendable {
    /// `true` or `false`.
    case truth
    /// `YES` or `NO`.
    case answer

    func text(_ boolean: Bool) -> String {
        switch self {
        case .truth: boolean ? "true" : "false"
        case .answer: boolean ? "YES" : "NO"
        }
    }
}
