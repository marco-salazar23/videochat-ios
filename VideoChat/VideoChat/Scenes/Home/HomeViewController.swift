//
//  HomeViewController.swift
//  VideoChat
//
//  Created by Marco Salazar Acosta on 3/31/20.
//  Copyright © 2020 Avantica Technologies. All rights reserved.
//

import UIKit
import Firebase
import Combine


final class HomeViewController: UIViewController {
    
    @IBOutlet private var tableView: UITableView!
    private let viewModel = HomeViewModel()
    

    private var cancelBag = CancelBag()
    override func viewDidLoad() {
        super.viewDidLoad()
        cancelBag.collect {
            viewModel.$username.sink(receiveValue: { [weak self] username in
                if let username = username {
                    self?.title = "Welcome \(username)"
                    
                } else {
                    DispatchQueue.main.async {
                        self?.askUsername()
                    }
                }
            })
            
            viewModel.$users.sink(receiveValue: { [weak self] _ in
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            })
            
            viewModel.$call.sink(receiveValue: { [weak self] call in
                if call != nil {
                    DispatchQueue.main.async {
                        self?.handle(call: call!)
                    }
                }
            })
            
            viewModel.$isUserBusy.sink(receiveValue: { [weak self] isBusy in
                if isBusy {
                    self?.showUserBusy()
                }
            })
            
        }
    }
    
    deinit {
        cancelBag.forEach({ $0.cancel() })
    }
    
    private func askUsername() {
        let alert = UIAlertController(title: "Username", message: "Write an username", preferredStyle: .alert)
        alert.addTextField { textfield in
            textfield.placeholder = "Username"
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {[weak self] _ in
            if let username = alert.textFields?.first?.text {
                self?.viewModel.set(username: username)
            } else {
                self?.askUsername()
            }
            
        }))
        present(alert, animated: true, completion: nil)
    }
    
    private func handle(call: Call) {
        let vc = CallViewController.instantiate(with: call)
        present(vc, animated: true, completion: nil)
    
    }
    
    private func showUserBusy() {
        let alert = UIAlertController(title: "Sorry", message: "The user is unavailable at the moment.\nPlease try again later.", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

//MARK:- UITableViewDataSource
extension HomeViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = viewModel.users[indexPath.row].username
        cell.detailTextLabel?.text = viewModel.users[indexPath.row].platform
        return cell
    }
}

//MARK:- UITableViewDelegate
extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.call(user: viewModel.users[indexPath.row])
    }
}
