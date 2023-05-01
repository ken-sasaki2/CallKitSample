//
//  CallCenter.swift
//  CallKitSample
//
//  Created by sasaki.ken on 2023/04/28.
//

import CallKit
import AVFoundation

final class CallCenter {
    
    private let controller = CXCallController()
    private let provider: CXProvider
    private var uuid = UUID()
    
    
    init(supportsVideo: Bool) {
        let providerConfiguration = CXProviderConfiguration()
        providerConfiguration.supportsVideo = supportsVideo // ビデオのサポートはどうか
        providerConfiguration.maximumCallGroups = 1 // 通話グループの人数
        providerConfiguration.includesCallsInRecents = true // システムに通話履歴を残すかどうか
        
        provider = CXProvider(configuration: providerConfiguration)
    }
    
    
    func setUp(_ delegate: CXProviderDelegate) {
        provider.setDelegate(delegate, queue: nil)
    }
    
    
    func startCall(_ isVideo: Bool) {
        uuid = UUID()
        let handle = CXHandle(type: .generic, value: "自分")
        let starCallAction = CXStartCallAction(call: uuid, handle: handle)
        starCallAction.isVideo = isVideo
        let transaction = CXTransaction(action: starCallAction)
        
        controller.request(transaction) { error in
            if let error = error {
                print("Error CXStartCallAction: \(error.localizedDescription)")
            }
        }
    }

    
    func incomingCall(_ hasVideo: Bool = false) {
        uuid = UUID()
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "発信者")
        update.hasVideo = hasVideo
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("Error reportNewIncomingCall: \(error.localizedDescription)")
            }
        }
    }
    
    
    func endCall() {
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        
        controller.request(transaction) { error in
            if let error = error {
                print("Error CXEndCallAction: \(error.localizedDescription)")
            }
        }
    }
    
    
    func connecting() {
        provider.reportOutgoingCall(with: uuid, startedConnectingAt: nil)
    }
    
    
    func connected() {
        provider.reportOutgoingCall(with: uuid, connectedAt: nil)
    }
    
    
    func ConfigureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            AVAudioSession.Category.playAndRecord,
            mode: .voiceChat,
            options: []
        )
    }
}
