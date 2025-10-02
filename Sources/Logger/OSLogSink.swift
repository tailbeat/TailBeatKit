//
//  OSLogStream.swift
//  TailBeat
//
//  Created by Stephan Arenswald on 02.10.25.
//

import Foundation
import OSLog

class OSLogSink {
    let timer: DispatchSourceTimer
    let interval: TimeInterval = 0.1
    let logStore: OSLogStore
    var lastPosition: OSLogPosition
    var lastDate: Date
    
    init(handler: @escaping (OSLogEntryLog) -> Void) throws {
        // init the log store
        logStore = try OSLogStore(scope: .currentProcessIdentifier)
        lastDate = .now
        lastPosition = self.logStore.position(date: lastDate)
        
        // init and start the timer
        timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(
            deadline: .now() + interval,
            repeating: interval,
            leeway: .milliseconds(10)
        )
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            print("\(Date.now.ISO8601Format())")
            
            lastPosition = self.logStore.position(date: lastDate)
            let entries = try! logStore.getEntries(
                at: lastPosition,
                matching: NSPredicate(format: "processID == %d", getpid())
            )
            
            var lastLogEntry: OSLogEntryLog?
            var count = 0
            for case let logEntry as OSLogEntryLog in entries {
                if logEntry.date >= lastDate {
                    handler(logEntry)
                    
                    lastLogEntry = logEntry
                    count += 1
                }
            }
            
            if let lastLogEntry {
                lastDate = lastLogEntry.date
            }
        }
        timer.resume()
    }
    
    deinit {
        timer.cancel()
    }
}
