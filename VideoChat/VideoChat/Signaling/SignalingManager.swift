//
//  SignalingManager.swift
//  VideoChat
//
//  Created by Marco Salazar Acosta on 3/30/20.
//  Copyright © 2020 Avantica Technologies. All rights reserved.
//

import Foundation
import WebRTC
import Firebase

protocol SignalingManagerProtocol {
    func signalingManagerGot(remoteDescription description: RTCSessionDescription)
    func signalingManagerGot(remoteIceCandidate candidate: RTCIceCandidate)
    func signalingManagerGot(remoteOffer offer: RTCSessionDescription)
}

extension RTCSdpType {
    var description: String {
        switch self {
        case .answer: return "answer"
        case .offer:  return "offer"
        case .prAnswer: return "prAnswer"
        default: return String(describing: self)
        }
    }
}

final class SignalingManager {
    private let delegate: SignalingManagerProtocol
    private let db: Firestore
    private let iOSRoom: DocumentReference
    private var iOSCalleeCandidatesCollection: CollectionReference?
    /*
     * Holds a reference to the ICE candidates
     * It's callerCandidates when the app makes the offer (creates room)/
     * It's calleeCandidates when the app joins a room.
     * */
    private  var candidatesCollection: CollectionReference?
    private  var currentRoom: DocumentReference?
    
    private var pendingCandidates:[RTCIceCandidate] = []
    
    
    init(delegate: SignalingManagerProtocol, identifier: String) {
        self.delegate = delegate
        db = Firestore.firestore()
        
        iOSRoom = db.collection(Constants.Room.collection).document(identifier);
        iOSCalleeCandidatesCollection = iOSRoom.collection(Constants.Offer.calleeCandidates);
    }
    
    func createOffer(sdp: RTCSessionDescription) {
        candidatesCollection = iOSRoom.collection(Constants.Offer.callerCandidates)
        
        let offer = [ Constants.Offer.type: sdp.type.description,
                      Constants.Offer.description: sdp.sdp,
        ]
        let offerInfo = [Constants.Offer.offer: offer]
        iOSRoom.setData(offerInfo)
        
        // Listening for remote session description below
        iOSRoom.addSnapshotListener {[weak self] (doc, error) in
            
            if let error = error {
                print(error.localizedDescription)
                return
            }
            guard let self = self,
                let document = doc,
                document.exists,
                let data = document.data(),
                let answer = data[Constants.Offer.answer] as? [String : Any] else { return }
            
            if let sdp = answer[Constants.Offer.description] as? String {
                let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)
                self.delegate.signalingManagerGot(remoteDescription: sessionDescription)
            }
        }
        
        // Listen for remote ICE candidates below
        iOSCalleeCandidatesCollection?.addSnapshotListener({ (querySnapshot, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            querySnapshot?.documentChanges.forEach({[weak self] change in
                if (change.type == .added) {
                    print("\(#file) \(#function)")
                    let data = change.document.data()
                    if let sdp = data[Constants.Offer.candidate] as? String,
                        let sdpMid = data[Constants.Offer.mid] as? String,
                        let sdpMLineIndex = data[Constants.Offer.mLineIndex] as? Int32 {
                        
                        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                        self?.delegate.signalingManagerGot(remoteIceCandidate: candidate)
                    }
                    
                }
            })
        })
        
    }
    
    
    func add(candidate: RTCIceCandidate) {
        
        if candidatesCollection == nil {
            pendingCandidates.append(candidate)
            
        } else if pendingCandidates.isEmpty {
            handle(candidate: candidate)
            
        } else {
            pendingCandidates.append(candidate)
            pendingCandidates.forEach({ handle(candidate: $0) })
            pendingCandidates.removeAll()
        }
        
    }
    
    private func handle(candidate: RTCIceCandidate) {
        
        let candidateInfo = [
            Constants.Offer.candidate: candidate.sdp,
            Constants.Offer.mLineIndex: candidate.sdpMLineIndex,
            Constants.Offer.mid: candidate.sdpMid ?? ""
            ] as [String : Any]
        candidatesCollection?.addDocument(data: candidateInfo)
    }
    
    
    
    func join(room: String) {
        print("\(#function) \(room)")
        currentRoom = db.collection(Constants.Room.collection).document(room);
        currentRoom?.getDocument(completion: { [weak self] (documentSnapshot, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            guard let self = self, let document = documentSnapshot else { return }
            
            if document.exists {
                self.candidatesCollection = self.currentRoom?.collection(Constants.Offer.calleeCandidates)
                let data = document.data()
                let offer = data?[Constants.Offer.offer] as? [String : Any]
                if let sdp = offer?[Constants.Offer.description] as? String {
                    let remoteOffer = RTCSessionDescription(type: .offer, sdp: sdp)
                    self.delegate.signalingManagerGot(remoteOffer: remoteOffer)
                }
                
                let callerReference = self.currentRoom?.collection(Constants.Offer.callerCandidates)
                callerReference?.addSnapshotListener({ (querySnapshot, error) in
                    if let error = error {
                        print(error.localizedDescription)
                        return
                    }
                    
                    querySnapshot?.documentChanges.forEach({[weak self] change in
                        if change.type == .added {
                            let data = change.document.data()
                            if let sdp = data[Constants.Offer.candidate] as? String,
                                let sdpMid = data[Constants.Offer.mid] as? String,
                                let sdpMLineIndex = data[Constants.Offer.mLineIndex] as? Int32 {
                                
                                let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                                self?.delegate.signalingManagerGot(remoteIceCandidate: candidate)
                            }
                            
                        }
                        
                    })
                    
                })
                
            }
        })
        
    }
    
    func update(answer: RTCSessionDescription) {
        
        let answer = [
            Constants.Offer.type : answer.type.description,
            Constants.Offer.description: answer.sdp
        ]
        let roomWithAnswer = [Constants.Offer.answer: answer]
        
        currentRoom?.updateData(roomWithAnswer)
    }
    
    
    func finishCall(){
        iOSRoom.delete()
    }
}
