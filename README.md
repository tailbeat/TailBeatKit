# TailBeatKit

`tb` is a drop-in replacement for `os.Logger`. It writes to the unified log,
takes the same calls — with os_log's options for privacy, layout and format —
and adds the call site and an optional context to every line, so a reader like
TailBeat can show where a line came from.

It has no dependencies and runs on macOS 12+ and iOS 15+ (iPadOS and CarPlay
included).

## Install

Add the package and its `tb` product:

```swift
dependencies: [
    .package(url: "https://github.com/tailbeat/TailBeatKit.git", from: "<latest release>"),
],
targets: [
    .target(name: "App", dependencies: [.product(name: "tb", package: "TailBeatKit")]),
]
```

## Use

Replace `import os` with `import tb`. The call sites stay as they are.

```swift
import tb

private let log = Logger(subsystem: "com.example.app", category: "sync")

log.info("sync started")
log.notice("imported \(count) files, cache used: \(usedCache)")
log.error("could not open \(url, privacy: .public): \(error)")
log.debug("read \(size, format: .byteCount) in \(seconds, format: .fixed(precision: 2)) s")
```

The initializers (`init(subsystem:category:)`, `init()`, `init(_: OSLog)`),
`isEnabled(type:)` and the methods are those of `os.Logger`, and each method
logs at the same level:

| Method | Level |
| --- | --- |
| `trace`, `debug` | debug |
| `info` | info |
| `notice`, `log(_:)` | default (notice) |
| `warning`, `error` | error |
| `critical`, `fault` | fault |
| `log(level:_:)` | the level you pass |

A message is a string literal. To log a `String` you already have, interpolate
it: `log.info("\(text)")`. A message is only built, and its interpolated
expressions only evaluated, when its level is recorded.

## Privacy

Every interpolated value is either *shown* or *hidden*. Without an option, the
kind of value decides, as in os_log:

| Value | Without an option |
| --- | --- |
| `Int`, `UInt` and the sized whole-number types, `Double`, `Float`, `Bool` — in any format | shown |
| `String`, objects (`NSObject`), errors, types, anything `CustomStringConvertible`, raw memory | hidden |

The `privacy:` option overrides that for one value:

| Option | The value is |
| --- | --- |
| `.auto` | shown or hidden by its kind (the default) |
| `.public` | shown |
| `.private` | hidden |
| `.sensitive` | hidden, in a debug build too |

A shown value is always written out. A hidden value depends on the build that
writes the line:

- a **debug build** writes it out, so you see what you are working on — except
  a `.sensitive` value, which no build writes out;
- **every other build** writes `<private>` in its place.

```swift
log.info("Hello \(planet)")                       // release: Hello <private>    debug: Hello Jupiter
log.info("Hello \(planet, privacy: .public)")     // release: Hello Jupiter      debug: Hello Jupiter
log.info("\(count) moons")                        // release: 95 moons           debug: 95 moons
log.info("\(count, privacy: .private) moons")     // release: <private> moons    debug: 95 moons
log.info("token \(token, privacy: .sensitive)")   // release: token <private>    debug: token <private>
```

"Debug build" means the kit was compiled with the `DEBUG` condition, which is
what SwiftPM and Xcode do for a debug configuration.

This is what os_log does on a system that records private data, and on one
that does not: where private data is recorded, a private value is readable and
a sensitive one still is not.

### Masks

`.auto(mask:)`, `.private(mask:)` and `.sensitive(mask:)` say what is written
in place of the value when it is hidden. With `.hash` that is a fingerprint
of the value instead of `<private>`:

```swift
log.info("login \(user, privacy: .private(mask: .hash))")
// release: login <mask.hash: 'PD4SKTJy3DjbPY2QLMkdNg=='>      debug: login jane@example.com
```

Equal values have the same fingerprint for as long as the process runs, so one
user or one file can be followed through a log without being readable. The
fingerprint is made with a key that only exists in the memory of the process:
it cannot be turned back into the value, and after a relaunch the same value
has another fingerprint. A value that is shown is written out as usual, mask
or not. `.none` is no mask.

## Layout and formats

An interpolated value takes the options it takes in os_log, and the kit writes
what os_log writes for them. Each row was checked against what `os.Logger`
itself puts into the log.

| Option | For | Example | Writes |
| --- | --- | --- | --- |
| `align: .left(columns:)`, `.right(columns:)`, `.none` | text, describable values, types, numbers | `"\(name, align: .right(columns: 6))"` | <code>&nbsp;&nbsp;&nbsp;&nbsp;ab</code> |
| `format: .decimal`, with `explicitPositiveSign`, `minDigits` | whole numbers | `"\(-5, format: .decimal(minDigits: 4))"` | `-0005` |
| `format: .hex`, `.octal`, with `explicitPositiveSign`, `includePrefix`, `uppercase`, `minDigits` | unsigned whole numbers | `"\(UInt(255), format: .hex(includePrefix: true))"` | `0xff` |
| `format: .fixed`, `.exponential`, `.hybrid`, `.hex`, with `precision`, `explicitPositiveSign`, `uppercase` | `Double`, `Float` | `"\(3.14159, format: .fixed(precision: 2))"` | `3.14` |
| `format: .truth`, `.answer` | `Bool` | `"\(true, format: .answer)"` | `YES` |
| `format: .byteCount`, `.byteCountIEC`, `.bitrate`, `.bitrateIEC`, `.secondsSince1970` | `Int`, `Int32` | `"\(1_536_000, format: .byteCount)"` | `1.54 MB` |
| `format: .darwinErrno`, `.darwinMode`, `.darwinSignal`, `.machErrno`, `.ipv4Address`, `.truth`, `.answer` | `Int32` | `"\(code, format: .darwinErrno)"` | `[2: No such file or directory]` |
| `format: .uuid`, `.ipv6Address`, `.sockaddr`, `.timeval`, `.timespec`, `.none` | raw memory: an `UnsafeRawBufferPointer`, or an `UnsafeRawPointer` with `bytes:` | `"\(bytes, format: .uuid)"` | `E621E1F8-C36C-495A-93FC-0C247A3E6E5F` |
| `attributes:` | every value except `Bool` | `"\(size, attributes: "bytes")"` | `1.54 MB` |

- A width counts UTF-8 bytes, and a value that is wider than its column is
  written in full.
- `.hex` and `.octal` are for unsigned numbers. On a signed number the call
  does not compile, with os_log's message: "Signed integers must be formatted
  using .decimal".
- The `+` and the `0x` or `0o` in front of an unsigned number belong to the
  message, not to the value: they are written for a hidden value too
  (`0x<private>`) and stay outside the column of an aligned one.
- A hidden value keeps its options where the build writes it out. `<private>`
  and a fingerprint are written as they are, not aligned.
- Raw memory without a format is written as its bytes: `'DE AD BE EF 01'`. The
  bytes are copied when the message is built, so the memory has to live no
  longer than the log call.
- `attributes:` is text that os_log stores with the value for tools that read
  the log. It changes what is written in one case, which os_log has too: when
  the last attribute is the name os_log has for a special format, the value
  is written in that format. For a whole number the names are `bytes`,
  `iec-bytes`, `bitrate`, `iec-bitrate`, `bool`, `BOOL` and `network:in_addr`;
  `time_t` if it has four or eight bytes; `darwin.errno`, `darwin.mode`,
  `darwin.signal` and `mach.errno` if it has four. For raw memory they are
  `uuid_t`, `network:in6_addr`, `network:sockaddr`, `timeval` and `timespec`.

## Differences to os_log

- **Who hides a value.** With `os.Logger` the system decides what happens to a
  private value, and its "record private data" setting makes those values
  readable. `tb` decides itself, when it writes the line. So that setting does
  not reveal a value the kit has hidden: in a release build the value is not
  in the log at all. And a debug build writes private values out on every
  system, whatever it is set to.
- **A hidden error.** os_log keeps the domain and the code of a hidden error
  readable (`Error Domain=NSCocoaErrorDomain Code=4`). The kit hides an error
  whole.
- **Fingerprints** are the kit's own. They have the shape of os_log's but not
  its values, and they are taken from the text of the value, so a number that
  is written in two formats has two fingerprints.
- **Times** are written in the time zone of the process that logs. os_log
  stores the number and writes the time in the time zone of whoever reads the
  log.
- **A format that does not fit** — `.uuid` for memory that is not 16 bytes
  long, the attribute `darwin.errno` on an `Int` — makes os_log write a note
  such as `<decode: mismatch …>`. The kit writes the value as it would without
  the format.
- **Mach errors** are described by `mach_error_string`. os_log's own table
  differs for a few groups of codes: it has no text for the old-style codes
  that function translates (-100 to -399, 1000 to 1099 and the like) or for
  IOKit's common codes (`0xe00002bc` and up), and it names the bootstrap codes
  1100 to 1105.
- **Long lines.** os_log has about 1 KB for all the values of one message and
  cuts each value that does not fit. A line of the kit travels as two values,
  its text and its call site: if together they are longer than about 1000
  bytes, os_log cuts the text and the call site is lost.
- **`OSLogIntegerFormatting` is generic** over the type of number it formats;
  that is how `.hex` on a signed number is refused. At a call site nothing
  changes. A variable of the type needs the argument spelled out:
  `OSLogIntegerFormatting<UInt8>`.
- **Not there:** the mail masks of `OSLogPrivacy.Mask` (`._mailAddress` and
  the like), which os_log marks as internal with an underscore. Attributes
  that start with `signpost.` and the attribute `multichar` have no effect.

## Call site and context

Each line ends with a marker and a small JSON object:

```
Hello <private> ⟦tb1⟧{"f":"App/Greeter.swift","fn":"greet(_:)","ln":12}
```

`f`, `fn` and `ln` are the file, function and line of the call. A debug build
writes the absolute file path, so a reader on the same machine can open the
source; every other build writes `Module/File.swift`.

Pass `context:` to add your own keys under `ctx`:

```swift
log.error("upload failed", context: ["request": requestID])
```

Context is written as it is in every build. Keep user data out of it and put
that in the message, where it has a privacy option.

## Also in the kit

- `log.error(error)` logs an error's `localizedDescription`. The description is
  a hidden value; pass `privacy: .public` to show it.
- `tb.start(subsystem:)` logs one record with the app's name and version. Call
  it once at launch.
- `tb.mask(_:)` turns a string into a short, stable, non-reversible token for
  values that should be recognisable but not readable.
- `exportRecentLogs(since:to:)` writes the current process's log entries to a
  file as NDJSON, for an "Export Logs" button.

## Next to `os`

The kit covers logging. For signposts and other `os` APIs, import `os` as
well. In a file that imports both, name the kit's logger `tb.Logger`.

`OSLogType` is Apple's own type under its own name. If a target turns on the
upcoming Swift feature `MemberImportVisibility`, its members such as `.info`
need `import os` too.

## Example

[`Examples/KitDemo`](Examples/KitDemo) is a small command-line program that
imports only `tb` and logs the way you would with `os.Logger`:

```sh
cd Examples/KitDemo
swift run KitDemo com.example.demo              # debug build
swift run -c release KitDemo com.example.demo   # release build
/usr/bin/log show --last 1m --info --debug --style ndjson \
    --predicate 'subsystem == "com.example.demo"'
```

Its file `EveryOption.swift` holds a call for every option above. The same
file — a symbolic link to it — is also compiled into `OSLoggerReference`,
where one compiler flag turns `import tb` into `import os`. Run both and the
log shows what each logger makes of the same call:

```sh
swift run OSLoggerReference com.example.demo    # the same calls through os.Logger, category "os"
```

`KitCompare` in the same package logs through `os.Logger` and `tb.Logger` side
by side (`swift run -c release KitCompare levels <subsystem>`) and times both
(`swift run -c release KitCompare time`).

## Upgrading from the `String` methods

Earlier versions of `Logger` took a `String`. Three things change:

- A `String` variable is interpolated: `log.info(text)` becomes
  `log.info("\(text)")`. Values are now hidden or shown as described above;
  add `privacy: .public` where a release build should show a value.
- `warning` logs at the error level, as `os.Logger.warning` does.
- `log.error(error)` treats the description as a hidden value.
