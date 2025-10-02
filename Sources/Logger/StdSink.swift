//
//  StdSink.swift
//  TailBeat
//
//  Created by Stephan Arenswald on 02.10.25.
//

import Foundation

class StdSink {
    var stopped: Bool = false
    
    init(handler: @escaping (String) -> Void) {
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

            while !self.stopped {
                let bytesRead = read(pipeReadHandle.fileDescriptor, buffer, 4096)
                if bytesRead > 0 {
                    let data = Data(bytes: buffer, count: bytesRead)
                    count += 1
                    if let output = String(data: data, encoding: .utf8) {
                        for line in output.split(separator: "\n") {
                            // Skip empty lines
                            guard !line.isEmpty else { continue }
                            handler(String(line))
                        }

                        // Also forward to original stdout
                        write(originalStdout, data.withUnsafeBytes { $0.baseAddress! }, data.count)
                    }
                }
            }
        }
    }
    
    deinit {
        self.stopped = true
    }
}
