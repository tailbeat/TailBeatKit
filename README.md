# TailBeatKit

`tb` is a drop-in replacement for `os.Logger`. It writes to the unified log,
takes the same calls — including os_log-style privacy options — and adds the
call site and an optional context to every line, so a reader like TailBeat can
show where a line came from.

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
| `Int`, `UInt` and the sized whole-number types, `Double`, `Float`, `Bool` | shown |
| `String`, objects (`NSObject`), errors, types, anything `CustomStringConvertible` | hidden |

The `privacy:` option overrides that for one value:

| Option | The value is |
| --- | --- |
| `.auto` | shown or hidden by its kind (the default) |
| `.public` | shown |
| `.private`, `.sensitive` | hidden |

A shown value is always written out. A hidden value depends on the build that
writes the line:

- a **debug build** writes it out, so you see everything while developing;
- **every other build** writes `<private>` in its place.

```swift
log.info("Hello \(planet)")                     // release: Hello <private>    debug: Hello Jupiter
log.info("Hello \(planet, privacy: .public)")   // release: Hello Jupiter      debug: Hello Jupiter
log.info("\(count) moons")                      // release: 95 moons           debug: 95 moons
log.info("\(count, privacy: .private) moons")   // release: <private> moons    debug: 95 moons
```

"Debug build" means the kit was compiled with the `DEBUG` condition, which is
what SwiftPM and Xcode do for a debug configuration.

### The one difference to os_log

With `os.Logger` the system decides what happens to a private value, and its
"record private data" setting makes those values readable. `tb` decides
itself, when it writes the line. So that setting does not reveal a value the
kit has hidden: in a release build the value is not in the log at all. And a
debug build writes hidden values out on every system, whatever it is set to.

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
