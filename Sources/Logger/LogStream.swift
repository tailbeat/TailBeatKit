//
//  LogStream.swift
//  TailBeat
//
//  Created by Stephan Arenswald on 29.09.25.
//


import Foundation
import Network
import OSLog
import UniformTypeIdentifiers

class LogStream {
    private var connection: NWConnection?
    private var events: AsyncStream<TailBeatEvent>
    private var continuation: AsyncStream<TailBeatEvent>.Continuation
    private var consumer: Task<Void, Never>?
    private var maxBufferSize: Int = 1000
    private var isStopped = false
    
    init() {
        // create the stream
        let stream = AsyncStream.makeStream(of: TailBeatEvent.self, bufferingPolicy: .bufferingNewest(maxBufferSize))
        events = stream.stream
        continuation = stream.continuation
    }
    
    func start() {
        isStopped = false
        startConsumerEventTask()
        connection?.start(queue: .global())
    }
    
    func stop() {
        isStopped = true
        consumer?.cancel()
        consumer = nil
        disconnect()
    }
    
    //
    // MARK: Connection handling
    //
    
    func connect(host: String, port: UInt16) {
        let params = NWParameters.tcp
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: params
        )
    }
    
    private func disconnect() {
        connection?.cancel()
    }
    
    func sendEvent(event: TailBeatEvent) {
        guard let connection else { return }
        
        if var data = try? JSONEncoder().encode(event) {
            data.append(0x0A)
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }
    
    //
    // MARK: Stream handling
    //
    
    func yield(event: TailBeatEvent) {
        continuation.yield(event)
    }
    
    func startConsumerEventTask() {
        // start the stream
        consumer = Task { [weak self] in
            guard let self else { return }
            
            for await event in self.events {
                // check if the task was stopped
                if isStopped { break }
                
                // send the event to TailBeat
                sendEvent(event: event)
            }
        }
    }
}