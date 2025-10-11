//
//  TBMessage.swift
//  TailBeatKit
//
//  Created by Stephan Arenswald on 10.10.25.
//

public enum TailBeatClientMessage: Codable {
    case ack(String)
    case error(String)
    
    case log(TailBeatEvent)
    case environment(AppEnvironment)
    case info(AppInfo)
    case windows([AppWindow])
    case defaults([PrefPatch])
}

public enum TailBeatServerMessage: Codable {
    case ack(String)
    case error(String)
    
    case windowAsKeyRequest(Int)
    case windowResizeRequest(WindowResizeRequest)
    case envChangeRequest(AppEnvironment)
    case userDefaultsPatch([PrefPatch])
}
