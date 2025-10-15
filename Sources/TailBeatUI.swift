//
//  TailBeatUI.swift
//  TailBeatKit
//
//  Created by Stephan Arenswald on 13.10.25.
//


import Foundation
import Observation
import SwiftUI

@MainActor
public final class TailBeatUI: ObservableObject {
    public static let shared = TailBeatUI()
    
    func resize(windowNumber: Int, to frame: NSRect) {
        if let w = NSApp.windows.first(where: { $0.windowNumber == windowNumber }) {
            w.setFrame(frame, display: true)
        }
    }
    
    func makeKey(windowNumber: Int) {
        if let w = NSApp.windows.first(where: { $0.windowNumber == windowNumber}) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
        }
    }
}
