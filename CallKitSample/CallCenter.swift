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
    
    init(supportsVider: Bool) {
        let providerConfiguration1 = CXProviderConfiguration(localizedName: "CallKitSample") // localizedName（非推奨）はもしかして不要？
        let providerConfiguration2 = CXProviderConfiguration()
        providerConfiguration1.supportsVideo = supportsVider // ビデオのサポートはどうか
        providerConfiguration1.maximumCallGroups = 1 // 通話グループの人数
        providerConfiguration1.includesCallsInRecents = true // システムに通話履歴を残すかどうか
        
        provider = CXProvider(configuration: providerConfiguration1)
    }
    
    func setUp(_ delegate: CXProviderDelegate) {
        provider.setDelegate(delegate, queue: nil)
    }
    
    // 発信
    func startCall() {
        uuid = UUID()
        let handle = CXHandle(type: .generic, value: "Aさん")
        let starCallAction = CXStartCallAction(call: uuid, handle: handle)
        let transaction = CXTransaction(action: starCallAction)
        
        controller.request(transaction) { error in
            if let error = error {
                print("Error CXStartCallAction: \(error.localizedDescription)")
            }
        }
    }
    
    // 着信
    func incomingCall(_ hasVideo: Bool = false) {
        uuid = UUID()
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "Bさん")
        update.hasVideo = hasVideo
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("Error reportNewIncomingCall: \(error.localizedDescription)")
            }
        }
    }
    
    // 通話終了
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
