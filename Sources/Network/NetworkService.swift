//
//  NetworkService.swift
//  TailBeat
//
//  Created by Stephan Arenswald on 08.10.25.
//

import AppKit
import Foundation
import Network

public struct PrefPatch: Codable, Identifiable, Sendable {
    public enum Value: Codable {
        case string(String), int(Int), bool(Bool), double(Double), data(Data), date(Date), null
    }
    public var id = UUID()
    public var key: String
    public var value: Value? // nil or .null means remove
    
    public init(key: String, value: Value? = nil) {
        self.key = key
        self.value = value
    }
}

extension PrefPatch.Value: Sendable {
    public static func fromAny(_ any: Any) -> PrefPatch.Value? {
        // Order matters because NSNumber bridges to multiple Swift types
        if let v = any as? String { return .string(v) }
        if let v = any as? Bool   { return .bool(v) }
        if let v = any as? Int    { return .int(v) }
        if let v = any as? Double { return .double(v) }
        if let v = any as? Float  { return .double(Double(v)) }
        if let v = any as? Data   { return .data(v) }

        // Common bridged NSNumber case (just in case):
        if let num = any as? NSNumber {
            // Try bool first (NSNumber(bool:) is also a number)
            let objCType = String(cString: num.objCType)
            if objCType == "c" { return .bool(num.boolValue) }      // 'c' == CChar / Bool
            // Integers
            if CFNumberIsFloatType(num) == false { return .int(num.intValue) }
            // Floats
            return .double(num.doubleValue)
        }

        // Unsupported (e.g., arrays/dictionaries/URL/Date) — skip or encode as string if you prefer
        return nil
    }
    
    public var displayString: String {
        switch self {
        case .string(let s):  return s
        case .int(let i):     return String(i)
        case .bool(let b):    return b ? "true" : "false"
        case .double(let d):  return String(d)
        case .data(let d):    return "\(d.count) bytes"
        case .date(let d):    return "\(d)"
        case .null:           return "∅"
        }
    }
}

/// Actor that owns the only connection there is to the TailBeat app (server side).
/// - Sends TailBeatClientMessage from the controlled app to the server (JSON formatted, separated by \n, i.e. 0x0A)
/// - Receives TailBeatServerMessage from the TailBeat app and emits the message to the core which actually
///     handles the messages. This is done via AsyncStream to make sure no message is lost (though this might never
///     happen as the number of messages from TailBeat to the app is rather small
final actor NetworkService {
    // Incoming messages
    private let msgPair = AsyncStream.makeStream(of: TailBeatServerMessage.self)
    var messages: AsyncStream<TailBeatServerMessage> { msgPair.stream }
    
    // Networking
    private var conn: NWConnection?
    private var isReady = false
    private var buffer = Data()
    private var pendingSends: [Data] = []
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    //
    // MARK: Lifecycle
    //
    
    func connect(
        host: String = "127.0.0.1",
        port: UInt16 = 8085
    ) {
        guard conn == nil else { return }
        
        let parameters = NWParameters.tcp
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: parameters
        )
        conn = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { await self.handleState(state) }
        }
        
        // start the connection
        let q = DispatchQueue(label: "tailbeat.network")
        connection.start(queue: q)
    }
    
    func close() {
        conn?.cancel()
        conn = nil
        isReady = false
        buffer.removeAll(keepingCapacity: false)
        pendingSends.removeAll(keepingCapacity: false)
    }
    
    //
    // MARK: Outgoing
    //
    // Sending messages from the connected app to the TailBeat app (server)
    //
    
    func send(_ message: TailBeatClientMessage) async {
        do {
            var data = try encoder.encode(message)
            data.append(0x0A)
            
            if isReady, let conn {
                conn.send(content: data, completion: .contentProcessed { _ in })
            } else {
                // Just in case the connect to TailBeat is not established yet, or TailBeat
                // is restarted the messages are stored and then later sent again
                // TODO: Add an option to disable this
                pendingSends.append(data)
            }
        } catch {
            // TODO: how do we log messages when print is intercepted?
        }
    }
    
    //
    // MARK: Internals
    //
    
    /// Handles the connection state from NWConnection. It also sends any buffered messages
    /// - Parameter state: connection state
    func handleState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            isReady = true
            
            // in case of any pending messages, now's the chance to send them
            flushPending()
            
            scheduleNextReceive()
            
        case .failed, .cancelled:
            close()
            
        case .waiting:
            // recovers the connection here (done by the system)
            break
            
        default:
            break
        }
    }
    
    /// In case a connection is not ready yet, then all messages will be buffered to be sent
    /// as soon as the connection recovers. When the connection has recovered, this func
    /// will send all buffered messages
    private func flushPending() {
        guard !pendingSends.isEmpty else { return }
        guard isReady else { return }
        guard let conn else { return }
        
        for data in pendingSends {
            conn.send(content: data, completion: .contentProcessed { _ in })
        }
        
        pendingSends.removeAll()
    }
    
    /// Registers a closure with the network connection to handle a package that got sent to the app. When
    /// a package arrives, the closure is called. No other packages are cought then unless scheduleNextReceive()
    /// is called again. (which is done by handleReceive()
    private func scheduleNextReceive() {
        guard let conn else { return }
        
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isEOF, error in
            guard let self else { return }
            Task {
                await self.handleReceive(data: data, isEOF: isEOF, error: error)
            }
        }
    }
    
    /// Adds the received package to the internal buffer and asks drainBuffer() to check if there is a new complete message
    /// - Parameters:
    ///   - data: data package received
    ///   - isEOF: if the connection was closed
    ///   - error: if any error happened
    private func handleReceive(data: Data?, isEOF: Bool, error: Error?) {
        if let data { buffer.append(data) }
        
        // check if there is a completed message
        drainBuffer()
        
        if isEOF || error != nil {
            close()
        } else {
            scheduleNextReceive()
        }
    }
    
    /// Checks if the current buffer contains a complete message to be handled
    private func drainBuffer() {
        while let nl = buffer.firstIndex(of: 0x0A) {
            // message found, take that and remove it from the buffer
            let line = buffer[..<nl]
            buffer.removeSubrange(...nl)
            
            // ignore empty lines
            if line.isEmpty { continue }
            
            if let msg = try? decoder.decode(TailBeatServerMessage.self, from: line) {
                emit(msg)
            } else {
                // TODO: Handle decoder errors here
            }
        }
    }
    
    /// Adds the received message to the stream to be handled by the core eventually, and to
    /// make sure the incoming messages are not blocked
    /// - Parameter message: message to handle
    private func emit(_ message: TailBeatServerMessage) {
        msgPair.continuation.yield(message)
    }
}

/**final actor NetworkService {
    // MARK: Signals
    var onEnvironmentChanged: (@MainActor (AppEnvironment) -> Void)?
    var onUserDefaultsPatched: (([PrefPatch]) -> Void)?
    var onWindowResizeRequest: ((WindowResizeRequest) -> Void)?
    var onWindowAsKeyRequest: ((Int) -> Void)?
    
    // MARK: Networking
    private let q = DispatchQueue(label: "io.tailbeat.client")
    private var conn: NWConnection?
    private var buffer = Data()
    
    // MARK: Logging stream
    private let events: AsyncStream<TailBeatEvent>
    private let continuation: AsyncStream<TailBeatEvent>.Continuation
    private var consumer: Task<Void, Never>?
    private var maxBufferSize: Int = 1000
    
    init() {
        let stream = AsyncStream.makeStream(of: TailBeatEvent.self, bufferingPolicy: .bufferingNewest(maxBufferSize))
        events = stream.stream
        continuation = stream.continuation
    }
    
    func connect(
        host: String = "127.0.0.1",
        port: UInt16 = 8085,
        appEnvironment: AppEnvironment,
        appInfo: AppInfo,
        appWindows: [AppWindow]
    ) {
        let p = NWParameters.tcp
        let c = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: p
        )
        conn = c
        c.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                Task {
                    await self.send(.ack("hello-from-host"))
                    await self.send(appInfo: appInfo)
                    await self.send(appEnvironment: appEnvironment)
                    await self.send(appWindows: appWindows)
                    await self.send(userDefaults: UserDefaults.standard)
                    await self.receiveLoop()
                }
            @unknown default:
                break
            }
        }
        c.start(queue: q)
        
        consumer = Task { await consumeLoop() }
    }
    
    // MARK: Send API
    func send(event: TailBeatEvent) {
        send(.log(event))
    }
    
    func send(userDefaults: UserDefaults) {
        let dict = userDefaults.dictionaryRepresentation()
        let patches = dict.map { (k, v) in PrefPatch(key: k, value: encodeUD(v)) }
        send(.defaults(patches))
    }
    
    func send(appEnvironment: AppEnvironment) {
        send(.environment(appEnvironment))
    }
    
    func send(appInfo: AppInfo) {
        send(.info(appInfo))
    }
    
    func send(appWindows: [AppWindow]) {
        send(.windows(appWindows))
    }
    
    // MARK: Subscribe for remote changes
    func changeOf(appEnvironment: @escaping @MainActor (AppEnvironment) -> Void) {
        onEnvironmentChanged = appEnvironment
    }
    
    func changeOf(userDefaults: @escaping ([PrefPatch]) -> Void) {
        onUserDefaultsPatched = userDefaults
    }
    
    func changeOf(windowResizeRequest: @escaping (WindowResizeRequest) -> Void) {
        onWindowResizeRequest = windowResizeRequest
    }
    
    func changeOf(windowAsKeyRequest: @escaping (Int) -> Void) {
        onWindowAsKeyRequest = windowAsKeyRequest
    }
    
    // MARK: Internals
    private func send(_ msg: TailBeatClientMessage) {
        guard let conn else { return }
        do {
            var data = try JSONEncoder().encode(msg)
            data.append(0x0A)
            conn.send(content: data, completion: .contentProcessed { _ in })
        } catch {
            
        }
    }
    
    private func receiveLoop() {
        conn?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data , _, isEOF, err in
            guard let self else { return }
            if let data { buffer.append(data) }
            self.drainBuffer()
            if isEOF || err != nil {
                self.conn?.cancel()
                return
            }
            self.receiveLoop()
        }
    }
    
    private func drainBuffer() {
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<nl]
            buffer.removeSubrange(...nl)
            if line.isEmpty { continue }
            if let msg = try? JSONDecoder().decode(TailBeatServerMessage.self, from: line) {
                handle(msg)
            }
        }
    }
    
    private func handle(_ msg: TailBeatServerMessage) {
        switch msg {
        case .envChangeRequest(let env):
            self.onEnvironmentChanged?(env)
        case .userDefaultsPatch(let patches):
            self.onUserDefaultsPatched?(patches)
        case .windowResizeRequest(let wrr):
            self.onWindowResizeRequest?(wrr)
        case .windowAsKeyRequest(let windowNumber):
            self.onWindowAsKeyRequest?(windowNumber)
        default:
            break
        }
    }
    
    // MARK: Helpers
    private func encodeUD(_ any: Any) -> PrefPatch.Value {
        switch any {
        case let v as String: return .string(v)
        case let v as Int: return .int(v)
        case let v as Bool: return .bool(v)
        case let v as Double: return .double(v)
        case let v as Data: return .data(v)
        case let v as Date: return .date(v)
        default: return .null
        }
    }
    
    //
    // MARK: Logging stream handling (input)
    //
    
    nonisolated func yield(event: TailBeatEvent) {
        continuation.yield(event)
    }
    
    //
    // MARK: Logging stream handling (output)
    //
    
    private func consumeLoop() async {
        for await event in events {
            send(event: event)
        }
    }
}
*/
