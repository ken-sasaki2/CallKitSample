//
//  ViewController.swift
//  CallKitSample
//
//  Created by sasaki.ken on 2023/04/28.
//

import UIKit
import CallKit
import AVFoundation
import SkyWay

final class ViewController: UIViewController {
    @IBOutlet weak var remoteView: SKWVideo!
    @IBOutlet weak var localView: SKWVideo!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var endButton: UIButton!
    
    private let callCenter = CallCenter(supportsVideo: true)
    
    private let apiKey = "f957505e-0ce1-491f-95fe-1cfa04050629"
    private let domain = "localhost"
    
    private var peer: SKWPeer?
    private var localStream: SKWMediaStream?
    private var remoteStream: SKWMediaStream?
    private var dataConnection: SKWDataConnection?
    private var mediaConnection: SKWMediaConnection?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startButton.isEnabled = false
        endButton.isEnabled = false
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        checkPermissionAudio()
        checkPermissionCanera()
        callCenter.setUp(self)
        setUpPeer()
    }
    
    
    private func toggleConnectionStatusUI(_ connection: Bool) {
        if connection {
            startButton.isEnabled = false
            endButton.isEnabled = true
        } else {
            startButton.isEnabled = true
            endButton.isEnabled = false
        }
    }
    
    
    @IBAction func start(_ sender: UIButton) {
        guard let peer = self.peer else {
            return
        }
        
        showPeersDialog(peer) { peerID in
            self.callCenter.startCall(true)
            self.connect(peerID)
        }
    }
    
    
    @IBAction func end(_ sender: UIButton) {
        if mediaConnection != nil {
            dataConnection?.close()
            mediaConnection?.close()
            toggleConnectionStatusUI(false)
            callCenter.endCall()
        }
    }
}


// SkyWay
extension ViewController {
    
    private func setUpPeer() {
        let option = SKWPeerOption()
        option.key = apiKey
        option.domain = domain
        option.debug = .DEBUG_LEVEL_ERROR_AND_WARNING
        peer = SKWPeer(options: option)
        
        if let _peer = peer {
            setUpPeerEventCallBacks(_peer)
            setUpLocalStream(_peer)
        } else {
            let alert = UIAlertController(title: "エラー", message: "Peerの設定に失敗しました", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default)
            alert.addAction(action)
            present(alert, animated: true)
        }
    }
    
    
    private func setUpLocalStream(_ peer: SKWPeer) {
        SKWNavigator.initialize(peer)
        
        let constraints = SKWMediaConstraints()
        constraints.maxWidth = 540
        constraints.maxHeight = 960
        constraints.cameraPosition = .CAMERA_POSITION_FRONT
        
        localStream = SKWNavigator.getUserMedia(constraints)
        localStream?.addVideoRenderer(localView, track: 0)
    }
    
    
    private func call(_ targetId: String) {
        let option = SKWCallOption()
        if let _mediaConnection = peer?.call(withId: targetId, stream: localStream, options: option) {
            mediaConnection = _mediaConnection
            setUpMediaConnectionCallbacks(_mediaConnection)
        } else {
            print("Fail call:", targetId)
        }
    }
    
    
    private func connect(_ targetId: String) {
        let options = SKWConnectOption()
        options.serialization = .SERIALIZATION_BINARY
        
        if let dataConnection = peer?.connect(withId: targetId, options: options) {
            self.dataConnection = dataConnection
            setupDataConnectionCallbacks(dataConnection)
        } else {
            print("Fail connect data connection")
        }
    }
}


//  Peer Event CallBack
extension ViewController {
    
    private func setUpPeerEventCallBacks(_ peer: SKWPeer) {
        
        peer.on(.PEER_EVENT_OPEN) { object in
            if let peerId = object as? String {
                DispatchQueue.main.async {
                    self.toggleConnectionStatusUI(false)
                    print("my peerId:", peerId)
                }
            }
        }
        
        peer.on(.PEER_EVENT_ERROR) { object in
            if let error = object as? SKWPeerError {
                print("Error peer callback:", error)
            }
        }
        
        peer.on(.PEER_EVENT_CLOSE) { _ in
            // 相手との接続が切れた場合の処理（サンプルアプリなので処理しない）
        }
        
        peer.on(.PEER_EVENT_CALL) { object in
            if let connection = object as? SKWMediaConnection {
                self.mediaConnection = connection
                self.setUpMediaConnectionCallbacks(connection)
                self.mediaConnection?.answer(self.localStream)
            }
        }
        
        peer.on(.PEER_EVENT_CONNECTION) { object in
            if let connection = object as? SKWDataConnection {
                if self.dataConnection == nil {
                    self.callCenter.incomingCall(true)
                }
                self.dataConnection = connection
                self.setupDataConnectionCallbacks(connection)
            }
        }
    }
}


// Mediaconnection Event CallBack
extension ViewController {
    
    private func setUpMediaConnectionCallbacks(_ mediaConnection: SKWMediaConnection) {
        
        mediaConnection.on(.MEDIACONNECTION_EVENT_STREAM) { object in
            if let mediaStream = object as? SKWMediaStream {
                self.remoteStream = mediaStream
                
                DispatchQueue.main.async {
                    self.remoteStream?.addVideoRenderer(self.remoteView, track: 0)
                }
                
                self.toggleConnectionStatusUI(true)
                self.callCenter.connected()
            }
        }
        
        mediaConnection.on(.MEDIACONNECTION_EVENT_CLOSE) { object in
            if let _ = object as? SKWMediaConnection {
                DispatchQueue.main.async {
                    self.remoteStream?.removeVideoRenderer(self.remoteView, track: 0)
                    self.remoteStream = nil
                    self.dataConnection = nil
                    self.mediaConnection = nil
                }
            }
            self.toggleConnectionStatusUI(false)
            self.callCenter.endCall()
        }
        
        mediaConnection.on(.MEDIACONNECTION_EVENT_ERROR) { object in
            if let error = object as? Error {
                print("Mediaconnection event error:", error)
            }
        }
    }
}


// Data Connection CallBack
extension ViewController {
    
    func setupDataConnectionCallbacks(_ dataConnection: SKWDataConnection) {
        
        dataConnection.on(.DATACONNECTION_EVENT_OPEN) { _ in
            self.toggleConnectionStatusUI(true)
        }
        
        dataConnection.on(.DATACONNECTION_EVENT_CLOSE) { object in
            self.dataConnection = nil
            self.toggleConnectionStatusUI(false)
            self.callCenter.endCall()
        }
    }
}


// 現状最小限のDelegate
extension ViewController: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        
    }
    
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        callCenter.ConfigureAudioSession()
        callCenter.connecting()
        action.fulfill()
    }
    
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        callCenter.ConfigureAudioSession()
        if let peer = self.dataConnection?.peer {
            self.call(peer)
        }
        action.fulfill()
    }
    
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        self.dataConnection?.close()
        self.mediaConnection?.close()
        action.fulfill()
    }
}


// ダイアログ
extension ViewController {
    
    private func showPeersDialog(_ peer: SKWPeer, handler: @escaping (String) -> Void) {
        if mediaConnection == nil {
            peer.listAllPeers() { peers in
                if let peerIds = peers as? [String] {
                    if peerIds.count <= 1 {
                        let alert = UIAlertController(title: "確認", message: "接続先がありません", preferredStyle: .alert)
                        let action = UIAlertAction(title: "キャンセル", style: .cancel)
                        alert.addAction(action)
                        self.present(alert, animated: true)
                    } else {
                        let alert = UIAlertController(title: "確認", message: "接続先を選択してください", preferredStyle: .alert)
                        
                        peerIds.forEach { peerId in
                            // 自分以外のpeerIDなら
                            if peerId != peer.identity {
                                let defaultAction = UIAlertAction(title: peerId, style: .default) { _ in
                                    handler(peerId)
                                }
                                alert.addAction(defaultAction)
                            }
                        }
                        let cancelAnction = UIAlertAction(title: "キャンセル", style: .cancel)
                        alert.addAction(cancelAnction)
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
}


// マイク許可
extension ViewController {
    
    private func checkPermissionAudio() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { result in
                print("AVCaptureDevice permission status:", result)
            }
        case .restricted:
            let alert = UIAlertController(title: "制限", message: "マイクの使用に制限がかかっています", preferredStyle: .alert)
            let action = UIAlertAction(title: "設定を開く", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            alert.addAction(action)
            present(alert, animated: true)
        case .denied:
            let alert = UIAlertController(title: "マイクの許可", message: "マイクの使用を許可してください", preferredStyle: .alert)
            let action = UIAlertAction(title: "設定を開く", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            alert.addAction(action)
            present(alert, animated: true)
        case .authorized:
            return
        @unknown default:
            return
        }
    }
}


// カメラ許可
extension ViewController {
    
    private func checkPermissionCanera() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { result in
                print("AVCaptureDevice permission status:", result)
            }
        case .restricted:
            let alert = UIAlertController(title: "制限", message: "カメラの使用に制限がかかっています", preferredStyle: .alert)
            let action = UIAlertAction(title: "設定を開く", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            alert.addAction(action)
            present(alert, animated: true)
        case .denied:
            let alert = UIAlertController(title: "カメラの許可", message: "カメラの使用を許可してください", preferredStyle: .alert)
            let action = UIAlertAction(title: "設定を開く", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            alert.addAction(action)
            present(alert, animated: true)
        case .authorized:
            return
        @unknown default:
            return
        }
    }
}
