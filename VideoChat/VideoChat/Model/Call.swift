//
//  Call.swift
//  VideoChat
//
//  Created by Marco Salazar Acosta on 4/2/20.
//  Copyright © 2020 Avantica Technologies. All rights reserved.
//

import Foundation

//MARK:- Call
struct Call {
    let id: String
    let roomId: String
    let type: CallType
    let origin: User
    let destination: User
    
    var currentUserId: String {
        switch type {
        case .incoming: return destination.id
        case .outgoing: return origin.id
        }
    }
}

//MARK:- CallType
enum CallType {
    case outgoing, incoming
}
