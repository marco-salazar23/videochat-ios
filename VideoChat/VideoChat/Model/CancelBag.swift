//
//  CancelBag.swift
//  VideoChat
//
//  Created by Marco Salazar Acosta on 4/2/20.
//  Copyright © 2020 Avantica Technologies. All rights reserved.
//

import Foundation
import Combine

/*
 Credits to https://gist.github.com/nalexn/33f14af1d163ea476ee499c0459824b2
 */
public typealias CancelBag = Set<AnyCancellable>

public extension CancelBag {
    mutating func collect(@Builder _ cancellables: () -> [AnyCancellable]) {
        formUnion(cancellables())
    }
    
    @_functionBuilder
    struct Builder {
        static func buildBlock(_ cancellables: AnyCancellable...) -> [AnyCancellable] {
            return cancellables
        }
    }
}
