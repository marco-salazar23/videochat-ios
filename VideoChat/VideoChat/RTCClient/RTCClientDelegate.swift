//
//  RTCClientDelegate.swift
//  VideoChat
//
//  Created by Marco Salazar Acosta on 3/31/20.
//  Copyright © 2020 Avantica Technologies. All rights reserved.
//

import Foundation
import WebRTC

public protocol RTCClientDelegate: class {
    func rtcClient(client : RTCClient, startCallWithSdp sdp: RTCSessionDescription)
    func rtcClient(client : RTCClient, createdAnswer answer: RTCSessionDescription)
    func rtcClient(client : RTCClient, didReceiveLocalVideoTrack localVideoTrack: RTCVideoTrack)
    func rtcClient(client : RTCClient, didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack)
    func rtcClient(client : RTCClient, didReceiveError error: Error)
    func rtcClient(client : RTCClient, didChangeConnectionState connectionState: RTCIceConnectionState)
    func rtcClient(client : RTCClient, didChangeState state: RTCClientState)
    func rtcClient(client : RTCClient, didGenerateIceCandidate iceCandidate: RTCIceCandidate)
    func rtcClient(client : RTCClient, didCreateLocalCapturer capturer: RTCCameraVideoCapturer)
}

public extension RTCClientDelegate {
    // add default implementation to extension for optional methods
    func rtcClient(client : RTCClient, didReceiveError error: Error) {
        
    }
    
    func rtcClient(client : RTCClient, didChangeConnectionState connectionState: RTCIceConnectionState) {
        
    }
    
    func rtcClient(client : RTCClient, didChangeState state: RTCClientState) {
        
    }
}
