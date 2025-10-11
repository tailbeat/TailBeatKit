//
//  RelevantNotifications.swift
//  TailBeatKit
//
//  Created by Stephan Arenswald on 11.10.25.
//

import AppKit
import Foundation
import Combine

class RelevantNotifications {
    private var notifications = Set<AnyCancellable>()
    
    var onAppWindowsResized: (([AppWindow]) -> Void)?
    
    init() {
//        NotificationCenter.default.publisher(for: NSWindow.didResizeNotification, object: nil)
//            .compactMap { $0.object as? NSWindow }
//            .receive(on: RunLoop.main)
//            .sink { window in
//                print("didResizeNotification \(window.title)")
//                self.updateWindows()
//            }
//            .store(in: &notifications)
//        
//        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: nil)
//            .compactMap { $0.object as? NSWindow }
//            .receive(on: RunLoop.main)
//            .sink { window in
//                print("didMoveNotification \(window.title)")
//                self.updateWindows()
//            }
//            .store(in: &notifications)
        
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification, object: nil)
            .compactMap { $0.object as? NSWindow }
            .receive(on: RunLoop.main)
            .sink { window in
                print("willCloseNotification \(window.title)")
                self.updateWindows(ignore: window)
            }
            .store(in: &notifications)
        
        NotificationCenter.default.publisher(for: NSWindow.didUpdateNotification, object: nil)
            .compactMap { $0.object as? NSWindow }
            .receive(on: RunLoop.main)
            .sink { window in
                print("didUpdateNotification \(window.title)")
                self.updateWindows()
            }
            .store(in: &notifications)
    }
    
    func updateWindows(ignore: NSWindow? = nil) {
        print("updateWindows")
        var result: [AppWindow] = []
        for window in NSApp.windows {
            print("windowNumber: \(window.windowNumber), title: \(window.title ?? "nil")")
            if ignore == nil || window.windowNumber != ignore!.windowNumber {
                let appWindow = AppWindow(
                    windowNumber: window.windowNumber,
                    title: window.title,
                    frame: window.frame
                )
                result.append(appWindow)
            }
        }
        self.onAppWindowsResized?(result)
    }
    
    deinit {
        notifications.forEach { $0.cancel() }
        notifications.removeAll()
    }
}
