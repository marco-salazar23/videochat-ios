//
//  RTCClient.swift
//  SwiftyWebRTC
//
//  Copyright © 2017 Ankit Aggarwal. All rights reserved.
//

import Foundation
import WebRTC

public class RTCClient: NSObject {
    typealias SDPObserver = (RTCSessionDescription?, Error?) -> Void
    
//    MARK:- Private properties
    fileprivate var iceServers: [RTCIceServer] = []
    fileprivate var peerConnection: RTCPeerConnection?
    fileprivate var connectionFactory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()
    fileprivate var audioTrack: RTCAudioTrack? // Save instance to be able to mute the call
    fileprivate var remoteIceCandidates: [RTCIceCandidate] = []
    fileprivate var isVideoCall = true
    
    public weak var delegate: RTCClientDelegate?
    
    fileprivate let audioCallConstraint = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio" : "true"],
                                                              optionalConstraints: nil)
    fileprivate let videoCallConstraint = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio" : "true", "OfferToReceiveVideo": "true"],
                                                              optionalConstraints: nil)
    private var callConstraint : RTCMediaConstraints {
        return self.isVideoCall ? self.videoCallConstraint : self.audioCallConstraint
    }
    
    fileprivate let defaultConnectionConstraint = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement": "true"])
    
    fileprivate var mediaConstraint: RTCMediaConstraints {
        let constraints = ["minWidth": "0", "minHeight": "0", "maxWidth" : "480", "maxHeight": "640"]
        return RTCMediaConstraints(mandatoryConstraints: constraints, optionalConstraints: nil)
    }
    
    private var state: RTCClientState = .connecting {
        didSet {
            self.delegate?.rtcClient(client: self, didChangeState: state)
        }
    }
    
    private var isCreatingRoom = false
    
    //MARK:- View life cycle
    public override init() {
        super.init()
    }
    
    public convenience init(iceServers: [RTCIceServer], videoCall: Bool = true) {
        self.init()
        self.iceServers = iceServers
        self.isVideoCall = videoCall
        self.configure()
    }
    
    deinit {
        guard let peerConnection = self.peerConnection else {
            return
        }
        if let stream = peerConnection.localStreams.first {
            audioTrack = nil
            peerConnection.remove(stream)
        }
    }
    
    public func configure() {
        initialisePeerConnectionFactory()
        initialisePeerConnection()
    }
    
    
    //MARK:- Public API
    public func startConnection() {
        guard let peerConnection = self.peerConnection else {
            return
        }
        self.state = .connecting
        let localStream = self.localStream()
        peerConnection.add(localStream)
        if let localVideoTrack = localStream.videoTracks.first {
            self.delegate?.rtcClient(client: self, didReceiveLocalVideoTrack: localVideoTrack)
        }
    }
    
    public func disconnect() {
        guard let peerConnection = self.peerConnection else {
            return
        }
        peerConnection.close()
        if let stream = peerConnection.localStreams.first {
            audioTrack = nil
            peerConnection.remove(stream)
        }
        isCreatingRoom = false
        self.delegate?.rtcClient(client: self, didChangeState: .disconnected)
    }
    
    public func makeOffer() {
        guard let peerConnection = self.peerConnection else {
            return
        }
        isCreatingRoom = true
        peerConnection.offer(for: callConstraint, completionHandler: createOfferObserver)
    }
    
    public func createAnswerForOfferReceived(withRemoteSDP remoteSdp: RTCSessionDescription?) {
        guard let sessionDescription = remoteSdp,
            let peerConnection = self.peerConnection else {
                return
        }
        // Add remote description
        peerConnection.setRemoteDescription(sessionDescription, completionHandler: remoteDescriptionObserver)
        
    }
    
    public func addIceCandidate(iceCandidate: RTCIceCandidate) {
        // Set ice candidate after setting remote description
        if self.peerConnection?.remoteDescription != nil {
            self.peerConnection?.add(iceCandidate)
        } else {
            self.remoteIceCandidates.append(iceCandidate)
        }
    }
    
    public func muteCall(_ mute: Bool) {
        self.audioTrack?.isEnabled = !mute
    }
    
    //MARK:- Observers
    
    lazy var createOfferObserver: SDPObserver = { [weak self] (sdp, error) in
        guard let self = self else { return }
        if let error = error {
            self.delegate?.rtcClient(client: self, didReceiveError: error)
        }
        else {
            self.handleSdpGenerated(sdpDescription: sdp)
        }
    }
    
    lazy var localDescriptionObserver: ((Error?) -> Void) = { [weak self] (error) in
        guard let self = self, let error = error else { return }
        self.delegate?.rtcClient(client: self, didReceiveError: error)
    }
    
    lazy var remoteDescriptionObserver: ((Error?) -> Void) = { [weak self] (error) in
        guard let self = self else { return }
        if let error = error {
            self.delegate?.rtcClient(client: self, didReceiveError: error)
        } else {
            self.handleRemoteDescriptionSet()
            // create answer
            self.peerConnection?.answer(for: self.callConstraint, completionHandler: self.createAnswerObserver)
        }
    }
    
    lazy var createAnswerObserver: SDPObserver = { [weak self] (sdp, error) in
        guard let self = self else { return }
        if let error = error {
            self.delegate?.rtcClient(client: self, didReceiveError: error)
        } else {
            self.handleAnswerReceived(sdpDescription: sdp)
            self.state = .connected
        }
    }
    
    lazy var handleAnswerObserver: ((Error?) -> Void) = { [weak self] (error) in
        guard let self = self else { return }
        if let error = error {
            self.delegate?.rtcClient(client: self, didReceiveError: error)
        } else {
            self.handleRemoteDescriptionSet()
            self.state = .connected
        }
    }
    
}

//MARK:- Helpers
private extension RTCClient {
    func handleRemoteDescriptionSet() {
        for iceCandidate in self.remoteIceCandidates {
            self.peerConnection?.add(iceCandidate)
        }
        self.remoteIceCandidates = []
    }
    
    // Generate local stream and keep it live and add to new peer connection
    func localStream() -> RTCMediaStream {
        let factory = self.connectionFactory
        let localStream = factory.mediaStream(withStreamId: "RTCmS")
        
        if self.isVideoCall {
            if !AVCaptureState.isVideoDisabled {
                let videoSource: RTCVideoSource = factory.videoSource()
                let capturer = RTCCameraVideoCapturer(delegate: videoSource)
                self.delegate?.rtcClient(client: self, didCreateLocalCapturer: capturer)
                let videoTrack = factory.videoTrack(with: videoSource, trackId: "RTCvS0")
                videoTrack.isEnabled = true
                localStream.addVideoTrack(videoTrack)
            } else {
                // show alert for video permission disabled
                let error = NSError.init(domain: RTCErrorDomain.videoPermissionDenied, code: 0, userInfo: nil)
                self.delegate?.rtcClient(client: self, didReceiveError: error)
            }
        }
        
        if !AVCaptureState.isAudioDisabled {
            let audioTrack = factory.audioTrack(withTrackId: "RTCaS0")
            self.audioTrack = audioTrack
            localStream.addAudioTrack(audioTrack)
        } else {
            // show alert for audio permission disabled
            let error = NSError.init(domain: RTCErrorDomain.audioPermissionDenied, code: 0, userInfo: nil)
            self.delegate?.rtcClient(client: self, didReceiveError: error)
        }
        return localStream
    }
    
    func initialisePeerConnectionFactory () {
        RTCPeerConnectionFactory.initialize()
        self.connectionFactory = RTCPeerConnectionFactory()
    }
    
    func initialisePeerConnection () {
        let configuration = RTCConfiguration()
        configuration.iceServers = self.iceServers
        self.peerConnection = self.connectionFactory.peerConnection(with: configuration,
                                                                    constraints: self.defaultConnectionConstraint,
                                                                    delegate: self)
    }
    
    func handleSdpGenerated(sdpDescription: RTCSessionDescription?) {
        
        guard let sdpDescription = sdpDescription  else {
            return
        }
        // set local description
        self.peerConnection?.setLocalDescription(sdpDescription, completionHandler: localDescriptionObserver)
        
        //  Signal to server to pass this sdp with for the session call
        self.delegate?.rtcClient(client: self, startCallWithSdp: sdpDescription)
        
    }
    
    
    func handleAnswerReceived(sdpDescription: RTCSessionDescription?) {
        
        guard let sdpDescription = sdpDescription  else {
            return
        }
        if isCreatingRoom {
            // set local description
            peerConnection?.setRemoteDescription(sdpDescription, completionHandler: handleAnswerObserver)
        } else {
            peerConnection?.setLocalDescription(sdpDescription, completionHandler: localDescriptionObserver)
            self.delegate?.rtcClient(client: self, createdAnswer: sdpDescription)
        }
        
    }
}


//MARK:- RTCPeerConnectionDelegate
extension RTCClient: RTCPeerConnectionDelegate {
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if stream.videoTracks.count > 0 {
            self.delegate?.rtcClient(client: self, didReceiveRemoteVideoTrack: stream.videoTracks[0])
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        
    }
    
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        self.delegate?.rtcClient(client: self, didChangeConnectionState: newState)
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        self.delegate?.rtcClient(client: self, didGenerateIceCandidate: candidate)
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        
    }
}
