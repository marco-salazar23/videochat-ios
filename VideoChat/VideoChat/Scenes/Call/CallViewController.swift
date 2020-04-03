//
//  CallViewController.swift
//  VideoChat
//
//  Created by Marco Salazar Acosta on 4/1/20.
//  Copyright © 2020 Avantica Technologies. All rights reserved.
//

import UIKit
import Combine
import WebRTC

final class CallViewController: UIViewController {
    
    @IBOutlet private var contactView: UIView!
    @IBOutlet private var contactActionsView: UIStackView!
    @IBOutlet private var contactLabel: UILabel!
    @IBOutlet private var contactActivity: UIActivityIndicatorView!
    @IBOutlet private var localView: RTCEAGLVideoView!
    @IBOutlet private var remoteView: RTCEAGLVideoView!
    
    private var call: Call!
    private var viewModel: CallViewModel!
    private var cancelBag = CancelBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if call.type == .incoming {
            contactLabel.text = "\(call.origin.username ?? "") wants to connect with you"
            contactActivity.isHidden = true
            contactActionsView.isHidden = false
        } else {
            contactLabel.text = "Connecting with \(call.destination.username ?? "")"
            contactActivity.isHidden = false
            contactActionsView.isHidden = true
            viewModel.makeCall()
        }
    
        cancelBag.collect {
            viewModel.$localVideoTrack.sink { [weak self] videoTrack in
                if let videoTrack = videoTrack,
                    let localView = self?.localView{
                    DispatchQueue.main.async {
                        videoTrack.add(localView)
                    }
                    
                }
            }
            
            viewModel.$remoteVideoTrack.sink { [weak self] videoTrack in
                if let videoTrack = videoTrack,
                    let remoteView = self?.remoteView {
                    DispatchQueue.main.async {
                        videoTrack.add(remoteView)
                    }
                    
                }
            }
            
            viewModel.$captureController.sink { capturer in
                DispatchQueue.main.async {
                    capturer?.startCapture()
                }
            }
            
            viewModel.$state.sink { [weak self] state in
                
                switch state {
                case .disconnected:
                    DispatchQueue.main.async {
                        self?.dismiss(animated: true, completion: nil)
                    }
                    
                case .connected:
                    DispatchQueue.main.async {
                        self?.contactView.isHidden = true
                    }
                case .connecting:
                    break
                }
                
            }
        }
        
    }
    
    deinit {
        cancelBag.forEach({ $0.cancel() })
    }
    
    
    @IBAction private func accept() {
        contactActionsView.isHidden = true
        contactActivity.isHidden = false
        viewModel.accept(call: call)
    }
    
    @IBAction private func reject() {
        viewModel.reject(call: call)
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction private func endCall() {
        viewModel.end(call: call)
    }
    
}

extension CallViewController {
    static func instantiate(with call: Call) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CallViewController") as! CallViewController
        vc.call = call
        vc.viewModel = CallViewModel(userId: call.currentUserId)
        return vc
    }
}





