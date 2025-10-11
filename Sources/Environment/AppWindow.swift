//
//  AppWindow.swift
//  TailBeatKit
//
//  Created by Stephan Arenswald on 11.10.25.
//

import Foundation

public struct WindowResizeRequest: Hashable, Codable, Sendable {
    let schemaVersion: Int = 1
    
    public let windowNumber: Int
    public let frame: CGRect
    
    public init(windowNumber: Int, frame: CGRect) {
        self.windowNumber = windowNumber
        self.frame = frame
    }
}

public struct AppWindow: Hashable, Codable, Sendable {
    let schemaVersion: Int = 1
    
    public let windowNumber: Int
    public let title: String
    public let frame: CGRect
}
