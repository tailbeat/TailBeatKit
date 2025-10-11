//
//  AppInfo.swift
//  TailBeatKit
//
//  Created by Stephan Arenswald on 10.10.25.
//

public struct AppInfo: Codable, Sendable {
    let schemaVersion: Int = 1
    
    public let name: String
    public let bundleId: String?
    public let version: String
    public let build: String
    public let localizations: Array<String>
    
    init(name: String, bundleId: String?, version: String, build: String, localizations: [String]) {
        self.name = name
        self.bundleId = bundleId
        self.version = version
        self.build = build
        self.localizations = localizations
    }
}
