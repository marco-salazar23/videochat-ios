//
//  HomeViewModel.swift
//  VideoChat
//
//  Created by Marco Salazar Acosta on 4/2/20.
//  Copyright © 2020 Avantica Technologies. All rights reserved.
//

import Foundation
import Firebase
import Combine

final class HomeViewModel: ObservableObject {
    private let db: Firestore
    
    @Published var username: String? = ""
    @Published var users:[User] = []
    @Published var call: Call?
    @Published var isUserBusy: Bool = false
    private var currentUser: User?
    private var uuid: String = ""
    private var busyChecker = BusyChecker()
    
    init() {
        db = Firestore.firestore()
        checkUsername()
        
    }
    
    func set(username: String) {
        if uuid.isEmpty {
            checkUsername()
        }
        let username = [Constants.User.username: username,
                        Constants.User.platform: Constants.User.platformName]
        db.collection(Constants.User.collection).document(uuid).setData(username, merge: true)
        getUsers()
        getCalls()
        
    }
    
    func call(user: User) {
        busyChecker.clear()
        
        db.collection(Constants.Call.collection)
            .whereField(Constants.Call.origin, isEqualTo: user.id)
            .getDocuments { [weak self] (documentSnapshot, error) in
                if let error = error {
                    print(error.localizedDescription)
                }
                guard let self = self,
                    let document = documentSnapshot else {
                        return
                }
                self.busyChecker.isOriginChecked = true
                self.busyChecker.isOriginBusy = !document.isEmpty
                self.checkIsBusy(user)
        }
        
        db.collection(Constants.Call.collection)
            .whereField(Constants.Call.destination, isEqualTo: user.id)
            .getDocuments { [weak self] (documentSnapshot, error) in
                if let error = error {
                    print(error.localizedDescription)
                }
                guard let self = self,
                    let document = documentSnapshot else {
                        
                        return
                }
                self.busyChecker.isDestinationChecked = true
                self.busyChecker.isDestinationBusy = !document.isEmpty
                self.checkIsBusy(user)
                
        }
        
    }
    
    //MARK:- Private helpers
    private func checkUsername() {
        if let uuid = UIDevice.current.identifierForVendor?.uuidString {
            self.uuid = uuid
            db.collection(Constants.User.collection).document(uuid).getDocument {[weak self] (documentSnapshot, error) in
                if let error = error {
                    print(error.localizedDescription)
                }
                guard let document = documentSnapshot, document.exists else {
                    self?.username = nil
                    return
                }
                if let user = User(document: document), let username = user.username {
                    self?.username = username
                    self?.currentUser = user
                    self?.getUsers()
                    self?.getCalls()
                    
                } else {
                    self?.username = nil
                    
                }
            }
        }
    }
    
    private func getUsers() {
        db.collection(Constants.User.collection).addSnapshotListener { [weak self] (querySnapshot, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            guard let snapshot = querySnapshot else { return }
            
            self?.users = snapshot.documents.compactMap({
                let user = User(document: $0)
                return user.id == self?.uuid ? nil : user
            })
            
        }
    }
    
    private func getCalls(){
        db.collection(Constants.Call.collection)
            .whereField(Constants.Call.destination, isEqualTo: uuid)
            .addSnapshotListener { [weak self] (documentSnapshot, error) in
                if let error = error {
                    print(error.localizedDescription)
                }
                
                guard let self = self,
                    let snapshot = documentSnapshot else { return }
                
                snapshot.documentChanges.forEach( {
                    if $0.type == .removed {
                        self.call = nil
                    } else {
                        
                        let callerData = $0.document.data()
                        let callerId = callerData[Constants.Call.origin] as? String ?? ""
                        
                        if let user = self.users.filter({ $0.id == callerId }).first, self.currentUser != nil{
                            self.call = Call(id: $0.document.documentID, roomId:callerId,  type: .incoming, origin: user, destination: self.currentUser!)
                        }
                        
                    }
                })
        }
    }
    
    private func checkIsBusy(_ user: User) {
        if (busyChecker.isCheckDone) {
            if (busyChecker.isUserBusy) {
                isUserBusy = true
            } else {
                let callInfo = [Constants.Call.origin: uuid,
                                Constants.Call.destination : user.id]
                
                let document = db.collection(Constants.Call.collection).document()
                document.setData(callInfo)
                
                if let currentUser = currentUser {
                    call = Call(id: document.documentID, roomId: uuid, type: .outgoing, origin: currentUser, destination: user)
                }
            }
        }
    }
    
    
    
}
//MARK:- Helper
extension HomeViewModel {
    private struct BusyChecker {
        var isOriginChecked = false
        var isDestinationChecked = false
        var isOriginBusy = false
        var isDestinationBusy = false
        
        mutating func clear() {
            isOriginChecked = false
            isDestinationChecked = false
            isOriginBusy = false
            isDestinationBusy = false
        }
        
        var isUserBusy: Bool {
            isOriginBusy || isDestinationBusy
        }
        
        var isCheckDone: Bool {
            isOriginChecked && isDestinationChecked
        }
        
    }
}
