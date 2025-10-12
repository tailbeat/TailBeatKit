//
//  TailBeat.swift
//  tailbeat-swift
//
//  Created by Stephan Arenswald on 28.09.25.
//

import Foundation
import SwiftUI

@MainActor
public class TailBeat: ObservableObject {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    @Published public var languageIdentifier: String
    
    private var net: NetworkService!
    private var relevantNotifications: RelevantNotifications!
    
    public init() {
        languageIdentifier = Locale.current.identifier
    }
    
    public func start2() {
        net = NetworkService()
        guard let net else { return }
        let appEnvironment = AppEnvironment(
            language: Locale.current.identifier,
            appearance: NSApp.appearance?.name.rawValue ?? "light"
        )
        let appInfo = AppInfo(
            name: Bundle.main.appName,
            bundleId: Bundle.main.bundleIdentifier,
            version: Bundle.main.appVersionLong,
            build: Bundle.main.appBuild,
            localizations: Bundle.main.localizations
        )
        let appWindows = NSApp.windows.map { window in
            AppWindow(windowNumber: window.windowNumber, title: window.title, frame: window.frame)
        }
        
        relevantNotifications = RelevantNotifications()
        relevantNotifications.onAppWindowsResized = { windows in
            Task.detached {
                await net.send(appWindows: windows)
            }
        }
        
        Task.detached {
            await net.connect(
                appEnvironment: appEnvironment,
                appInfo: appInfo,
                appWindows: appWindows
            )
            await self.net.changeOf(windowResizeRequest: { wrr in
                Task { @MainActor in
                    if let window = NSApp.windows.first(where: { $0.windowNumber == wrr.windowNumber }) {
                        window.setFrame(wrr.frame, display: true)
                    }
                }
            })
            await self.net.changeOf(windowAsKeyRequest: { windowNumber in
                Task { @MainActor in
                    if let window = NSApp.windows.first(where: { $0.windowNumber == windowNumber }) {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            })
            await net.changeOf(appEnvironment: { env in
                Task { @MainActor in
                    // appearance first
                    if let appearance = env.appearance {
                        if appearance == "light" {
                            NSApp.appearance = NSAppearance(named: .aqua)
                        } else {
                            NSApp.appearance = NSAppearance(named: .darkAqua)
                        }
                    }
                    
                    // language second
                    if let language = env.language {
                        self.languageIdentifier = language
                    }
                }
            })
            await net.changeOf(userDefaults: { patches in
                let ud = UserDefaults.standard
                patches.forEach { p in
                    switch p.value {
                    case .string(let v)?: ud.set(v, forKey: p.key)
                    case .int(let v)?:    ud.set(v, forKey: p.key)
                    case .bool(let v)?:   ud.set(v, forKey: p.key)
                    case .double(let v)?: ud.set(v, forKey: p.key)
                    case .data(let v)?:   ud.set(v, forKey: p.key)
                    case .date(let v)?:   ud.set(v, forKey: p.key)
                    case .null, nil:      ud.removeObject(forKey: p.key)
                    }
                }
            })
        }
    }
    
    public func log(_ msg: String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        Task {
            await net.send(event: .init(
                timestamp: .now,
                type: .Log,
                level: .Debug,
                category: "",
                message: msg,
                context: nil,
                file: file.description,
                function: function.description,
                line: Int(line)
            ))
        }
    }
}
