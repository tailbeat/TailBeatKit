//
//  TailBeatLogger.swift
//  tailbeat-swift
//
//  Created by Stephan Arenswald on 28.09.25.
//

import Foundation
import Network
import OSLog
import UniformTypeIdentifiers




extension LogStream: @unchecked Sendable {}


public class TailBeatLogger {
    private var logStream: LogStream
    private var osLogTimer: DispatchSourceTimer?
    
    init() {
        logStream = LogStream()
    }
    
    public func start(
        host: String = "127.0.0.1",
        port: UInt16 = 8085,
        collectOSLogs: Bool = false,
        collectStdout: Bool = false,
        collectStderr: Bool = false
    ) {
        logStream.connect(host: host, port: port)
        logStream.start()
        
        if collectStdout && collectStderr {
            interceptStdoutAndStderr(collectStdout, collectStderr) { message in
                if message.starts(with: "OSLOG-") {
                    return // skip OSLOG messages
                }
                
                self.log(message, source: .Stdout)
            }
        }
        
        if collectOSLogs {
            startPeriodicOSLogPolling(interval: 0.1)
        }
        
        logAppStart()
    }
    
    func interceptStdoutAndStderr(_ collectStdout: Bool, _ collectStderr: Bool, logHandler: @escaping (String) -> Void) {
        // Create a pipe
        let pipe = Pipe()
        let pipeReadHandle = pipe.fileHandleForReading
        let pipeWriteHandle = pipe.fileHandleForWriting

        // Duplicate current stdout/stderr so we can still write to it
        let originalStdout = dup(STDOUT_FILENO)
        let originalStderr = dup(STDERR_FILENO)

        // Redirect stdout and stderr to the pipe
        dup2(pipeWriteHandle.fileDescriptor, STDOUT_FILENO)
        dup2(pipeWriteHandle.fileDescriptor, STDERR_FILENO)

        // Background thread to read data from the pipe
        DispatchQueue.global(qos: .background).async {
            var count = 0
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }

            while true {
                let bytesRead = read(pipeReadHandle.fileDescriptor, buffer, 4096)
                if bytesRead > 0 {
                    let data = Data(bytes: buffer, count: bytesRead)
                    count += 1
                    if let output = String(data: data, encoding: .utf8) {
                        for line in output.split(separator: "\n") {
                            // Skip empty lines
                            guard !line.isEmpty else { continue }
                            logHandler(String(line))
                        }

                        // Also forward to original stdout
                        write(originalStdout, data.withUnsafeBytes { $0.baseAddress! }, data.count)
                    }
                }
            }
        }
    }

    private func startPeriodicOSLogPolling(interval: TimeInterval) {
           // 1️⃣ Initialize the store scoped to this process
           let logStore: OSLogStore
           do {
               logStore = try OSLogStore(scope: .currentProcessIdentifier)
           } catch {
               print("Couldn’t open OSLogStore:", error)
               return
           }

           // 2️⃣ Start reading from “right now”
           var lastPosition = logStore.position(date: Date())

           // 3️⃣ Schedule a DispatchSourceTimer on a background queue
           let timer = DispatchSource.makeTimerSource(queue: .global(qos: .background))
           timer.schedule(deadline: .now() + interval,
                          repeating: interval,
                          leeway: .milliseconds(10))
           timer.setEventHandler { [weak self] in
               guard let self = self else { return }
               do {
                   // 4️⃣ Fetch all entries since lastPosition
                   let entries = try logStore.getEntries(at: lastPosition)
                   
                   // 5️⃣ Iterate only the OSLogEntryLog entries
                   for case let logEntry as OSLogEntryLog in entries {
                       // 6️⃣ Advance our cursor by date
                       lastPosition = logStore.position(date: logEntry.date)
                       
                       // 7️⃣ Map OSLog levels to your TailBeatLevel
                       let level: TailBeatLogLevel = {
                           switch logEntry.level {
                           case .debug:   return .Debug
                           case .info:    return .Info
                           case .notice:  return .Info
                           case .error:   return .Error
                           case .fault:   return .Fatal
                           case .undefined: return .Debug
                           @unknown default: return .Debug
                           }
                       }()

                       // 8️⃣ Send it over TailBeat
                       self.log(
                           level: level,
                           category: logEntry.category,
                           logEntry.composedMessage,
                           context: nil,
                           file: "",
                           function: "",
                           line: 0,
                           extras: [],
                           source: .OSLog
                       )
                   }
               } catch {
                   print("Failed fetching OSLog entries:", error)
               }
           }
           timer.resume()
           self.osLogTimer = timer
       }

    
    public func log(level: TailBeatLogLevel = .Debug,
             category: String = "",
             _ message: String,
             context: [String: String]? = nil,
             file: String = #file,
             function: String = #function,
             line: Int = #line,
             extras: [TailBeatExtras] = [],
             source: TailBeatLogSource = .TailBeat
    ) {
        log(type: .Log, level: level, category: category, message, context: context, file: file, function: function, line: line, extras: extras, source: source)
    }
    
    private func log(
                     type: TailBeatEventType,
        level: TailBeatLogLevel = .Debug,
         category: String = "",
         _ message: String,
         context: [String: String]? = nil,
         file: String = #file,
         function: String = #function,
         line: Int = #line,
         extras: [TailBeatExtras] = [],
         source: TailBeatLogSource = .TailBeat
    ) {
#if DEBUG
        var file = file
        var function = function
        var line = line
        
        if source != .TailBeat {
            file = ""
            function = ""
            line = 0
        }
        
        let log = TailBeatEvent(
            timestamp: Date(),
            type: type,
            level: level,
            category: category,
            message: message,
            context: context,
            file: file,
            function: function,
            line: line,
            extras: extras,
            source: source
        )
        
        logStream.yield(event: log)
#endif
    }
    
    func logAppStart() {
        let appName = Bundle.main.appName
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "Unknown Bundle Identifier"
        let appVersion = Bundle.main.appVersionLong
        
        log(
            type: .AppStarted,
            level: .Info,
            "\(appName) started (\(appVersion)) (\(bundleIdentifier))"
        )
    }
}
