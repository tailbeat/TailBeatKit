//
//  TailBeat.swift
//  tailbeat-swift
//
//  Created by Stephan Arenswald on 28.09.25.
//

import Foundation
import Observation
import SwiftUI



final actor LogBus<Event: Sendable> {
    private let stream: AsyncStream<Event>
    private let cont: AsyncStream<Event>.Continuation
    var events: AsyncStream<Event> { stream }

    init(buffer: Int = 1_000) {
        let pair = AsyncStream.makeStream(
            of: Event.self,
            bufferingPolicy: .bufferingNewest(buffer)
        )
        stream = pair.stream
        cont = pair.continuation
    }

    func enqueue(_ e: Event) { cont.yield(e) }
}

/**
actor NetworkService {
    // expose a stream of incoming server messages
    private let msgPair = AsyncStream.makeStream(of: TailBeatServerMessage.self)
    var messages: AsyncStream<TailBeatServerMessage> { msgPair.stream }

    // ... NWConnection setup, receive loop, decode lines, then:
    private func emit(_ m: TailBeatServerMessage) { msgPair.continuation.yield(m) }

    // sender
    func send(_ m: TailBeatClientMessage) async { /* encode + conn.send */ }
}
*/

final actor TailBeatCore {
    static let shared = TailBeatCore()
    private var started: Bool = false
    
    // Dependencies
    private let net: NetworkService
    private let logBus: LogBus<TailBeatEvent>
    
    // All tasks running to make this work
    private var tasks: [Task<Void, Never>] = []
    
    // Other stuff
    private var relevantNotifications: RelevantNotifications!
    
    init() {
        self.net = NetworkService()
        self.logBus = LogBus<TailBeatEvent>(buffer: 1_000)
    }
    
    //
    // MARK: Lifecycle
    //
    
    internal func start(host: String, port: UInt16) async {
        // only start once
        guard !started else { return }
        started = true
        
        // 1) take logs from the async sequence and send them to the network
        tasks.append(Task { [logBus, net] in
            for await event in await logBus.events {
                await self.net.send(.log(event))
            }
        })
        
        // 2) wait for messages from the connected TailBeat server and handle them
        tasks.append(Task { [net, weak self] in
            guard let self else { return }
            for await msg in await net.messages {
                await self.handle(msg)
            }
        })
        
        // 3) connect + handshake (collect first info and send to TailBeat app)
        tasks.append(Task { [weak self] in
            guard let self else { return }
            
            // connect
            await self.net.connect(host: host, port: port)
            
            let env = await self.collectEnvironment()
            let info = await self.collectAppInfo()
            let windows = await self.collectWindows()
            
            await self.net.send(.ack("hello-from-app"))
            await self.net.send(.info(info))
            await self.net.send(.environment(env))
            await self.net.send(.windows(windows))
            await self.net.send(.defaults(self.snapshotUserDefaults()))
        })
        
        
        relevantNotifications = RelevantNotifications()
        relevantNotifications.onAppWindowsResized = { windows in
            Task {
                await self.net.send(.windows(windows))
            }
        }
    }
    
    internal func stop() async {
        for task in tasks { task.cancel() }
        tasks.removeAll()
        started = false
        await net.close()
    }
    
    //
    // MARK: Public entry for facade or others
    //
    
    func enqueueLog(_ event: TailBeatEvent) async {
        await logBus.enqueue(event)
    }
    
    //
    // MARK: Internals
    //
    
    /// Handles message incoming from the TailBeat app (i.e. executes the changes requested by TailBeat)
    /// - Parameter message: server message (payload)
    private func handle(_ message: TailBeatServerMessage) async {
        switch message {
        case .requestDefaults:
            await self.net.send(.defaults(self.snapshotUserDefaults()))
        case .languageChangeRequest(let lang):
            await MainActor.run { LanguageControl().change(to: lang) }
        case .appearanceChangeRequest(let appearance):
            await MainActor.run { AppearanceControl().change(to: appearance) }
        case .windowResizeRequest(let req):
            await MainActor.run { TailBeatUI.shared.resize(windowNumber: req.windowNumber, to: req.frame) }
        case .windowAsKeyRequest(let number):
            await MainActor.run { TailBeatUI.shared.makeKey(windowNumber: number) }
        case .userDefaultsPatch(let patches):
            break
        case .ack, .error:
            break
        }
    }
    
    @MainActor
    private func collectEnvironment() -> AppEnvironment {
        let isDark = NSApp.appearance?.name == .darkAqua
        let appearance = isDark ? "dark" : "light"
        let locale = Locale.current.identifier
        return AppEnvironment(language: locale, appearance: appearance)
    }
    
    @MainActor
    private func collectAppInfo() -> AppInfo {
        let name = Bundle.main.appName
        let bundleId = Bundle.main.bundleIdentifier
        let version = Bundle.main.appVersionLong
        let build = Bundle.main.appBuild
        let localizations = Bundle.main.localizations
        
        return AppInfo(name: name, bundleId: bundleId, version: version, build: build, localizations: localizations)
    }
    
    @MainActor
    private func collectWindows() -> [AppWindow] {
        NSApp.windows.map { window in
            AppWindow(windowNumber: window.windowNumber, title: window.title, frame: window.frame)
        }
    }
    
    private func snapshotUserDefaults() -> [PrefPatch] {
        UserDefaults.standard.dictionaryRepresentation().map { (k, v) in
            PrefPatch(key: k, value: encodeUserDefault(v))
        }
    }
    
    private func applyUserDefaults(_ patches: [PrefPatch]) {
        let ud = UserDefaults.standard
        for patch in patches {
            switch patch.value {
            case .string(let v): ud.set(v, forKey: patch.key)
            case .int(let v): ud.set(v, forKey: patch.key)
            case .bool(let v): ud.set(v, forKey: patch.key)
            case .double(let v): ud.set(v, forKey: patch.key)
            case .data(let v): ud.set(v, forKey: patch.key)
            case .date(let v): ud.set(v, forKey: patch.key)
            case .null, nil: ud.removeObject(forKey: patch.key)
            case .array, .dictionary: fatalError("Cannot store non-scalar values in UserDefaults")
            }
        }
    }
    
    private func encodeUserDefault(_ any: Any) -> PrefPatch.Value {
        // Fast paths
        if let v = any as? String { return .string(v) }
        if let v = any as? Bool   { return .bool(v) }
        if let v = any as? Int    { return .int(v) }
        if let v = any as? Double { return .double(v) }
        if let v = any as? Float  { return .double(Double(v)) }
        if let v = any as? Data   { return .data(v) }
        if let v = any as? Date   { return .date(v) }
        if any is NSNull          { return .null }

        // NSNumber can be Bool or Number; check objCType
        if let num = any as? NSNumber {
            let t = String(cString: num.objCType)
            if t == "c" { return .bool(num.boolValue) }        // 'c' == CChar / Bool
            if CFNumberIsFloatType(num) == false { return .int(num.intValue) }
            return .double(num.doubleValue)
        }

        // Arrays (AppleLanguages will come through here as [Any])
        if let arr = any as? [Any] {
            return .array(arr.map(encodeUserDefault))
        }

        // Dictionaries (many defaults store nested dicts)
        if let dict = any as? [String: Any] {
            var out: [String: PrefPatch.Value] = [:]
            out.reserveCapacity(dict.count)
            for (k, v) in dict { out[k] = encodeUserDefault(v) }
            return .dictionary(out)
        }

        // Optional convenience: URLs stored as strings
        if let url = any as? URL {
            return .string(url.absoluteString)
        }

        // Fallback
        return .null
    }
}
