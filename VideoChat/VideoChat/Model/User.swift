//
//  User.swift
//  VideoChat
//
//  Created by Marco Salazar Acosta on 4/2/20.
//  Copyright © 2020 Avantica Technologies. All rights reserved.
//

import Foundation
import Firebase

struct User: Codable {
    let username: String?
    let platform: String?
    let id: String
    
    init(document: QueryDocumentSnapshot) {
        let data = document.data()
        username = data[Constants.User.username] as? String
        platform = data[Constants.User.platform] as? String
        id = document.documentID
    }
    
    init?(document: DocumentSnapshot) {
        if let data = document.data() {
            username = data[Constants.User.username] as? String
            platform = data[Constants.User.platform] as? String
            id = document.documentID
        } else {
            return nil
        }
    }
}
