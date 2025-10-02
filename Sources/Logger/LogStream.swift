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

actor LogStream {
    private var connection: NWConnection?
    private let events: AsyncStream<TailBeatEvent>
    private let continuation: AsyncStream<TailBeatEvent>.Continuation
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
        consumer = Task { await consumeLoop() }
        connection?.start(queue: .global())
    }
    
    func stop() {
        isStopped = true
        consumer?.cancel()
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
    
    //
    // MARK: Stream handling (input)
    //
    
    nonisolated func yield(event: TailBeatEvent) {
        continuation.yield(event)
    }
    
    //
    // MARK: Stream handling (output)
    //
    
    private func consumeLoop() async {
        for await event in events {
            if isStopped { break }
            await sendEvent(event: event)
        }
    }
    
    private func sendEvent(event: TailBeatEvent) {
        guard let connection else { return }
        
        if var data = try? JSONEncoder().encode(event) {
            data.append(0x0A)
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }
}
