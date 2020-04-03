//
//  Constants.swift
//  VideoChat
//
//  Created by Marco Salazar Acosta on 4/3/20.
//  Copyright © 2020 Avantica Technologies. All rights reserved.
//

import Foundation

struct Constants {
    static let stunServers = ["stun:stun1.l.google.com:19302","stun:stun2.l.google.com:19302"]
    
    struct Room {
        static let collection = "rooms"
    }
    
    struct Call {
        static let collection = "calls"
        static let origin = "origin"
        static let destination = "destination"
    }
    
    struct User {
        static let collection = "users"
        static let platform = "platform"
        static let username = "username"
        static let platformName = "iOS"
    }
    
    struct Offer {
        static let calleeCandidates = "calleeCandidates"
        static let callerCandidates = "callerCandidates"
        static let type = "type"
        static let description = "sdp"
        static let offer = "offer"
        static let answer = "answer"
        static let candidate = "candidate"
        static let mid = "sdpMid"
        static let mLineIndex = "sdpMLineIndex"
        
    }
}
