//
//  CallViewModel.swift
//  VideoChat
//
//  Created by Marco Salazar Acosta on 4/2/20.
//  Copyright © 2020 Avantica Technologies. All rights reserved.
//

import Foundation
import Combine
import WebRTC
import Firebase

final class CallViewModel {
    private let db: Firestore
    private var signalingClient: SignalingManager?
    private var videoClient:  RTCClient?
    
    @Published var localVideoTrack: RTCVideoTrack?
    @Published var remoteVideoTrack: RTCVideoTrack?
    @Published var captureController: RTCCapturer?
    @Published var state: RTCClientState = .disconnected
    
    init(userId: String) {
        db = Firestore.firestore()
        signalingClient = SignalingManager(delegate: self, identifier: userId)
        listenCallsFrom(user: userId)
        configureVideoClient()
    }
    
    private func configureVideoClient() {
        let iceServers = [RTCIceServer(urlStrings: Constants.stunServers)]
        let client = RTCClient(iceServers: iceServers, videoCall: true)
        client.delegate = self
        self.videoClient = client
        client.startConnection()
    }
    
    func reject(call: Call) {
        finish(call: call)
    }
    
    func accept(call: Call) {
        signalingClient?.join(room: call.roomId)
    }
    
    func makeCall() {
        videoClient?.makeOffer()
    }
    
    func end(call: Call){
        finish(call: call)
    }
    
}

extension CallViewModel {
    
    private func finish(call: Call) {
        db.collection(Constants.Call.collection).document(call.id).delete {[weak self] _ in
            self?.signalingClient?.finishCall()
            self?.videoClient?.disconnect()
        }
    }
    
    private func listenCallsFrom(user: String){
        db.collection(Constants.Call.collection).whereField(Constants.Call.origin, isEqualTo: user).addSnapshotListener { [weak self] (documentSnapshot, error) in
            if let error = error {
                print(error.localizedDescription)
            }
            
            guard let self = self,
                let snapshot = documentSnapshot else { return }
            
            snapshot.documentChanges.forEach( {
                if $0.type == .removed {
                    self.signalingClient?.finishCall()
                    self.state = .disconnected
                }
            })
        }
    }
}

extension CallViewModel: RTCClientDelegate {
    func rtcClient(client : RTCClient, startCallWithSdp sdp: RTCSessionDescription) {
        signalingClient?.createOffer(sdp: sdp)
    }
    
    func rtcClient(client: RTCClient, createdAnswer answer: RTCSessionDescription) {
        print("\(#file) \(#function)")
        signalingClient?.update(answer: answer)
    }
    
    func rtcClient(client : RTCClient, didReceiveLocalVideoTrack localVideoTrack: RTCVideoTrack) {
        self.localVideoTrack = localVideoTrack
    }
    
    func rtcClient(client : RTCClient, didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack) {
        self.remoteVideoTrack = remoteVideoTrack
    }
    
    func rtcClient(client : RTCClient, didReceiveError error: Error) {

    }
    
    func rtcClient(client : RTCClient, didChangeConnectionState connectionState: RTCIceConnectionState) {
        if connectionState == .disconnected {
            client.disconnect()
        } else if connectionState == .connected {
            state = .connected
        }
    }
    
    func rtcClient(client : RTCClient, didChangeState state: RTCClientState) {
        self.state = state
    }
    
    func rtcClient(client : RTCClient, didGenerateIceCandidate iceCandidate: RTCIceCandidate) {
        signalingClient?.add(candidate: iceCandidate)
    }
    
    func rtcClient(client : RTCClient, didCreateLocalCapturer capturer: RTCCameraVideoCapturer) {
        
        let settingsModel = RTCCapturerSettingsModel()
        self.captureController = RTCCapturer.init(withCapturer: capturer, settingsModel: settingsModel)
    }
    
}


extension CallViewModel: SignalingManagerProtocol {
    func signalingManagerGot(remoteDescription description: RTCSessionDescription) {
        videoClient?.createAnswerForOfferReceived(withRemoteSDP: description)
    }
    
    func signalingManagerGot(remoteIceCandidate candidate: RTCIceCandidate) {
        videoClient?.addIceCandidate(iceCandidate: candidate)
    }
    
    func signalingManagerGot(remoteOffer offer: RTCSessionDescription) {
        videoClient?.createAnswerForOfferReceived(withRemoteSDP: offer)
    }
    
    
}
