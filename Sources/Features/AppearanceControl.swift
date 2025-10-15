//
//  AppearanceControl.swift
//  TailBeatKit
//
//  Created by Stephan Arenswald on 15.10.25.
//

import AppKit

public enum Appearance: String, Codable, Sendable {
    case light
    case dark
}

class AppearanceControl {
    func change(to appearance: Appearance) {
        if appearance == .light {
            NSApp.appearance = NSAppearance(named: .aqua)
        } else {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
