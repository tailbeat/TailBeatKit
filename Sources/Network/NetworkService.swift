//
//  NetworkService.swift
//  TailBeat
//
//  Created by Stephan Arenswald on 08.10.25.
//

import AppKit
import Foundation
import Network

public struct PrefPatch: Codable, Identifiable {
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

extension PrefPatch.Value {
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

final actor NetworkService {
    // MARK: Signals
    var onEnvironmentChanged: ((AppEnvironment) -> Void)?
    var onUserDefaultsPatched: (([PrefPatch]) -> Void)?
    var onWindowResizeRequest: ((WindowResizeRequest) -> Void)?
    var onWindowAsKeyRequest: ((Int) -> Void)?
    
    // MARK: Networking
    private let q = DispatchQueue(label: "io.tailbeat.client")
    private var conn: NWConnection?
    private var buffer = Data()
    
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
    func changeOf(appEnvironment: @escaping (AppEnvironment) -> Void) {
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
}
